import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../models/inspection.dart';
import '../../services/api_service.dart';
import '../main_navigation_screen.dart';

class InspectionsScreen extends StatefulWidget {
  const InspectionsScreen({super.key});

  @override
  State<InspectionsScreen> createState() => _InspectionsScreenState();
}

class _InspectionsScreenState extends State<InspectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Inspection> _inspections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInspections();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadInspections() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchInspections();
    if (mounted) {
      setState(() {
        _inspections = data;
        _isLoading = false;
      });
    }
  }

  void _shareSafetyItinerary(Inspection insp) {
    Share.share(
      '🛡️ RENTILLY PROPERTY INSPECTION SAFETY ITINERARY\n\n'
      'I am currently going for a verified in-person property inspection. Details below for emergency safety tracking:\n\n'
      '📍 Property: ${insp.propertyTitle}\n'
      '🏢 Address: ${insp.propertyAddress}\n'
      '📅 Scheduled Date & Time: ${insp.scheduledDate}\n'
      '🔑 Gate Pass Code: ${insp.inspectionPassCode}\n'
      '👤 Host Type: Verified Rentilly Landlord / Corporate Partner\n'
      '🛡️ Emergency Safety Rule: I will demand the host presents their official Rentilly Digital ID before entry.\n\n'
      'Live Inspection Verification: https://rentilly.ng/safety/inspection/${insp.id}',
    );
  }

  void _showReviewDialog(Inspection insp) {
    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.accentOrange, size: 22),
              const SizedBox(width: 8),
              Text('Rate & Review Host', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How was your inspection for "${insp.propertyTitle}"?', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.accentOrange,
                      size: 30,
                    ),
                    onPressed: () => setDlgState(() => rating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Did the host present their Rentilly Digital ID? Was the property accurate to photos?',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Thank you! Review submitted and inspection escrow disbursed.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Submit Review', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          ],
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
          'Property Inspections',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '4K Live Video 📹'),
            Tab(text: 'In-Person Tour 🚶'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: 4K Live Video Tour with Landlord / Host Scheduled Window
            _buildVideoTourTab(),
            // Tab 2: Verified In-Person Inspection Walkthrough
            _buildInPersonTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTourTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Video Hero Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D5C46), Color(0xFF07382B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE 4K STREAM',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₦0 Agent Free',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Zero Physical Stress.\nReal-Time 4K Video Walkthrough.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect live with direct landlords or verified partners. Inspect plumbing, water pressure, and power before committing.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'ACTIVE VIDEO SESSIONS',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              children: [
                const Icon(Icons.video_call_outlined, size: 40, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  'No Upcoming Video Calls',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'When you request a 4K live tour from a listing, your direct call session will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    MainNavigationScreen.of(context)?.switchTab(1);
                  },
                  icon: const Icon(Icons.search_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Explore Properties for Live Video',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInPersonTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Mandatory Digital ID Safety Directive Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.security_rounded, size: 22, color: Color(0xFFB45309)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MANDATORY HOST DIGITAL ID POLICY',
                            style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF92400E), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Always demand to see the host\'s official Rentilly Digital ID (Landlord or Corporate Partner) upon arrival. If they cannot produce their matching Digital ID with accredited status, DO NOT enter the property.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF78350F), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_inspections.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: const Icon(Icons.directions_walk_rounded, size: 36, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No Scheduled In-Person Visits',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Browse verified properties to book an in-person physical walkthrough directly with the owner.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ..._inspections.map((insp) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                insp.propertyTitle,
                                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(insp.status.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${insp.propertyAddress} • ${insp.scheduledDate}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 12),

                        // Estate Gate Code Box
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ESTATE GATE CODE', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                  Text(insp.inspectionPassCode, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                ],
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gate Pass ${insp.inspectionPassCode} copied to clipboard', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Copy Pass', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons: Safety Share & Review
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _shareSafetyItinerary(insp),
                                icon: const Icon(Icons.share_location_rounded, size: 14, color: AppColors.primary),
                                label: Text(
                                  'Share Itinerary (Safety) 🛡️',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showReviewDialog(insp),
                                icon: const Icon(Icons.star_rate_rounded, size: 14, color: Colors.white),
                                label: Text(
                                  'Rate & Review ⭐',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentOrange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
  }
}
