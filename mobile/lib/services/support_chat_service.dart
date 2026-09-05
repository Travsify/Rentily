import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/user_profile.dart';

class SupportChatService {
  static const String _supabaseUrl = AppConstants.supabaseUrl;
  static const String _supabaseKey = AppConstants.supabaseAnonKey;
  static const String _apiBaseUrl = AppConstants.apiBaseUrl;

  // ---------------------------------------------------------------------------
  // Shared Supabase REST headers
  // ---------------------------------------------------------------------------
  static Map<String, String> get _supabaseHeaders => {
        'apikey': _supabaseKey,
        'Authorization': 'Bearer $_supabaseKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  // ---------------------------------------------------------------------------
  // 1. createOrGetConversation
  // ---------------------------------------------------------------------------
  /// Creates or retrieves a support conversation.
  /// First tries the backend API; falls back to direct Supabase REST on failure.
  static Future<Map<String, dynamic>> createOrGetConversation(
    UserProfile user,
    String subject,
  ) async {
    // --- Primary: backend API ---
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/support/conversations'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': user.id,
              'user_email': user.email,
              'user_name': user.fullName.isNotEmpty ? user.fullName : 'User',
              'user_role': user.role,
              'subject': subject,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = json.decode(response.body);
        if (body is Map<String, dynamic>) {
          final dynamic conv = body['conversation'] ?? body['data'] ?? body;
          if (conv is Map<String, dynamic> && conv.containsKey('id')) {
            return conv;
          }
        }
      }
    } catch (_) {
      // fall through to Supabase direct
    }

    // --- Fallback: check existing open conversation in Supabase ---
    try {
      final existing = await http.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/support_conversations?user_email=eq.${Uri.encodeComponent(user.email)}&subject=eq.${Uri.encodeComponent(subject)}&status=neq.resolved&order=created_at.desc&limit=1&select=*'),
        headers: _supabaseHeaders,
      );

