import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/features/auth/data/auth_repository.dart';
import 'package:school_erp_staff_app/core/auth/biometric_service.dart';

// Manages the UI of the LoginScreen (showing password, OTP, or passwordless OTP flow)
enum LoginScreenState {
  credentials,  // Default: username + password
  otp,          // Existing: OTP for 2-step (after password)
  otpRequest,   // NEW: passwordless — enter phone/email
  otpVerify,    // NEW: passwordless — enter OTP code
  schoolPicker, // NEW: multi-school disambiguation
}

final loginStateProvider =
    StateProvider<LoginScreenState>((ref) => LoginScreenState.credentials);

// Provides the AuthRepository instance to the controller
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

// Provides the BiometricService instance
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

// NEW: Holds OTP request metadata for the verify screen
final otpMetadataProvider = StateProvider<OtpRequestResult?>((ref) => null);

// NEW: Holds the identifier (phone/email) being used for OTP login
final otpIdentifierProvider = StateProvider<String>((ref) => '');

// NEW: Holds userId for multi-school scenarios
final otpUserIdProvider = StateProvider<int?>((ref) => null);

// NEW: Checks if OTP login is enabled on the platform (cached per session)
final otpAvailableProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return await repo.checkOtpAvailability();
});