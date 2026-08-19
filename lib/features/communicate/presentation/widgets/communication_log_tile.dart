import 'package:flutter/material.dart';
import '../../data/communication_log_model.dart';
import '../../../communicate/presentation/widgets/message_content_sheet.dart';

/// A single row in the communication log list.
///
/// Displays recipient, channel badge, notification type, status, and date.
/// Tapping opens a bottom sheet with full message content.
class CommunicationLogTile extends StatelessWidget {
  final CommunicationLogEntry entry;

  const CommunicationLogTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMessageContent(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Recipient + Status ──
              Row(
                children: [
                  // Recipient type badge
                  _RecipientBadge(type: entry.recipientType),
                  const SizedBox(width: 8),
                  // Recipient name
                  Expanded(
                    child: Text(
                      entry.recipientName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Status badge
                  _StatusBadge(isSent: entry.isSent),
                ],
              ),
              const SizedBox(height: 8),

              // ── Row 2: Contact + Channel ──
              Row(
                children: [
                  Icon(Icons.alternate_email, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entry.contactAddr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _ChannelChip(channel: entry.channel),
                ],
              ),
              const SizedBox(height: 8),

              // ── Row 3: Notification type + Date ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.notificationType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    entry.createdAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              // ── Row 4 (conditional): Reason if skipped ──
              if (entry.isSkipped && entry.reason != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.reason!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Row 5 (conditional): Tap hint when message content exists ──
              if (entry.messageContent != null && entry.messageContent!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.visibility_outlined, size: 13, color: Colors.blue.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to view message',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageContent(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => MessageContentSheet(entry: entry),
    );
  }
}

// ── Private Sub-widgets ────────────────────────────────────────────────────────

class _RecipientBadge extends StatelessWidget {
  final String type;

  const _RecipientBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isUser = type.toLowerCase() == 'user';
    final color = isUser ? Colors.indigo : Colors.teal;
    final label = isUser ? 'User' : type;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.shade700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isSent;

  const _StatusBadge({required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSent ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSent ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 12,
            color: isSent ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isSent ? 'SENT' : 'SKIPPED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSent ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String channel;

  const _ChannelChip({required this.channel});

  @override
  Widget build(BuildContext context) {
    final config = _channelConfig(channel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.fgColor),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: config.fgColor,
            ),
          ),
        ],
      ),
    );
  }

  static _ChannelConfig _channelConfig(String channel) {
    return switch (channel.toLowerCase()) {
      'sms' => _ChannelConfig(
        icon: Icons.sms_outlined,
        label: 'SMS',
        fgColor: Colors.blue.shade700,
        bgColor: Colors.blue.shade50,
      ),
      'whatsapp' => _ChannelConfig(
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        fgColor: Colors.green.shade700,
        bgColor: Colors.green.shade50,
      ),
      'mail' => _ChannelConfig(
        icon: Icons.email_outlined,
        label: 'Email',
        fgColor: Colors.purple.shade700,
        bgColor: Colors.purple.shade50,
      ),
      _ => _ChannelConfig(
        icon: Icons.notifications_outlined,
        label: channel,
        fgColor: Colors.grey.shade700,
        bgColor: Colors.grey.shade100,
      ),
    };
  }
}

class _ChannelConfig {
  final IconData icon;
  final String label;
  final Color fgColor;
  final Color bgColor;

  const _ChannelConfig({
    required this.icon,
    required this.label,
    required this.fgColor,
    required this.bgColor,
  });
}
