import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../main_navigation_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool forcePasswordMode;

  const LoginScreen({super.key, this.forcePasswordMode = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isBiometricMode = true;
  UserProfile? _savedUser;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedUserSession();
  }

  void _checkSavedUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricsEnabled = prefs.getBool('rentilly_biometrics_enabled') ?? true;
    final savedUser = await AuthService.getCurrentUser();

    if (savedUser != null && savedUser.email.isNotEmpty && biometricsEnabled && !widget.forcePasswordMode) {
      setState(() {
        _savedUser = savedUser;
        _isBiometricMode = true;
      });
      // Automatically prompt biometric login after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleBiometricAuth();
      });
    } else {
      setState(() {
        _savedUser = savedUser;
        _isBiometricMode = false;
        if (savedUser?.email.isNotEmpty == true) {
          _emailController.text = savedUser!.email;
        }
      });
    }
  }

  void _handleBiometricAuth() async {
    setState(() => _errorMessage = null);

    final authenticated = await BiometricService.authenticate(
      reason: 'Scan your fingerprint or face to log in to Rentilly',
    );

    if (authenticated) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Biometric authentication cancelled. Tap below to retry or switch to password.';
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rentilly_biometrics_enabled', true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Authentication failed.';
      });
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

  // 1. Futuristic Biometric-First Screen (Zero Email/Password fields shown)
  Widget _buildBiometricView() {
    final name = _savedUser?.fullName.isNotEmpty == true ? _savedUser!.fullName : 'Patrick Achua';
    final email = _savedUser?.email.isNotEmpty == true ? _savedUser!.email : 'patrickachua3@gmail.com';
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand Logo
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.shield_rounded, size: 30, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),

        // User Avatar
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials.isNotEmpty ? initials : 'PA',
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'Welcome back, $name',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 36),

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
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Large Glowing Biometric Fingerprint Button
        GestureDetector(
          onTap: _handleBiometricAuth,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.primaryLight, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.fingerprint_rounded, size: 48, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Tap to Login with Fingerprint / Face ID',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 40),

        // Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _handleBiometricAuth,
            icon: const Icon(Icons.fingerprint_rounded, size: 18, color: Colors.white),
            label: Text('Authenticate with Biometrics', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Switch to Password Button
        TextButton(
          onPressed: () {
            setState(() {
              _isBiometricMode = false;
              _errorMessage = null;
            });
          },
          child: Text(
            'Use Email & Password Instead',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  // 2. Standard Email & Password Fallback View
  Widget _buildPasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand Shield Logo
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.shield_rounded, size: 36, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Center(
          child: Text(
            'Sign In to Rentilly',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Direct real estate and living escrow protocol.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 28),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Email Field
        Text('EMAIL ADDRESS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'name@example.com',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.primary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
          ),
        ),
        const SizedBox(height: 16),

        // Password Field
        Text('PASSWORD', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
          ),
        ),
        const SizedBox(height: 24),

        // Sign In Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Sign In', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),

        if (_savedUser != null) ...[
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _isBiometricMode = true),
              icon: const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.primary),
              label: Text('Switch to Biometric Sign In', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
        ],

        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
            },
            child: RichText(
              text: TextSpan(
                text: "Don't have an account? ",
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                children: [
                  TextSpan(
                    text: 'Register Now',
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
