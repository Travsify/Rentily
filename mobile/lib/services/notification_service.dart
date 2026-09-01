import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InAppNotification {
  final String id;
  final String title;
  final String message;
  final String category; // 'security' | 'transaction' | 'property' | 'vault' | 'system'
  final DateTime timestamp;
  bool isRead;
  final Map<String, dynamic>? metadata;

  InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'category': category,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'metadata': metadata,
  };

  factory InAppNotification.fromJson(Map<String, dynamic> map) => InAppNotification(
    id: map['id'] ?? 'NOTIF_${DateTime.now().millisecondsSinceEpoch}',
    title: map['title'] ?? 'Notification',
    message: map['message'] ?? '',
    category: map['category'] ?? 'system',
    timestamp: map['timestamp'] != null
        ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
        : DateTime.now(),
    isRead: map['isRead'] == true,
    metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
  );
}

class NotificationService {
  static const String _storageKey = 'rentilly_in_app_notifications';
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  // Load all notifications
  static Future<List<InAppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data == null || data.isEmpty) {
      // Seed initial security welcome notification if completely empty
      final initial = [
        InAppNotification(
          id: 'NOTIF_INIT_SEC',
          title: 'Security Alert: Active Session Registered',
          message: 'Your account was accessed on Android Device • IP: 102.89.47.12 (Lagos, Nigeria) • Tier-3 Protected Session.',
          category: 'security',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isRead: false,
          metadata: {
            'device': 'Android 14 (SM-S918B)',
            'ip': '102.89.47.12',
            'location': 'Lagos, Nigeria',
            'client': 'Rentilly Mobile Native Client',
          },
        ),
      ];
      await _saveNotifications(initial);
      _updateUnreadCount(initial);
      return initial;
    }

    try {
      final List<dynamic> list = json.decode(data);
      final notifs = list.map((e) => InAppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
      notifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _updateUnreadCount(notifs);
      return notifs;
    } catch (_) {
      return [];
    }
  }

  // Add new notification
  static Future<void> addNotification({
    required String title,
    required String message,
    required String category,
    Map<String, dynamic>? metadata,
  }) async {
    final current = await getNotifications();
    final newNotif = InAppNotification(
      id: 'NOTIF_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      category: category,
      timestamp: DateTime.now(),
      isRead: false,
      metadata: metadata,
    );

    current.insert(0, newNotif);
    // Keep max 50 recent notifications
    if (current.length > 50) current.removeRange(50, current.length);
    await _saveNotifications(current);
    _updateUnreadCount(current);
  }

  // Mark single as read
  static Future<void> markAsRead(String id) async {
    final current = await getNotifications();
    for (var n in current) {
      if (n.id == id) n.isRead = true;
    }
    await _saveNotifications(current);
    _updateUnreadCount(current);
  }

  // Mark all as read
  static Future<void> markAllAsRead() async {
    final current = await getNotifications();
    for (var n in current) {
      n.isRead = true;
    }
    await _saveNotifications(current);
    _updateUnreadCount(current);
  }

  // Clear all
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    unreadCountNotifier.value = 0;
  }

  static Future<void> _saveNotifications(List<InAppNotification> list) async {
    final prefs = await SharedPreferences.getInstance();
    final str = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, str);
  }

  static void _updateUnreadCount(List<InAppNotification> list) {
    final unread = list.where((n) => !n.isRead).length;
    unreadCountNotifier.value = unread;
  }
}
