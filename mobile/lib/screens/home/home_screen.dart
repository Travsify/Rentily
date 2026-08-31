import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../wallet/wallet_screen.dart';
import '../properties/properties_screen.dart';
import '../my_spaces/my_spaces_screen.dart';
import '../bills/bills_screen.dart';
import '../vaults/vaults_screen.dart';
import '../messages/messages_screen.dart';
import '../inspections/inspections_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  bool _hideBalance = false;
  final double _balance = 2450000.00;
  final String _accountNumber = '9948291038';
  final String _bankName = 'Wema Bank';

  String _userLocation = 'Lekki Phase 1, Lagos';
  final List<String> _locations = [
    'Lekki Phase 1, Lagos',
    'Old Ikoyi, Lagos',
    'Victoria Island, Lagos',
    'Ikeja GRA, Lagos',
    'Maitama, Abuja (FCT)',
    'Wuse 2, Abuja (FCT)',
    'Port Harcourt, Rivers',
    'Ibadan, Oyo',
    'Enugu State',
    'Asaba, Delta',
    'Benin City, Edo',
    'Kano State',
  ];

  final PageController _bannerController = PageController();
  int _currentBanner = 0;

  final List<Map<String, dynamic>> _heroBanners = [
    {
      'tag': 'ANTI-AGENT DISRUPTION',
      'title': 'Zero 20% Agent Fees Guaranteed',
      'description': 'Connect directly with verified property owners. Save an average of ₦850,000 on your next home.',
      'icon': Icons.shield_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'tag': 'LIVING VAULTS',
      'title': 'Earn 11.5% Yield on Your Rent Savings',
      'description': 'Set aside 10% on every payment towards your next annual rent renewal with inflation protection.',
      'icon': Icons.trending_up_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'tag': 'DISCO AUTOPILOT',
      'title': 'Never Sit in Darkness Again',
      'description': 'Automated electricity token top-ups for EKEDC, IKEDC, AEDC, IBEDC, and PHED meters.',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFF3B82F6),
    },
  ];

  void _copyAccount() {
    Clipboard.setData(ClipboardData(text: _accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Account Number Copied! Send funds from any Nigerian banking app.',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar: Greeting & Action Icons (Clean & Uncluttered)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Greeting & Location
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Good day, Femi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('👋', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _showLocationPicker,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primaryLight),
                            const SizedBox(width: 3),
                            Text(
                              _userLocation,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Action Icons (Messages & Notification Bell)
                  Row(
                    children: [
                      // Chat Icon with unread badge
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MessagesScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Notification Bell
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. The Living Wallet Card (Before the Grid)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F382A),
                        Color(0xFF061E16),
                        Color(0xFF090E17),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Brand & Wema Bank Tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_rounded, size: 16, color: AppColors.primaryLight),
                              const SizedBox(width: 5),
                              Text(
                                'RENTILLY ESCROW WALLET',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _bankName.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Balance Section
                      Text(
                        'AVAILABLE BALANCE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.9,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            _hideBalance ? '₦ • • • • • •' : '₦${_currencyFormat.format(_balance)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _hideBalance = !_hideBalance),
                            child: Icon(
                              _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Virtual Account Number Pill with 1-Tap Copy
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'NUBAN: $_accountNumber • $_bankName',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: _copyAccount,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Copy',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3 Quick Action Buttons on the Card
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCardQuickAction(Icons.add_rounded, 'Add Money', _copyAccount),
                          _buildCardQuickAction(Icons.north_east_rounded, 'Transfer', () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
                          }),
                          _buildCardQuickAction(Icons.savings_rounded, 'Living Vault', () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaultsScreen()));
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 3. Circular Grid-Based Quick Hub (The Core 4 Action Pods)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CORE SERVICES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    'Direct & Scam-Free',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2x2 Grid with Circular Pods
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  // Pod 1: Properties
                  _buildCircularGridPod(
                    title: 'Properties',
                    subtitle: 'Rent & Buy Direct',
                    icon: Icons.apartment_rounded,
                    color: const Color(0xFF10B981),
                    badge: 'Zero 20% Fee',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PropertiesScreen(initialPurpose: 'rent')),
                      );
                    },
                  ),

                  // Pod 2: My Spaces
                  _buildCircularGridPod(
                    title: 'My Spaces',
                    subtitle: 'Active Lease & Deeds',
                    icon: Icons.vpn_key_rounded,
                    color: const Color(0xFFF59E0B),
                    badge: '1 Leased',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MySpacesScreen()),
                      );
                    },
                  ),

                  // Pod 3: Bill Payments
                  _buildCircularGridPod(
                    title: 'Bill Payments',
                    subtitle: 'Disco, Data, Airtime',
                    icon: Icons.electric_meter_rounded,
                    color: const Color(0xFF3B82F6),
                    badge: 'Instant Token',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BillsScreen()),
                      );
                    },
                  ),

                  // Pod 4: Rent Savings
                  _buildCircularGridPod(
                    title: 'Living Vaults',
                    subtitle: 'Save for Rent & Power',
                    icon: Icons.savings_rounded,
                    color: const Color(0xFF8B5CF6),
                    badge: '11.5% Yield',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VaultsScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 4. Slidable Hero Banner Carousel
              SizedBox(
                height: 120,
                child: PageView.builder(
                  controller: _bannerController,
                  onPageChanged: (idx) => setState(() => _currentBanner = idx),
                  itemCount: _heroBanners.length,
                  itemBuilder: (context, index) {
                    final b = _heroBanners[index];
                    final Color color = b['color'] as Color;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.16),
                            AppColors.surfaceDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(b['icon'] as IconData, size: 20, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  b['tag'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b['title'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Banner Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _heroBanners.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentBanner == i ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _currentBanner == i ? AppColors.primaryLight : AppColors.borderDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5. Active Inspection Gate Pass Quick Access
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InspectionsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.security_rounded, size: 16, color: AppColors.primaryLight),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Physical Inspection Gate Pass Ready',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Plot 18, Lekki Phase 1 • Gate Pass: 749201',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: AppColors.primaryLight),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularGridPod({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Circular Orb Icon & Micro-Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.16),
                    border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(icon, size: 20, color: color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Your State / Region',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final loc = _locations[index];
                    final isSelected = loc == _userLocation;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                      ),
                      title: Text(
                        loc,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primaryLight : Colors.white,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, size: 16, color: AppColors.primaryLight) : null,
                      onTap: () {
                        setState(() => _userLocation = loc);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
