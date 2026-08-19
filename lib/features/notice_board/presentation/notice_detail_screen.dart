import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import '../../../core/branding/branding_providers.dart';

class NoticeDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = notice['title'] ?? 'Notice Details';
    final content = notice['content'] ?? '<p>No content available.</p>';
    final date = notice['published_at'] != null ? DateTime.parse(notice['published_at']) : DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);
    final timeFormatted = DateFormat('hh:mm a').format(date);

    // Determine audience chip styling
    String audienceLabel = 'General';
    Color audienceColor = Colors.blue.shade100;
    Color audienceTextColor = Colors.blue.shade800;
    IconData audienceIcon = Icons.public;

    if (notice['recipient_type'] == 'staff') {
      audienceLabel = 'Staff Only';
      audienceColor = Colors.purple.shade100;
      audienceTextColor = Colors.purple.shade800;
      audienceIcon = Icons.badge;
    } else if (notice['recipient_type'] == 'parents') {
      audienceLabel = 'Parents';
      audienceColor = Colors.orange.shade100;
      audienceTextColor = Colors.orange.shade800;
      audienceIcon = Icons.family_restroom;
    } else if (notice['recipient_type'] == 'class') {
      audienceLabel = notice['noticable'] != null ? notice['noticable']['name'] : ref.watch(terminologyProvider).classLabel;
      audienceColor = Colors.green.shade100;
      audienceTextColor = Colors.green.shade800;
      audienceIcon = Icons.class_;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Notice'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Section
            Container(
              color: Theme.of(context).primaryColor,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: audienceColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(audienceIcon, size: 16, color: audienceTextColor),
                            const SizedBox(width: 6),
                            Text(
                              audienceLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: audienceTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Card
            Transform.translate(
              offset: const Offset(0, -16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: HtmlWidget(
                      content,
                      textStyle: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        height: 1.6,
                      ),
                      customStylesBuilder: (element) {
                        if (element.localName == 'a') {
                          return {'color': '#1976D2', 'text-decoration': 'none'};
                        }
                        if (element.localName == 'p') {
                          return {'margin-bottom': '1em'};
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
            ),
            
            // Footer Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'Published on $formattedDate at $timeFormatted',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}