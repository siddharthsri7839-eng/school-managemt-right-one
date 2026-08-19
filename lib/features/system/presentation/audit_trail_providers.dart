import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../data/audit_trail_repository.dart';

class AuditTrailState {
  final List<dynamic> logs;
  final bool isLoading;
  final bool isFetchingMore;
  final String? errorMessage;
  final int currentPage;
  final bool hasMore;
  final String? eventFilter;
  final String sortOrder;

  AuditTrailState({
    this.logs = const [],
    this.isLoading = true,
    this.isFetchingMore = false,
    this.errorMessage,
    this.currentPage = 1,
    this.hasMore = true,
    this.eventFilter,
    this.sortOrder = 'desc',
  });

  AuditTrailState copyWith({
    List<dynamic>? logs,
    bool? isLoading,
    bool? isFetchingMore,
    String? errorMessage,
    int? currentPage,
    bool? hasMore,
    String? eventFilter,
    String? sortOrder,
  }) {
    return AuditTrailState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      errorMessage: errorMessage, // We want to be able to nullify it, but copyWith semantics usually make this hard. Let's just allow it for simplicity unless specified differently
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      eventFilter: eventFilter ?? this.eventFilter,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  AuditTrailState copyWithClearError({
    List<dynamic>? logs,
    bool? isLoading,
    bool? isFetchingMore,
    int? currentPage,
    bool? hasMore,
    String? eventFilter,
    String? sortOrder,
  }) {
    return AuditTrailState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      errorMessage: null,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      eventFilter: eventFilter ?? this.eventFilter,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class AuditTrailController extends StateNotifier<AuditTrailState> {
  final AuditTrailRepository _repository;

  AuditTrailController(this._repository) : super(AuditTrailState()) {
    fetchLogs();
  }

  Future<void> fetchLogs({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWithClearError(isLoading: true, currentPage: 1, logs: [], hasMore: true);
    } else {
      state = state.copyWithClearError(isLoading: true);
    }

    try {
      final data = await _repository.fetchAuditLogs(
        page: state.currentPage,
        eventFilter: state.eventFilter,
        sortOrder: state.sortOrder,
      );
      
      final newLogs = data['audits'] as List<dynamic>;
      final pagination = data['pagination'];

      state = state.copyWithClearError(
        isLoading: false,
        logs: refresh ? newLogs : [...state.logs, ...newLogs],
        hasMore: pagination['has_more'],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ApiException.from(e).message,
      );
    }
  }

  Future<void> fetchMoreLogs() async {
    if (state.isLoading || state.isFetchingMore || !state.hasMore) return;

    state = state.copyWithClearError(isFetchingMore: true, currentPage: state.currentPage + 1);

    try {
      final data = await _repository.fetchAuditLogs(
        page: state.currentPage,
        eventFilter: state.eventFilter,
        sortOrder: state.sortOrder,
      );
      
      final newLogs = data['audits'] as List<dynamic>;
      final pagination = data['pagination'];

      state = state.copyWithClearError(
        isFetchingMore: false,
        logs: [...state.logs, ...newLogs],
        hasMore: pagination['has_more'],
      );
    } catch (e) {
      // Revert page if failed
      state = state.copyWith(
        isFetchingMore: false,
        currentPage: state.currentPage - 1,
        errorMessage: ApiException.from(e).message,
      );
    }
  }

  void setFilter(String? eventFilter) {
    if (state.eventFilter == eventFilter) return;
    state = state.copyWith(eventFilter: eventFilter);
    fetchLogs(refresh: true);
  }

  void setSortOrder(String sortOrder) {
    if (state.sortOrder == sortOrder) return;
    state = state.copyWith(sortOrder: sortOrder);
    fetchLogs(refresh: true);
  }
}

final auditTrailControllerProvider = StateNotifierProvider<AuditTrailController, AuditTrailState>((ref) {
  return AuditTrailController(ref.watch(auditTrailRepositoryProvider));
});
