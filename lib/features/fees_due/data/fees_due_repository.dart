import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import '../domain/fees_due_models.dart';

/// Read-only access to the teacher's class due-fees (view + contact parent).
class FeesDueRepository {
  final ApiClient _apiClient;
  FeesDueRepository(this._apiClient);

  static const _base = '/staff/fees-due';

  Future<Map<String, dynamic>> getClasses() async {
    try {
      final res = await _apiClient.dio.get('$_base/classes');
      final data = (res.data as Map).cast<String, dynamic>();
      return {
        'classes': ((data['data'] as List?) ?? [])
            .map((c) => ClassOption.fromJson((c as Map).cast<String, dynamic>()))
            .toList(),
        'filters': ((data['filters'] as List?) ?? [])
            .map((f) => FilterOption.fromJson((f as Map).cast<String, dynamic>()))
            .toList(),
      };
    } on DioException catch (e) {
      throw _map(e);
    } catch (e) {
      // Parse / unexpected-shape errors never reach the user raw.
      throw ApiException.from(e);
    }
  }

  Future<FeesDuePage> getList({
    int? classId,
    int? sectionId,
    String filterType = 'all',
    String? dueDate,
    String? search,
    int page = 1,
  }) async {
    try {
      final res = await _apiClient.dio.get(_base, queryParameters: {
        if (classId != null) 'class_id': classId,
        if (sectionId != null) 'section_id': sectionId,
        'filter_type': filterType,
        if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
      });
      final data = (res.data as Map).cast<String, dynamic>();
      final meta = (data['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
      return FeesDuePage(
        rows: ((data['data'] as List?) ?? [])
            .map((r) => FeesDueRow.fromJson((r as Map).cast<String, dynamic>()))
            .toList(),
        summary: DueSummary.fromJson((data['summary'] as Map?)?.cast<String, dynamic>() ?? const {}),
        currentPage: (meta['current_page'] as int?) ?? 1,
        lastPage: (meta['last_page'] as int?) ?? 1,
        total: (meta['total'] as int?) ?? 0,
        currencySymbol: '${meta['currency_symbol'] ?? ''}',
      );
    } on DioException catch (e) {
      throw _map(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// URL (relative to the dio baseUrl) for the streamed PDF export.
  String pdfPath({
    int? classId,
    int? sectionId,
    String filterType = 'all',
    String? dueDate,
  }) {
    final q = <String, String>{
      'filter_type': filterType,
      if (classId != null) 'class_id': '$classId',
      if (sectionId != null) 'section_id': '$sectionId',
      if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
    };
    final query = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return '$_base/pdf?$query';
  }

  ApiException _map(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode == 403 && data is Map && data['error'] == 'module_disabled') {
      return const ApiException.forbidden('module_disabled');
    }
    return ApiException.fromDioException(e);
  }
}

final feesDueRepositoryProvider = Provider<FeesDueRepository>((ref) {
  return FeesDueRepository(ref.watch(apiClientProvider));
});
