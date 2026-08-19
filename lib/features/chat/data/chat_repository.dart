import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'chat_models.dart';

/// Talks to the shared chat endpoints (Api\V1\Chat\ChatController). The staff
/// app is always the "teacher" side; reachability is enforced server-side.
class ChatRepository {
  final ApiClient _apiClient;
  ChatRepository(this._apiClient);

  Future<ChatConfig> getConfig() async {
    try {
      final response = await _apiClient.dio.get('/chat/config');
      return ChatConfig.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
    } catch (_) {
      // Config gates UI visibility only — any failure just hides chat.
      return ChatConfig.disabled;
    }
  }

  Future<List<ChatSectionContacts>> getContacts() async {
    try {
      final response = await _apiClient.dio.get('/chat/contacts');
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      return (data['sections'] as List? ?? const [])
          .map((e) => ChatSectionContacts.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to load your class contacts.');
    }
  }

  Future<ChatInbox> getThreads() async {
    try {
      final response = await _apiClient.dio.get('/chat/threads');
      final threads = (response.data['data'] as List? ?? const [])
          .map((e) => ChatThreadSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return ChatInbox(
        threads: threads,
        unreadTotal: response.data['unread_total'] as int? ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to load your conversations.');
    }
  }

  /// Find-or-create the thread for a student/parent pair. Idempotent.
  Future<int> openThread({required String type, required int studentId}) async {
    try {
      final response = await _apiClient.dio.post('/chat/threads', data: {
        'type': type,
        'student_id': studentId,
      });
      return response.data['data']['id'] as int;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to open the conversation.');
    }
  }

  Future<List<ChatMessageModel>> getMessages(
    int threadId, {
    int? afterId,
    int? beforeId,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/chat/threads/$threadId/messages',
        queryParameters: {
          if (afterId != null) 'after_id': afterId,
          if (beforeId != null) 'before_id': beforeId,
        },
      );
      return (response.data['data'] as List? ?? const [])
          .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to load messages.');
    }
  }

  Future<ChatMessageModel> sendMessage(
    int threadId, {
    String? body,
    String? attachmentPath,
    String? attachmentFileName,
  }) async {
    try {
      final dynamic payload;
      if (attachmentPath != null) {
        payload = FormData.fromMap({
          if (body != null && body.isNotEmpty) 'body': body,
          'attachment': await MultipartFile.fromFile(
            attachmentPath,
            filename: attachmentFileName,
          ),
        });
      } else {
        payload = {'body': body};
      }

      final response = await _apiClient.dio.post(
        '/chat/threads/$threadId/messages',
        data: payload,
      );
      return ChatMessageModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to send the message.');
    }
  }

  Future<void> markRead(int threadId, int upToMessageId) async {
    try {
      await _apiClient.dio.post('/chat/threads/$threadId/read', data: {
        'up_to_message_id': upToMessageId,
      });
    } catch (_) {
      // Read receipts are best-effort; never surface an error for them.
    }
  }

  Future<void> unsend(int messageId) async {
    try {
      await _apiClient.dio.post('/chat/messages/$messageId/unsend');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to unsend the message.');
    }
  }

  Future<void> report(int messageId, String? reason) async {
    try {
      await _apiClient.dio.post('/chat/messages/$messageId/report', data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to report the message.');
    }
  }
}
