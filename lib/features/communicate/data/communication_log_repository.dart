import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'communication_log_model.dart';

/// Repository for fetching communication log data from the staff API.
///
/// Follows the project's established pattern: DioException → ApiException
/// conversion in every catch block, matching
/// [FeesDashboardRepository] and [NoticeRepository].
class CommunicationLogRepository {
  final ApiClient _apiClient;

  CommunicationLogRepository(this._apiClient);

  /// Fetch a paginated list of communication logs.
  ///
  /// - [channel]: optional filter — `sms`, `mail`, or `whatsapp`. Null for all.
  /// - [search]: optional text search on recipient name/email/subject.
  /// - [page]: pagination page number (1-indexed).
  Future<CommunicationLogResponse> getLogs({
    String? channel,
    String? search,
    int page = 1,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
      };

      if (channel != null && channel.isNotEmpty) {
        queryParams['channel'] = channel;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.dio.get(
        '/staff/communication-log',
        queryParameters: queryParams,
      );

      return CommunicationLogResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
