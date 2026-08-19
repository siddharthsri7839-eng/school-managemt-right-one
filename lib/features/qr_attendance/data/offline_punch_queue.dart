import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/offline_punch.dart';
import '../domain/qr_models.dart';
import 'qr_attendance_repository.dart';

/// Durable queue of punches captured while offline (plan §P3). Persisted with the
/// same secure storage the rest of the app uses (no new dependency). The list is
/// small — a gate rush is dozens, not thousands — so a single JSON blob under one
/// key is sufficient and keeps ordering trivial (FIFO).
class OfflinePunchQueue {
  final QrAttendanceRepository _repo;
  OfflinePunchQueue(this._repo);

  static const _key = 'qr_offline_punches';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<List<PendingPunch>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map>();
      return list.map((m) => PendingPunch.fromJson(m.cast<String, dynamic>())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<PendingPunch> items) async {
    await _storage.write(key: _key, value: jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<int> count() async => (await _read()).length;

  Future<void> enqueue(PendingPunch punch) async {
    final items = await _read();
    items.add(punch);
    await _write(items);
  }

  Future<void> clear() async => _storage.delete(key: _key);

  /// Flush sequentially, honouring the server's verdict per item:
  ///  - success            → drop (sent).
  ///  - stale (client-side) → drop before sending (the server would reject anyway).
  ///  - business rejection  → drop (rejected): the server said no, retrying won't help.
  ///  - network error       → stop and keep the rest for the next attempt.
  Future<FlushResult> flush() async {
    final items = await _read();
    if (items.isEmpty) {
      return const FlushResult(sent: 0, droppedStale: 0, rejected: 0, remaining: 0);
    }

    final now = DateTime.now();
    var sent = 0, droppedStale = 0, rejected = 0;
    final remaining = <PendingPunch>[];

    for (var i = 0; i < items.length; i++) {
      final p = items[i];

      if (p.isStale(now)) {
        droppedStale++;
        continue; // never today anymore — drop with a warning upstream.
      }

      try {
        await _repo.punch(
          type: p.type,
          id: p.id,
          status: p.status,
          scannedAt: p.scannedAt,
          latitude: p.latitude,
          longitude: p.longitude,
          accuracy: p.accuracy,
          isMocked: p.isMocked,
          deviceUuid: p.deviceUuid,
        );
        sent++;
      } on QrScanException {
        // Server rejected this specific punch (stale/duplicate/scope) — dropping it
        // is correct; retrying can never succeed.
        rejected++;
      } catch (_) {
        // Network (or unexpected) error: still offline. Keep this and everything
        // after it, in order, for the next flush.
        remaining.addAll(items.sublist(i));
        break;
      }
    }

    await _write(remaining);
    return FlushResult(sent: sent, droppedStale: droppedStale, rejected: rejected, remaining: remaining.length);
  }
}

final offlinePunchQueueProvider = Provider<OfflinePunchQueue>((ref) {
  return OfflinePunchQueue(ref.watch(qrAttendanceRepositoryProvider));
});
