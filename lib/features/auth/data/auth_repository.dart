import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'package:school_erp_staff_app/core/storage/secure_storage_service.dart';
import 'package:school_erp_staff_app/features/auth/data/user_model.dart';

/// Result from login or OTP verify.
class LoginResult {
  final bool otpRequired;
  final String? token;
  final User? user;
  final Map<String, dynamic>? firebaseConfig;

  LoginResult({
    required this.otpRequired,
    this.token,
    this.user,
    this.firebaseConfig,
  });
}

/// Result from OTP request (step 1).
class OtpRequestResult {
  final bool otpSent;
  final bool multipleAccounts;
  final List<String> channels;
  final String? maskedContact;
  final int expiresIn;
  final int resendCooldown;
  final int? userId;
  final List<AccountInfo>? accounts;
  final String? error;

  OtpRequestResult({
    required this.otpSent,
    this.multipleAccounts = false,
    this.channels = const [],
    this.maskedContact,
    this.expiresIn = 300,
    this.resendCooldown = 60,
    this.userId,
    this.accounts,
    this.error,
  });
}

/// Account info for multi-school picker.
class AccountInfo {
  final int userId;
  final String schoolName;
  final String userType;

  AccountInfo({
    required this.userId,
    required this.schoolName,
    required this.userType,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      userId: json['user_id'] as int,
      schoolName: json['school_name'] as String,
      userType: json['user_type'] as String,
    );
  }
}

class AuthRepository {
  final ApiClient _apiClient;
  AuthRepository(this._apiClient);

  /// Cache the resolved per-school branding embedded in a login response so the
  /// next cold start themes the app for the user's school. Fire-and-forget and
  /// fully guarded — branding is cosmetic and must never affect login (plan N4).
  void _cacheBranding(dynamic data) {
    try {
      if (data is Map && data['branding'] is Map) {
        SecureStorageService().saveBrandingRaw(jsonEncode(data['branding']));
      }
    } catch (_) {
      // ignore — login proceeds regardless
    }
  }

  /// Verifies the saved token and fetches the user's latest data on app startup.
  Future<User> getProfile() async {
    try {
      final response = await _apiClient.dio.get('/staff/profile');
      return User.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException.network('Could not verify session. Please check your network connection.');
    }
  }

  /// Returns true when the backend runs in demo mode. Defaults to false on any
  /// error so real deployments never show the quick-access buttons.
  Future<bool> checkDemoMode() async {
    try {
      final response = await _apiClient.dio.get('/demo/config');
      return response.data['demo_mode'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// One-tap demo login: the server picks a seeded account for [role] and returns
  /// the same payload as a normal login.
  Future<LoginResult> demoLogin({required String role}) async {
    try {
      final response = await _apiClient.dio.post(
        '/demo/login',
        data: {
          'role': role,
          'device_name': 'mobile_app',
        },
      );
      final data = response.data;
      final token = data['token'] as String;
      final user = User.fromJson(data['user']);
      _cacheBranding(data);
      return LoginResult(
        otpRequired: false,
        token: token,
        user: user,
        firebaseConfig: data['firebase_config'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException.network('Could not connect to the server. Please try again later.');
    }
  }

  /// Check if OTP login is enabled on the platform.
  Future<bool> checkOtpAvailability() async {
    try {
      final response = await _apiClient.dio.get('/otp-login/check');
      return response.data['otp_available'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Attempts to log the user in with credentials and optional OTP.
  Future<LoginResult> login({
    required String username,
    required String password,
    String? otp,
  }) async {
    try {
      final deviceUuid = await SecureStorageService().getDeviceUuid();
      final response = await _apiClient.dio.post(
        '/login',
        data: {
          'username': username,
          'password': password,
          'device_name': 'mobile_app',
          'device_uuid': deviceUuid,
          if (otp != null) 'otp': otp,
        },
      );
      final data = response.data;
      final bool otpRequired = data['otp_required'] ?? false;

      if (otpRequired) {
        return LoginResult(otpRequired: true);
      } else {
        final token = data['token'] as String;
        final user = User.fromJson(data['user']);
        _cacheBranding(data);
        return LoginResult(
          otpRequired: false,
          token: token,
          user: user,
          firebaseConfig: data['firebase_config'] as Map<String, dynamic>?,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException.network('Could not connect to the server. Please try again later.');
    }
  }

  // =========================================================================
  // PASSWORDLESS OTP LOGIN
  // =========================================================================

  /// Step 1: Request OTP for a phone number or email.
  Future<OtpRequestResult> requestOtp({required String identifier}) async {
    try {
      final response = await _apiClient.dio.post(
        '/otp-login/request',
        data: {
          'identifier': identifier,
          'app': 'staff',
        },
      );
      final data = response.data as Map<String, dynamic>;

      if (data['multiple_accounts'] == true) {
        final accounts = (data['accounts'] as List)
            .map((a) => AccountInfo.fromJson(a as Map<String, dynamic>))
            .toList();
        return OtpRequestResult(
          otpSent: false,
          multipleAccounts: true,
          accounts: accounts,
        );
      }

      return OtpRequestResult(
        otpSent: data['otp_sent'] as bool? ?? false,
        channels: List<String>.from(data['channels'] ?? []),
        maskedContact: data['masked_contact'] as String?,
        expiresIn: data['expires_in'] as int? ?? 300,
        resendCooldown: data['resend_cooldown'] as int? ?? 60,
        userId: data['user_id'] as int?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network('Connection Error: ${e.toString()}');
    }
  }

  /// Step 2: Verify OTP and get auth token.
  Future<LoginResult> verifyOtp({
    required String identifier,
    required String otp,
    int? userId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/otp-login/verify',
        data: {
          'identifier': identifier,
          'otp': otp,
          'app': 'staff',
          if (userId != null) 'user_id': userId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = User.fromJson(data['user']);
      _cacheBranding(data);

      return LoginResult(
        otpRequired: false,
        token: token,
        user: user,
        firebaseConfig: data['firebase_config'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException.network('Could not connect to the server.');
    }
  }

  /// Resend OTP with cooldown.
  Future<OtpRequestResult> resendOtp({
    required String identifier,
    int? userId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/otp-login/resend',
        data: {
          'identifier': identifier,
          'app': 'staff',
          if (userId != null) 'user_id': userId,
        },
      );
      final data = response.data as Map<String, dynamic>;

      return OtpRequestResult(
        otpSent: data['otp_sent'] as bool? ?? false,
        channels: List<String>.from(data['channels'] ?? []),
        maskedContact: data['masked_contact'] as String?,
        expiresIn: data['expires_in'] as int? ?? 300,
        resendCooldown: data['resend_cooldown'] as int? ?? 60,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException.network('Could not connect to the server.');
    }
  }
}