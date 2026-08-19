import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'branding_providers.dart';

/// Renders the brand logo with a resilient fallback chain (plan §5.4):
///   network `logo_url`  →  bundled `assets/images/app_logo.png`  →  themed icon.
/// A 404 / unreachable / null logo never yields a broken-image box.
class BrandLogo extends ConsumerWidget {
  final double? height;
  final double? width;
  final BoxFit fit;

  const BrandLogo({super.key, this.height, this.width, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoUrl = ref.watch(brandingProvider.select((b) => b.logoUrl));

    if (logoUrl == null || logoUrl.isEmpty) {
      return _bundled(context);
    }

    return Image.network(
      logoUrl,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _bundled(context),
      errorBuilder: (context, error, stack) => _bundled(context),
    );
  }

  Widget _bundled(BuildContext context) {
    return Image.asset(
      'assets/images/app_logo.png',
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stack) => Icon(
        Icons.school_rounded,
        size: height ?? width ?? 40,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
