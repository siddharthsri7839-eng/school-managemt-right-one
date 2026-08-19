/// Models for the Student–Teacher Chat module (shared /api/v1/chat endpoints).
library;

class ChatConfig {
  final bool enabled;
  final String? role; // teacher | student | parent
  final bool teacherStudentEnabled;
  final bool teacherParentEnabled;
  final int unsendWindowMinutes;

  const ChatConfig({
    required this.enabled,
    this.role,
    this.teacherStudentEnabled = false,
    this.teacherParentEnabled = false,
    this.unsendWindowMinutes = 15,
  });

  factory ChatConfig.fromJson(Map<String, dynamic> json) {
    return ChatConfig(
      enabled: json['enabled'] == true,
      role: json['role'] as String?,
      teacherStudentEnabled: json['teacher_student_enabled'] == true,
      teacherParentEnabled: json['teacher_parent_enabled'] == true,
      unsendWindowMinutes: json['unsend_window_minutes'] as int? ?? 15,
    );
  }

  static const disabled = ChatConfig(enabled: false);
}

class ChatThreadSummary {
  final int id;
  final String type; // teacher_student | teacher_parent
  final String title;
  final int studentId;
  final String studentName;
  final bool isFrozen;
  final int unreadCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  const ChatThreadSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.studentId,
    required this.studentName,
    required this.isFrozen,
    required this.unreadCount,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  factory ChatThreadSummary.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'];
    String? preview;
    if (last is Map) {
      if (last['is_deleted'] == true) {
        preview = 'Message removed';
      } else if ((last['body'] as String?)?.isNotEmpty == true) {
        preview = last['body'] as String;
      } else if (last['attachment_name'] != null) {
        preview = '📎 ${last['attachment_name']}';
      }
    }

    return ChatThreadSummary(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'teacher_student',
      title: json['title'] as String? ?? '',
      studentId: json['student_id'] as int? ?? 0,
      studentName: json['student_name'] as String? ?? '',
      isFrozen: json['is_frozen'] == true,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessagePreview: preview,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)?.toLocal()
          : null,
    );
  }
}

class ChatInbox {
  final List<ChatThreadSummary> threads;
  final int unreadTotal;

  const ChatInbox({required this.threads, required this.unreadTotal});
}

class ChatMessageModel {
  final int id;
  final int threadId;
  final int senderId;
  final String? body;
  final String? attachmentUrl;
  final String? attachmentType; // image | pdf
  final String? attachmentName;
  final bool isDeleted;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    this.body,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.isDeleted = false,
    this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      threadId: json['thread_id'] as int,
      senderId: json['sender_id'] as int,
      body: json['body'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      attachmentName: json['attachment_name'] as String?,
      isDeleted: json['is_deleted'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
    );
  }

  ChatMessageModel asDeleted() => ChatMessageModel(
        id: id,
        threadId: threadId,
        senderId: senderId,
        isDeleted: true,
        createdAt: createdAt,
      );
}

// ---------------------------------------------------------------------------
// Contacts (teacher view: my sections → students)
// ---------------------------------------------------------------------------

class ChatStudentContact {
  final int studentId;
  final String name;
  final bool canStudentChat;
  final bool canParentChat;

  const ChatStudentContact({
    required this.studentId,
    required this.name,
    required this.canStudentChat,
    required this.canParentChat,
  });

  factory ChatStudentContact.fromJson(Map<String, dynamic> json) {
    return ChatStudentContact(
      studentId: json['student_id'] as int,
      name: json['name'] as String? ?? '',
      canStudentChat: json['can_student_chat'] == true,
      canParentChat: json['can_parent_chat'] == true,
    );
  }
}

class ChatSectionContacts {
  final int sectionId;
  final String label;
  final List<ChatStudentContact> students;

  const ChatSectionContacts({
    required this.sectionId,
    required this.label,
    required this.students,
  });

  factory ChatSectionContacts.fromJson(Map<String, dynamic> json) {
    return ChatSectionContacts(
      sectionId: json['section_id'] as int,
      label: json['label'] as String? ?? '',
      students: (json['students'] as List? ?? const [])
          .map((e) => ChatStudentContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
