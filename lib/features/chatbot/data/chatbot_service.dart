import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../models/chat_message.dart';

final chatbotServiceProvider = Provider<ChatbotService>((ref) {
  return ChatbotService(ref.watch(apiClientProvider));
});

class ChatbotService {
  final ApiClient _apiClient;

  ChatbotService(this._apiClient);

  Dio get _dio => _apiClient.dio;

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    int? conversationId,
    File? image,
    String? model,
  }) async {
    try {
      final formData = FormData.fromMap({
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (model != null) 'model': model,
      });

      if (image != null) {
        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(image.path),
        ));
      }

      final response = await _dio.post(
        '/staff/chatbot/send',
        data: formData,
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to send message');
    }
  }

  Future<List<ChatMessage>> getHistory(int conversationId) async {
    try {
      final response = await _dio.post(
        '/staff/chatbot/history',
        data: {'conversation_id': conversationId},
      );

      final List<dynamic> data = response.data['data'];
      // Map API response to ChatMessage model
      return data.map((json) {
        return ChatMessage(
          content: json['content'] ?? '',
          role: json['role'] == 'user' ? 'user' : 'ai',
          timestamp: DateTime.parse(json['timestamp']),
        );
      }).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to load history');
    }
  }

  Future<Map<String, dynamic>> fetchConfig() async {
    try {
      final response = await _dio.get('/staff/chatbot/config');
      return response.data['data'];
    } catch (_) {
      return {'name': 'AI Assistant', 'logo': null, 'enabled': true};
    }
  }

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    try {
      final response = await _dio.get('/staff/chatbot/conversations');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (_) {
      return [];
    }
  }
}
