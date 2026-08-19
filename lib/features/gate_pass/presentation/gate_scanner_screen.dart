import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
// The re-arm rule is the one part of a scanner that must not be improvised, and it
// is already solved and unit-tested for the attendance scanner. Reused deliberately
// rather than reimplemented — see the class docs there.
import '../../qr_attendance/presentation/qr_scanner_controller.dart';
import '../data/gate_pass_repository.dart';
import '../domain/gate_models.dart';
import 'gate_providers.dart';

/// The Gate tab — a gatekeeper's phone standing in for a terminal.
///
/// The person using this is at a gate with someone impatient in front of them, so
/// the screen shows one enormous verdict and at most one button. Every allow/deny
/// decision is the server's; this screen drives the camera and renders the answer.
///
/// Deliberately **online-only for the decision**: a pass can be cancelled seconds
/// before someone arrives, so a cached "yes" is not safe to act on. When the phone
/// cannot reach the server it says so plainly and tells the guard not to open the
/// gate — an honest refusal beats a confident guess about a child.
class GateScannerScreen extends ConsumerWidget {
  const GateScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(gateConfigProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Gate'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Who is out right now',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => _showOutNow(context, ref),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          // `frontoffice.*` permissions are not filtered by module state in
          // UserResource (the prefix is `frontoffice`, the module key is
          // `front_office`), so a guard at a school with Front Office switched off
          // still sees this tile and lands here. Say why, plainly.
          final err = ApiException.from(e);
          final moduleOff = err.message.contains('module_disabled');
          return _Notice(
            icon: moduleOff ? Icons.extension_off_outlined : Icons.cloud_off,
            message: moduleOff
                ? 'The Front Office module is switched off for this school, so gate passes are unavailable.'
                : err.message,
            onRetry: moduleOff ? null : () => ref.invalidate(gateConfigProvider),
          );
        },
        data: (config) {
          if (!config.canVerify) {
            return const _Notice(
              icon: Icons.lock_outline,
              message:
                  'You do not have permission to verify gate passes.\nAsk the office for the gate role.',
            );
          }
          if (!config.enabled) {
            return const _Notice(
              icon: Icons.qr_code_scanner,
              message: 'Gate scanning is switched off for this school.',
            );
          }
          return _GateView(config: config);
        },
      ),
    );
  }

  void _showOutNow(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      builder: (_) => const _OutNowSheet(),
    );
  }
}

// ---------------------------------------------------------------------------

enum _Phase { scanning, checking, deciding }

class _GateView extends ConsumerStatefulWidget {
  final GateConfig config;
  const _GateView({required this.config});

  @override
  ConsumerState<_GateView> createState() => _GateViewState();
}

class _GateViewState extends ConsumerState<_GateView> {
  late final MobileScannerController _camera;
  late final ScanArmGate _gate;

  _Phase _phase = _Phase.scanning;
  GateDecision? _decision;
  String? _lastCode;
  int _outNow = 0;

  @override
  void initState() {
    super.initState();
    _outNow = widget.config.outNow;
    _gate = ScanArmGate(cooldown: const Duration(seconds: 3));
    _camera = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    // Default the gate picker to the first configured gate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(selectedGateProvider);
      if (current == null && widget.config.gates.isNotEmpty) {
        ref.read(selectedGateProvider.notifier).state = widget.config.gates.first;
      }
    });
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty) continue;
      // last-seen is updated even while a verdict is up, so a card held in front
      // of the lens through the whole result cannot re-fire on resume.
      if (_gate.offer(code, now, active: _phase == _Phase.scanning)) {
        _check(code);
      }
    }
  }

  Future<void> _check(String code) async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.checking;
      _lastCode = code;
    });
    await _camera.stop();

    final decision = await _call((repo, gate, uuid) =>
        repo.verify(code: code, gate: gate, deviceUuid: uuid));

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _decision = decision;
      _phase = _Phase.deciding;
      if (decision.outNow >= 0) _outNow = decision.outNow;
    });
  }

  Future<void> _confirm() async {
    final code = _lastCode;
    if (code == null) return;

    setState(() => _phase = _Phase.checking);

    final decision = await _call((repo, gate, uuid) =>
        repo.commit(code: code, gate: gate, deviceUuid: uuid));

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _decision = decision;
      _phase = _Phase.deciding;
      if (decision.outNow >= 0) _outNow = decision.outNow;
    });
  }

  /// One place that turns a transport failure into an honest refusal.
  Future<GateDecision> _call(
    Future<GateDecision> Function(
            GatePassRepository repo, String? gate, String uuid)
        run,
  ) async {
    try {
      final repo = ref.read(gatePassRepositoryProvider);
      final uuid = await SecureStorageService().getDeviceUuid();
      return await run(repo, ref.read(selectedGateProvider), uuid);
    } catch (e) {
      return GateDecision.offline(
        'No connection to the school server, so this pass cannot be checked. '
        'Do not open the gate — call the office.',
      );
    }
  }

  Future<void> _reset() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.scanning;
      _decision = null;
      _lastCode = null;
    });
    await _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _camera, onDetect: _onDetect),
        const _ScanFrame(),
        Positioned(top: 0, left: 0, right: 0, child: _topBar()),
        if (_phase == _Phase.checking)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator()),
          ),
        if (_phase == _Phase.deciding && _decision != null)
          _VerdictSheet(
            decision: _decision!,
            onConfirm: _confirm,
            onDone: _reset,
          ),
        if (_phase == _Phase.scanning)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomBar(),
          ),
      ],
    );
  }

  Widget _topBar() {
    final gates = widget.config.gates;
    final selected = ref.watch(selectedGateProvider);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.door_front_door_outlined,
                color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            if (gates.length > 1)
              DropdownButton<String>(
                value: selected ?? gates.first,
                dropdownColor: const Color(0xFF161B22),
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: gates
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) =>
                    ref.read(selectedGateProvider.notifier).state = v,
              )
            else
              Text(
                selected ?? (gates.isNotEmpty ? gates.first : 'Main Gate'),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            const Spacer(),
            Text('$_outNow out',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan the pass QR, or the person\'s ID card',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _round(Icons.flashlight_on_outlined, 'Torch',
                    () => _camera.toggleTorch()),
                _round(Icons.cameraswitch_outlined, 'Flip',
                    () => _camera.switchCamera()),
                _round(Icons.keyboard_outlined, 'Type it', _manualEntry),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _round(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  /// A cracked lens or a smudged slip must not stop the gate working.
  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter the code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Pass number or admission number',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Check'),
          ),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) _check(code);
  }
}

