import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import 'package:dio/dio.dart';

class FrontOfficeRepository {
  final ApiClient _apiClient;

  FrontOfficeRepository(this._apiClient);

  Future<Map<String, dynamic>> getDashboard({String status = 'All', String? sortFollowup}) async {
    try {
      final response = await _apiClient.dio.get(
        '/staff/front-office/dashboard',
        queryParameters: {
          if (status != 'All') 'status': status,
          if (sortFollowup != null) 'sort_followup': sortFollowup,
        },
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      throw ApiException.server(e.response?.data['message'] ?? 'Failed to load front office data.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }
}

final frontOfficeRepositoryProvider = Provider<FrontOfficeRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FrontOfficeRepository(apiClient);
});
