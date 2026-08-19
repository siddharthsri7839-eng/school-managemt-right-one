import '../../../core/api/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class ExamRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getExamList({required int studentId}) async {
    final response = await _apiClient.dio.get(
      '/parent/exams',
      queryParameters: {'student_id': studentId},
    );
    return response.data['data'];
  }

  Future<String> getReportCardHtml({required int studentId, required int setupId}) async {
    final response = await _apiClient.dio.get(
      '/parent/exams/report-card/$setupId',
      queryParameters: {'student_id': studentId},
    );
    return response.data['html_content'];
  }

  Future<void> openUploadedMarksheet({required int studentId, required int marksheetId}) async {
     final response = await _apiClient.dio.get(
      '/parent/exams/uploaded-marksheet/$marksheetId',
      queryParameters: {'student_id': studentId},
    );
    final url = Uri.parse(response.data['file_url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch URL';
    }
  }
}