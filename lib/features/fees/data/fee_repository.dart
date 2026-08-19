import '../../../core/api/api_client.dart';

class FeeRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getFeeInvoices({required int studentId}) async {
    final response = await _apiClient.dio.get(
      '/parent/fees',
      queryParameters: {'student_id': studentId},
    );
    return response.data['data'];
  }
}