import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/qr_attendance_repository.dart';
import '../domain/qr_models.dart';

/// The per-school scanner config + this operator's capabilities. Loaded once when
/// the scanner opens; drives camera formats, auto/manual mode and which
/// affordances are shown.
final qrScannerConfigProvider = FutureProvider.autoDispose<QrScannerConfig>((ref) {
  return ref.watch(qrAttendanceRepositoryProvider).config();
});
