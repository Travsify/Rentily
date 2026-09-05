import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/support_chat_service.dart';

class SupportChatScreen extends StatefulWidget {
  final UserProfile? user;

  const SupportChatScreen({super.key, this.user});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  UserProfile? _user;
  Map<String, dynamic>? _conversation;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  bool _showSubjectPicker = false;
  List<Map<String, dynamic>> _allConversations = [];

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Function? _cancelSubscription;

  static const List<String> _subjects = [
    'Bank Transfers & Deposits',
    'Withdrawals & Bank Payouts',
    'Virtual Dollar Cards',
    'BVN / KYC & Tier Upgrades',
    'Escrow & Rent Protection',
    'General Enquiry',
  ];

  static const List<IconData> _subjectIcons = [
    Icons.account_balance_rounded,
    Icons.payments_rounded,
    Icons.credit_card_rounded,
    Icons.verified_user_outlined,
    Icons.shield_outlined,
    Icons.help_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _cancelSubscription?.call();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _user = widget.user ?? await AuthService.getCurrentUser();
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final conversations =
        await SupportChatService.getConversations(_user!.email);

    if (mounted) {
      setState(() => _allConversations = conversations);
    }

    if (conversations.isEmpty) {
      setState(() {
        _isLoading = false;
        _showSubjectPicker = true;
      });
    } else {
      // Use most recent open conversation; if all resolved, still show it
      final open = conversations.firstWhere(
        (c) => c['status'] != 'resolved',
        orElse: () => conversations.first,
      );
      await _openConversation(open);
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conv) async {
    setState(() {
      _conversation = conv;
      _isLoading = true;
      _showSubjectPicker = false;
    });

    final msgs = await SupportChatService.getMessages(conv['id'] as String);

    setState(() {
      _messages = msgs;
      _isLoading = false;
    });

    // Mark as read
    SupportChatService.markMessagesRead(conv['id'] as String);

    _startPolling(conv['id'] as String);
    _scrollToBottom(delay: 300);
  }

  void _startPolling(String conversationId) {
    _cancelSubscription?.call();
    _cancelSubscription = SupportChatService.subscribeToMessages(
      conversationId,
      _onNewMessage,
    );
  }

  void _onNewMessage(Map<String, dynamic> msg) {
    final msgId = msg['id']?.toString();
    final alreadyPresent = _messages.any((m) => m['id']?.toString() == msgId);
    if (alreadyPresent) return;

    setState(() {
      _messages.add(msg);
      _isTyping = false;
    });
    SupportChatService.markMessagesRead(_conversation!['id'] as String);
    _scrollToBottom(delay: 100);
  }

  Future<void> _selectSubject(String subject) async {
    if (_user == null) return;

    setState(() {
      _isLoading = true;
      _showSubjectPicker = false;
    });

    try {
      final conv = await SupportChatService.createOrGetConversation(
        _user!,
        subject,
      );
      await _openConversation(conv);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showSubjectPicker = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not start conversation. Please try again.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending || _conversation == null || _user == null) {
      return;
    }

    setState(() {
      _isSending = true;
      _isTyping = false;
    });
    _msgController.clear();

    // Optimistic local insert
    final optimisticMsg = {
      'id': 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      'conversation_id': _conversation!['id'],
      'sender': 'user',
      'sender_name': _user!.fullName,
      'message': text,
      'message_type': 'text',
      'is_read': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom(delay: 80);

    try {
      await SupportChatService.sendMessage(
        _conversation!['id'] as String,
        text,
        _user!,
      );
    } catch (_) {
      // Keep optimistic message in UI even on error
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isTyping = false;
        });
      }
    }
  }

  void _scrollToBottom({int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openNewConversation() {
    _cancelSubscription?.call();
    setState(() {
      _conversation = null;
      _messages = [];
      _showSubjectPicker = true;
    });
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoading
            ? _buildLoader()
            : _showSubjectPicker
                ? _buildSubjectPicker()
                : _buildChatView(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded,
            size: 22, color: AppColors.textPrimary),
        onPressed: () {
          if (!_showSubjectPicker && _allConversations.isNotEmpty) {
            setState(() => _showSubjectPicker = true);
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar with green dot
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    'RS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rentilly Support',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Live Human Support • Pure Human Agents',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  color: const Color(0xFF059669),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (!_showSubjectPicker)
          TextButton.icon(
            onPressed: () {
              setState(() => _showSubjectPicker = true);
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
            label: Text(
              'Topics',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 14),
          Text(
            'Connecting to support...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Subject Picker
  // ---------------------------------------------------------------------------
  Widget _buildSubjectPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header illustration
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'How can we help you?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Select a topic or return to an ongoing conversation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              return _SubjectTile(
                icon: _subjectIcons[i],
                label: _subjects[i],
                onTap: () => _selectSubject(_subjects[i]),
              );
            },
          ),
          if (_allConversations.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'RECENT CONVERSATIONS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allConversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = _allConversations[i];
                final isCurrent = _conversation?['id'] == c['id'];
                return InkWell(
                  onTap: () => _openConversation(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent ? AppColors.primary : AppColors.borderDark,
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['subject'] ?? 'Support Chat',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              if (c['last_message'] != null && c['last_message'].toString().isNotEmpty)
                                Text(
                                  c['last_message'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Our team is available Mon–Sat, 8 AM–6 PM WAT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chat View
  // ---------------------------------------------------------------------------
  Widget _buildChatView() {
    final isResolved = _conversation?['status'] == 'resolved';

    return Column(
      children: [
        // Resolved banner
        if (isResolved) _buildResolvedBanner(),

        // Message list
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyChat()
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, idx) {
                    if (_isTyping && idx == _messages.length) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[idx]);
                  },
                ),
        ),

        // Input bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildResolvedBanner() {
    return GestureDetector(
      onTap: _openNewConversation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFFEF3C7),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFFD97706), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This conversation has been resolved. Tap to open a new one.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD97706), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'Start the conversation',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Type your message below and our team will get back to you shortly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final sender = msg['sender']?.toString() ?? 'user';
    final isMe = sender == 'user';
    final isBot = sender == 'bot';
    final message = msg['message']?.toString() ?? '';
    final createdAt = msg['created_at']?.toString() ?? '';
    final timeLabel = _formatTime(createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Agent/Bot avatar
          if (!isMe) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBot
                    ? const Color(0xFF059669)
                    : AppColors.primary.withValues(alpha: 0.9),
              ),
              child: Center(
                child: Text(
                  'RS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender label for human support agent
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (msg['sender_name']?.toString().isNotEmpty == true &&
                                    msg['sender_name'] != 'Rentilly Support Bot')
                                ? msg['sender_name'].toString()
                                : 'Support Agent',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 10,
                            color: Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.65)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF059669),
            ),
            child: Center(
              child: Text(
                'RS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.borderDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
                const SizedBox(width: 4),
                _TypingDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isResolved = _conversation?['status'] == 'resolved';

    return Container(
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
              enabled: !isResolved,
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: isResolved
                    ? 'Conversation resolved'
                    : 'Type your message...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.2),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isResolved ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isResolved
                    ? AppColors.borderDark
                    : (_isSending
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);

      final hour = dt.hour > 12
          ? dt.hour - 12
          : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour:$minute $period';

      if (msgDay == today) return timeStr;
      final diff = today.difference(msgDay).inDays;
      if (diff == 1) return 'Yesterday $timeStr';
      return '${dt.day}/${dt.month} $timeStr';
    } catch (_) {
      return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Subject Tile widget
// ---------------------------------------------------------------------------
class _SubjectTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated typing dot
// ---------------------------------------------------------------------------
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
