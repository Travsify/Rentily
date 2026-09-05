import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/payment_security_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/security_telemetry_service.dart';
import '../../services/otp_service.dart';
import '../../widgets/login_2fa_modal.dart';
import '../main_navigation_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool forcePasswordMode;
  final bool isFromInactivityTimeout;

  const LoginScreen({
    super.key,
    this.forcePasswordMode = false,
    this.isFromInactivityTimeout = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isBiometricMode = true;
  bool _pinSetUp = false; // tracks if user has created their 6-digit security PIN
  UserProfile? _savedUser;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkSavedUserSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkSavedUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricsEnabled = prefs.getBool('rentilly_biometrics_enabled') ?? false;
    final rememberedUser = await AuthService.getRememberedUser();
    final wasLockedFromInactivity = prefs.getBool('rentilly_session_locked_inactivity') ?? false;

    // Also verify biometrics are ACTUALLY available on this device,
    // not just that the flag was set. Without this check, users without
    // enrolled fingerprints get stuck on the biometric screen.
    final bioHardwareAvailable = await BiometricService.isBiometricsAvailable();

    final canUseBiometrics = rememberedUser != null &&
        !widget.forcePasswordMode &&
        bioHardwareAvailable &&
        (biometricsEnabled || wasLockedFromInactivity || widget.isFromInactivityTimeout);

    // Load whether user has set up a PIN (for PIN prompt in profile)
    final pinSetUp = await PaymentSecurityService.hasPaymentPin();

    if (canUseBiometrics) {
      if (mounted) {
        setState(() {
          _savedUser = rememberedUser;
          _isBiometricMode = true;
          _pinSetUp = pinSetUp;
          if (rememberedUser.email.isNotEmpty) {
            _emailController.text = rememberedUser.email;
          }
        });

        // Automatically prompt biometrics if returning from inactivity timeout
        if (widget.isFromInactivityTimeout || wasLockedFromInactivity) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleBiometricAuth();
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _savedUser = rememberedUser;
          _isBiometricMode = false;
          _pinSetUp = pinSetUp;
          if (rememberedUser?.email.isNotEmpty == true) {
            _emailController.text = rememberedUser!.email;
          }
        });
      }
    }
  }

  void _handleBiometricAuth() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authenticated = await BiometricService.authenticate(
        reason: 'Scan your fingerprint to unlock your Rentilly account',
      );

      if (authenticated) {
        final result = await AuthService.loginWithBiometrics();
        final user = result['user'] as UserProfile? ?? await AuthService.getCurrentUser();
        final isPartner = user != null && user.isPartner;
        final isLandlord = user != null && user.isLandlord;

        // Register user with OneSignal for push notifications
        await PushNotificationService.setUserTags();

        // Dispatch immediate security telemetry email alert
        if (user != null) {
          SecurityTelemetryService.recordActivity(
            title: 'Biometric Sign-in Alert 🛡️',
            message: 'Your Rentilly account was successfully unlocked using biometric authentication.',
            userEmail: user.email,
            userName: user.fullName,
            userId: user.id,
            category: 'security',
            extraMetadata: {'Authentication Type': 'Biometric Fingerprint / Face ID'},
          );
        }

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MainNavigationScreen(
              initialPartnerMode: isPartner,
              initialLandlordMode: isLandlord,
            ),
          ),
          (route) => false,
        );
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Biometric scan was not completed. Tap the fingerprint icon to try again or switch to password.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Biometric service temporarily unavailable. Please use password to sign in.';
        });
      }
    }
  }

  void _handlePasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(email: email, password: password);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'] as UserProfile?;
      final isPartner = user != null && user.isPartner;
      final isLandlord = user != null && user.isLandlord;

      // 1. Dispatch high-security 6-digit OTP via Resend API
      setState(() => _isLoading = true);
      await OtpService.sendOtp(
        email: email,
        userName: user?.fullName,
        channel: 'email',
        purpose: 'Sign-in Authentication 2FA',
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      // 2. Present 2FA OTP Confirmation Modal
      Login2faModal.show(
        context,
        email: email,
        userName: user?.fullName,
        onVerified: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('rentilly_biometrics_enabled', true);

          // Register user with OneSignal for push notifications
          await PushNotificationService.setUserTags();

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => MainNavigationScreen(
                initialPartnerMode: isPartner,
                initialLandlordMode: isLandlord,
              ),
            ),
            (route) => false,
          );
        },
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Authentication failed.';
      });
    }
  }

  void _handleDirectOtpLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address to receive a login OTP code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await OtpService.sendOtp(
        email: email,
        channel: 'email',
        purpose: 'Sign-in Login OTP',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        Login2faModal.show(
          context,
          email: email,
          onVerified: () async {
            final currentUser = await AuthService.getCurrentUser();
            final isPartner = currentUser != null && currentUser.isPartner;
            final isLandlord = currentUser != null && currentUser.isLandlord;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('rentilly_biometrics_enabled', true);
            await PushNotificationService.setUserTags();

            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => MainNavigationScreen(
                  initialPartnerMode: isPartner,
                  initialLandlordMode: isLandlord,
                ),
              ),
              (route) => false,
            );
          },
        );
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Could not send login OTP. Please check your email.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error while sending OTP. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: _isBiometricMode ? _buildBiometricView() : _buildPasswordView(),
          ),
        ),
      ),
    );
  }

  // 1. Futuristic Fintech Biometric Screen (Revolut / Apple Pay style)
  Widget _buildBiometricView() {
    final name = _savedUser?.fullName.isNotEmpty == true ? _savedUser!.fullName : 'Rentilly User';
    final email = _savedUser?.email.isNotEmpty == true ? _savedUser!.email : '';
    final accNum = _savedUser?.accountNumber?.isNotEmpty == true ? _savedUser!.accountNumber! : '';
    final maskedAcc = accNum.length >= 4 ? '•••• ${accNum.substring(accNum.length - 4)}' : '';
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand Shield Emblem
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.shield_rounded, size: 28, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'RENTILLY',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'Rentilly Escrow & Direct Real Estate Exchange',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // User Identity Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderDark),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.backgroundDark,
                      border: Border.all(color: AppColors.primaryLight, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'PA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Welcome, $name',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$email • Dedicated Escrow $maskedAcc',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Interactive Pulsing Biometric Fingerprint Button
        GestureDetector(
          onTap: _handleBiometricAuth,
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                      )
                    : const Icon(Icons.fingerprint_rounded, size: 54, color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'Verify Fingerprint',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        Text(
          'Click to log in with fingerprint',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 36),

        // Action Button: Verify Fingerprint
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleBiometricAuth,
            icon: const Icon(Icons.fingerprint_rounded, size: 20, color: Colors.white),
            label: Text(
              'Verify Fingerprint to Log In',
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Alternative 1: Sign in with Password
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isBiometricMode = false;
                _errorMessage = null;
              });
            },
            icon: const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary),
            label: Text(
              'Sign in with Password instead',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: AppColors.borderDark, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Alternative 2: Sign in with Email OTP
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isBiometricMode = false;
                _errorMessage = null;
              });
              _handleDirectOtpLogin();
            },
            icon: const Icon(Icons.mark_email_read_outlined, size: 16, color: AppColors.primary),
            label: Text(
              'Sign in with OTP Code instead',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Switch / Use Another Account
        TextButton(
          onPressed: () {
            setState(() {
              _isBiometricMode = false;
              _savedUser = null;
              _emailController.clear();
              _passwordController.clear();
              _errorMessage = null;
            });
          },
          child: Text(
            'Use Another Account',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),

        // ── PIN Setup Notice ──────────────────────────────────────────────────
        // Only shown when user has NOT yet created their security PIN.
        // They must create one before they can authorize transactions.
        if (!_pinSetUp) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final created = await PaymentSecurityService.authorizeTransaction(
                context,
                title: 'Set Up Security PIN',
                amount: 0,
              );
              if (created && mounted) {
                setState(() => _pinSetUp = true);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_outlined, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Up Your Security PIN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          'You need a 6-digit PIN to authorize payments. Tap to create one now.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFD97706)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 2. Email & Password View (Only displayed when explicitly requested)
  Widget _buildPasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.shield_rounded, size: 32, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: Text(
            'Welcome to Rentilly',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Sign in to access your direct escrow portal',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 32),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'EMAIL ADDRESS',
          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. patrickachua3@gmail.com',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'PASSWORD',
          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textSecondary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 10),

        // Forgot Password Action
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(
                    initialEmail: _emailController.text.trim(),
                  ),
                ),
              );
            },
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text('Sign In with Password', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),

        // Direct Login with OTP Code
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleDirectOtpLogin,
            icon: const Icon(Icons.mark_email_read_outlined, size: 18, color: AppColors.primary),
            label: Text(
              'Sign In with OTP Code (Email)',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_savedUser != null)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _isBiometricMode = true),
              icon: const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.primary),
              label: Text('Use Biometric Fingerprint Login', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),

        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: Text.rich(
              TextSpan(
                text: "Don't have an account? ",
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                children: [
                  TextSpan(
                    text: 'Create Account',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
