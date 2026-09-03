import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../constants/app_constants.dart';
import '../widgets/inactivity_watcher.dart';
import '../widgets/date_of_birth_modal.dart';
import 'auth_service.dart';
import 'api_service.dart';

/// Manages OneSignal push notifications for Rentilly.
/// Handles initialization, permission requests, player ID registration,
/// and notification tap deep-linking.
class PushNotificationService {
  static bool _initialized = false;

  /// Initialize OneSignal SDK and register for push notifications.
  /// Call this once in main.dart after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Set log level for debugging (remove in production for cleaner logs)
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);

      // Initialize with Rentilly's OneSignal App ID
      OneSignal.initialize(AppConstants.oneSignalAppId);

      // Request notification permission (shows the system prompt on Android 13+ / iOS)
      final accepted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('[PushNotification] Permission accepted: \$accepted');

      // Listen for push subscription changes (new player ID assigned)
      OneSignal.User.pushSubscription.addObserver((state) {
        final playerId = state.current.id;
        if (playerId != null && playerId.isNotEmpty) {
          debugPrint('[PushNotification] Player ID: \$playerId');
          _registerPlayerIdWithBackend(playerId);
        }
      });

      // Register the current player ID if already available
      final currentPlayerId = OneSignal.User.pushSubscription.id;
      if (currentPlayerId != null && currentPlayerId.isNotEmpty) {
        debugPrint('[PushNotification] Existing Player ID: \$currentPlayerId');
        _registerPlayerIdWithBackend(currentPlayerId);
      }

      // Handle notification tapped (user taps a push notification)
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('[PushNotification] Notification clicked: \${event.notification.title}');
        _handleNotificationTap(event);
      });

      // Handle foreground notifications (show them as banners)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        // Allow the notification to display in foreground
        event.notification.display();
        debugPrint('[PushNotification] Foreground notification: \${event.notification.title}');
      });

      debugPrint('[PushNotification] OneSignal initialized successfully');
    } catch (e) {
      debugPrint('[PushNotification] Init error: \$e');
    }
  }

  /// After user logs in, tag them in OneSignal for targeted pushes.
  static Future<void> setUserTags() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return;

      // Set external user ID for cross-platform identification
      OneSignal.login(user.id);

      // Tag user with role and email for segment-based targeting
      OneSignal.User.addTags({
        'role': user.role,
        'email': user.email,
        'fullName': user.fullName,
        'verified': (user.isVerified || user.bvnVerified).toString(),
      });

      // Set email for OneSignal email channel
      OneSignal.User.addEmail(user.email);

      // Also register player ID now that we know who the user is
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) {
        await _registerPlayerIdWithBackend(playerId);
      }

      debugPrint('[PushNotification] User tags set for: \${user.email}');
    } catch (e) {
      debugPrint('[PushNotification] setUserTags error: \$e');
    }
  }

  /// On logout, remove OneSignal user association.
  static Future<void> clearUserTags() async {
    try {
      OneSignal.logout();
      debugPrint('[PushNotification] User logged out from OneSignal');
    } catch (e) {
      debugPrint('[PushNotification] clearUserTags error: $e');
    }
  }

  static Future<void> logout() async {
    await clearUserTags();
  }

  /// Register the OneSignal player ID with our Supabase backend
  /// so the server can send targeted pushes.
  static Future<void> _registerPlayerIdWithBackend(String playerId) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return;
      final cleanEmail = user.email.toLowerCase().trim();

      // Encapsulated server-side mutation
      await ApiService.registerOneSignalPlayer(
        playerId,
        userId: user.id.isNotEmpty ? user.id : null,
        email: cleanEmail.isNotEmpty ? cleanEmail : null,
      );

      debugPrint('[PushNotification] Player ID registered via backend API for: $cleanEmail');
    } catch (e) {
      debugPrint('[PushNotification] Backend registration error: $e');
    }
  }

  /// Handle notification tap — deep-link to the correct screen.
  static void _handleNotificationTap(OSNotificationClickEvent event) async {
    try {
      final data = event.notification.additionalData ?? {};
      final String? action = data['action']?.toString();
      final String title = event.notification.title ?? '';
      final String body = event.notification.body ?? '';
      debugPrint('[PushNotification] Deep-link action: $action, title: $title');

      final isDobOrKyc = action == 'open_dob' ||
          action == 'open_kyc' ||
          action == 'open_rekyc' ||
          title.toLowerCase().contains('upgrade') ||
          title.toLowerCase().contains('birth') ||
          title.toLowerCase().contains('kyc') ||
          title.toLowerCase().contains('action required') ||
          body.toLowerCase().contains('birth') ||
          body.toLowerCase().contains('upgrade');

      if (isDobOrKyc) {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;

        final user = await AuthService.getCurrentUser();
        if (user != null && context.mounted) {
          DateOfBirthModal.show(
            context,
            user: user,
            onSuccess: (updated) {
              debugPrint('[PushNotification] User successfully activated: ${updated.accountNumber}');
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[PushNotification] Tap handler error: $e');
    }
  }
}
