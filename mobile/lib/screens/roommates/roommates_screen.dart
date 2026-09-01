import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/roommate_post.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/roommate_service.dart';
import '../../widgets/post_roommate_modal.dart';
import '../../widgets/split_escrow_modal.dart';
import '../../widgets/verification_modal.dart';
import '../messages/messages_screen.dart';

class RoommatesScreen extends StatefulWidget {
  const RoommatesScreen({super.key});

  @override
  State<RoommatesScreen> createState() => _RoommatesScreenState();
}

class _RoommatesScreenState extends State<RoommatesScreen> {
  UserProfile? _user;
  List<RoommatePost> _allPosts = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'have_room', 'need_room', '2_split', '3_split'

  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final u = await AuthService.getCurrentUser();
    final posts = await RoommateService.getPosts();
    if (mounted) {
      setState(() {
        _user = u;
        _allPosts = posts;
        _isLoading = false;
      });
    }
  }

  List<RoommatePost> get _filteredPosts {
    if (_selectedFilter == 'all') return _allPosts;
    if (_selectedFilter == 'have_room' || _selectedFilter == 'need_room') {
      return _allPosts.where((p) => p.postType == _selectedFilter).toList();
    }
    if (_selectedFilter == '2_split') {
      return _allPosts.where((p) => p.splitCount == 2).toList();
    }
    if (_selectedFilter == '3_split') {
      return _allPosts.where((p) => p.splitCount == 3).toList();
    }
    return _allPosts;
  }

  void _openPostModal() {
    if (_user == null) return;
    PostRoommateModal.show(
      context,
      user: _user!,
      onPostCreated: _loadData,
    );
  }

  void _openChatWithRoommate(RoommatePost post) async {
    if (_user == null) return;

    if (!_user!.isVerified) {
      VerificationModal.show(context, onSuccess: (updated) {
        setState(() => _user = updated);
      });
      return;
    }

    final threadId = 'THREAD_${post.id}_${_user!.id}';
    final existingThread = {
      'id': threadId,
      'name': post.userName,
      'avatar': post.userAvatar,
      'propertyTitle': 'Co-Living (${post.splitCount}-Person Split): ${post.bedroomType}',
      'time': 'Just now',
      'lastMessage': 'Hi ${post.userName}, I saw your Split-the-Scroll request for ${post.bedroomType} and would like to connect!',
      'unread': 0,
      'messages': [
        {
          'sender': _user!.fullName.isNotEmpty ? _user!.fullName : 'Me',
          'isMe': true,
          'text': 'Hi ${post.userName}! I saw your verified ${post.splitCount}-person request on Split-the-Scroll for ${post.bedroomType} in ${post.location}. Are you still looking for a flatmate?',
          'time': DateFormat('hh:mm a').format(DateTime.now()),
        }
      ],
    };

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('rentilly_chat_threads');
    List<Map<String, dynamic>> threads = [];
    if (saved != null) {
      try {
        final List<dynamic> decoded = json.decode(saved);
        threads = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    final idx = threads.indexWhere((t) => t['id'] == threadId);
    if (idx >= 0) {
      threads[idx] = existingThread;
    } else {
      threads.insert(0, existingThread);
    }
    await prefs.setString('rentilly_chat_threads', json.encode(threads));

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          thread: existingThread,
          currentUser: _user,
          onMessageSent: (_) {},
        ),
      ),
    );
  }

  void _openSplitEscrow(RoommatePost post) {
    if (_user == null) return;
    SplitEscrowModal.show(context, post: post, user: _user!);
  }

  void _sharePost(RoommatePost post) {
    Share.share(
      'Check out this verified co-living request on Rentilly Split-the-Scroll:\n\n'
      '${post.userName} is looking for a flatmate for a ${post.bedroomType} in ${post.location} (₦${_currencyFormat.format(post.budgetShare)}/yr per share • ${post.splitCount}-person split).\n\n'
      'Connect securely with 0% caution fees on Rentilly: https://rentilly.ng/roommates/${post.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredPosts;

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
            Row(
              children: [
                Text(
                  'Split-the-Scroll',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'CO-LIVING 👥',
                    style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: AppColors.accentOrange),
                  ),
                ),
              ],
            ),
            Text(
              'Find Verified Roommates & Split Rent (2-3 Persons)',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPostModal,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Post Request',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contained Header Filter Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Roommates 👥'),
                    _buildFilterChip('have_room', 'Have a Room 🛋️'),
                    _buildFilterChip('need_room', 'Seeking Room 🔍'),
                    _buildFilterChip('2_split', '2-Way Split (50%)'),
                    _buildFilterChip('3_split', '3-Way Split (33%)'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.borderDark),

            // Scrollable Contained Feed Cards
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : list.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final post = list[index];
                            return _buildRoommateCard(post);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
            color: isSel ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRoommateCard(RoommatePost post) {
    final splitLabel = post.splitCount == 3 ? '3-WAY SPLIT (33.3%)' : '2-WAY SPLIT (50%)';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. User Header Box
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  ),
                  child: Center(
                    child: Text(
                      post.userAvatar,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.userName,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF0284C7)),
                        ],
                      ),
                      Text(
                        post.userOccupation,
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: post.postType == 'have_room' ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: post.postType == 'have_room' ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    post.postType == 'have_room' ? 'HAVE ROOM 🛋️' : 'NEED ROOM 🔍',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: post.postType == 'have_room' ? AppColors.primary : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Contained Rent Breakdown Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$splitLabel SHARE',
                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₦${_currencyFormat.format(post.budgetShare)} / yr',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL APARTMENT RENT',
                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₦${_currencyFormat.format(post.totalRent)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Property & Location Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.bedroomType,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: AppColors.accentOrange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.location,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      post.moveInTimeline,
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Lifestyle Compatibility Cloud
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: post.lifestyleTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // 5. Bio Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              post.aboutMe,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),

          // 6. Contained Bottom Action Dock
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 17, color: AppColors.textSecondary),
                  onPressed: () => _sharePost(post),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openChatWithRoommate(post),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text('Connect', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openSplitEscrow(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.handshake_rounded, size: 13, color: AppColors.accentOrange),
                        const SizedBox(width: 5),
                        Text('Split Escrow', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Roommate Requests Yet',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first verified user to post a co-living request on Split-the-Scroll and find a flatmate to split rent 50/50 (2 persons) or 33% (3 persons).',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openPostModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Post Roommate Request', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
