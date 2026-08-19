import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import '../data/student_repository.dart';

/// Shared "change a student's photo" flow: pick from camera/gallery, compress,
/// upload, and surface success/error. Returns the new photo URL on success
/// (may be an empty string) or `null` if cancelled or failed.
///
/// Used by both the student profile screen and the "Photo Missing" worklist.
Future<String?> pickAndUploadStudentPhoto(
  BuildContext context,
  int studentId,
) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 70,
    maxWidth: 1080,
  );
  if (picked == null || !context.mounted) return null;

  // showDialog pushes onto the ROOT navigator (useRootNavigator defaults to
  // true). The app runs inside a StatefulShellRoute, so a plain
  // Navigator.of(context) resolves to the shell's BRANCH navigator instead —
  // popping that would navigate the screen away and leave this loader stuck on
  // the root overlay forever. Always dismiss it via the root navigator.
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final url = await StudentRepository().updateStudentPhoto(
      studentId: studentId,
      filePath: picked.path,
      fileName: picked.name,
    );
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close loader
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated.'), backgroundColor: Colors.green),
      );
    }
    return url ?? '';
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close loader
    }
    final message = e is ApiException ? e.message : ApiException.from(e).message;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
    return null;
  }
}
