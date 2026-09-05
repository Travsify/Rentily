import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/direct_message_service.dart';

/// Full Supabase-backed chat detail screen for direct tenant ↔ owner/partner chat.
class DirectChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final UserProfile currentUser;

  const DirectChatDetailScreen({
    super.key,
    required this.conversation,
    required this.currentUser,
  });

  @override
  State<DirectChatDetailScreen> createState() => _DirectChatDetailScreenState();
}

class _DirectChatDetailScreenState extends State<DirectChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Function? _cancelPolling;

  String get _conversationId =>
      widget.conversation['id']?.toString() ?? '';

  bool get _isTenant {
    final r = widget.currentUser.role.toLowerCase();
    return r == 'renter' || r == 'buyer';
  }

  String get _ownerName =>
      widget.conversation['owner_name']?.toString() ?? 'Owner';
  String get _propertyTitle =>
      widget.conversation['property_title']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markRead();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs =
          await DirectMessageService.getMessages(_conversationId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        _scrollToBottom();
        _startPolling();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _cancelPolling = DirectMessageService.subscribeToMessages(
      _conversationId,
      (newMsg) {
        if (!mounted) return;
        final alreadyExists =
            _messages.any((m) => m['id']?.toString() == newMsg['id']?.toString());
        if (!alreadyExists) {
          setState(() => _messages.add(newMsg));
          _scrollToBottom();
        }
      },
    );
  }

  void _markRead() {
    if (_isTenant) {
      DirectMessageService.markTenantRead(_conversationId);
    } else {
      DirectMessageService.markOwnerRead(_conversationId);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _msgController.clear();
    });

    // Optimistic insert
    final optimistic = {
      'id': 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      'conversation_id': _conversationId,
      'sender_id': widget.currentUser.id,
      'sender_name': widget.currentUser.fullName.isNotEmpty
          ? widget.currentUser.fullName
          : widget.currentUser.email.split('@')[0],
      'sender_role': widget.currentUser.role,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      '_optimistic': true,
    };

    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final saved = await DirectMessageService.sendMessage(
        conversationId: _conversationId,
        senderId: widget.currentUser.id,
        senderName: widget.currentUser.fullName.isNotEmpty
            ? widget.currentUser.fullName
            : widget.currentUser.email.split('@')[0],
        senderRole: widget.currentUser.role,
        message: text,
      );

      // Replace optimistic entry with the real row from Supabase
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere(
              (m) => m['id']?.toString() == optimistic['id']?.toString());
          if (idx >= 0) _messages[idx] = saved;
        });
      }
    } catch (_) {
      // Leave optimistic message in place — it may have persisted anyway
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _cancelPolling?.call();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ownerName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_propertyTitle.isNotEmpty)
              Text(
                _propertyTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Anti-circumvention notice
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFFFFBEB),
              child: Row(
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'For your protection, never share bank details or pay outside the Rentilly platform.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: const Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chat stream
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet. Say hello! 👋',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, idx) {
                            final m = _messages[idx];
                            final isMe =
                                m['sender_id']?.toString() ==
                                    widget.currentUser.id;
                            final text =
                                m['message']?.toString() ?? '';
                            final timeStr =
                                _formatTime(m['created_at']?.toString());

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isMe ? 16 : 4),
                                    bottomRight:
                                        Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: isMe
                                      ? null
                                      : Border.all(
                                          color: AppColors.borderDark),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        color: isMe
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8.5,
                                        color: isMe
                                            ? Colors.white
                                                .withValues(alpha: 0.7)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded,
                              size: 18, color: Colors.white),
                    ),
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
