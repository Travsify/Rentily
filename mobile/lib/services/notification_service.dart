import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

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
  static const String _readIdsKey = 'rentilly_read_notification_ids';
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  // Load all notifications (with permanent ledger and transaction synchronization)
  static Future<List<InAppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList(_readIdsKey) ?? [];
    final readSet = readIds.toSet();

    List<InAppNotification> list = [];

    // 1. Read locally stored custom/pushed notifications
    final data = prefs.getString(_storageKey);
    if (data != null && data.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(data);
        list = decoded.map((e) => InAppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }

    // 2. Fetch live transactions to ensure zero transaction notifications are ever lost
    try {
      final user = await AuthService.getCurrentUser() ?? await AuthService.getRememberedUser();
      final email = user?.email ?? 'patrickachua3@gmail.com';
      final liveTxs = await ApiService.fetchLiveTransactions(email);

      for (final tx in liveTxs) {
        final txId = (tx['id'] ?? tx['reference'] ?? '').toString();
        final notifId = 'NOTIF_TX_$txId';
        
        final alreadyExists = list.any((n) => n.id == notifId || (n.metadata != null && n.metadata!['txId'] == txId));
        if (!alreadyExists) {
          final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final isCredit = amt > 0 || tx['type'] == 'inflow' || tx['isCredit'] == true;
          final dateStr = (tx['date'] ?? '').toString();
          final txDate = DateTime.tryParse(dateStr) ?? DateTime.now();
          final cleanTitle = (tx['title'] ?? 'Wallet Transaction').toString();

          String title;
          String message;
          String category = 'transaction';

          if (cleanTitle.toLowerCase().contains('airtime') || cleanTitle.toLowerCase().contains('utility')) {
            title = '⚡ Airtime VTU Recharge Successful';
            message = '₦${amt.abs().toStringAsFixed(2)} was debited for $cleanTitle. Reference: ${tx['reference'] ?? txId}.';
          } else if (!isCredit) {
            title = '💸 Escrow Vault Withdrawal Payout Dispatched';
            message = 'Payout of ₦${amt.abs().toStringAsFixed(2)} to ${tx['beneficiary'] ?? tx['recipient'] ?? 'Bank Account'} has been processed and settled by NIBSS.';
          } else {
            title = '💰 Inbound Bank Settlement Received';
            message = 'Deposit of +₦${amt.abs().toStringAsFixed(2)} received into your Flutterwave MFB Settlement Vault (9254090338).';
          }

          list.add(InAppNotification(
            id: notifId,
            title: title,
            message: message,
            category: category,
            timestamp: txDate,
            isRead: readSet.contains(notifId),
            metadata: {
              'txId': txId,
              'amount': amt,
              'reference': tx['reference'] ?? txId,
            },
          ));
        }
      }
    } catch (_) {}

    // Apply read state
    for (var n in list) {
      if (readSet.contains(n.id)) {
        n.isRead = true;
      }
    }

    // Sort newest first
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _saveNotifications(list);
    _updateUnreadCount(list);
    return list;
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
    if (current.length > 60) current.removeRange(60, current.length);
    await _saveNotifications(current);
    _updateUnreadCount(current);
  }

  // Mark single as read
  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList(_readIdsKey) ?? [];
    if (!readIds.contains(id)) {
      readIds.add(id);
      await prefs.setStringList(_readIdsKey, readIds);
    }

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
    final prefs = await SharedPreferences.getInstance();
    final readIds = current.map((n) => n.id).toList();
    await prefs.setStringList(_readIdsKey, readIds);

    for (var n in current) {
      n.isRead = true;
    }
    await _saveNotifications(current);
    _updateUnreadCount(current);
  }

  // Alias for markAllAsRead
  static Future<void> markAllRead() => markAllAsRead();

  // Delete notification
  static Future<void> deleteNotification(String id) async {
    final current = await getNotifications();
    current.removeWhere((n) => n.id == id);
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
    final encoded = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static void _updateUnreadCount(List<InAppNotification> list) {
    final count = list.where((n) => !n.isRead).length;
    unreadCountNotifier.value = count;
  }
}
