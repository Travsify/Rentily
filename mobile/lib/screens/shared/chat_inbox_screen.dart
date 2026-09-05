import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/direct_message_service.dart';
import '../messages/direct_chat_detail_screen.dart';

/// Landlord / partner inbox — shows all incoming tenant conversations.
/// Backed by Supabase via [DirectMessageService].
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatInboxScreen()),
    );
  }

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  UserProfile? _currentUser;
  List<Map<String, dynamic>> _convos = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) setState(() => _currentUser = u);
    await _loadConversations();
    _startPolling();
  }

  Future<void> _loadConversations() async {
    final user = _currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final convos =
          await DirectMessageService.getOwnerConversations(user.id);
      if (mounted) {
        setState(() {
          _convos = convos;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final user = _currentUser;
      if (user == null || !mounted) return;
      try {
        final convos =
            await DirectMessageService.getOwnerConversations(user.id);
        if (mounted) setState(() => _convos = convos);
      } catch (_) {}
    });
  }

  void _openChat(Map<String, dynamic> convo) {
    final user = _currentUser;
    if (user == null) return;
    // Mark owner read immediately
    DirectMessageService.markOwnerRead(convo['id']?.toString() ?? '');
    setState(() {
      final idx = _convos.indexWhere((c) => c['id'] == convo['id']);
      if (idx >= 0) _convos[idx] = {..._convos[idx], 'unread_by_owner': 0};
    });
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => DirectChatDetailScreen(
        conversation: convo,
        currentUser: user,
      ),
    ))
        .then((_) => _loadConversations());
  }

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return 'TN';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalUnread = _convos.fold<int>(
        0, (s, c) => s + ((c['unread_by_owner'] as num?)?.toInt() ?? 0));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Messages',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '$totalUnread',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadConversations,
              child: _convos.isEmpty
                  ? ListView(
                      children: [
                        _buildEmpty(),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _convos.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildConvoCard(_convos[i]),
                    ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).size.height * 0.18,
        left: 32,
        right: 32,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 60,
              color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(
            'No messages yet',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'No tenant messages yet. When tenants contact you about your properties, they\'ll appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildConvoCard(Map<String, dynamic> c) {
    final unread = (c['unread_by_owner'] as num?)?.toInt() ?? 0;
    final tenantName = c['tenant_name']?.toString() ?? 'Tenant';
    final propertyTitle = c['property_title']?.toString() ?? '';
    final lastMsg = c['last_message']?.toString() ?? '';
    final timeStr = _relativeTime(c['last_message_at']?.toString());

    return GestureDetector(
      onTap: () => _openChat(c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread > 0
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.borderDark,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            // Tenant avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(tenantName),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tenantName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (propertyTitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      propertyTitle,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg.isNotEmpty ? lastMsg : 'Tap to open chat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: unread > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
