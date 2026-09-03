import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
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
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static Future<String> _getStorageKey() async {
    final user = await AuthService.getCurrentUser();
    final uid = (user != null && user.id.isNotEmpty) ? user.id : 'guest';
    return 'rentilly_notifs_$uid';
  }

  static Future<String> _getReadIdsKey() async {
    final user = await AuthService.getCurrentUser();
    final uid = (user != null && user.id.isNotEmpty) ? user.id : 'guest';
    return 'rentilly_read_notifs_$uid';
  }

  // Load notifications for the CURRENT authenticated user only
  static Future<List<InAppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    final readIdsKey = await _getReadIdsKey();

    final readIds = prefs.getStringList(readIdsKey) ?? [];
    final readSet = readIds.toSet();

    List<InAppNotification> list = [];

    // 1. Read locally stored notifications for this specific user
    final data = prefs.getString(storageKey);
    if (data != null && data.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(data);
        list = decoded.map((e) => InAppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
        
        // Remove any legacy mock notifications or hardcoded numbers
        list.removeWhere((n) =>
          n.title.contains('9254090338') ||
          n.message.contains('9254090338') ||
          n.message.contains('Patrick Achua') ||
          n.id.startsWith('MOCK_') ||
          n.id.startsWith('DUMMY_') ||
          (n.metadata != null && (
            n.metadata!['txId']?.toString().contains('2086819478') == true ||
            n.metadata!['txId']?.toString().contains('2086772538') == true ||
            n.metadata!['txId']?.toString().contains('1028202500') == true
          ))
        );
      } catch (_) {}
    }

    // 2. Only fetch live payment notifications if the user is VERIFIED and has an active email
    try {
      final user = await AuthService.getCurrentUser();
      final isVerified = user != null && (user.isVerified || user.bvnVerified);
      
      if (user != null && isVerified && user.email.trim().isNotEmpty) {
        final liveTxs = await ApiService.fetchLiveTransactions(user.email.trim());

        for (final tx in liveTxs) {
          final txId = (tx['id'] ?? tx['reference'] ?? '').toString();
          if (txId.isEmpty) continue;
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

            if (cleanTitle.toLowerCase().contains('airtime') || cleanTitle.toLowerCase().contains('utility') || cleanTitle.toLowerCase().contains('electricity')) {
              title = '⚡ Bill Payment Successful';
              message = '₦${amt.abs().toStringAsFixed(2)} was debited for $cleanTitle. Reference: ${tx['reference'] ?? txId}.';
            } else if (!isCredit) {
              title = '💸 Withdrawal Payout Dispatched';
              message = 'Payout of ₦${amt.abs().toStringAsFixed(2)} to ${tx['beneficiary'] ?? tx['recipient'] ?? 'Bank Account'} has been processed.';
            } else {
              final bankName = user.bankName ?? 'Settlement Bank';
              final accNo = user.accountNumber != null && user.accountNumber!.isNotEmpty ? ' (${user.accountNumber})' : '';
              title = '💰 Inbound Bank Settlement Received';
              message = 'Deposit of +₦${amt.abs().toStringAsFixed(2)} received into your $bankName Settlement Vault$accNo.';
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
      }
    } catch (_) {}

    // 3. Fetch from Supabase Cloud notifications table
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user.id.isNotEmpty) {
        final uri = Uri.parse('${AppConstants.supabaseUrl}/rest/v1/notifications?user_id=eq.${user.id}&order=created_at.desc&limit=30');
        final response = await http.get(uri, headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
        }).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List<dynamic> sbNotifs = json.decode(response.body);
          for (final item in sbNotifs) {
            final rawId = item['id']?.toString() ?? '';
            if (rawId.isEmpty) continue;
            final notifId = 'NOTIF_SB_$rawId';

            final alreadyExists = list.any((n) => n.id == notifId || n.id == rawId);
            if (!alreadyExists) {
              final isDbRead = item['read'] == true;
              list.add(InAppNotification(
                id: notifId,
                title: item['title'] ?? 'Notification',
                message: item['message'] ?? '',
                category: item['category'] ?? 'general',
                timestamp: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
                isRead: isDbRead || readSet.contains(notifId) || readSet.contains(rawId),
                metadata: item['metadata'] != null ? Map<String, dynamic>.from(item['metadata']) : null,
              ));
            }
          }
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

  // Add new notification for current user and dispatch Push & Email
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
    await _saveNotifications(current);
    _updateUnreadCount(current);

    // Dispatches Real-time Push Notification & Branded Resend HTML Email
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user.email.trim().isNotEmpty) {
        ApiService.dispatchNotification(
          email: user.email.trim(),
          userId: user.id,
          userName: user.fullName,
          category: category,
          title: title,
          message: message,
          metadata: metadata,
        );
      }
    } catch (_) {}
  }

  // Mark single notification as read
  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final readIdsKey = await _getReadIdsKey();
    final readIds = prefs.getStringList(readIdsKey) ?? [];
    if (!readIds.contains(id)) {
      readIds.add(id);
      await prefs.setStringList(readIdsKey, readIds);
    }

    final current = await getNotifications();
    for (var n in current) {
      if (n.id == id) {
        n.isRead = true;
      }
    }
    await _saveNotifications(current);
    _updateUnreadCount(current);

    // Sync read status to Supabase Cloud
    try {
      final realId = id.startsWith('NOTIF_SB_') ? id.replaceFirst('NOTIF_SB_', '') : id;
      if (realId.contains('-')) { // Valid UUID format
        final uri = Uri.parse('${AppConstants.supabaseUrl}/rest/v1/notifications?id=eq.$realId');
        await http.patch(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'apikey': AppConstants.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
            'Prefer': 'return=minimal',
          },
          body: json.encode({'read': true}),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    final current = await getNotifications();
    final readIds = current.map((e) => e.id).toList();

    final prefs = await SharedPreferences.getInstance();
    final readIdsKey = await _getReadIdsKey();
    await prefs.setStringList(readIdsKey, readIds);

    for (var n in current) {
      n.isRead = true;
    }
    await _saveNotifications(current);
    _updateUnreadCount(current);

    // Sync all to read in Supabase for this user
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user.id.isNotEmpty) {
        final uri = Uri.parse('${AppConstants.supabaseUrl}/rest/v1/notifications?user_id=eq.${user.id}');
        await http.patch(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'apikey': AppConstants.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
            'Prefer': 'return=minimal',
          },
          body: json.encode({'read': true}),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  // Alias for backward compatibility
  static Future<void> markAllRead() => markAllAsRead();

  // Delete single notification
  static Future<void> deleteNotification(String id) async {
    final current = await getNotifications();
    current.removeWhere((n) => n.id == id);
    await _saveNotifications(current);
    _updateUnreadCount(current);
  }

  // Clear all notifications for current user
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    final readIdsKey = await _getReadIdsKey();
    await prefs.remove(storageKey);
    await prefs.remove(readIdsKey);
    unreadCountNotifier.value = 0;
  }

  static Future<void> _saveNotifications(List<InAppNotification> list) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _getStorageKey();
    final encoded = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }

  static void _updateUnreadCount(List<InAppNotification> list) {
    final unread = list.where((n) => !n.isRead).length;
    unreadCountNotifier.value = unread;
  }

  // Periodic real-time background sync loop (polls Supabase every 20s while app active)
  static Timer? _syncTimer;

  static void startRealtimeSync() {
    _syncTimer?.cancel();
    // Run initial sync
    getNotifications().catchError((_) => <InAppNotification>[]);
    // Start periodic 20-second poll
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      getNotifications().catchError((_) => <InAppNotification>[]);
    });
  }

  static void stopRealtimeSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
