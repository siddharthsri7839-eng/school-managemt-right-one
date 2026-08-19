import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'package:school_erp_staff_app/core/services/push_notification_service.dart';
import 'package:school_erp_staff_app/core/storage/secure_storage_service.dart';
import 'package:school_erp_staff_app/features/auth/data/auth_repository.dart';
import 'package:school_erp_staff_app/features/auth/data/user_model.dart';
import 'package:school_erp_staff_app/core/auth/biometric_service.dart';
import 'auth_providers.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  late final AuthRepository _authRepository;
  late final SecureStorageService _storageService;
  late final BiometricService _biometricService;

  @override
  Future<User?> build() async {
    _authRepository = ref.watch(authRepositoryProvider);
    _storageService = SecureStorageService();
    _biometricService = ref.watch(biometricServiceProvider);

    final token = await _storageService.readToken();
    if (token != null) {
      try {
        final user = await _authRepository.getProfile();
        
        // Allow all staff roles, exclude students and parents
        final forbiddenTypes = ['student', 'parent'];
        if (forbiddenTypes.contains(user.userType)) {
          await _storageService.deleteSession();
          return null;
        }

        // Re-init push notifications from the config saved at login.
        // Fire-and-forget — must never delay or break session restore.
        _storageService.readFirebaseConfig().then((config) {
          if (config != null) {
            PushNotificationService.fcmInit(config);
          }
        });

        return user;
      } catch (e) {
        await _storageService.deleteSession();
        return null;
      }
    }
    return null;
  }

  // =========================================================================
  // EXISTING: Password login
  // =========================================================================
  Future<void> login(String username, String password, {String? otp}) async {
    state = await AsyncValue.guard(() async {
      final result = await _authRepository.login(
          username: username, password: password, otp: otp);

      if (result.otpRequired) {
        ref.read(loginStateProvider.notifier).state = LoginScreenState.otp;
        return null;
      }

      if (result.token != null && result.user != null) {
        final forbiddenTypes = ['student', 'parent'];

        if (!forbiddenTypes.contains(result.user!.userType)) {
          await _storageService.saveSession(
            token: result.token!,
            user: result.user!,
            firebaseConfig: result.firebaseConfig,
            username: username,
            password: password,
          );

          // Give the platform a moment to fully commit secure storage
          // before the UI navigates to the dashboard.
          await Future.delayed(const Duration(milliseconds: 300));

          await PushNotificationService.fcmInit(result.firebaseConfig);

          return result.user;
        } else {
          throw const ApiException.forbidden('Access Denied. Please use the Parent/Student App for this account.');
        }
      }
      throw const ApiException.server('Invalid response from the server.');
    });
  }

  // =========================================================================
  // DEMO QUICK-ACCESS LOGIN
  // =========================================================================
  /// One-tap demo login. Mirrors [login] but takes no credentials and never
  /// stores them for biometric reuse (demo sessions are throwaway).
  Future<void> demoLogin(String role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _authRepository.demoLogin(role: role);

      if (result.token != null && result.user != null) {
        final forbiddenTypes = ['student', 'parent'];
        if (forbiddenTypes.contains(result.user!.userType)) {
          throw const ApiException.forbidden(
              'Access Denied. Please use the Parent/Student App for this account.');
        }
        await _storageService.saveSession(
          token: result.token!,
          user: result.user!,
          firebaseConfig: result.firebaseConfig,
        );
        await Future.delayed(const Duration(milliseconds: 300));
        await PushNotificationService.fcmInit(result.firebaseConfig);
        return result.user;
      }
      throw const ApiException.server('Invalid response from the server.');
    });
  }

  // =========================================================================
  // NEW: Passwordless OTP login
  // =========================================================================

  /// Step 1: Request OTP for a phone number or email.
  Future<void> requestOtpLogin(String identifier) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result =
          await _authRepository.requestOtp(identifier: identifier);

      ref.read(otpIdentifierProvider.notifier).state = identifier;

      if (result.multipleAccounts && result.accounts != null) {
        ref.read(otpMetadataProvider.notifier).state = result;
        ref.read(loginStateProvider.notifier).state =
            LoginScreenState.schoolPicker;
        return null;
      }

      if (result.otpSent) {
        ref.read(otpMetadataProvider.notifier).state = result;
        ref.read(otpUserIdProvider.notifier).state = result.userId;
        ref.read(loginStateProvider.notifier).state =
            LoginScreenState.otpVerify;
      }

      return null;
    });
  }

  /// Step 1b: Send OTP for a specific user (after school picker).
  Future<void> requestOtpForUser(String identifier, int userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      ref.read(otpUserIdProvider.notifier).state = userId;
      final result = await _authRepository.resendOtp(
        identifier: identifier,
        userId: userId,
      );

      if (result.otpSent) {
        ref.read(otpMetadataProvider.notifier).state = result;
        ref.read(loginStateProvider.notifier).state =
            LoginScreenState.otpVerify;
      }

      return null;
    });
  }

  /// Step 2: Verify OTP and log in.
  Future<void> verifyOtpLogin(String identifier, String otp) async {
    state = await AsyncValue.guard(() async {
      final userId = ref.read(otpUserIdProvider);
      final result = await _authRepository.verifyOtp(
        identifier: identifier,
        otp: otp,
        userId: userId,
      );

      if (result.token != null && result.user != null) {
        final forbiddenTypes = ['student', 'parent'];

        if (!forbiddenTypes.contains(result.user!.userType)) {
          await _storageService.saveSession(
            token: result.token!,
            user: result.user!,
            firebaseConfig: result.firebaseConfig,
          );

          await Future.delayed(const Duration(milliseconds: 300));
          await PushNotificationService.fcmInit(result.firebaseConfig);
          return result.user;
        } else {
          throw const ApiException.forbidden('Access Denied. Please use the Parent/Student App.');
        }
      }
      throw const ApiException.server('Invalid response from the server.');
    });
  }

  /// Resend OTP.
  Future<void> resendOtp() async {
    final identifier = ref.read(otpIdentifierProvider);
    final userId = ref.read(otpUserIdProvider);

    final result = await _authRepository.resendOtp(
      identifier: identifier,
      userId: userId,
    );

    if (result.otpSent) {
      ref.read(otpMetadataProvider.notifier).state = result;
    }
  }

  // =========================================================================
  // EXISTING: Biometric login
  // =========================================================================
  Future<void> loginWithBiometrics() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final isBiometricEnabled = await _storageService.isBiometricEnabled();
      if (!isBiometricEnabled) {
        throw const ApiException.forbidden('Biometric login is not enabled.');
      }

      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        // User cancelled or biometric failed — just return current state quietly
        return state.valueOrNull;
      }

      final creds = await _storageService.getStoredCredentials();
      if (creds == null) {
        // Keystore was corrupted or credentials were wiped — disable biometric
        // so the user isn't stuck in a loop, and ask them to log in normally.
        await _storageService.clearBiometricData();
        throw const ApiException.forbidden(
          'Your saved login has expired or was reset by the device. '
          'Please log in with your username and password to re-enable biometric login.',
        );
      }

      final result = await _authRepository.login(
        username: creds['username']!,
        password: creds['password']!,
      );

      if (result.token != null && result.user != null) {
        await _storageService.saveSession(
          token: result.token!,
          user: result.user!,
          firebaseConfig: result.firebaseConfig,
        );

        // Give the platform a moment to fully commit secure storage
        await Future.delayed(const Duration(milliseconds: 300));

        await PushNotificationService.fcmInit(result.firebaseConfig);

        return result.user;
      }
      throw const ApiException.server('Biometric login failed. Please try logging in with your password.');
    });
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storageService.setBiometricEnabled(enabled);
  }

  Future<bool> isBiometricAvailable() async {
    return await _biometricService.isBiometricAvailable();
  }

  Future<bool> getBiometricPreference() async {
    return await _storageService.isBiometricEnabled();
  }

  // =========================================================================
  // NAVIGATION
  // =========================================================================
  void goBackToCredentials() {
    state = AsyncValue.data(state.valueOrNull);
    ref.read(loginStateProvider.notifier).state = LoginScreenState.credentials;
  }

  void switchToOtpLogin() {
    state = AsyncValue.data(state.valueOrNull);
    ref.read(loginStateProvider.notifier).state = LoginScreenState.otpRequest;
  }

  void switchToPasswordLogin() {
    state = AsyncValue.data(state.valueOrNull);
    ref.read(loginStateProvider.notifier).state = LoginScreenState.credentials;
  }

  void goBackToOtpRequest() {
    state = AsyncValue.data(state.valueOrNull);
    ref.read(otpMetadataProvider.notifier).state = null;
    ref.read(otpUserIdProvider.notifier).state = null;
    ref.read(loginStateProvider.notifier).state = LoginScreenState.otpRequest;
  }

  // =========================================================================
  // LOGOUT
  // =========================================================================
  Future<void> logout() async {
    state = const AsyncValue.loading();

    // Remove the device token while the auth token is still valid.
    await PushNotificationService.unregister();

    // Trigger router redirect to login screen immediately
    state = const AsyncValue.data(null);
    ref.read(loginStateProvider.notifier).state = LoginScreenState.credentials;
    
    // Wait for the route transition and Hero animations to complete
    // so any lingering widgets don't crash from missing tokens during unmount.
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Safely purge the token from memory and device
    await _storageService.deleteSession();
  }
}