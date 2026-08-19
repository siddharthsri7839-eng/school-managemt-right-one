import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:school_erp_staff_app/features/auth/data/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class SecureStorageService {
  // Singleton pattern
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  // Safe read helper to prevent crashes due to Android Keystore corruption
  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      debugPrint("🛡️ [Security] PlatformException during read. Keystore might be corrupted: $e");
      try {
        await _storage.deleteAll();
      } catch (e2) {
        debugPrint("❌ [Storage] FAILED to delete all storage after exception: $e2");
      }
      return null;
    } catch (e) {
      debugPrint("❌ [Storage] FAILED to read key $key: $e");
      return null;
    }
  }
  // Static cache to bridge ALL instances and prevent race conditions
  static String? _cachedToken;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _firebaseConfigKey = 'firebase_config';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _lastUsernameKey = 'last_username';
  static const _lastPasswordKey = 'last_password';
  static const _deviceUuidKey = 'device_uuid';
  static const _brandingKey = 'branding_payload';

  /// Returns a stable per-install device id, generating and persisting one on
  /// first use. Used by the backend for device binding (one account = one
  /// device) and to stop a single phone punching attendance for many staff.
  Future<String> getDeviceUuid() async {
    try {
      final existing = await _safeRead(_deviceUuidKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final newId = const Uuid().v4();
      await _storage.write(key: _deviceUuidKey, value: newId);
      return newId;
    } catch (e) {
      debugPrint("❌ [Storage] FAILED to get device uuid: $e");
      // Fall back to an ephemeral id so attendance still works; the backend
      // treats a missing/changing id as unbound rather than blocking the user.
      return const Uuid().v4();
    }
  }

  Future<void> saveSession({
    required String token,
    required User user,
    Map<String, dynamic>? firebaseConfig,
    String? username,
    String? password,
  }) async {
    try {
      _cachedToken = token; // Update cache immediately
      
      // ✅ SECURITY HARDENING: If a different user is logging in, 
      // wipe the biometric data of the previous user to prevent "Race Condition" logins.
      if (username != null) {
        final lastUser = await _safeRead(_lastUsernameKey);
        if (lastUser != null && lastUser != username) {
          debugPrint("🛡️ [Security] Different user detected. Clearing legacy biometric data.");
          await clearBiometricData();
        }
      }

      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

      if (firebaseConfig != null) {
        await _storage.write(key: _firebaseConfigKey, value: jsonEncode(firebaseConfig));
      }

      // Save credentials for biometric login if provided
      if (username != null && password != null) {
        await _storage.write(key: _lastUsernameKey, value: username);
        await _storage.write(key: _lastPasswordKey, value: password);
      }

      debugPrint("🚀 [STATIC-CACHE] Session and credentials updated.");
    } catch (e) {
      debugPrint("❌ [Storage] FAILED to save session: $e");
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _safeRead(_biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint("❌ [Storage] Unexpected error reading biometric preference: $e");
      return false;
    }
  }

  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final username = await _safeRead(_lastUsernameKey);
      final password = await _safeRead(_lastPasswordKey);
      if (username != null && password != null) {
        return {'username': username, 'password': password};
      }
      return null;
    } catch (e) {
      debugPrint("❌ [Storage] Unexpected error reading credentials: $e");
      return null;
    }
  }

  Future<void> clearBiometricData() async {
    _cachedToken = null; // Also clear cache when clearing biometric data just in case
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _lastUsernameKey);
    await _storage.delete(key: _lastPasswordKey);
  }

  Future<String?> readToken() async {
    try {
      if (_cachedToken != null) {
        debugPrint("🎯 [STATIC-CACHE] Token FOUND in memory!");
        return _cachedToken;
      }

      final token = await _safeRead(_tokenKey);
      if (token != null) {
        _cachedToken = token; // Populate cache
        debugPrint("💾 [STATIC-CACHE] Token loaded from DISK into memory.");
      } else {
        debugPrint("❓ [STATIC-CACHE] Token NOT FOUND anywhere.");
      }
      return token;
    } catch (e) {
      debugPrint("❌ [Storage] FAILED to read token: $e");
      return null;
    }
  }

  Future<User?> readUser() async {
    try {
      final userJson = await _safeRead(_userKey);
      if (userJson != null) {
        debugPrint("✅ [Storage] User data read successfully.");
        return User.fromJson(jsonDecode(userJson));
      }
      debugPrint("ℹ️ [Storage] No user data found in storage.");
      return null;
    } catch (e) {
      debugPrint("❌ [Storage] FAILED to read user data: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> readFirebaseConfig() async {
    try {
      final configJson = await _safeRead(_firebaseConfigKey);
      if (configJson != null) {
        return jsonDecode(configJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("❌ [Storage] FAILED to read firebase config: $e");
      return null;
    }
  }

  /// Cache the raw `/branding` JSON payload for instant offline theming on the
  /// next cold start. Non-sensitive; reuses secure storage to avoid a new dep.
  Future<void> saveBrandingRaw(String raw) async {
    try {
      await _storage.write(key: _brandingKey, value: raw);
    } catch (e) {
      debugPrint("⚠️ [Storage] Failed to cache branding: $e");
    }
  }

  /// Read the cached branding payload. Returns null if absent/unreadable.
  Future<String?> readBrandingRaw() => _safeRead(_brandingKey);

  Future<void> deleteSession() async {
    try {
      _cachedToken = null; // Clear cache immediately
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
      await _storage.delete(key: _firebaseConfigKey);
      debugPrint("✅ [Storage] Session deleted successfully from memory and device.");
    } catch (e) {
      debugPrint("❌ [Storage] FAILED to delete session: $e");
    }
  }
}