// ---------------------------------------------------------------------------

/// The verdict. Covers the camera preview entirely, which structurally prevents a
/// re-decode while it is open.
class _VerdictSheet extends StatelessWidget {
  final GateDecision decision;
  final VoidCallback onConfirm;
  final VoidCallback onDone;

  const _VerdictSheet({
    required this.decision,
    required this.onConfirm,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final allow = decision.isAllow;
    final colour = allow ? const Color(0xFF2EA043) : const Color(0xFFD13232);
    final pass = decision.pass;

    return Container(
      color: const Color(0xFF0D1117),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: colour.withValues(alpha: 0.16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  Icon(allow ? Icons.check_circle : Icons.cancel,
                      color: colour, size: 46),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _verdictText(),
                          style: TextStyle(
                            color: colour,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(decision.message,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: pass == null
                    ? const SizedBox.shrink()
                    : _PassBody(pass: pass, showEscort: allow),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (allow && !decision.committed)
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colour,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: onConfirm,
                        child: Text(
                          decision.isGoingOut ? 'Confirm exit' : 'Confirm return',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (allow && !decision.committed) const SizedBox(width: 12),
                  Expanded(
                    flex: allow && !decision.committed ? 0 : 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 24),
                      ),
                      onPressed: onDone,
                      child: Text(
                        allow && !decision.committed ? 'Cancel' : 'Next scan',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _verdictText() {
    if (!decision.isAllow) return 'DO NOT ALLOW';
    if (decision.committed) {
      return decision.isGoingOut ? 'RECORDED — OUT' : 'RECORDED — IN';
    }
    return decision.isGoingOut ? 'ALLOW — GOING OUT' : 'ALLOW — COMING BACK';
  }
}

class _PassBody extends StatelessWidget {
  final GatePassBrief pass;
  final bool showEscort;
  const _PassBody({required this.pass, required this.showEscort});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Portrait(url: pass.photoUrl, width: 96, height: 116),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pass.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    [pass.sub, pass.identifier].where((s) => (s ?? '').isNotEmpty).join(' · '),
                    style: const TextStyle(color: Colors.white60, fontSize: 13.5),
                  ),
                  const SizedBox(height: 10),
                  _fact('Pass', pass.passNo),
                  _fact('Reason', pass.reason),
                  _fact('Out at', pass.gateOutAt ?? pass.expectedOut ?? '—'),
                  _fact('Returning', pass.returning ? 'Yes, today' : 'Not today'),
                ],
              ),
            ),
          ],
        ),
        if (showEscort && (pass.escort?.isPresent ?? false)) ...[
          const SizedBox(height: 18),
          _EscortPanel(escort: pass.escort!),
        ],
      ],
    );
  }

  Widget _fact(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
              text: '$label   ',
              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      );
}

/// Amber and unmissable: handing the child to the wrong adult is the failure this
/// whole module exists to prevent.
class _EscortPanel extends StatelessWidget {
  final GateEscort escort;
  const _EscortPanel({required this.escort});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFB46914).withValues(alpha: 0.14),
        border: Border.all(color: const Color(0xFF7A4B12)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Portrait(url: escort.photoUrl, width: 68, height: 82),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HAND THE CHILD ONLY TO THIS PERSON',
                    style: TextStyle(
                        color: Color(0xFFE3A857),
                        fontSize: 10.5,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(escort.name ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                Text(
                  [escort.relation, escort.phone]
                      .where((s) => (s ?? '').isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                if ((escort.idProof ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('ID shown: ${escort.idProof}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  const _Portrait({required this.url, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF0A0D12),
        child: (url == null || url!.isEmpty)
            ? const Icon(Icons.person_outline, color: Colors.white24, size: 34)
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person_outline,
                    color: Colors.white24, size: 34),
              ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

/// The fire-drill list: who is off campus right now.
class _OutNowSheet extends ConsumerWidget {
  const _OutNowSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gateOutNowProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Currently off campus',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(ApiException.from(e).message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
              ),
              data: (rows) => rows.isEmpty
                  ? const Center(
                      child: Text('Nobody is out right now.',
                          style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                      controller: controller,
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        return ListTile(
                          title: Text(r.name,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            [r.sub, r.reason]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: Text(
                            r.outAt == null
                                ? ''
                                : TimeOfDay.fromDateTime(r.outAt!)
                                    .format(context),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  const _Notice({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
