import 'package:flutter/material.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';

/// A reusable widget that renders appropriate error UI based on the error type.
///
/// Replaces all the ad-hoc `errorStr.contains('403')` patterns scattered
/// across screens with a single, consistent error display.
///
/// Usage:
/// ```dart
/// error: (err, stack) => ApiErrorWidget(
///   error: err,
///   onRetry: () => ref.invalidate(someProvider),
/// ),
/// ```
class ApiErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ApiErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final apiError = _resolveError(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(apiError),
            const SizedBox(height: 20),
            Text(
              _getTitle(apiError),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              apiError.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel ?? 'Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ApiException apiError) {
    if (apiError.isForbidden) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.lock_person, size: 48, color: Colors.orange.shade700),
      );
    }
    if (apiError.isUnauthorized) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.key_off, size: 48, color: Colors.red.shade700),
      );
    }
    if (apiError.isNetworkError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.wifi_off, size: 48, color: Colors.blue.shade700),
      );
    }
    if (apiError.isNotFound) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.search_off, size: 48, color: Colors.grey.shade600),
      );
    }
    // Generic / server error
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
    );
  }

  String _getTitle(ApiException apiError) {
    if (apiError.isForbidden) return 'Access Restricted';
    if (apiError.isUnauthorized) return 'Session Expired';
    if (apiError.isNetworkError) return 'No Connection';
    if (apiError.isNotFound) return 'Not Found';
    if (apiError.isServerError) return 'Server Error';
    return 'Something Went Wrong';
  }

  /// Resolve any error type into an [ApiException] for consistent rendering.
  /// Delegates to the single normaliser so a raw [DioException], socket dump,
  /// or stray string is always shown as a friendly, typed error.
  ApiException _resolveError(Object error) => ApiException.from(error);
}
