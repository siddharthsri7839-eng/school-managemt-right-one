import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app document / image viewer — the same "inbuilt viewer" concept the web
/// panel uses, so staff never have to bounce out to an external browser to look
/// at a homework submission.
///
/// Renders PDFs (Syncfusion) and images (zoomable) natively, with a Download
/// action (save / share the file) and an external-open fallback for types
/// Flutter can't render (Office docs, archives).
///
/// [url] is expected to be a fully-resolved, loadable URL (e.g. the signed
/// media link the API returns). Type is detected from the URL PATH, not the
/// whole string, because signed URLs carry a `?expires=…&signature=…` query.
class DocumentViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _downloading = false;

  String get _pathLower {
    final uri = Uri.tryParse(widget.url);
    final path = (uri != null && uri.path.isNotEmpty) ? uri.path : widget.url;
    return path.toLowerCase();
  }

  bool get _isPdf => _pathLower.endsWith('.pdf');

  bool get _isImage =>
      _pathLower.endsWith('.jpg') ||
      _pathLower.endsWith('.jpeg') ||
      _pathLower.endsWith('.png') ||
      _pathLower.endsWith('.gif') ||
      _pathLower.endsWith('.webp');

  /// Filename for the saved file — the URL's last path segment (query stripped),
  /// falling back to a slug of the title.
  String _downloadFileName() {
    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.contains('.')) return last;
    }
    final slug = widget.title
        .replaceAll(RegExp(r'[^\w\s.-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return slug.isEmpty ? 'download' : slug;
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      // Signed media URLs are publicly fetchable (signature-based), so a bare
      // Dio client is enough — no auth interceptor needed.
      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data ?? <int>[];
      if (bytes.isEmpty) throw 'Empty file';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_downloadFileName()}');
      await file.writeAsBytes(bytes);

      // Hand the saved file to the OS sheet — "Save to Files"/Downloads, Drive,
      // or share to any app.
      await Share.shareXFiles([XFile(file.path)], text: widget.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.url);
    var launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          _downloading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download / Save',
                  onPressed: _download,
                ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open externally',
            onPressed: _openExternally,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isPdf) {
      return SfPdfViewer.network(widget.url);
    }

    if (_isImage) {
      return Container(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stack) =>
                  _fallback('This image could not be loaded.'),
            ),
          ),
        ),
      );
    }

    return _fallback(
      "This file type can't be previewed inside the app. You can download it "
      'or open it with another app.',
    );
  }

  Widget _fallback(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