      if (existing.statusCode == 200) {
        final list = json.decode(existing.body) as List<dynamic>;
        if (list.isNotEmpty) {
          return Map<String, dynamic>.from(list.first as Map);
        }
      }
    } catch (_) {}

    // --- Fallback: create new conversation directly in Supabase ---
    final now = DateTime.now().toUtc().toIso8601String();
    final createResp = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/support_conversations'),
      headers: _supabaseHeaders,
      body: json.encode({
        'user_id': user.id,
        'user_email': user.email,
        'user_name': user.fullName.isNotEmpty ? user.fullName : 'User',
        'user_role': user.role,
        'subject': subject,
        'status': 'open',
        'priority': 'normal',
        'last_message': '',
        'last_message_at': now,
        'unread_by_user': 0,
        'unread_by_agent': 0,
      }),
    );

    if (createResp.statusCode == 200 || createResp.statusCode == 201) {
      final body = json.decode(createResp.body);
      if (body is List && body.isNotEmpty) {
        return Map<String, dynamic>.from(body.first as Map);
      }
      if (body is Map<String, dynamic>) return body;
    }

    throw Exception('Failed to create or retrieve support conversation.');
  }

  // ---------------------------------------------------------------------------
  // 2. sendMessage
  // ---------------------------------------------------------------------------
  /// Sends a user message to Supabase and triggers an auto-reply bot response.
  static Future<void> sendMessage(
    String conversationId,
    String message,
    UserProfile user,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final senderName = user.fullName.isNotEmpty ? user.fullName : 'User';

    // Insert user message
    await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/support_messages'),
      headers: _supabaseHeaders,
      body: json.encode({
        'conversation_id': conversationId,
        'sender': 'user',
        'sender_name': senderName,
        'message': message,
        'message_type': 'text',
        'is_read': false,
      }),
    );

    // Update conversation last_message and last_message_at
    await http.patch(
      Uri.parse(
          '$_supabaseUrl/rest/v1/support_conversations?id=eq.$conversationId'),
      headers: _supabaseHeaders,
      body: json.encode({
        'last_message': message,
        'last_message_at': now,
      }),
    );

    // Increment unread_by_agent (read-then-write)
    _incrementUnreadByAgent(conversationId);

    // Trigger auto-reply bot asynchronously
    _sendAutoReply(conversationId, message, user);
  }

  /// Increments unread_by_agent by fetching current value then patching.
  static Future<void> _incrementUnreadByAgent(String conversationId) async {
    try {
      final resp = await http.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/support_conversations?id=eq.$conversationId&select=unread_by_agent'),
        headers: _supabaseHeaders,
      );
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final current = (list.first as Map<String, dynamic>)['unread_by_agent'] as int? ?? 0;
          await http.patch(
            Uri.parse(
                '$_supabaseUrl/rest/v1/support_conversations?id=eq.$conversationId'),
            headers: _supabaseHeaders,
            body: json.encode({'unread_by_agent': current + 1}),
          );
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Auto-reply bot
  // ---------------------------------------------------------------------------
  static Future<void> _sendAutoReply(
    String conversationId,
    String userMessage,
    UserProfile user,
  ) async {
    final lower = userMessage.toLowerCase();
    String? specificReply;

    // Check specific topics with smart priority
    if (_containsAny(lower, ['debit', 'debited', 'withdraw', 'payout', 'deducted', 'deduct', 'minus', 'reversal', 'reversed'])) {
      specificReply =
          'Hi ${user.firstName}! 💳 For bank account debits & withdrawals: All payouts to Nigerian banks are routed directly through automated settlement rails (Maplerad & Paystack). If your account was debited or you are waiting on a bank payout, our ledger automatically verifies every NIBSS settlement reference. If a transaction was debited multiple times or delayed, a live agent is reviewing your account to reconcile and reverse any discrepancies.';
    } else if (_containsAny(lower, ['card', 'virtual card', 'mastercard', 'visa card', 'dollar card', 'cvv', 'card funding', 'card top-up', 'card blocked', 'card frozen'])) {
      specificReply =
          'Hi ${user.firstName}! 💳 For Virtual Dollar Cards: You can manage your card, check 3D Secure OTPs, view spend balances, or freeze/unfreeze cards directly in your Vaults tab → Cards. For international merchant declines, please ensure your card balance has a sufficient authorization buffer.';
    } else if (_containsAny(lower, ['deposit', 'fund', 'wema', '9psb', 'virtual account', 'transfer delayed', 'did not reflect', 'not reflected', 'inflow', 'high-value', 'high value'])) {
      specificReply =
          'Hi ${user.firstName}! 🏦 For bank deposits into your Dedicated Virtual Accounts (9PSB Daily Vault or Commercial Wema Bank Escrow Vault): Transfers typically reflect within 2 to 10 minutes via NIBSS. Our backend actively auto-syncs with banking APIs. If you have the session ID or transaction reference, kindly drop it here for instant verification.';
    } else if (_containsAny(lower, ['bvn', 'kyp', 'kyc', 'nin', 'tier', 'verification', 'unverified', 'upgrade'])) {
      specificReply =
          'Hi ${user.firstName}! 🛡️ For Verification & Tier Upgrades: Rentilly uses CBN-compliant KYC tiers. Tier 1 requires BVN/NIN. You can upgrade to Tier 2 (₦200,000 daily limit) right from your Profile settings by submitting your residential address. For Tier 3 (₦5,000,000+ daily limit), our compliance team is standing by to assist.';
    } else if (_containsAny(lower, ['rent', 'escrow', 'landlord', 'property', 'lease', 'tenancy', 'inspection', 'agreement', 'partner'])) {
      specificReply =
          'Hi ${user.firstName}! 🔒 For Escrow & Leases: All rental funds remain 100% safeguarded inside your Rentilly Escrow Vault until you physically inspect and approve the property. Payouts are never released to a landlord without your direct authorization.';
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));

    final botMessage = specificReply ??
        'Hi ${user.firstName}! 👋 Thanks for contacting Rentilly Support. Your inquiry has been routed to our active support team. One of our support agents will respond to you shortly. For urgent escalations, reach us at support@myrentilly.com';

    await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/support_messages'),
      headers: _supabaseHeaders,
      body: json.encode({
        'conversation_id': conversationId,
        'sender': 'bot',
        'sender_name': 'Rentilly Support Bot',
        'message': botMessage,
        'message_type': 'text',
        'is_read': false,
      }),
    );

    // Update conversation with bot reply as last_message
    await http.patch(
      Uri.parse(
          '$_supabaseUrl/rest/v1/support_conversations?id=eq.$conversationId'),
      headers: _supabaseHeaders,
      body: json.encode({
        'last_message': botMessage,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
        'unread_by_user': 1,
      }),
    );
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  // ---------------------------------------------------------------------------
  // 3. getMessages
  // ---------------------------------------------------------------------------
  /// Fetches all messages for a conversation, ordered by created_at ascending.
  static Future<List<Map<String, dynamic>>> getMessages(
      String conversationId) async {
    final response = await http.get(
      Uri.parse(
          '$_supabaseUrl/rest/v1/support_messages?conversation_id=eq.$conversationId&order=created_at.asc&select=*'),
      headers: _supabaseHeaders,
    );

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // 4. getConversations
  // ---------------------------------------------------------------------------
  /// Fetches all conversations for a user by email, ordered by last_message_at desc.
  static Future<List<Map<String, dynamic>>> getConversations(
      String userEmail) async {
    final response = await http.get(
      Uri.parse(
          '$_supabaseUrl/rest/v1/support_conversations?user_email=eq.${Uri.encodeComponent(userEmail)}&order=last_message_at.desc&select=*'),
      headers: _supabaseHeaders,
    );

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // 5. markMessagesRead
  // ---------------------------------------------------------------------------
  /// Marks all incoming (agent/bot) messages as read and resets user unread counter.
  static Future<void> markMessagesRead(String conversationId) async {
    await Future.wait([
      // Reset unread_by_user counter on the conversation
      http.patch(
        Uri.parse(
            '$_supabaseUrl/rest/v1/support_conversations?id=eq.$conversationId'),
        headers: _supabaseHeaders,
        body: json.encode({'unread_by_user': 0}),
      ),
      // Mark all non-user messages as read
      http.patch(
        Uri.parse(
            '$_supabaseUrl/rest/v1/support_messages?conversation_id=eq.$conversationId&sender=neq.user'),
        headers: _supabaseHeaders,
        body: json.encode({'is_read': true}),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // 6. subscribeToMessages  (polling-based, 3-second interval)
  // ---------------------------------------------------------------------------
  /// Starts polling for new messages every 3 seconds.
  /// Calls [onMessage] for each new message received since the last poll.
  /// Returns a [Function] that cancels the polling timer when invoked.
  static Function subscribeToMessages(
    String conversationId,
    Function(Map<String, dynamic>) onMessage,
  ) {
    String? lastSeenId;

    final timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final messages = await getMessages(conversationId);
        if (messages.isEmpty) return;

        final latestId = messages.last['id']?.toString();
        if (latestId == null || latestId == lastSeenId) return;

        final List<Map<String, dynamic>> newOnes;
        if (lastSeenId == null) {
          // First poll: surface all existing messages so UI can initialise
          newOnes = messages;
        } else {
          // Subsequent polls: only emit messages after the last known one
          final idx = messages.indexWhere((m) => m['id']?.toString() == lastSeenId);
          newOnes = idx >= 0 ? messages.sublist(idx + 1) : messages;
        }

        lastSeenId = latestId;
        for (final msg in newOnes) {
          onMessage(msg);
        }
      } catch (_) {}
    });

    return () => timer.cancel();
  }
}
