import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../data/offline_exams_repository.dart';

class OfflineExamsDashboardState {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? errorMessage;

  OfflineExamsDashboardState({
    this.data,
    this.isLoading = true,
    this.errorMessage,
  });

  OfflineExamsDashboardState copyWith({
    Map<String, dynamic>? data,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OfflineExamsDashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  OfflineExamsDashboardState copyWithClearError({
    Map<String, dynamic>? data,
    bool? isLoading,
  }) {
    return OfflineExamsDashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: null,
    );
  }
}

class OfflineExamsDashboardController extends StateNotifier<OfflineExamsDashboardState> {
  final OfflineExamsRepository _repository;

  OfflineExamsDashboardController(this._repository) : super(OfflineExamsDashboardState()) {
    fetchDashboardData();
  }

  Future<void> fetchDashboardData({bool refresh = false}) async {
    if (!refresh) {
      state = state.copyWithClearError(isLoading: true);
    }

    try {
      final data = await _repository.fetchDashboardData();
      state = state.copyWithClearError(
        isLoading: false,
        data: data,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred.',
      );
    }
  }
}

final offlineExamsDashboardControllerProvider = StateNotifierProvider<OfflineExamsDashboardController, OfflineExamsDashboardState>((ref) {
  final repository = ref.watch(offlineExamsRepositoryProvider);
  return OfflineExamsDashboardController(repository);
});
