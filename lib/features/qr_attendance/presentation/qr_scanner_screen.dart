import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/offline_punch_queue.dart';
import '../data/qr_attendance_repository.dart';
import '../domain/offline_punch.dart';
import '../domain/qr_models.dart';
import 'qr_attendance_providers.dart';
import 'qr_scanner_controller.dart';

enum _ScanState { scanning, reading, showingResult }

/// Full-screen QR / barcode attendance scanner. The camera runs continuously; a
/// decode that passes the re-arm gate pauses the camera, resolves the card and
/// shows a colour-coded result sheet that *covers* the preview (which structurally
/// prevents a re-decode while it is open). Every security decision is the server's;
/// this screen only drives the camera and renders the outcome.
class QrScannerScreen extends ConsumerWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(qrScannerConfigProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('QR Attendance'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ConfigError(message: ApiException.from(e).message, onRetry: () => ref.refresh(qrScannerConfigProvider)),
        data: (config) {
          if (!config.canMarkStudents && !config.canMarkStaff) {
            return const _ConfigError(
              message: 'You do not have permission to mark attendance by scanning.',
            );
          }
          return _ScannerView(config: config);
        },
      ),
    );
  }
}

class _ScannerView extends ConsumerStatefulWidget {
  final QrScannerConfig config;
  const _ScannerView({required this.config});

