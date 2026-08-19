import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'survey_models.dart';

/// Talks to the staff survey endpoints (Api\V1\Staff\SurveyController).
/// Access is invitation-scoped server-side, so no student/child id is needed.
class SurveyRepository {
  final ApiClient _apiClient;
  SurveyRepository(this._apiClient);

  /// Every survey invitation addressed to the signed-in staff member.
  Future<List<SurveyInvitationSummary>> getMySurveys() async {
    try {
      final response = await _apiClient.dio.get('/staff/surveys');
      final list = (response.data['data'] as List? ?? const []);
      return list
          .map((e) => SurveyInvitationSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to load your surveys.');
    }
  }

  /// The single "important" survey to prompt the staff member with on app open,
  /// or null. The backend stops returning it once answered or the survey closes.
  Future<SurveyInvitationSummary?> getPopupSurvey() async {
    try {
      final response = await _apiClient.dio.get('/staff/surveys/popup');
      final data = response.data['data'];
      if (data is Map) {
        return SurveyInvitationSummary.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to load survey prompt.');
    }
  }

  /// One survey to respond to, resolved by its invitation token.
  Future<SurveyDetail> getSurvey(String token) async {
    try {
      final response = await _apiClient.dio.get('/staff/surveys/$token');
      return SurveyDetail.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to load this survey.');
    }
  }

  /// Submit answers, keyed by question id. Values are shaped by the caller to
  /// match the backend: int for rating, 'yes'/'no' for yes/no, choice id (or a
  /// list of ids) for choice types, ISO date for date, plain string for text.
  Future<void> respond(String token, Map<int, dynamic> answers) async {
    try {
      // JSON object keys must be strings.
      final payload = answers.map((k, v) => MapEntry(k.toString(), v));
      await _apiClient.dio.post(
        '/staff/surveys/$token/respond',
        data: {'answers': payload},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException(message: 'Failed to submit your response.');
    }
  }
}
