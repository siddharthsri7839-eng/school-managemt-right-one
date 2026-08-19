import '../../../core/api/api_client.dart';

class NoticeRepository {
  final ApiClient _apiClient;
  NoticeRepository(this._apiClient);

  Future<List<dynamic>> getNotices({
    String? search,
    String? recipientType,
    String sort = 'desc',
  }) async {
    final response = await _apiClient.dio.get(
      '/staff/notices',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (recipientType != null && recipientType != 'all_types') 'recipient_type': recipientType,
        'sort': sort,
      },
    );
    return response.data['data'];
  }

  // ✅ ADD THIS NEW METHOD TO POST THE NOTICE
  Future<void> createNotice({
    required String title,
    required String content,
    required String publishedAt,
    required String recipientType,
    int? noticableId,
  }) async {
    await _apiClient.dio.post(
      '/staff/notices',
      data: {
        'title': title,
        'content': content,
        'published_at': publishedAt,
        'recipient_type': recipientType,
        'noticable_id': noticableId,
      },
    );
  }
}