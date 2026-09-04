import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class InactivityWatcher extends StatefulWidget {
  final Widget child;
  final int timeoutMinutes;

  const InactivityWatcher({
    super.key,
    required this.child,
    this.timeoutMinutes = 5,
  });

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  bool _isLoggedOut = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkInactivity();
    });
  }

  void _recordUserActivity() {
    _lastActivity = DateTime.now();
    _isLoggedOut = false;
  }

  void _checkInactivity() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) return;

    final inactiveDuration = DateTime.now().difference(_lastActivity);
    if (inactiveDuration.inMinutes >= widget.timeoutMinutes && !_isLoggedOut) {
      _isLoggedOut = true;
      // Lock session instead of wiping credentials — keeps biometric quick unlock intact!
      await AuthService.lockSessionForInactivity();

      final navState = rootNavigatorKey.currentState;
      if (navState != null) {
        navState.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(isFromInactivityTimeout: true),
          ),
          (route) => false,
        );

        // ignore: use_build_context_synchronously
        final currentCtx = rootNavigatorKey.currentContext;
        if (currentCtx != null) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(currentCtx).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session locked due to 5 min inactivity. Unlock with fingerprint or face.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordUserActivity(),
      onPointerMove: (_) => _recordUserActivity(),
      onPointerUp: (_) => _recordUserActivity(),
      child: widget.child,
    );
  }
}
