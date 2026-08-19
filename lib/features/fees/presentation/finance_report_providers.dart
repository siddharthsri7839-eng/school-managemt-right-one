import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';

// --- State ---
class FinanceReportOptionsState {
  final List<dynamic> feeGroups;
  final bool isLoading;
  final String? errorMessage;

  FinanceReportOptionsState({
    this.feeGroups = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  FinanceReportOptionsState copyWith({
    List<dynamic>? feeGroups,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FinanceReportOptionsState(
      feeGroups: feeGroups ?? this.feeGroups,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// --- Controller ---
class FinanceReportOptionsController extends StateNotifier<FinanceReportOptionsState> {
  final ApiClient _apiClient;

  FinanceReportOptionsController(this._apiClient) : super(FinanceReportOptionsState()) {
    fetchOptions();
  }

  Future<void> fetchOptions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.get('/staff/reports/finance/options');
      state = state.copyWith(
        feeGroups: response.data['fee_groups'] ?? [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load report options',
      );
    }
  }
}

final financeReportOptionsProvider = StateNotifierProvider<FinanceReportOptionsController, FinanceReportOptionsState>((ref) {
  return FinanceReportOptionsController(ref.watch(apiClientProvider));
});
