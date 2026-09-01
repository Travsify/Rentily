import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../models/property.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/partner_listing_modal.dart';
import '../../widgets/partner_id_card_modal.dart';
import '../../widgets/partner_landlord_onboard_modal.dart';
import '../../widgets/quick_utilities_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../inspections/inspections_screen.dart';
import '../properties/properties_screen.dart';

class PartnerDashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;

  const PartnerDashboardScreen({super.key, this.onSwitchToTenant});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  List<Property> _mandateProperties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartnerData();
  }

  void _loadPartnerData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    final allProps = await ApiService.fetchProperties();

    if (mounted) {
      setState(() {
        _user = user;
        _mandateProperties = allProps.where((p) => p.listedByRole == 'verified_partner').toList();
        _isLoading = false;
      });
    }
  }

  void _copyAccount(String accountNumber, String bankName) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account Number $accountNumber copied! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final businessName = _user?.businessName ?? 'Apex Realty Partners Ltd';
    final cacNumber = _user?.cacNumber ?? 'RC 1928374';
    final accountNumber = _user?.accountNumber ?? '9834192847';
    final bankName = _user?.bankName ?? 'Providus Bank';
    final partnerId = 'RNT-PTR-${_user?.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4) ?? "0042"}';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'RENTILLY PARTNER PORTAL 🏢',
                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.onSwitchToTenant != null)
            TextButton.icon(
              onPressed: widget.onSwitchToTenant,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
              label: Text(
                'Consumer Mode',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _loadPartnerData(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Corporate Identity Hero Card
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
                              const Icon(Icons.business_rounded, size: 18, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                'ACCREDITED CORPORATE FIRM',
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
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF4ADE80)),
                            ),
                            child: Text(
                              'VERIFIED 🛡️',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF4ADE80),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        businessName,
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'CAC: $cacNumber • Partner ID: $partnerId',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rep: ${_user?.fullName ?? "Principal Broker"} • ${_user?.email ?? ""}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white60),
                      ),
                      const SizedBox(height: 20),

                      // Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('COMMISSION EARNINGS', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                                const SizedBox(height: 2),
                                Text('₦${_currencyFormat.format(_user?.walletBalance ?? 0.0)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ACTIVE MANDATES', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                                const SizedBox(height: 2),
                                Text('${_mandateProperties.length} Units', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.accentOrange)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Dedicated Escrow Settlement Virtual Bank Account Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                              const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'ESCROW SETTLEMENT BANK ACCOUNT',
                                style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AUTOMATED PAYOUTS',
                              style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(accountNumber, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                              Text('$bankName • $businessName / Rentilly', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                            onPressed: () => _copyAccount(accountNumber, bankName),
                            tooltip: 'Copy Account Number',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  WithdrawalModal.show(
                                    context,
                                    user: _user!,
                                    onWithdrawalSuccess: (newBal) {
                                      setState(() => _user = _user!.copyWith(walletBalance: newBal));
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.north_east_rounded, size: 14, color: AppColors.primary),
                              label: Text('Withdraw Funds', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => QuickUtilitiesModal.show(context),
                              icon: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                              label: Text('Buy Utilities', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentOrange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3. Partner Core Operations Suite
                Text(
                  'PARTNER BROKERAGE SUITE',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                // 1. Onboard My Landlords (New Supercharged Link & Mandate Lock)
                _buildActionCard(
                  icon: Icons.link_rounded,
                  title: 'Onboard My Landlord (Auto-Lock Commissions) 🔗',
                  subtitle: 'Share your WhatsApp invite link. All client listings are auto-linked with guaranteed 2.5% rent / 2.0% sales payout.',
                  tag: 'MANDATE LOCK',
                  color: const Color(0xFF16A34A),
                  onTap: () {
                    if (_user != null) {
                      PartnerLandlordOnboardModal.show(context, user: _user!);
                    }
                  },
                ),

                // 2. List Property Under Mandate (Anti-Ghost Physical Presence)
                _buildActionCard(
                  icon: Icons.add_home_work_rounded,
                  title: 'Add Property Under Mandate (Anti-Ghost Shield)',
                  subtitle: 'In-property presence verification + signed owner Power of Attorney. ₦5,000 max inspection fee.',
                  tag: 'NEW LISTING',
                  color: AppColors.primary,
                  onTap: () {
                    if (_user != null) {
                      PartnerListingModal.show(context, user: _user!, onListingCreated: _loadPartnerData);
                    }
                  },
                ),

                // 3. Partner Accreditation Digital ID Card
                _buildActionCard(
                  icon: Icons.badge_rounded,
                  title: 'My Partner Accreditation ID Card 🪪',
                  subtitle: 'Digital Rentilly CAC accreditation credential & scannable QR verification for estate gates.',
                  tag: 'OFFICIAL ID',
                  color: const Color(0xFF0D9488),
                  onTap: () {
                    if (_user != null) {
                      PartnerIdCardModal.show(context, user: _user!);
                    }
                  },
                ),

                // 4. Field Inspection Bookings & Gate Passes
                _buildActionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Field Inspections & Estate Security Passes',
                  subtitle: 'Manage upcoming physical walkthroughs, generate 6-digit estate passes, and share safety itineraries.',
                  tag: 'ACTIVE',
                  color: const Color(0xFF0284C7),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InspectionsScreen()));
                  },
                ),
                const SizedBox(height: 22),

                // 4. Active Listings Under Mandate
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MANDATE INVENTORY (${_mandateProperties.length})',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PropertiesScreen()));
                      },
                      child: Text('View Public Feed', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_mandateProperties.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.apartment_rounded, size: 36, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        Text('No Active Mandate Listings', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          'Upload verified properties under owner mandate to start earning 2.5% rent and 2.0% sales commissions.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ..._mandateProperties.map((prop) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              prop.images.isNotEmpty ? prop.images[0] : 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(prop.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('${prop.neighborhood}, ${prop.state}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('₦${_currencyFormat.format(prop.basePrice)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '2.5% COMM LOCKED',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w800, color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
