import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/roommate_post.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/roommate_service.dart';

class PostRoommateModal extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onPostCreated;

  const PostRoommateModal({
    super.key,
    required this.user,
    required this.onPostCreated,
  });

  static void show(BuildContext context, {required UserProfile user, required VoidCallback onPostCreated}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostRoommateModal(user: user, onPostCreated: onPostCreated),
    );
  }

  @override
  State<PostRoommateModal> createState() => _PostRoommateModalState();
}

class _PostRoommateModalState extends State<PostRoommateModal> {
  String _postType = 'have_room'; // 'have_room' | 'need_room'
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _totalRentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();

  String _selectedState = 'Lagos';
  String _bedroomType = '2 Bedroom Apartment';
  String _moveInTimeline = 'Immediate';
  String _genderPref = 'Any';

  final List<String> _availableLifestyleTags = [
    'Remote Worker',
    'Hybrid Worker',
    'Corporate 9-to-5',
    'Non-Smoker',
    'Quiet / Introverted',
    'Early Bird',
    'Night Owl',
    'Pet Friendly',
    'Clean & Organized',
    'No Late Parties',
    'Fitness Lover',
    'Foodie / Cook',
  ];

  final List<String> _selectedTags = ['Remote Worker', 'Non-Smoker', 'Quiet / Introverted'];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _occupationController.text = 'Professional';
    if (widget.user.state != null && widget.user.state!.isNotEmpty) {
      _selectedState = widget.user.state!;
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _totalRentController.dispose();
    _locationController.dispose();
    _aboutController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    final budgetStr = _budgetController.text.replaceAll(',', '').trim();
    final budget = double.tryParse(budgetStr) ?? 0.0;
    final totalStr = _totalRentController.text.replaceAll(',', '').trim();
    final total = double.tryParse(totalStr) ?? (budget * 2);
    final location = _locationController.text.trim();
    final about = _aboutController.text.trim();
    final occupation = _occupationController.text.trim();

    if (budget <= 0) {
      _showToast('Please enter your target budget share (₦).');
      return;
    }
    if (location.isEmpty) {
      _showToast('Please enter the target neighborhood / area.');
      return;
    }

    setState(() => _isSubmitting = true);

    final newPost = RoommatePost(
      id: 'ROOM_${DateTime.now().millisecondsSinceEpoch}',
      userId: widget.user.id,
      userName: widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Verified Renter',
      userAvatar: widget.user.fullName.isNotEmpty
          ? widget.user.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
          : 'VR',
      userOccupation: occupation.isNotEmpty ? occupation : 'Professional',
      postType: _postType,
      budgetShare: budget,
      totalRent: total,
      splitPercentage: total > 0 ? ((budget / total) * 100).round() : 50,
      location: '$location, $_selectedState',
      state: _selectedState,
      bedroomType: _bedroomType,
      moveInTimeline: _moveInTimeline,
      genderPreference: _genderPref,
      lifestyleTags: _selectedTags,
      imageUrls: [
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
        'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
      ],
      aboutMe: about.isNotEmpty ? about : 'Looking for a responsible, verified flatmate to split our lease through Rentilly living escrow.',
      isVerified: widget.user.isVerified,
      createdAt: DateTime.now(),
    );

    await RoommateService.addPost(newPost);

    await NotificationService.addNotification(
      title: 'Roommate Request Published 👥✨',
      message: 'Your ${_postType == "have_room" ? "Co-Living Host" : "Roommate Search"} request in $location ($_selectedState) is live on Split-the-Scroll.',
      category: 'property',
      metadata: {
        'budget': '₦${NumberFormat('#,###').format(budget)} / yr',
        'location': location,
        'state': _selectedState,
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onPostCreated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Roommate request published to Split-the-Scroll!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.accentOrange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post on Split-the-Scroll 👥',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Verified Co-Living & Split-Escrow Requests',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Post Type Switcher
                Text('1. SELECT REQUEST TYPE', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _postType = 'have_room'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _postType == 'have_room' ? AppColors.primary : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _postType == 'have_room' ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.meeting_room_rounded, size: 20, color: _postType == 'have_room' ? Colors.white : AppColors.primary),
                              const SizedBox(height: 4),
                              Text(
                                'I Have a Room 🛋️',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _postType == 'have_room' ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Seeking a flatmate',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  color: _postType == 'have_room' ? Colors.white70 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _postType = 'need_room'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _postType == 'need_room' ? AppColors.primary : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _postType == 'need_room' ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.person_search_rounded, size: 20, color: _postType == 'need_room' ? Colors.white : AppColors.primary),
                              const SizedBox(height: 4),
                              Text(
                                'Buddy Up / Need Room 🔍',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _postType == 'need_room' ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Let us rent together',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  color: _postType == 'need_room' ? Colors.white70 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Budget Share & Total Rent
                Text('2. BUDGET SHARE & TOTAL ANNUAL RENT (₦)', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: _inputDeco(hint: 'My Share: e.g. 1,200,000'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _totalRentController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: _inputDeco(hint: 'Total: e.g. 2,400,000'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Location & State
                Text('3. TARGET AREA / NEIGHBORHOOD', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _locationController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(hint: 'e.g. Lekki Phase 1, Freedom Way'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedState,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(),
                        items: ['Lagos', 'Abuja', 'Oyo', 'Rivers', 'Ogun', 'Enugu'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedState = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 4. Bedroom Type & Timeline
                Text('4. APARTMENT TYPE & TIMELINE', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _bedroomType,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(),
                        items: [
                          '2 Bedroom Apartment',
                          '3 Bedroom Apartment',
                          'Shared Duplex / Penthouse',
                          'Serviced Mini Flat',
                        ].map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _bedroomType = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _moveInTimeline,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(),
                        items: [
                          'Immediate',
                          'Within 14 Days',
                          'Within 30 Days',
                          'Flexible',
                        ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) => setState(() => _moveInTimeline = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 5. Gender Preference & Occupation
                Text('5. GENDER PREFERENCE & OCCUPATION', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _genderPref,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(),
                        items: ['Any', 'Female Only', 'Male Only'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => _genderPref = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _occupationController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(hint: 'e.g. Software Engineer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 6. Lifestyle Compatibility Badges
                Text('6. LIFESTYLE & HABITS (SELECT ALL THAT APPLY)', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _availableLifestyleTags.map((tag) {
                    final isSel = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(
                        tag,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: isSel ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSel,
                      backgroundColor: const Color(0xFFF1F5F9),
                      selectedColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSel ? AppColors.primary : AppColors.borderDark),
                      ),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // 7. About Me & Cleanliness Bio
                Text('7. ABOUT YOU & CO-LIVING STANDARDS', style: _labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _aboutController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: _inputDeco(hint: 'Describe your routine, work schedule, cleanliness standards, and guest policy...'),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 18, color: AppColors.accentOrange),
                            const SizedBox(width: 6),
                            Text(
                              'Publish to Split-the-Scroll',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  InputDecoration _inputDeco({String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
    );
  }
}