  @override
  ConsumerState<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends ConsumerState<_ScannerView> {
  late final MobileScannerController _camera;
  late final ScanArmGate _gate;
  final ScanTally _tally = ScanTally();

  _ScanState _state = _ScanState.scanning;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _gate = ScanArmGate(
      cooldown: Duration(seconds: widget.config.scanCooldownSeconds.clamp(1, 60)),
    );
    _camera = MobileScannerController(
      formats: _mapFormats(widget.config.allowedFormats),
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    // Drain anything left over from a previous offline session, and show the count.
    WidgetsBinding.instance.addPostFrameCallback((_) => _flush(silent: true));
  }

  OfflinePunchQueue get _queue => ref.read(offlinePunchQueueProvider);

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  QrAttendanceRepository get _repo => ref.read(qrAttendanceRepositoryProvider);

  // ── decode → gate → accept ─────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      final accept = _gate.offer(code, now, active: _state == _ScanState.scanning);
      if (accept) {
        _handleAccepted(code);
        break; // one card per frame
      }
    }
  }

  Future<void> _handleAccepted(String code) async {
    setState(() => _state = _ScanState.reading);
    await _camera.stop();

    try {
      final profile = await _repo.resolve(code);
      await _processProfile(profile);
    } on QrScanException catch (e) {
      // The server actively rejected the code (wrong school, signed-required, …).
      HapticFeedback.heavyImpact();
      _tally.record('rejected');
      await _showResultSheet(_ResultSheetData.denied(e.message));
    } catch (e) {
      final ex = ApiException.from(e);
      if (ex.isNetworkError) {
        await _handleOffline(code);
      } else {
        HapticFeedback.heavyImpact();
        await _showResultSheet(_ResultSheetData.denied(ex.message));
      }
    }

    if (mounted) {
      await _camera.start();
      setState(() => _state = _ScanState.scanning);
    }
  }

  /// Offline path: resolve() failed with no connection. A **signed** card still
  /// carries its type + id, so we can queue a punch for later; a plain code cannot
  /// be identified without the server and is refused.
  Future<void> _handleOffline(String code) async {
    final token = SignedToken.tryParse(code);
    if (token == null) {
      _toast('Offline: this card needs a connection to scan. Reconnect and try again.', error: true);
      return;
    }
    if (token.type == 'staff' && !widget.config.canMarkStaff) {
      _toast('Offline: you cannot queue staff attendance here.', error: true);
      return;
    }
    if (token.type == 'student' && !widget.config.canMarkStudents) {
      _toast('Offline: you cannot queue student attendance here.', error: true);
      return;
    }

    final ctx = await _capturePunchContext();
    if (ctx == null) return; // a location/device error already surfaced.

    await _queue.enqueue(PendingPunch(
      type: token.type,
      id: token.id,
      status: null, // offline can't show the manual picker; server derives status
      scannedAt: DateTime.now(),
      latitude: ctx.latitude,
      longitude: ctx.longitude,
      accuracy: ctx.accuracy,
      isMocked: ctx.isMocked,
      deviceUuid: ctx.deviceUuid,
    ));
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _pending += 1);
    await _showResultSheet(_ResultSheetData.queued(token.type, token.id));
  }

  Future<void> _processProfile(QrScanProfile profile) async {
    // Already complete → amber, nothing to do.
    if (profile.alreadyComplete) {
      HapticFeedback.mediumImpact();
      _tally.record('complete');
      await _showResultSheet(_ResultSheetData.info(profile, 'Attendance already complete for today.', Colors.amber.shade700));
      return;
    }

    // Not markable by this operator (out of scope, or view-only).
    if (!profile.canMark) {
      HapticFeedback.mediumImpact();
      await _showResultSheet(_ResultSheetData.info(
        profile,
        widget.config.isGate ? 'You cannot mark this record.' : 'This person is not in one of your classes.',
        Colors.blueGrey,
      ));
      return;
    }

    // Manual mode: let the operator pick a status before marking.
    if (!widget.config.autoAttendance) {
      await _showManualSheet(profile);
      return;
    }

    // Auto mode: capture location + punch straight away.
    await _punchAndShow(profile, status: null);
  }

  Future<void> _punchAndShow(QrScanProfile profile, {required String? status}) async {
    final ctx = await _capturePunchContext();
    if (ctx == null) return; // a location/device error already surfaced.

    try {
      final result = await _repo.punch(
        type: profile.type,
        id: profile.id,
        status: status,
        latitude: ctx.latitude,
        longitude: ctx.longitude,
        accuracy: ctx.accuracy,
        isMocked: ctx.isMocked,
        deviceUuid: ctx.deviceUuid,
      );
      HapticFeedback.lightImpact();
      _tally.record(result.action);
      await _showResultSheet(_ResultSheetData.success(profile, result));
      // Network is clearly up — opportunistically drain any offline backlog.
      unawaited(_flush(silent: true));
    } on QrScanException catch (e) {
      HapticFeedback.heavyImpact();
      _tally.record('rejected');
      await _showResultSheet(_ResultSheetData.denied(e.message, profile: profile));
    } catch (e) {
      final ex = ApiException.from(e);
      if (ex.isNetworkError) {
        // Lost connection between resolve and punch — queue it instead of losing it.
        await _queue.enqueue(PendingPunch(
          type: profile.type,
          id: profile.id,
          status: status,
          scannedAt: DateTime.now(),
          latitude: ctx.latitude,
          longitude: ctx.longitude,
          accuracy: ctx.accuracy,
          isMocked: ctx.isMocked,
          deviceUuid: ctx.deviceUuid,
        ));
        HapticFeedback.selectionClick();
        if (mounted) setState(() => _pending += 1);
        await _showResultSheet(_ResultSheetData.queued(profile.type, profile.id, name: profile.name));
      } else {
        HapticFeedback.heavyImpact();
        await _showResultSheet(_ResultSheetData.denied(ex.message, profile: profile));
      }
    }
  }

  /// Drain the offline queue. [silent] suppresses the "nothing happened" toast used
  /// by the opportunistic background flushes.
  Future<void> _flush({bool silent = false}) async {
    final FlushResult res = await _queue.flush();
    if (!mounted) return;
    setState(() => _pending = res.remaining);
    if (res.didAnything || !silent) {
      final parts = <String>[
        if (res.sent > 0) 'synced ${res.sent}',
        if (res.droppedStale > 0) '${res.droppedStale} expired',
        if (res.rejected > 0) '${res.rejected} rejected',
        if (res.remaining > 0) '${res.remaining} still pending',
      ];
      _toast(parts.isEmpty ? 'Nothing to sync.' : parts.join(' · '),
          error: res.remaining > 0 && res.sent == 0);
    }
  }

  // ── location / device attestation (reuses the self-punch rules) ─────────────

  Future<_PunchContext?> _capturePunchContext() async {
    double? lat, lng, accuracy;
    bool isMocked = false;

    if (widget.config.geofenceRequired) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('Location services are off. Enable them to mark attendance.', error: true);
        return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _toast('Location permission is required to mark attendance.', error: true);
        return null;
      }
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        if (pos.isMocked) {
          _toast('Mock/fake location detected. Turn off location spoofing.', error: true);
          return null;
        }
        lat = pos.latitude;
        lng = pos.longitude;
        accuracy = pos.accuracy;
        isMocked = pos.isMocked;
      } catch (_) {
        _toast('Could not get a precise location. Try again.', error: true);
        return null;
      }
    }

    final deviceUuid = await SecureStorageService().getDeviceUuid();
    return _PunchContext(latitude: lat, longitude: lng, accuracy: accuracy, isMocked: isMocked, deviceUuid: deviceUuid);
  }

  // ── result / manual sheets ──────────────────────────────────────────────────

  Future<void> _showResultSheet(_ResultSheetData data) async {
    setState(() => _state = _ScanState.showingResult);
    Timer? autoClose;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Auto-dismiss after the cooldown so a gate queue keeps moving.
        autoClose = Timer(Duration(seconds: widget.config.scanCooldownSeconds.clamp(2, 8)), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return _ResultSheet(data: data);
      },
    );
    autoClose?.cancel();
  }

  Future<void> _showManualSheet(QrScanProfile profile) async {
    setState(() => _state = _ScanState.showingResult);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualSheet(
        profile: profile,
        onSubmit: (status) async {
          Navigator.of(ctx).pop();
          await _punchAndShow(profile, status: status);
        },
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(controller: _camera, onDetect: _onDetect),
        const _ReticleOverlay(),
        if (widget.config.highAssurance)
          const Positioned(top: 12, left: 12, right: 12, child: _HighAssuranceBanner()),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomBar(
            tally: _tally,
            pending: _pending,
            mode: widget.config.isGate ? 'Gate' : 'Classroom',
            onTorch: () => _camera.toggleTorch(),
            onFlip: () => _camera.switchCamera(),
            onSync: () => _flush(),
          ),
        ),
      ],
    );
  }

  static List<BarcodeFormat> _mapFormats(List<String> names) {
    const map = {
      'QR_CODE': BarcodeFormat.qrCode,
      'CODE_128': BarcodeFormat.code128,
      'CODE_39': BarcodeFormat.code39,
      'EAN_13': BarcodeFormat.ean13,
      'EAN_8': BarcodeFormat.ean8,
      'UPC_A': BarcodeFormat.upcA,
      'UPC_E': BarcodeFormat.upcE,
      'PDF_417': BarcodeFormat.pdf417,
      'DATA_MATRIX': BarcodeFormat.dataMatrix,
      'AZTEC': BarcodeFormat.aztec,
    };
    final formats = names.map((n) => map[n]).whereType<BarcodeFormat>().toList();
    return formats.isEmpty ? [BarcodeFormat.qrCode, BarcodeFormat.code128] : formats;
  }
}

