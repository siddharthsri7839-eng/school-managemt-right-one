/// Strongly-typed model for a single communication log entry.
///
/// Maps 1:1 to the JSON structure returned by
/// `GET /api/v1/staff/communication-log`.
class CommunicationLogEntry {
  final int id;
  final String recipientName;
  final String recipientType;
  final String contactAddr;
  final String channel;
  final String notificationType;
  final String status;
  final String? reason;
  final String? subject;
  final String? messageContent;
  final String createdAt;

  const CommunicationLogEntry({
    required this.id,
    required this.recipientName,
    required this.recipientType,
    required this.contactAddr,
    required this.channel,
    required this.notificationType,
    required this.status,
    this.reason,
    this.subject,
    this.messageContent,
    required this.createdAt,
  });

  factory CommunicationLogEntry.fromJson(Map<String, dynamic> json) {
    return CommunicationLogEntry(
      id: json['id'] as int,
      recipientName: (json['recipient_name'] as String?) ?? 'N/A',
      recipientType: (json['recipient_type'] as String?) ?? 'Unknown',
      contactAddr: (json['contact_addr'] as String?) ?? 'N/A',
      channel: (json['channel'] as String?) ?? 'unknown',
      notificationType: (json['notification_type'] as String?) ?? 'General',
      status: (json['status'] as String?) ?? 'unknown',
      reason: json['reason'] as String?,
      subject: json['subject'] as String?,
      messageContent: json['message_content'] as String?,
      createdAt: (json['created_at'] as String?) ?? 'N/A',
    );
  }

  /// Whether this notification was successfully sent.
  bool get isSent => status.toLowerCase() == 'sent';

  /// Whether this notification was skipped.
  bool get isSkipped => status.toLowerCase() == 'skipped';
}

/// Wrapper for a paginated API response of communication log entries.
class CommunicationLogResponse {
  final List<CommunicationLogEntry> logs;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const CommunicationLogResponse({
    required this.logs,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  /// Whether there are more pages to load.
  bool get hasMorePages => currentPage < lastPage;

  factory CommunicationLogResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return CommunicationLogResponse(
      logs: data
          .map((e) => CommunicationLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (meta['current_page'] as int?) ?? 1,
      lastPage: (meta['last_page'] as int?) ?? 1,
      perPage: (meta['per_page'] as int?) ?? 20,
      total: (meta['total'] as int?) ?? 0,
    );
  }
}
