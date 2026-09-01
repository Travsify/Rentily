import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../models/property.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/partner_bottom_bar.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/partner_listing_modal.dart';
import '../../widgets/partner_id_card_modal.dart';
import '../../widgets/partner_landlord_onboard_modal.dart';
import '../../widgets/quick_utilities_modal.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../properties/properties_screen.dart';
import '../inspections/inspections_screen.dart';
import 'partner_wallet_screen.dart';
import 'partner_profile_screen.dart';
import '../../services/notification_service.dart';
import '../shared/notification_center_screen.dart';
import '../shared/chat_inbox_screen.dart';

class PartnerDashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;

  const PartnerDashboardScreen({super.key, this.onSwitchToTenant});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _PartnerHubTab(onSwitchToTenant: widget.onSwitchToTenant),
      const PropertiesScreen(initialPurpose: 'all'),
      const PartnerWalletScreen(),
      const InspectionsScreen(),
      PartnerProfileScreen(onSwitchToTenant: widget.onSwitchToTenant),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: PartnerBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _PartnerHubTab extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;

  const _PartnerHubTab({this.onSwitchToTenant});

  @override
  State<_PartnerHubTab> createState() => _PartnerHubTabState();
}

class _PartnerHubTabState extends State<_PartnerHubTab> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  List<Property> _mandateProperties = [];
  bool _isLoading = true;

  final List<String> _partnerQuotes = const [
    '“The best time to buy a home is always five years ago.” — Ray Brown',
    '“In real estate, you make 10% of your money because you\'re a genius and 90% because you caught a great wave.” — Jeff Greene',
    '“Don\'t wait to buy real estate. Buy real estate and wait.” — Will Rogers',
  ];

  @override
  void initState() {
    super.initState();
    _loadPartnerData();
  }

  void _loadPartnerData() async {
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

    final isVerified = _user?.isVerified ?? false;
    final businessName = _user?.businessName ?? 'Apex Realty Partners Ltd';
    final cacNumber = _user?.cacNumber ?? 'RC 1928374';
    final accountNumber = _user?.accountNumber ?? '9834192847';
    final bankName = _user?.bankName ?? 'Flutterwave MFB';
    final partnerId = 'RNT-PTR-${_user?.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4) ?? "0042"}';
    final operationalBalance = _user?.walletBalance ?? 0.0;
    final escrowCommission = 0.00;

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
          // 1. Chat Icon with Messages Inbox
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textPrimary, size: 21),
            tooltip: 'Tenant & Buyer Messages',
            onPressed: () => ChatInboxScreen.show(context),
          ),
          // 2. Notification Bell with Unread Badge
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.unreadCountNotifier,
            builder: (context, count, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 23),
                    tooltip: 'In-App Activity Notifications',
                    onPressed: () => NotificationCenterScreen.show(context),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                        child: Center(
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
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
                // 1. Corporate Identity Hero Card with Dual Balance
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
                              color: isVerified ? const Color(0xFF22C55E).withValues(alpha: 0.2) : AppColors.accentOrange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isVerified ? const Color(0xFF4ADE80) : AppColors.accentOrange),
                            ),
                            child: Text(
                              isVerified ? 'CAC VERIFIED 🛡️' : 'TIER 1 (UNVERIFIED)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: isVerified ? const Color(0xFF4ADE80) : AppColors.accentOrange,
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
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rep: ${_user?.fullName ?? "Principal Broker"} • ${_user?.email ?? ""}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white60),
                      ),
                      const SizedBox(height: 18),

                      // Metrics Dual Balances
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('OPERATING FUNDS', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                                const SizedBox(height: 2),
                                Text('₦${_currencyFormat.format(operationalBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('COMMISSIONS IN ESCROW', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                                const SizedBox(height: 2),
                                Text('₦${_currencyFormat.format(escrowCommission)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Real Estate Quote Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _partnerQuotes[DateTime.now().second % _partnerQuotes.length],
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF78350F), fontStyle: FontStyle.italic, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Dedicated Settlement Bank Account Card (Strict KYC Gated)
                if (!isVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.shield_outlined, size: 20, color: AppColors.accentOrange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Activate Commissions Account', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Complete CAC & BVN check to unlock your automated commission account.', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            VerificationModal.show(context, onSuccess: (updated) {
                              setState(() => _user = updated);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Verify 🛡️', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
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
                            Text('COMMISSIONS SETTLEMENT BANK ACCOUNT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                              child: Text('AUTOMATED SETTLEMENT', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_user != null) AddMoneyModal.show(context, user: _user!);
                                },
                                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                label: Text('Fund Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                // 4. Partner Brokerage Suite Grid Layout
                Text(
                  'PARTNER BROKERAGE SUITE (GRID)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _buildGridCard(
                      icon: Icons.link_rounded,
                      title: 'Onboard Landlord',
                      subtitle: 'Auto-Lock Commissions 🔗',
                      badge: 'MANDATE',
                      color: const Color(0xFF16A34A),
                      onTap: () {
                        if (_user != null) {
                          PartnerLandlordOnboardModal.show(context, user: _user!);
                        }
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.add_home_work_rounded,
                      title: 'Add Mandate Listing',
                      subtitle: 'Anti-Ghost Physical Proof',
                      badge: 'NEW',
                      color: AppColors.primary,
                      onTap: () {
                        if (_user != null) {
                          PartnerListingModal.show(context, user: _user!, onListingCreated: _loadPartnerData);
                        }
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.badge_rounded,
                      title: 'Partner Digital ID',
                      subtitle: 'CAC Accredited Credential',
                      badge: 'OFFICIAL',
                      color: const Color(0xFF0D9488),
                      onTap: () {
                        if (_user != null) {
                          PartnerIdCardModal.show(context, user: _user!);
                        }
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Field Inspections',
                      subtitle: '6-Digit Gate Passes',
                      badge: 'ACTIVE',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InspectionsScreen()));
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.wifi_rounded,
                      title: 'Field Utilities',
                      subtitle: '4K Data, Airtime & Power',
                      badge: 'TOP-UP',
                      color: AppColors.accentOrange,
                      onTap: () => QuickUtilitiesModal.show(context),
                    ),
                    _buildGridCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Commissions Vault',
                      subtitle: '2.5% Rent / 2.0% Sale',
                      badge: 'ESCROW',
                      color: const Color(0xFF7C3AED),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerWalletScreen()));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 5. Mandate Inventory List
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

  Widget _buildGridCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge, style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w900, color: color)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 1),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
