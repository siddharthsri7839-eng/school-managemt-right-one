import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/api/api_providers.dart';
import 'core/branding/branding.dart';
import 'core/branding/branding_providers.dart';
import 'core/branding/branding_repository.dart';
import 'core/config/app_colors.dart';
import 'core/config/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/storage/secure_storage_service.dart';

// This container is made global to be accessible by the AuthInterceptor.
final providerContainer = ProviderContainer();

Future<void> main() async {
  // Required for async operations before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Load the IANA timezone database so attendance punch times can be rendered
  // in the school's timezone regardless of the device's clock/timezone.
  tz.initializeTimeZones();

  // Load cached (or compile-time fallback) branding BEFORE the first frame so the
  // app opens instantly and offline, already themed (plan §5.1 N2). Never throws.
  try {
    final dio = providerContainer.read(apiClientProvider).dio;
    BrandingNotifier.seed = (await BrandingRepository(dio).loadCached()).effective;
  } catch (_) {
    BrandingNotifier.seed = const Branding.fallback();
  }
  AppColors.applyBranding(BrandingNotifier.seed);

  // NOTE: We no longer await authControllerProvider here.
  // The SplashScreen handles the auth initialization and shows a branded
  // loading screen instead of a blank white screen.

  runApp(
    UncontrolledProviderScope(
      container: providerContainer,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // After the first frame, refresh ONLY the platform brand and ONLY when not
    // logged in. A logged-in user keeps the per-school brand cached at login and
    // seeded at bootstrap — we must not clobber it. Failures are ignored (E7).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = await SecureStorageService().readToken();
      if (token == null) {
        ref.read(brandingProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final branding = ref.watch(brandingProvider);

    return MaterialApp.router(
      title: branding.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(branding),
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
    );
  }
}
