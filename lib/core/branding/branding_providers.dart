import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import 'branding.dart';
import 'branding_repository.dart';
import 'terminology.dart';

/// Current branding for the staff app. Seeded synchronously at bootstrap (from
/// the local cache or the compile-time fallback) so the first frame is themed,
/// then refreshed from the network in the background.
final brandingProvider =
    NotifierProvider<BrandingNotifier, Branding>(BrandingNotifier.new);

/// The school's academic wording (Class/Section/Subject → Year/Form/…).
/// Derived from the branding payload; canonical English until the school (and
/// the platform master switch) opts in. Watch this in any screen that renders
/// one of the three governed nouns.
final terminologyProvider = Provider<Terminology>(
  (ref) => ref.watch(brandingProvider.select((b) => b.terminology)),
);

class BrandingNotifier extends Notifier<Branding> {
  /// Set in `main()` BEFORE `runApp` so the initial state is the cached brand.
  static Branding seed = const Branding.fallback();

  @override
  Branding build() => seed;

  /// Background refresh. On any failure the current state is kept (plan E7).
  Future<void> refresh({int? schoolId}) async {
    try {
      final repo = BrandingRepository(ref.read(apiClientProvider).dio);
      final fetched = await repo.fetchAndCache(schoolId: schoolId);
      state = fetched.effective;
    } catch (_) {
      // keep current state
    }
  }

  /// Apply a branding object obtained elsewhere (e.g. login response).
  void apply(Branding branding) => state = branding.effective;
}
