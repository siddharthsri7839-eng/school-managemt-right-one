import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../data/academic_dashboard_repository.dart';

// State model
class AcademicDashboardState {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? errorMessage;

  AcademicDashboardState({
    this.data,
    this.isLoading = true,
    this.errorMessage,
  });

  AcademicDashboardState copyWith({
    Map<String, dynamic>? data,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AcademicDashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// Controller
class AcademicDashboardController extends StateNotifier<AcademicDashboardState> {
  final AcademicDashboardRepository _repository;

  AcademicDashboardController(this._repository) : super(AcademicDashboardState()) {
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _repository.getAcademicDashboardData();
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      String message = 'Failed to load academics dashboard';
      if (e is ApiException) {
        message = e.message;
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }
}

final academicDashboardControllerProvider = StateNotifierProvider<AcademicDashboardController, AcademicDashboardState>((ref) {
  return AcademicDashboardController(ref.watch(academicDashboardRepositoryProvider));
});
