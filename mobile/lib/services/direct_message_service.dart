import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Supabase-backed direct messaging service for tenant ↔ landlord/partner chat.
/// Uses raw HTTP REST calls — no supabase_flutter package.
class DirectMessageService {
  static const String _baseUrl = '${AppConstants.supabaseUrl}/rest/v1';
  static const String _apiBaseUrl = AppConstants.apiBaseUrl;

  static Map<String, String> get _headers => {
        'apikey': AppConstants.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  // ---------------------------------------------------------------------------
  // 1. createOrGetConversation
  // ---------------------------------------------------------------------------
  /// Returns an existing conversation or creates a new one.
  static Future<Map<String, dynamic>> createOrGetConversation({
    required String tenantId,
    required String tenantEmail,
    required String tenantName,
    required String ownerId,
    required String ownerName,
    required String ownerRole,
    required String propertyId,
    required String propertyTitle,
    required String propertyAddress,
  }) async {
    // --- Check for existing open conversation ---
    try {
      final existing = await http.get(
        Uri.parse(
          '$_baseUrl/direct_conversations'
          '?tenant_id=eq.${Uri.encodeComponent(tenantId)}'
          '&property_id=eq.${Uri.encodeComponent(propertyId)}'
          '&status=neq.closed'
          '&order=created_at.desc'
          '&limit=1'
          '&select=*',
        ),
        headers: _headers,
      );

      if (existing.statusCode == 200) {
        final list = json.decode(existing.body) as List<dynamic>;
        if (list.isNotEmpty) {
          return Map<String, dynamic>.from(list.first as Map);
        }
      }
    } catch (_) {}

    // --- Create new conversation ---
    final now = DateTime.now().toUtc().toIso8601String();
    final createResp = await http.post(
      Uri.parse('$_baseUrl/direct_conversations'),
      headers: _headers,
      body: json.encode({
        'tenant_id': tenantId,
        'tenant_email': tenantEmail,
        'tenant_name': tenantName,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'owner_role': ownerRole,
        'property_id': propertyId,
        'property_title': propertyTitle,
        'property_address': propertyAddress,
        'status': 'active',
        'last_message': '',
        'last_message_at': now,
        'unread_by_tenant': 0,
        'unread_by_owner': 0,
      }),
    );

    if (createResp.statusCode == 200 || createResp.statusCode == 201) {
      final body = json.decode(createResp.body);
      if (body is List && body.isNotEmpty) {
        return Map<String, dynamic>.from(body.first as Map);
      }
      if (body is Map<String, dynamic>) return body;
    }

    throw Exception(
        'Failed to create or retrieve direct conversation. Status: ${createResp.statusCode}');
  }

  // ---------------------------------------------------------------------------
  // 2. sendMessage
  // ---------------------------------------------------------------------------
  /// Posts a message to Supabase, updates conversation metadata,
  /// and fires a fire-and-forget scan to the anti-circumvention API.
  static Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Insert message
    final msgResp = await http.post(
      Uri.parse('$_baseUrl/direct_messages'),
      headers: _headers,
      body: json.encode({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'message': message,
        'is_flagged': false,
      }),
    );

    // Update conversation last_message and last_message_at
    await http.patch(
      Uri.parse('$_baseUrl/direct_conversations?id=eq.$conversationId'),
      headers: _headers,
      body: json.encode({
        'last_message': message,
        'last_message_at': now,
      }),
    );

    // Increment unread counter (read-then-write to avoid overwrite)
    _incrementUnread(conversationId, senderRole);

    // Fire-and-forget: anti-circumvention scan
    _scanMessage(conversationId, message, senderId);

    if (msgResp.statusCode == 200 || msgResp.statusCode == 201) {
      final body = json.decode(msgResp.body);
      if (body is List && body.isNotEmpty) {
        return Map<String, dynamic>.from(body.first as Map);
      }
      if (body is Map<String, dynamic>) return body;
    }

    // Return a local optimistic map if Supabase didn't return the row
    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'message': message,
      'created_at': now,
    };
  }

  /// Increments the correct unread counter based on sender role.
  static Future<void> _incrementUnread(
      String conversationId, String senderRole) async {
    try {
      final resp = await http.get(
        Uri.parse(
            '$_baseUrl/direct_conversations?id=eq.$conversationId&select=unread_by_tenant,unread_by_owner'),
        headers: _headers,
      );
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          final isTenantSender =
              senderRole == 'renter' || senderRole == 'buyer';
          final field =
              isTenantSender ? 'unread_by_owner' : 'unread_by_tenant';
          final currentVal = (row[field] as int?) ?? 0;
          await http.patch(
            Uri.parse(
                '$_baseUrl/direct_conversations?id=eq.$conversationId'),
            headers: _headers,
            body: json.encode({field: currentVal + 1}),
          );
        }
      }
    } catch (_) {}
  }

  /// Fire-and-forget anti-circumvention scan.
  static void _scanMessage(
      String conversationId, String message, String senderId) {
    http
        .post(
          Uri.parse('$_apiBaseUrl/direct-chat/scan'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'conversation_id': conversationId,
            'message': message,
            'sender_id': senderId,
          }),
        )
        .timeout(const Duration(seconds: 10))
        .catchError((_) {});
  }

  // ---------------------------------------------------------------------------
  // 3. getMessages
  // ---------------------------------------------------------------------------
  /// Fetches all messages for a conversation, ordered by created_at ascending.
  static Future<List<Map<String, dynamic>>> getMessages(
      String conversationId) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/direct_messages?conversation_id=eq.$conversationId&order=created_at.asc&select=*'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // 4. getTenantConversations
  // ---------------------------------------------------------------------------
  /// Fetches all active conversations for a tenant by their email.
  static Future<List<Map<String, dynamic>>> getTenantConversations(
      String tenantEmail) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/direct_conversations?tenant_email=eq.${Uri.encodeComponent(tenantEmail)}&status=neq.closed&order=last_message_at.desc&select=*'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // 5. getOwnerConversations
  // ---------------------------------------------------------------------------
  /// Fetches all active conversations for a landlord/partner by their user id.
  static Future<List<Map<String, dynamic>>> getOwnerConversations(
      String ownerId) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/direct_conversations?owner_id=eq.${Uri.encodeComponent(ownerId)}&status=neq.closed&order=last_message_at.desc&select=*'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // 6. markTenantRead
  // ---------------------------------------------------------------------------
  static Future<void> markTenantRead(String conversationId) async {
    try {
      await http.patch(
        Uri.parse(
            '$_baseUrl/direct_conversations?id=eq.$conversationId'),
        headers: _headers,
        body: json.encode({'unread_by_tenant': 0}),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 7. markOwnerRead
  // ---------------------------------------------------------------------------
  static Future<void> markOwnerRead(String conversationId) async {
    try {
      await http.patch(
        Uri.parse(
            '$_baseUrl/direct_conversations?id=eq.$conversationId'),
        headers: _headers,
        body: json.encode({'unread_by_owner': 0}),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 8. subscribeToMessages  (3-second polling)
  // ---------------------------------------------------------------------------
  /// Starts polling for new messages every 3 seconds.
  /// Returns a cancel function — call it in dispose().
  static Function subscribeToMessages(
    String conversationId,
    Function(Map<String, dynamic>) onNew,
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
          // First poll — surface all so UI can initialise
          newOnes = messages;
        } else {
          final idx =
              messages.indexWhere((m) => m['id']?.toString() == lastSeenId);
          newOnes = idx >= 0 ? messages.sublist(idx + 1) : messages;
        }

        lastSeenId = latestId;
        for (final msg in newOnes) {
          onNew(msg);
        }
      } catch (_) {}
    });

    return () => timer.cancel();
  }
}
