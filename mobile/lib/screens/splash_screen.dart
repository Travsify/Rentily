import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'auth/login_screen.dart';
import 'onboarding_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _checkAuthGate();
  }

  void _checkAuthGate() async {
    // Proactively fetch remote feature flags so they are cached before reaching dashboard
    try {
      await ApiService.fetchFeatureFlags();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 2600));
    _proceedToNextScreen();
  }

  void _proceedToNextScreen() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // Check if user has seen onboarding
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool(AppConstants.seenOnboardingKey) ?? false;

    if (!mounted) return;

    // First-time user → show onboarding
    if (!seenOnboarding) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }

    // Returning user → check auth
    final bool loggedIn = await AuthService.isLoggedIn();
    final user = await AuthService.getCurrentUser();

    if (!mounted) return;

    if (loggedIn) {
      final isPartner = user != null && user.isPartner;
      final isLandlord = user != null && user.isLandlord;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => MainNavigationScreen(
            initialPartnerMode: isPartner,
            initialLandlordMode: isLandlord,
          ),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D1B), // Deep, ultra-clean solid dark surface
      body: SafeArea(
        child: Stack(
          children: [
            // Center Branding & Value Proposition
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Rentilly Logo with High-Contrast Emerald Glow
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 36,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 2. Main Title in ULTRA-BRIGHT Pure White
                            Text(
                              AppConstants.appName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: Colors.white, // Ultra-visible pure white
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Official Core Mission Statement
                            Text(
                              'Built by Landlords for Every Tenant/Landlord',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF34D399), // High-visibility bright emerald
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 3. High-Contrast Tagline Pill (Federal & Nationwide)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'NATIONWIDE DIRECT RENTALS • ZERO AGENTS • ESCROW SAFE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // 4. Key Value Guidance Pillars (Resonating across all 36 States & FCT)
                            _buildFeaturePill(
                              icon: Icons.verified_user_rounded,
                              title: 'Verified Landlords Nationwide',
                              subtitle: 'Direct owner listings across all 36 States & the FCT',
                            ),
                            const SizedBox(height: 10),
                            _buildFeaturePill(
                              icon: Icons.shield_rounded,
                              title: 'Protected Rent Escrow',
                              subtitle: 'Rent held safe nationwide until physical key handover',
                            ),
                            const SizedBox(height: 10),
                            _buildFeaturePill(
                              icon: Icons.credit_card_rounded,
                              title: 'Virtual Dollar Cards',
                              subtitle: 'Institutional USD Visa for global subscriptions & spend',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom Loading Indicator & Tap-to-Continue Action
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Securing connection to Rentilly Federal Escrow...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE2E8F0), // High-contrast crisp light grey
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quick Action button if user wants to enter immediately
                  GestureDetector(
                    onTap: _proceedToNextScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tap to Enter',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF34D399)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Legal Compliance Guarantee Text (Federal Republic of Nigeria)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.gavel_rounded, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        'Empowered by the Laws of the Federal Republic of Nigeria & FCT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8), // Readable muted slate
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF34D399), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Ultra visible white
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8), // Clear readable slate
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
