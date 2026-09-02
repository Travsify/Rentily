import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
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
      await PushNotificationService.clearUserTags();
      await AuthService.logout();

      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        rootNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session timed out after 5 minutes of inactivity for your account security.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
