import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../data/survey_models.dart';
import '../data/survey_repository.dart';

final surveyRepositoryProvider = Provider<SurveyRepository>((ref) {
  return SurveyRepository(ref.watch(apiClientProvider));
});

/// The signed-in staff member's survey inbox.
final mySurveysProvider =
    FutureProvider.autoDispose<List<SurveyInvitationSummary>>((ref) {
  return ref.watch(surveyRepositoryProvider).getMySurveys();
});

/// A single survey to respond to, by invitation token.
final surveyDetailProvider =
    FutureProvider.autoDispose.family<SurveyDetail, String>((ref, token) {
  return ref.watch(surveyRepositoryProvider).getSurvey(token);
});

/// The active "important" survey to prompt on app open, or null.
final surveyPopupProvider = FutureProvider.autoDispose<SurveyInvitationSummary?>((ref) {
  return ref.watch(surveyRepositoryProvider).getPopupSurvey();
});
