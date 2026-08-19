import '../data/notice_repository.dart';

class CreateNoticeController {
  final NoticeRepository _repository;
  CreateNoticeController(this._repository);

  Future<void> submitNotice({
    required String title,
    required String content,
    required String publishedAt,
    required String recipientType,
    int? noticableId,
  }) async {
    await _repository.createNotice(
      title: title,
      content: content,
      publishedAt: publishedAt,
      recipientType: recipientType,
      noticableId: noticableId,
    );
  }
}