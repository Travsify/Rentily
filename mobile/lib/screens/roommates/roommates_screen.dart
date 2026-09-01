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
  String _selectedFilter = 'all'; // 'all', 'have_room', 'need_room', 'Lagos', 'Abuja', 'Ibadan'

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
    return _allPosts.where((p) => p.state.toLowerCase().contains(_selectedFilter.toLowerCase()) || p.location.toLowerCase().contains(_selectedFilter.toLowerCase())).toList();
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

    // Check KYC verification
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
      'propertyTitle': 'Co-Living: ${post.bedroomType} (${post.location})',
      'time': 'Just now',
      'lastMessage': 'Hi ${post.userName}, I saw your Split-the-Scroll request for ${post.bedroomType} and would like to connect!',
      'unread': 0,
      'messages': [
        {
          'sender': _user!.fullName.isNotEmpty ? _user!.fullName : 'Me',
          'isMe': true,
          'text': 'Hi ${post.userName}! I saw your verified request on Split-the-Scroll for ${post.bedroomType} in ${post.location}. Are you still looking for a co-tenant?',
          'time': DateFormat('hh:mm a').format(DateTime.now()),
        }
      ],
    };

    // Save thread to messages
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
      '${post.userName} is looking for a flatmate for a ${post.bedroomType} in ${post.location} (₦${_currencyFormat.format(post.budgetShare)}/yr per share).\n\n'
      'Connect securely with 0% caution fees on Rentilly: https://rentilly.ng/roommates/${post.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredPosts;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark luxury aesthetic for Split-the-Scroll
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Split-the-Scroll',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'CO-LIVING 👥',
                    style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ),
            Text(
              'Find Verified Roommates & Split Rent 50/50',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white70),
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
            // Filter Strip
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: const Color(0xFF1E293B),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Roommates 👥'),
                    _buildFilterChip('have_room', 'Have a Room 🛋️'),
                    _buildFilterChip('need_room', 'Seeking Room 🔍'),
                    _buildFilterChip('Lagos', 'Lagos 🌴'),
                    _buildFilterChip('Abuja', 'Abuja 🏛️'),
                    _buildFilterChip('Ibadan', 'Ibadan 🌳'),
                  ],
                ),
              ),
            ),

            // Scrollable Feed Cards
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : list.isEmpty
                      ? _buildEmptyState()
                      : PageView.builder(
                          scrollDirection: Axis.vertical,
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
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : const Color(0xFF334155),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? AppColors.primary : const Color(0xFF475569)),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRoommateCard(RoommatePost post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: User Identity & Verification Pill
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  ),
                  child: Center(
                    child: Text(
                      post.userAvatar,
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
                        children: [
                          Flexible(
                            child: Text(
                              post.userName,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF38BDF8)),
                        ],
                      ),
                      Text(
                        post.userOccupation,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.postType == 'have_room' ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFF16A34A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: post.postType == 'have_room' ? const Color(0xFF0284C7) : const Color(0xFF16A34A)),
                  ),
                  child: Text(
                    post.postType == 'have_room' ? 'HAVE ROOM 🛋️' : 'NEED ROOM 🔍',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: post.postType == 'have_room' ? const Color(0xFF38BDF8) : const Color(0xFF4ADE80),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Budget & Split Highlight Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY 50% ANNUAL SHARE',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₦${_currencyFormat.format(post.budgetShare)} / year',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL APARTMENT RENT',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₦${_currencyFormat.format(post.totalRent)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFDE047)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Property & Location Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.bedroomType,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: AppColors.accentOrange),
                    const SizedBox(width: 4),
                    Text(
                      post.location,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text(
                      post.moveInTimeline,
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lifestyle Compatibility Tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: post.lifestyleTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Bio Snippet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.aboutMe,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white60, height: 1.4),
            ),
          ),
          const Spacer(),

          // Bottom Action Dock
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // Share Button
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18, color: Colors.white70),
                  onPressed: () => _sharePost(post),
                ),
                const SizedBox(width: 4),

                // Connect & Chat Button
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => _openChatWithRoommate(post),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Connect', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Split Escrow Button
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () => _openSplitEscrow(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.handshake_rounded, size: 14, color: AppColors.accentOrange),
                        const SizedBox(width: 6),
                        Text('Split Escrow', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Roommates in this Category',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first verified user to post a co-living request on Split-the-Scroll and find a flatmate in your target area.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white60, height: 1.45),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openPostModal,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Post Roommate Request', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
