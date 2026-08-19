import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  /// Checks if the device has biometric hardware and if it's configured.
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      if (!canAuthenticate) return false;

      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint("❌ [Biometric] Availability check failed: $e");
      return false;
    } catch (e) {
      debugPrint("❌ [Biometric] Unexpected error checking availability: $e");
      return false;
    }
  }

  /// Triggers the biometric authentication prompt.
  Future<bool> authenticate() async {
    if (_isAuthenticating) {
      debugPrint("ℹ️ [Biometric] Authentication already in progress. Skipping.");
      return false;
    }

    try {
      _isAuthenticating = true;
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to log in to SCS Staff',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("❌ [Biometric] Authentication PlatformException: $e");
      return false;
    } catch (e) {
      debugPrint("❌ [Biometric] Unexpected authentication error: $e");
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }
}
