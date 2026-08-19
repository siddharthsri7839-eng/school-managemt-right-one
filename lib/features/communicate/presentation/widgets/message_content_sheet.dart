import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../data/communication_log_model.dart';

/// Bottom sheet that displays the full message content of a communication log entry.
///
/// Renders HTML content using `flutter_widget_from_html` (already a project dependency).
class MessageContentSheet extends StatelessWidget {
  final CommunicationLogEntry entry;

  const MessageContentSheet({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header: Channel + Status ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildChannelIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Message Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // ── Scrollable Content ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient info
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'To',
                    value: '${entry.recipientName} (${entry.recipientType})',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.alternate_email,
                    label: 'Address',
                    value: entry.contactAddr,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.schedule,
                    label: 'Date',
                    value: entry.createdAt,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: entry.notificationType,
                  ),

                  // Reason (if skipped)
                  if (entry.isSkipped && entry.reason != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Reason',
                      value: entry.reason!,
                      valueColor: Colors.orange.shade800,
                    ),
                  ],

                  // Subject
                  if (entry.subject != null && entry.subject!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Subject',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subject!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  // Message content
                  if (entry.messageContent != null && entry.messageContent!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Message Content',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: HtmlWidget(
                        entry.messageContent!,
                        textStyle: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.content_paste_off, size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            'No message content recorded',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Close button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelIcon() {
    final config = _channelVisual(entry.channel);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: config.bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(config.icon, size: 18, color: config.fgColor),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: entry.isSent ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entry.isSent ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 14,
            color: entry.isSent ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            entry.isSent ? 'SENT' : 'SKIPPED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: entry.isSent ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  static ({IconData icon, Color fgColor, Color bgColor}) _channelVisual(String channel) {
    return switch (channel.toLowerCase()) {
      'sms' => (
        icon: Icons.sms_outlined,
        fgColor: Colors.blue.shade700,
        bgColor: Colors.blue.shade50,
      ),
      'whatsapp' => (
        icon: Icons.chat_outlined,
        fgColor: Colors.green.shade700,
        bgColor: Colors.green.shade50,
      ),
      'mail' => (
        icon: Icons.email_outlined,
        fgColor: Colors.purple.shade700,
        bgColor: Colors.purple.shade50,
      ),
      _ => (
        icon: Icons.notifications_outlined,
        fgColor: Colors.grey.shade700,
        bgColor: Colors.grey.shade100,
      ),
    };
  }
}

/// Compact info row with icon, label, and value.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
