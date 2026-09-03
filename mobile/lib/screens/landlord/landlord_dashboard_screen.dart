import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../models/property.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/landlord_bottom_bar.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/partner_listing_modal.dart';
import '../../widgets/partner_id_card_modal.dart';
import '../../widgets/quick_utilities_modal.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../properties/properties_screen.dart';
import '../inspections/inspections_screen.dart';
import 'landlord_wallet_screen.dart';
import 'landlord_profile_screen.dart';
import 'landlord_digital_leases_screen.dart';
import '../cards/cards_screen.dart';
import '../../utils/id_utils.dart';
import '../../services/notification_service.dart';
import '../shared/notification_center_screen.dart';
import '../shared/chat_inbox_screen.dart';
import '../../widgets/biometric_prompt_modal.dart';

class LandlordDashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;

  const LandlordDashboardScreen({super.key, this.onSwitchToTenant});

  @override
  State<LandlordDashboardScreen> createState() => _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen> {
  int _currentIndex = 0;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _LandlordPortfolioTab(
        onSwitchToTenant: widget.onSwitchToTenant,
        onNavigateToTab: (index) => setState(() => _currentIndex = index),
      ),
      const PropertiesScreen(initialPurpose: 'all'),
      const LandlordWalletScreen(),
      const InspectionsScreen(),
      LandlordProfileScreen(onSwitchToTenant: widget.onSwitchToTenant),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: LandlordBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _LandlordPortfolioTab extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;
  final ValueChanged<int>? onNavigateToTab;

  const _LandlordPortfolioTab({this.onSwitchToTenant, this.onNavigateToTab});

  @override
  State<_LandlordPortfolioTab> createState() => _LandlordPortfolioTabState();
}

