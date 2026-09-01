import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/inspection.dart';
import '../../services/api_service.dart';

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
                  blurRadius: 16,
                  offset: const Offset(0, 6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('4K LIVE STREAM READY', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                    const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Scheduled 4K Live Video Tour',
                  style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Join during the landlord\'s scheduled broadcast window as they walk through the property live. Ask real-time questions, inspect plumbing, water pressure, and compound security without travelling.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'UPCOMING LANDLORD LIVE BROADCASTS',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),

          // Broadcast Card 1
          _buildBroadcastCard(
            title: '4-Bedroom Fully Detached Duplex + BQ',
            location: 'Lekki Phase 1, Lagos',
            host: 'Engr. Patrick (Direct Owner)',
            time: 'Today, 4:30 PM (WAT)',
            isLiveSoon: true,
          ),

          // Broadcast Card 2
          _buildBroadcastCard(
            title: 'Luxury 2-Bedroom Serviced Apartment',
            location: 'Maitama, Abuja (FCT)',
            host: 'Alhaji Ibrahim (Direct Landlord)',
            time: 'Tomorrow, 11:00 AM (WAT)',
            isLiveSoon: false,
          ),

          // Broadcast Card 3
          _buildBroadcastCard(
            title: 'Executive 3-Bedroom Flat with Water View',
            location: 'Peter Odili Road, Port Harcourt',
            host: 'Barrister Nneka (Verified Manager)',
            time: 'Thursday, 2:00 PM (WAT)',
            isLiveSoon: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastCard({
    required String title,
    required String location,
    required String host,
    required String time,
    required bool isLiveSoon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
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
                  color: isLiveSoon ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLiveSoon ? Icons.fiber_manual_record_rounded : Icons.schedule_rounded,
                      size: 10,
                      color: isLiveSoon ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLiveSoon ? 'STARTING SOON' : 'SCHEDULED WINDOW',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isLiveSoon ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            '$location • Host: $host',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Registered for "$title" 4K live broadcast! You will receive notification before the landlord goes live.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              icon: const Icon(Icons.video_camera_front_rounded, size: 16, color: Colors.white),
              label: Text(
                isLiveSoon ? 'Join 4K Live Broadcast' : 'Set Live Reminder',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLiveSoon ? AppColors.accentOrange : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInPersonTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _inspections.isEmpty
            ? Center(
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
              )
            : ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: _inspections.length,
                itemBuilder: (context, index) {
                  final insp = _inspections[index];
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
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ESTATE GATE CODE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                Text(insp.inspectionPassCode, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                      ],
                    ),
                  );
                },
              );
  }
}
