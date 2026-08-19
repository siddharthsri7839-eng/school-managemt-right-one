import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import '../data/transport_repository.dart';

class TransportDashboardState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  TransportDashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
  });

  TransportDashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? data,
  }) {
    return TransportDashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      data: data ?? this.data,
    );
  }
}

class TransportDashboardController extends StateNotifier<TransportDashboardState> {
  final TransportRepository _repository;

  TransportDashboardController(this._repository) : super(TransportDashboardState()) {
    fetchDashboardData();
  }

  Future<void> fetchDashboardData({bool refresh = false}) async {
    if (state.isLoading) return;
    
    if (!refresh && state.data != null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final data = await _repository.getDashboardData();
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: ApiException.from(e).message);
    }
  }
}

final transportDashboardControllerProvider =
    StateNotifierProvider<TransportDashboardController, TransportDashboardState>((ref) {
  final repository = ref.watch(transportRepositoryProvider);
  return TransportDashboardController(repository);
});
