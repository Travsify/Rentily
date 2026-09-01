import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/partner_listing_modal.dart';
import '../properties/properties_screen.dart';
import '../inspections/inspections_screen.dart';

class LandlordDashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;

  const LandlordDashboardScreen({super.key, this.onSwitchToTenant});

  @override
  State<LandlordDashboardScreen> createState() => _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = u;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.fullName.isNotEmpty == true ? _user!.fullName : 'Landlord / Seller';
    final isVerified = _user?.isVerified ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'LANDLORD / PARTNER PORTAL',
                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accentOrange),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Switch to Tenant / Buyer Mode
          TextButton.icon(
            onPressed: widget.onSwitchToTenant,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
            label: Text(
              'Buyer Mode',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Landlord / Partner Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
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
                        Row(
                          children: [
                            const Icon(Icons.business_center_rounded, size: 18, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              _user?.role == 'partner' ? 'VERIFIED CORPORATE PARTNER' : 'DIRECT PROPERTY OWNER',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? AppColors.primaryLight.withValues(alpha: 0.2)
                                : AppColors.accentOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isVerified ? AppColors.primaryLight : AppColors.accentOrange,
                            ),
                          ),
                          child: Text(
                            isVerified ? 'VERIFIED' : 'UNVERIFIED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isVerified ? Colors.white : AppColors.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _user?.role == 'partner' && _user?.businessName != null ? _user!.businessName! : name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _user?.role == 'partner' ? 'CAC RC/BN: ${_user?.cacNumber ?? "Verified Partner"} • ${_user?.email ?? ""}' : (_user?.email ?? ''),
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white60),
                    ),
                    const SizedBox(height: 20),

                    // Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user?.role == 'partner' ? 'PARTNER COMMISSIONS' : 'ACTIVE ESCROW RENT',
                                style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60),
                              ),
                              const SizedBox(height: 2),
                              Text('₦0.00', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VETTED PROPERTIES', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                              const SizedBox(height: 2),
                              Text('0 Units', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.accentOrange)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Owner Operations Hub
              Text(
                'LANDLORD & PARTNER SUITE',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              // 1. List New Property (Opens Anti-Ghost Partner Listing Modal)
              _buildActionCard(
                icon: Icons.add_home_work_rounded,
                title: 'List Property (Landlord / Partner)',
                subtitle: 'Anti-ghost listing protection. 2.5% Rent / 2.0% Sales Commission.',
                tag: 'NEW LISTING',
                color: AppColors.primary,
                onTap: () {
                  if (_user != null) {
                    PartnerListingModal.show(context, user: _user!, onListingCreated: _loadUser);
                  }
                },
              ),

              // 2. Inspection Gate Passes & Self-Tours
              _buildActionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Inspection Bookings & Gate Passes',
                subtitle: 'Manage self-tour access, schedule video calls, issue gate passes.',
                tag: 'ACTIVE',
                color: const Color(0xFF0284C7),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InspectionsScreen()));
                },
              ),

              // 3. Digital Leases & Tenancy Contracts
              _buildActionCard(
                icon: Icons.history_edu_rounded,
                title: 'Tenancy Agreements & Caution Escrow',
                subtitle: 'Standard Lagos Law compliant lease generation and photo-inspected caution escrow release.',
                tag: 'LEGAL',
                color: const Color(0xFF7C3AED),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No active tenant leases currently require review.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                  );
                },
              ),

              // 4. Landlord Bank Payout Account
              _buildActionCard(
                icon: Icons.account_balance_rounded,
                title: 'Direct Settlement & Bank Payouts',
                subtitle: 'Receive instant rent settlements directly to your verified commercial bank account.',
                tag: 'PAYOUTS',
                color: AppColors.accentOrange,
                onTap: () {
                  if (!isVerified) {
                    VerificationModal.show(context, onSuccess: (updated) {
                      setState(() => _user = updated);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payout account linked to ${_user?.accountNumber ?? "Dedicated Account"}', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String tag,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(tag, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }

  void _showListPropertyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('List New Property', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 6),
            Text('Connect directly with verified renters and buyers with zero middleman fees.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Title & Documentation Verification', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Upload proof of ownership (Deed of Assignment, Governor Consent, or C of O) to obtain the Direct Landlord Badge.', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Direct listing wizard initiated!', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Proceed to Property Onboarding', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
