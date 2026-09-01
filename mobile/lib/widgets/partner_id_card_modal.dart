import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';

class PartnerIdCardModal extends StatelessWidget {
  final UserProfile user;

  const PartnerIdCardModal({super.key, required this.user});

  static void show(BuildContext context, {required UserProfile user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartnerIdCardModal(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPartner = user.role == 'partner';
    final businessName = isPartner
        ? (user.businessName ?? 'Apex Realty Partners Ltd')
        : user.fullName;
    final cacNumber = user.cacNumber ?? (isPartner ? 'RC 1928374' : 'Verified Property Owner');
    final prefix = isPartner ? 'RNT-PTR' : 'RNT-LLD';
    final digitalId = '$prefix-${user.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4)}';
    final state = user.state ?? 'Lagos';
    final officeAddress = isPartner
        ? (user.officeAddress ?? 'Admiralty Way, Lekki Phase 1')
        : 'Direct Property Owner (Title Audited)';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPartner ? 'Rentilly Corporate Partner ID' : 'Rentilly Verified Landlord ID',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Official Field Inspection Credential',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                      ],
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

          // Scrollable Card Presentation Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // The Official Digital Badge Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPartner
                          ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
                          : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isPartner
                          ? AppColors.primaryLight.withValues(alpha: 0.4)
                          : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Watermark Pattern
                      Positioned(
                        right: -20,
                        bottom: -20,
                        child: Icon(
                          isPartner ? Icons.verified_user_rounded : Icons.vpn_key_rounded,
                          size: 180,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Top Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentOrange,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'RENTILLY',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isPartner ? 'CORPORATE PARTNER' : 'DIRECT LANDLORD',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white70,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF4ADE80)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF4ADE80)),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPartner ? 'ACCREDITED' : 'TITLE VERIFIED',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF4ADE80),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Identity Section
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar / Seal
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: isPartner
                                          ? [AppColors.primaryLight, AppColors.primary]
                                          : [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
                                    ),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      businessName.isNotEmpty
                                          ? businessName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                                          : 'RN',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        businessName,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isPartner ? 'CAC REGISTRATION: $cacNumber' : 'TITLE HOLDER & DIRECT OWNER',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isPartner ? const Color(0xFF38BDF8) : const Color(0xFF4ADE80),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isPartner
                                            ? 'Rep: ${user.fullName.isNotEmpty ? user.fullName : "Principal Director"}'
                                            : 'Verified via BVN & Deed of Ownership',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Card Divider
                            Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                            const SizedBox(height: 16),

                            // Details & QR Badge Box
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildMetaItem(isPartner ? 'PARTNER ACCREDITATION ID' : 'LANDLORD DIGITAL ID', digitalId),
                                      const SizedBox(height: 8),
                                      _buildMetaItem('STATE OF OPERATION', state),
                                      const SizedBox(height: 8),
                                      _buildMetaItem(isPartner ? 'VERIFIED OFFICE' : 'VERIFICATION STATUS', officeAddress),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Real-time Verification Badge Box
                                Container(
                                  width: 76,
                                  height: 76,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.qr_code_2_rounded, size: 36, color: Color(0xFF0F172A)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SCAN TO VERIFY',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 6.5, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Gate & Inspection Notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isPartner
                              ? 'Present this Digital ID to Estate Security and prospective tenants during in-person property walkthroughs to confirm Rentilly official accreditation.'
                              : 'Present this Digital Landlord ID to prospective tenants during inspections so they can verify authentic property ownership before entering the premises.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Share & Present ID Button
                ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      'Official Rentilly ${isPartner ? "Corporate Partner" : "Landlord"} Credential:\n\n'
                      'Name/Business: $businessName\n'
                      '${isPartner ? "CAC Registration: $cacNumber\n" : ""}'
                      'Digital ID: $digitalId\n'
                      'Accreditation Verification: https://rentilly.ng/verify/${isPartner ? "partner" : "landlord"}/$digitalId',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text('Share / Present Digital ID Card', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white60, letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}
