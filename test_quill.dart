import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'dart:convert';

void main() {
  // Try to find html to delta in flutter_quill
  try {
    print('Testing flutter_quill HTML support...');
    // This is pseudo-code to test existence
    // final doc = Document.fromHtml('<p>test</p>');
    print('flutter_quill test done');
  } catch (e) {
    print(e);
  }
}
