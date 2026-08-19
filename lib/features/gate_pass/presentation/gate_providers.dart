import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gate_pass_repository.dart';
import '../domain/gate_models.dart';

/// Gate configuration + this operator's capabilities. Loaded once when the Gate
/// tab opens; drives the gate picker and the "you cannot verify" state.
final gateConfigProvider = FutureProvider.autoDispose<GateConfig>((ref) {
  return ref.watch(gatePassRepositoryProvider).config();
});

/// Who is off campus right now — the list that matters in a fire drill.
final gateOutNowProvider =
    FutureProvider.autoDispose<List<GateOutEntry>>((ref) {
  return ref.watch(gatePassRepositoryProvider).outNow();
});

/// The gate this terminal is standing at. Held in app state rather than on the
/// server: one phone can be moved between gates during a shift.
final selectedGateProvider = StateProvider<String?>((ref) => null);
