import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/branding/brand_logo.dart';
import 'package:school_erp_staff_app/core/config/app_colors.dart';
import 'package:school_erp_staff_app/core/config/app_config.dart';
import 'auth_controller.dart';
import 'auth_providers.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpVerifyController = TextEditingController();
  bool _isBiometricAvailable = false;
  bool _isDemoMode = false;

  // Resend cooldown timer
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricStatus();
      _checkDemoMode();
    });
  }

  Future<void> _checkDemoMode() async {
    try {
      final isDemo =
          await ref.read(authRepositoryProvider).checkDemoMode();
      if (mounted) setState(() => _isDemoMode = isDemo);
    } catch (_) {
      // leave demo buttons hidden on any error
    }
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final notifier = ref.read(authControllerProvider.notifier);
      _isBiometricAvailable = await notifier.isBiometricAvailable();
      if (mounted) setState(() {});
    } catch (e) {
      // Silently disable biometric button if check fails (e.g. no hardware)
      _isBiometricAvailable = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _phoneController.dispose();
    _otpVerifyController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  // =========================================================================
  // PASSWORD LOGIN
  // =========================================================================
  Future<void> _loginWithBiometrics() async {
    // loginWithBiometrics() now sets state via AsyncValue.guard(),
    // so errors are handled by the ref.listen callback below.
    // This try-catch is a safety net for truly unexpected failures.
    try {
      await ref.read(authControllerProvider.notifier).loginWithBiometrics();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : 'Biometric login is temporarily unavailable. Please log in with your password.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _submitCredentials() {
    FocusScope.of(context).unfocus();
    final currentState = ref.read(loginStateProvider);
    
    if (currentState == LoginScreenState.credentials &&
        (_usernameController.text.trim().isEmpty ||
            _passwordController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter both username and password.')));
      return;
    }
    if (currentState == LoginScreenState.otp &&
        _otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter the OTP.')));
      return;
    }

    ref.read(authControllerProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
          otp: currentState == LoginScreenState.otp
              ? _otpController.text.trim()
              : null,
        );
  }

  // =========================================================================
  // PASSWORDLESS OTP
  // =========================================================================
  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number or email.')),
      );
      return;
    }
    await ref.read(authControllerProvider.notifier).requestOtpLogin(phone);

    final meta = ref.read(otpMetadataProvider);
    if (meta != null && meta.otpSent) {
      _startResendTimer(meta.resendCooldown);
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpVerifyController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP.')),
      );
      return;
    }
    final identifier = ref.read(otpIdentifierProvider);
    await ref
        .read(authControllerProvider.notifier)
        .verifyOtpLogin(identifier, otp);
  }

  Future<void> _resendOtp() async {
    try {
      await ref.read(authControllerProvider.notifier).resendOtp();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent.'), backgroundColor: Colors.green),
        );
      }
      _startResendTimer(60);
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Could not resend OTP. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectSchool(AccountInfo account) async {
    final identifier = ref.read(otpIdentifierProvider);
    await ref
        .read(authControllerProvider.notifier)
        .requestOtpForUser(identifier, account.userId);

    final meta = ref.read(otpMetadataProvider);
    if (meta != null && meta.otpSent) {
      _startResendTimer(meta.resendCooldown);
    }
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        final error = next.error;
        final String message;
        if (error is ApiException) {
          message = error.message;
        } else {
          // NEVER show raw PlatformException / stack traces to users.
          // Log for debugging, show a generic friendly message.
          debugPrint('❌ [LoginScreen] Unhandled auth error: $error');
          message = 'Something went wrong. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final loginUiState = ref.watch(loginStateProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandLogo(height: 120),
              const SizedBox(height: 24),
              Text(
                AppConfig.loginSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // ===== CREDENTIALS / 2-STEP OTP =====
                      if (loginUiState == LoginScreenState.credentials ||
                          loginUiState == LoginScreenState.otp)
                        _buildCredentialsSection(loginUiState, isLoading),

                      // ===== PASSWORDLESS OTP REQUEST =====
                      if (loginUiState == LoginScreenState.otpRequest)
                        _buildOtpRequestSection(isLoading),

                      // ===== PASSWORDLESS OTP VERIFY =====
                      if (loginUiState == LoginScreenState.otpVerify)
                        _buildOtpVerifySection(isLoading),

                      // ===== SCHOOL PICKER =====
                      if (loginUiState == LoginScreenState.schoolPicker)
                        _buildSchoolPickerSection(isLoading),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION: Credentials (existing)
  // =========================================================================
  Widget _buildCredentialsSection(LoginScreenState loginUiState, bool isLoading) {
    final isOtpScreen = loginUiState == LoginScreenState.otp;

    return Column(
      children: [
        if (!isOtpScreen) ...[
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Email or Staff ID',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitCredentials(),
          ),
        ] else ...[
          const Text(
            'An OTP is required. Please check your email and enter it below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(
              labelText: 'One-Time Password',
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (_) => _submitCredentials(),
          ),
          TextButton(
            onPressed: isLoading ? null : ref.read(authControllerProvider.notifier).goBackToCredentials,
            child: const Text('Back to Login'),
          )
        ],
        const SizedBox(height: 24),
        if (isLoading)
          const CircularProgressIndicator()
        else
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 50)),
                  onPressed: _submitCredentials,
                  child: Text(
                    isOtpScreen ? 'Verify & Login' : 'Login',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              if (!isOtpScreen && _isBiometricAvailable) ...[
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    iconSize: 32,
                    icon: Icon(
                      Icons.fingerprint,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: _loginWithBiometrics,
                  ),
                ),
              ],
            ],
          ),
        // "Login with OTP" — only on the credentials screen AND only when the
        // platform has OTP login enabled. Defaults to hidden until the check
        // resolves, so a disabled setting never flashes the button.
        if (!isOtpScreen &&
            (ref.watch(otpAvailableProvider).asData?.value ?? false)) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).switchToOtpLogin(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.sms_outlined, size: 20),
            label: const Text(
              'LOGIN WITH SMS/OTP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
        if (!isOtpScreen && _isDemoMode) _buildDemoQuickAccess(isLoading),
      ],
    );
  }

  // =========================================================================
  // DEMO QUICK ACCESS (only shown when the server is in demo mode)
  // =========================================================================
  Widget _buildDemoQuickAccess(bool isLoading) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('QUICK ACCESS',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _demoButton(
                  label: 'Teacher',
                  icon: Icons.co_present_outlined,
                  role: 'teacher',
                  isLoading: isLoading),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _demoButton(
                  label: 'School Admin',
                  icon: Icons.admin_panel_settings_outlined,
                  role: 'schooladmin',
                  isLoading: isLoading),
            ),
          ],
        ),
      ],
    );
  }

  Widget _demoButton({
    required String label,
    required IconData icon,
    required String role,
    required bool isLoading,
  }) {
    return OutlinedButton.icon(
      onPressed: isLoading
          ? null
          : () => ref.read(authControllerProvider.notifier).demoLogin(role),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  // =========================================================================
  // SECTION: OTP Request (passwordless)
  // =========================================================================
  Widget _buildOtpRequestSection(bool isLoading) {
    return Column(
      children: [
        const Text(
          'Login with OTP',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your phone number or email to receive a one-time password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Phone Number or Email',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _requestOtp(),
        ),
        const SizedBox(height: 24),
        if (isLoading)
          const CircularProgressIndicator()
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _requestOtp,
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Send OTP', style: TextStyle(fontSize: 16)),
            ),
          ),
        const SizedBox(height: 20),
        const Divider(),
        TextButton.icon(
          onPressed: () => ref
              .read(authControllerProvider.notifier)
              .switchToPasswordLogin(),
          icon: Icon(Icons.lock_outline,
              color: Theme.of(context).colorScheme.primary, size: 18),
          label: Text('Login with Password instead',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      ],
    );
  }

  // =========================================================================
  // SECTION: OTP Verify (passwordless)
  // =========================================================================
  Widget _buildOtpVerifySection(bool isLoading) {
    final meta = ref.watch(otpMetadataProvider);
    final channelText = meta?.channels.isNotEmpty == true
        ? meta!.channels.map((c) => c[0].toUpperCase() + c.substring(1)).join(' & ')
        : 'your registered contact';

    return Column(
      children: [
        // Channel indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.success.withAlpha((0.3 * 255).round())),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OTP sent via $channelText to ${meta?.maskedContact ?? ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        TextFormField(
          controller: _otpVerifyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            labelText: 'Enter OTP',
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
          onFieldSubmitted: (_) => _verifyOtp(),
        ),
        const SizedBox(height: 24),

        if (isLoading)
          const CircularProgressIndicator()
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _verifyOtp,
              icon: const Icon(Icons.login),
              label: const Text('Verify & Login',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
        const SizedBox(height: 12),

        // Resend + Back
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => ref
                  .read(authControllerProvider.notifier)
                  .goBackToOtpRequest(),
              child: const Text('← Back'),
            ),
            _resendCountdown > 0
                ? Text('Resend in ${_resendCountdown}s',
                    style: TextStyle(color: Colors.grey[500]))
                : TextButton(
                    onPressed: _resendOtp,
                    child: Text('Resend OTP',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // SECTION: School Picker (multi-school)
  // =========================================================================
  Widget _buildSchoolPickerSection(bool isLoading) {
    final meta = ref.watch(otpMetadataProvider);
    final accounts = meta?.accounts ?? [];

    return Column(
      children: [
        const Text(
          'Select Your School',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Multiple accounts found. Select which school to log into:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...accounts.map((account) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: isLoading ? null : () => _selectSchool(account),
                leading: Icon(
                  account.userType == 'parent'
                      ? Icons.family_restroom
                      : Icons.badge_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(account.schoolName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(account.userType[0].toUpperCase() +
                    account.userType.substring(1)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            )),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => ref
              .read(authControllerProvider.notifier)
              .goBackToOtpRequest(),
          child: const Text('← Back'),
        ),
      ],
    );
  }
}