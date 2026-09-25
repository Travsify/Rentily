import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalSlides = 5;

  static const List<List<Color>> _slideGradients = [
    // Slide 1: Zero Agents. Direct Owners.
    [Color(0xFF0E1217), Color(0xFF03070E)],
    // Slide 2: Your Money, Protected.
    [Color(0xFF0B1016), Color(0xFF03070E)],
    // Slide 3: Verified. Every Time.
    [Color(0xFF0C121A), Color(0xFF03070E)],
    // Slide 4: One Wallet. Every Payment.
    [Color(0xFF090D14), Color(0xFF03070E)],
    // Slide 5: Your Home Journey Starts Here.
    [Color(0xFF0F141A), Color(0xFF03070E)],
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache all 5 slide images for locked 60/120fps silky performance
    for (int i = 1; i <= _totalSlides; i++) {
      precacheImage(AssetImage('assets/images/onboard_$i.jpg'), context);
    }
  }

  void _finishOnboarding() {
    HapticFeedback.mediumImpact();
    // Persist seen status in background without blocking navigation
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(AppConstants.seenOnboardingKey, true);
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const RegisterScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalSlides - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lock system UI overlays to light icons on dark background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF03070E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF03070E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-screen PageView with Per-Slide Matching Background & Auto-Contained Scaling
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            onPageChanged: (index) {
              if (_currentPage != index) {
                HapticFeedback.selectionClick();
                setState(() {
                  _currentPage = index;
                });
              }
            },
            itemCount: _totalSlides,
            itemBuilder: (context, index) {
              final gradient = _slideGradients[index % _slideGradients.length];

              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradient,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 1080,
                      height: 1920,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // High-Fidelity Pre-Rendered Slide Asset (1080x1920 Native Resolution)
                          Image.asset(
                            'assets/images/onboard_${index + 1}.jpg',
                            fit: BoxFit.fill,
                            width: 1080,
                            height: 1920,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF070D1B),
                                child: const Center(
                                  child: Icon(
                                    Icons.home_work_rounded,
                                    size: 128,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Proportional Hit Target: Top Right "Skip"
                          if (index < _totalSlides - 1)
                            Positioned(
                              top: 50,
                              right: 30,
                              width: 260,
                              height: 150,
                              child: Semantics(
                                label: 'Skip onboarding',
                                button: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _finishOnboarding,
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                            ),

                          // Proportional Hit Target: Bottom "Continue / Get Started" Button
                          Positioned(
                            bottom: 60,
                            left: 50,
                            right: 50,
                            height: 200,
                            child: Semantics(
                              label: index == _totalSlides - 1 ? 'Get Started' : 'Continue',
                              button: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _nextPage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. Universal Fallback Safe Touch Layer for device extreme outer edges
          SafeArea(
            child: Column(
              children: [
                // Top header row fallback for Skip tap
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 80, height: 48),
                      if (_currentPage < _totalSlides - 1)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _finishOnboarding,
                          child: Container(
                            width: 90,
                            height: 48,
                            alignment: Alignment.centerRight,
                            color: Colors.transparent,
                          ),
                        )
                      else
                        const SizedBox(width: 80, height: 48),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom bar fallback for Continue tap
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _nextPage,
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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

