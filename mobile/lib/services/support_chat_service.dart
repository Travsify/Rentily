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
  /// Sends a user message to Supabase directly to the live human support queue.
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

    // Increment unread_by_agent (read-then-write) so human agents see new message
    await _incrementUnreadByAgent(conversationId);
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
