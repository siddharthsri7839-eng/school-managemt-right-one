class ChatMessage {
  final int? id;
  final String content;
  final String role; // 'user' or 'ai'
  final DateTime timestamp;
  final bool isSending;

  ChatMessage({
    this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isSending = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
        id: json['id'],
        content: json['content'] ?? '',
        role: json['role'] == 'assistant' ? 'ai' : (json['role'] ?? 'user'),
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now());
  }
}
