import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../models/inspection.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/partner_id_card_modal.dart';
import '../../utils/id_utils.dart';
import '../main_navigation_screen.dart';

class InspectionsScreen extends StatefulWidget {
  const InspectionsScreen({super.key});

  @override
  State<InspectionsScreen> createState() => _InspectionsScreenState();
}

class _InspectionsScreenState extends State<InspectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Inspection> _inspections = [];
  UserProfile? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    final data = await ApiService.fetchInspections();
    if (mounted) {
      setState(() {
        _user = user;
        _inspections = data;
        _isLoading = false;
      });
    }
  }

  bool get _isHost => _user?.role == 'owner' || _user?.role == 'landlord' || _user?.role == 'partner';

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
      'Live Inspection Verification: https://myrentilly.com/safety/inspection/${insp.id}',
    );
  }

  void _shareHostGatePass(Inspection insp) {
    final hostId = IdUtils.formatOpsId(_user?.id, isPartner: _user?.role == 'partner');

    Share.share(
      '🔑 RENTILLY ESTATE ACCESS GATE PASS\n\n'
      'Dear Tenant,\n\n'
      'Your upcoming property inspection has been approved. Please present this pass at the estate security gate:\n\n'
      '📍 Property: ${insp.propertyTitle}\n'
      '🏢 Address: ${insp.propertyAddress}\n'
      '📅 Scheduled Date & Time: ${insp.scheduledDate}\n'
      '🔑 6-Digit Gate Code: ${insp.inspectionPassCode}\n'
      '👤 Accredited Host ID: $hostId\n\n'
      'Our host will present their matching Rentilly Digital ID upon arrival.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          _isHost ? 'Host Walkthroughs & Gate Passes' : 'Property Inspections',
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
          tabs: [
            Tab(text: _isHost ? 'Host 4K Live Video 📹' : '4K Live Video 📹'),
            Tab(text: _isHost ? 'Host In-Person Visits 🚶' : 'In-Person Tour 🚶'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildVideoTourTab(),
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
                colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
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
                            _isHost ? 'BROADCAST 4K STREAM' : 'LIVE 4K STREAM',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Zero Physical Stress',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isHost
                      ? 'Host Real-Time 4K Video Walkthroughs.\nConnect with Diaspora Tenants.'
                      : 'Zero Physical Stress.\nReal-Time 4K Video Walkthrough.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, height: 1.25),
                ),
                const SizedBox(height: 6),
                Text(
                  _isHost
                      ? 'Broadcast live HD video from your unit directly to prospective tenants. Showcase water pressure, interior finishing, and answer questions live.'
                      : 'Connect live with direct landlords or verified partners. Inspect plumbing, water pressure, and power before committing.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _isHost ? 'SCHEDULED BROADCAST SESSIONS' : 'ACTIVE VIDEO SESSIONS',
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
                  _isHost ? 'No Active Video Broadcast Requests' : 'No Upcoming Video Calls',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _isHost
                      ? 'When tenants schedule a 4K live video inspection for your properties, incoming requests appear here.'
                      : 'When you request a 4K live tour from a listing, your direct call session will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_isHost) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Video broadcast portal is active and ready for tenant sessions.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                      );
                    } else {
                      MainNavigationScreen.of(context)?.switchTab(1);
                    }
                  },
                  icon: Icon(_isHost ? Icons.videocam_rounded : Icons.search_rounded, size: 16, color: Colors.white),
                  label: Text(
                    _isHost ? 'Test Camera & 4K Stream 🎥' : 'Explore Properties for Live Video',
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
              // Digital ID Policy Card (Role-tailored for Host vs Tenant)
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
                            _isHost ? 'HOST ACCREDITATION & DIGITAL ID DIRECTIVE' : 'MANDATORY HOST DIGITAL ID POLICY',
                            style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF92400E), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isHost
                                ? 'As an accredited Rentilly host, always present your Official Digital ID Card upon tenant arrival. This satisfies estate security protocols and clears tenant inspection escrow.'
                                : 'Always demand to see the host\'s official Rentilly Digital ID (Landlord or Corporate Partner) upon arrival. If they cannot produce their matching Digital ID with accredited status, DO NOT enter the property.',
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
                          _isHost ? 'No Pending Inspection Requests' : 'No Scheduled In-Person Visits',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isHost
                            ? 'When tenants book in-person walkthroughs for your units, their booking schedules and gate passes appear here.'
                            : 'Browse verified properties to book an in-person physical walkthrough directly with the owner.',
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
                                  Text(_isHost ? 'TENANT GATE PASS' : 'ESTATE GATE CODE', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                  Text(insp.inspectionPassCode, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                ],
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  if (_isHost) {
                                    _shareHostGatePass(insp);
                                  } else {
                                    _shareSafetyItinerary(insp);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(_isHost ? 'Send to Tenant 📤' : 'Copy Pass', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons
                        Row(
                          children: [
                            if (_isHost) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (_user != null) PartnerIdCardModal.show(context, user: _user!);
                                  },
                                  icon: const Icon(Icons.badge_rounded, size: 14, color: Colors.white),
                                  label: Text('Present My Digital ID 🪪', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ] else ...[
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
                            ],
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