class _PunchContext {
  final double? latitude, longitude, accuracy;
  final bool isMocked;
  final String? deviceUuid;
  const _PunchContext({this.latitude, this.longitude, this.accuracy, required this.isMocked, this.deviceUuid});
}

// ── result sheet model + widget ───────────────────────────────────────────────

class _ResultSheetData {
  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final QrScanProfile? profile;

  const _ResultSheetData({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    this.profile,
  });

  factory _ResultSheetData.success(QrScanProfile p, QrPunchResult r) => _ResultSheetData(
        color: r.isIn ? Colors.green.shade600 : Colors.blue.shade600,
        icon: r.isIn ? Icons.login : Icons.logout,
        title: r.isIn ? 'Marked IN${r.time != null ? ' · ${r.time}' : ''}' : 'Marked OUT${r.time != null ? ' · ${r.time}' : ''}',
        message: p.name,
        profile: p,
      );

  factory _ResultSheetData.info(QrScanProfile p, String message, Color color) => _ResultSheetData(
        color: color,
        icon: Icons.info_outline,
        title: p.name,
        message: message,
        profile: p,
      );

  factory _ResultSheetData.denied(String message, {QrScanProfile? profile}) => _ResultSheetData(
        color: Colors.red.shade600,
        icon: Icons.block,
        title: 'Not marked',
        message: message,
        profile: profile,
      );

  factory _ResultSheetData.queued(String type, int id, {String? name}) => _ResultSheetData(
        color: Colors.blueGrey.shade600,
        icon: Icons.cloud_off,
        title: 'Queued — offline',
        message: name ?? '${type == 'staff' ? 'Staff' : 'Student'} #$id will sync when back online',
      );
}

class _ResultSheet extends StatelessWidget {
  final _ResultSheetData data;
  const _ResultSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: Colors.white, size: 56),
            const SizedBox(height: 12),
            if (p != null && (p.photoUrl?.isNotEmpty ?? false))
              CircleAvatar(radius: 34, backgroundImage: NetworkImage(p.photoUrl!)),
            Text(data.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(data.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (p != null) ...[
              const SizedBox(height: 4),
              Text('${p.code ?? ''}  ·  ${p.subtitle}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: data.color),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSheet extends StatefulWidget {
  final QrScanProfile profile;
  final Future<void> Function(String status) onSubmit;
  const _ManualSheet({required this.profile, required this.onSubmit});

  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  String _status = 'Present';
  static const _options = ['Present', 'Late', 'Half Day', 'Absent'];

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${p.code ?? ''}  ·  ${p.subtitle}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _options
                  .map((o) => ChoiceChip(
                        label: Text(o),
                        selected: _status == o,
                        onSelected: (_) => setState(() => _status = o),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => widget.onSubmit(_status), child: const Text('Mark'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── overlay chrome ────────────────────────────────────────────────────────────

class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _HighAssuranceBanner extends StatelessWidget {
  const _HighAssuranceBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(10),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Flexible(child: Text('Secure ID cards only at this school', style: TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final ScanTally tally;
  final int pending;
  final String mode;
  final VoidCallback onTorch;
  final VoidCallback onFlip;
  final VoidCallback onSync;
  const _BottomBar({
    required this.tally,
    required this.pending,
    required this.mode,
    required this.onTorch,
    required this.onFlip,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${tally.inCount} IN · ${tally.outCount} OUT · ${tally.alreadyDone} already done'
            '${tally.rejected > 0 ? ' · ${tally.rejected} rejected' : ''}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (pending > 0) ...[
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(Icons.cloud_upload, size: 18, color: Colors.white),
              label: Text('$pending pending — tap to sync', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange.shade800,
              onPressed: onSync,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundAction(icon: Icons.flash_on, label: 'Torch', onTap: onTorch),
              Chip(label: Text('$mode mode'), backgroundColor: Colors.white24, labelStyle: const TextStyle(color: Colors.white)),
              _RoundAction(icon: Icons.cameraswitch, label: 'Flip', onTap: onFlip),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _ConfigError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ConfigError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
