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

class _InspectionsScreenState extends State<InspectionsScreen> {
  List<Inspection> _inspections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInspections();
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'My Physical Inspections',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Show your 6-digit gate code to estate security guards at the checkpoint.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _inspections.isEmpty
                        ? Center(
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
                                  child: const Icon(Icons.calendar_today_outlined, size: 36, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No Scheduled Inspections',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Explore verified properties and book an in-person viewing with 1 tap.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 10,
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
                                        Text(
                                          insp.propertyTitle,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            insp.status.toUpperCase(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${insp.propertyAddress} • ${insp.scheduledDate} at ${insp.scheduledTimeSlot}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 16),

                                    // Gate Security Pass Box
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
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
                                                'SECURITY GATE PASS',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textSecondary,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                              Text(
                                                insp.inspectionPassCode,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 2.0,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(Icons.qr_code_2_rounded, size: 32, color: AppColors.textPrimary),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
