import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  UserProfile? _currentUser;
  List<Map<String, dynamic>> _threads = [];

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  void _loadThreads() async {
    final u = await AuthService.getCurrentUser();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('rentilly_chat_threads');

    if (saved != null) {
      try {
        final List<dynamic> decoded = json.decode(saved);
        setState(() {
          _currentUser = u;
          _threads = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
        return;
      } catch (_) {}
    }

    // Default active conversations with direct property landlords
    final defaults = [
      {
        'id': 'chat_001',
        'name': 'Chief Adebayo Falana',
        'role': 'Direct Owner • Lekki Phase 1',
        'avatar': 'AF',
        'propertyTitle': 'Luxury 4-Bedroom Semi-Detached Duplex',
        'lastMessage': 'Good day. The C of O and Governor Consent are ready for your physical inspection.',
        'time': '10:45 AM',
        'unread': 1,
        'messages': [
          {
            'sender': 'Chief Adebayo Falana',
            'isMe': false,
            'text': 'Hello! Thank you for your interest in my 4-Bedroom Duplex in Lekki Phase 1.',
            'time': '10:30 AM'
          },
          {
            'sender': 'Chief Adebayo Falana',
            'isMe': false,
            'text': 'Good day. The C of O and Governor Consent are ready for your physical inspection.',
            'time': '10:45 AM'
          }
        ]
      },
      {
        'id': 'chat_002',
        'name': 'Dr. Somtochukwu Eze',
        'role': 'Direct Owner • Maitama Abuja',
        'avatar': 'SE',
        'propertyTitle': 'Executive 5-Bedroom Maitama Mansion',
        'lastMessage': 'The silent 50kVA generator was serviced yesterday. Looking forward to meeting you.',
        'time': 'Yesterday',
        'unread': 0,
        'messages': [
          {
            'sender': 'Dr. Somtochukwu Eze',
            'isMe': false,
            'text': 'Welcome! The Maitama property is available for inspection anytime between 11 AM and 4 PM.',
            'time': 'Yesterday'
          },
          {
            'sender': 'Dr. Somtochukwu Eze',
            'isMe': false,
            'text': 'The silent 50kVA generator was serviced yesterday. Looking forward to meeting you.',
            'time': 'Yesterday'
          }
        ]
      },
      {
        'id': 'chat_003',
        'name': 'Rentilly Legal Escrow Desk',
        'role': 'Official Verification Support',
        'avatar': 'RL',
        'propertyTitle': 'Tenancy Agreement & Caution Deposit',
        'lastMessage': 'Your Living Escrow account is active and protected under Lagos Tenancy Law 2011.',
        'time': 'Aug 29',
        'unread': 0,
        'messages': [
          {
            'sender': 'Rentilly Legal Desk',
            'isMe': false,
            'text': 'Welcome to Rentilly! We ensure 100% agent-free transactions with legal escrow protection.',
            'time': 'Aug 29'
          },
          {
            'sender': 'Rentilly Legal Desk',
            'isMe': false,
            'text': 'Your Living Escrow account is active and protected under Lagos Tenancy Law 2011.',
            'time': 'Aug 29'
          }
        ]
      }
    ];

    setState(() {
      _currentUser = u;
      _threads = defaults;
    });

    await prefs.setString('rentilly_chat_threads', json.encode(defaults));
  }

  void _openChat(Map<String, dynamic> thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          thread: thread,
          currentUser: _currentUser,
          onMessageSent: (updatedThread) async {
            final idx = _threads.indexWhere((t) => t['id'] == updatedThread['id']);
            if (idx >= 0) {
              setState(() {
                _threads[idx] = updatedThread;
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('rentilly_chat_threads', json.encode(_threads));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Direct Owner Messages',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          itemCount: _threads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final t = _threads[idx];
            final unread = (t['unread'] as num?)?.toInt() ?? 0;

            return InkWell(
              onTap: () => _openChat(t),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          t['avatar'] ?? 'DL',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t['name'] ?? 'Direct Owner',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                t['time'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: unread > 0 ? AppColors.accentOrange : AppColors.textSecondary,
                                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t['propertyTitle'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t['lastMessage'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: unread > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> thread;
  final UserProfile? currentUser;
  final Function(Map<String, dynamic>) onMessageSent;

  const ChatDetailScreen({
    super.key,
    required this.thread,
    required this.currentUser,
    required this.onMessageSent,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    final raw = widget.thread['messages'] as List<dynamic>? ?? [];
    _messages = raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    final myName = widget.currentUser?.fullName.isNotEmpty == true ? widget.currentUser!.fullName : 'Me';

    final newMsg = {
      'sender': myName,
      'isMe': true,
      'text': text,
      'time': timeStr,
    };

    setState(() {
      _messages.add(newMsg);
      _msgController.clear();
    });

    final updated = Map<String, dynamic>.from(widget.thread);
    updated['messages'] = _messages;
    updated['lastMessage'] = text;
    updated['time'] = 'Just now';
    updated['unread'] = 0;
    widget.onMessageSent(updated);

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread['name'] ?? 'Direct Owner',
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            Text(
              widget.thread['role'] ?? 'Direct Owner',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, idx) {
                  final m = _messages[idx];
                  final isMe = m['isMe'] == true;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['text'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: isMe ? Colors.white : AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            m['time'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Message Input Bar
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
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Type your message to owner...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
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
                      child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
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