class _LandlordPortfolioTabState extends State<_LandlordPortfolioTab> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  List<Property> _properties = [];
  bool _isLoading = true;

  final List<String> _landlordQuotes = const [
    '“Ninety percent of all millionaires become so through owning real estate.” — Andrew Carnegie',
    '“Real estate cannot be lost or stolen, nor can it be carried away. Managed with reasonable care, it is about the safest investment in the world.” — Franklin D. Roosevelt',
    '“Landlords grow rich in their sleep without working, risking, or economizing.” — John Stuart Mill',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    AuthService.currentUserNotifier.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) {
      setState(() {
        _user = AuthService.currentUserNotifier.value;
      });
    }
  }

  void _loadData() async {
    final user = await AuthService.getCurrentUser();
    final allProps = await ApiService.fetchProperties();
    try {
      await ApiService.fetchFeatureFlags();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _user = user;
        _properties = allProps;
        _isLoading = false;
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) BiometricPromptModal.checkAndPrompt(context);
      });
    }
  }

  void _copyAccount(String accountNumber) {
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
    final name = _user?.fullName ?? 'Property Owner';
    final landlordId = IdUtils.formatOpsId(_user?.id, isPartner: false);
    final operationalBalance = _user?.walletBalance ?? 0.0;
    final escrowBalance = 0.00;
    final accountNumber = _user?.accountNumber ?? (_user?.isVerified == true ? 'Pending 9PSB NUBAN' : 'Pending Verification');
    final bankName = _user?.bankName ?? '9PSB (Rentilly)';

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
                'LANDLORD ASSET PORTAL 🔑',
                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.primary),
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
          onRefresh: () async => _loadData(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Direct Property Owner Card (Styled in Rentilly Brand Green with Tap-to-Wallet)
                GestureDetector(
                  onTap: () {
                    if (widget.onNavigateToTab != null) {
                      widget.onNavigateToTab!(2);
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LandlordWalletScreen()));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF042F2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3), width: 1.2),
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
                                const Icon(Icons.real_estate_agent_rounded, size: 18, color: Color(0xFF4ADE80)),
                                const SizedBox(width: 6),
                                Text(
                                  'DIRECT PROPERTY OWNER',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: const Color(0xFF4ADE80),
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
                                isVerified ? 'TITLE VERIFIED 🔑' : 'TIER 1 (UNVERIFIED)',
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
                          name,
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Landlord ID: $landlordId • ${_user?.email ?? ""}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFFFBBF24), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 18),

                        // Metrics Dual Balances (Tappable to Wallet)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
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
                              Container(width: 1, height: 32, color: Colors.white24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ACTIVE ESCROW FUNDS', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                                    const SizedBox(height: 2),
                                    Text('₦${_currencyFormat.format(escrowBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24))),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white70),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                          _landlordQuotes[DateTime.now().second % _landlordQuotes.length],
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
                              Text('Activate Settlement Account', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Complete BVN/NIN check to unlock your dedicated escrow account.', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
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
                          child: Text('Verify 🔑', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
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
                            Text('SETTLEMENT BANK ACCOUNT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                              child: Text('DIRECT ESCROW PAYOUT', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
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
                                Text('$bankName • $name / Rentilly', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                              onPressed: () => _copyAccount(accountNumber),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_user != null) {
                                    AddMoneyModal.show(context, user: _user!, onAccountUpdated: (u) {
                                      setState(() => _user = u);
                                    });
                                  }
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
                                label: Text('Withdraw', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
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

                // 4. Landlord Asset Suite Grid Layout
                Text(
                  'LANDLORD ASSET SUITE (GRID)',
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
                      icon: Icons.add_home_work_rounded,
                      title: 'List Property',
                      subtitle: 'Direct Owner • ₦0 Agent',
                      badge: 'NEW',
                      color: AppColors.primary,
                      onTap: () {
                        if (_user != null) {
                          PartnerListingModal.show(context, user: _user!, onListingCreated: _loadData);
                        }
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.badge_rounded,
                      title: 'My Landlord ID',
                      subtitle: 'Title Audited PDF Credential',
                      badge: 'OFFICIAL',
                      color: const Color(0xFF0D9488),
                      onTap: () {
                        if (_user != null) {
                          PartnerIdCardModal.show(context, user: _user!);
                        }
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.history_edu_rounded,
                      title: 'Digital Leases',
                      subtitle: 'Tenancy Law Agreements',
                      badge: 'LEGAL',
                      color: const Color(0xFF7C3AED),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LandlordDigitalLeasesScreen()));
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.receipt_long_rounded,
                      title: 'Bill Payment',
                      subtitle: 'Utilities & Units',
                      badge: 'INSTANT',
                      color: AppColors.accentOrange,
                      onTap: () => QuickUtilitiesModal.show(context),
                    ),
                    _buildGridCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Gate Passes',
                      subtitle: 'Walkthrough Approvals',
                      badge: 'ACTIVE',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        if (widget.onNavigateToTab != null) {
                          widget.onNavigateToTab!(3);
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InspectionsScreen()));
                        }
                      },
                    ),
                    _buildGridCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Escrow Vault',
                      subtitle: 'Settlements & Payouts',
                      badge: 'SECURE',
                      color: const Color(0xFF16A34A),
                      onTap: () {
                        if (widget.onNavigateToTab != null) {
                          widget.onNavigateToTab!(2);
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LandlordWalletScreen()));
                        }
                      },
                    ),
                    if (ApiService.featureFlags.enableVirtualCards)
                      _buildGridCard(
                        icon: Icons.credit_card_rounded,
                        title: 'Dollar Cards Desk',
                        subtitle: 'Virtual USD Visa',
                        badge: 'GLOBAL',
                        color: const Color(0xFF0284C7),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardsScreen()));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // 5. Portfolio Inventory List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PORTFOLIO INVENTORY (${_properties.length})',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        if (widget.onNavigateToTab != null) {
                          widget.onNavigateToTab!(1);
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PropertiesScreen()));
                        }
                      },
                      child: Text('View Public Feed', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                ..._properties.take(3).map((prop) {
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
                                      'ACTIVE UNIT',
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
