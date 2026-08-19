import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_providers.dart';
import 'main_scaffold.dart';

class SecurePdfViewerScreen extends ConsumerStatefulWidget {
  final String title;
  final String pdfUrl;

  const SecurePdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  @override
  ConsumerState<SecurePdfViewerScreen> createState() => _SecurePdfViewerScreenState();
}

class _SecurePdfViewerScreenState extends ConsumerState<SecurePdfViewerScreen> {
  Uint8List? _pdfBytes;
  String? _localFilePath;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get<List<int>>(
        widget.pdfUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/json'},
        ),
      );

      if (mounted) {
        final bytes = response.data!;
        
        // Verify it's actually a PDF by checking magic number "%PDF"
        if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
          setState(() {
            _errorMessage = 'Server returned invalid PDF data:\\n${String.fromCharCodes(bytes)}';
            _isLoading = false;
          });
          return;
        }

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/secure_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(bytes);

        setState(() {
          _pdfBytes = Uint8List.fromList(bytes);
          _localFilePath = file.path;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Try to decode JSON error message if possible
          String errorText = e.message ?? 'Failed to download PDF';
          if (e.response?.data != null) {
            try {
              final data = e.response?.data;
              if (data is Map && data['message'] != null) {
                errorText = data['message'];
              } else if (data is List) {
                // If the response is a raw bytes list but was an error json string
                final jsonString = String.fromCharCodes(data as List<int>);
                errorText = jsonString; 
              }
            } catch (_) {}
          }
          _errorMessage = errorText;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    
    // Provide a neat filename
    final fileName = widget.title.replaceAll(' ', '_').toLowerCase() + '.pdf';
    
    final xFile = XFile.fromData(
      _pdfBytes!,
      name: fileName,
      mimeType: 'application/pdf',
    );
    
    await Share.shareXFiles([xFile], text: 'Secure Report: ${widget.title}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MainScaffold(
        title: widget.title,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading secure report...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return MainScaffold(
        title: widget.title,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _fetchPdf();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MainScaffold(
      title: widget.title,
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _sharePdf,
          tooltip: 'Share / Download',
        ),
      ],
      body: _localFilePath == null
          ? const Center(child: Text("Error: No file path"))
          : PDFView(
              filePath: _localFilePath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              onError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to render PDF: $error')),
                );
              },
            ),
    );
  }
}
