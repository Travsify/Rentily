import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../wallet/wallet_screen.dart';
import '../my_spaces/my_spaces_screen.dart';
import '../bills/bills_screen.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../roommates/roommates_screen.dart';
import '../cards/cards_screen.dart';
import '../main_navigation_screen.dart';
import '../../services/notification_service.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/biometric_prompt_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../../widgets/daily_quotes_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  bool _hideBalance = false;
  UserProfile? _user;
  bool _isLoadingUser = true;

  String _userLocation = 'Lagos State';
  final List<String> _locations = [
    'Lagos State',
    'Abuja (FCT)',
    'Rivers (Port Harcourt)',
    'Oyo (Ibadan)',
    'Enugu State',
    'Delta (Asaba / Warri)',
    'Edo (Benin City)',
    'Kano State',
    'Ogun (Abeokuta)',
    'Kaduna State',
  ];

  final PageController _bannerController = PageController();
  int _currentBanner = 0;

  final List<Map<String, dynamic>> _heroBanners = [
    {
      'tag': 'ANTI-AGENT PLATFORM',
      'title': 'Zero 20% Agent Fees Guaranteed',
      'description': 'Direct connection to verified property landlords. Legal escrow protection guaranteed.',
      'icon': Icons.shield_rounded,
      'color': AppColors.primary,
    },
    {
      'tag': 'LIVING VAULTS',
      'title': 'Earn 11.5% Yield on Your Rent Savings',
      'description': 'Save automatically towards your next annual rent renewal with inflation hedge.',
      'icon': Icons.trending_up_rounded,
      'color': AppColors.accentOrange,
    },
    {
      'tag': 'DISCO AUTOPILOT',
      'title': 'Instant Electricity Tokens 24/7',
      'description': 'Direct prepaid token generation across all 11 Nigerian electricity Discos.',
      'icon': Icons.bolt_rounded,
      'color': AppColors.primaryLight,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
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
        if (_user?.state != null && _user!.state!.isNotEmpty) {
          _userLocation = '${_user!.state}, Nigeria';
        }
      });
    }
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  void _loadUser() async {
    final u = await AuthService.getCurrentUser();
    await NotificationService.getNotifications();
    if (mounted) {
      setState(() {
        _user = u;
        _isLoadingUser = false;
        if (u?.state != null && u!.state!.isNotEmpty) {
          _userLocation = '${u.state}, Nigeria';
        }
      });
      if (u?.isVerified == true) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) BiometricPromptModal.checkAndPrompt(context);
        });
      }
    }
  }

  void _copyAccount() {
    if (_user != null) {
      AddMoneyModal.show(
        context,
        user: _user!,
        onAccountUpdated: (u) => setState(() => _user = u),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Real first name greeting (e.g. "Patrick" or "Femi")
    final String firstName = _user?.firstName ?? 'User';
    final double balance = _user?.walletBalance ?? 0.00;
    final String? accNum = _user?.accountNumber;
    final String bank = _user?.bankName ?? 'Flutterwave MFB';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar: Greeting & Action Icons (Pure Real Name & Guaranteed Visible Actions)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Side: Greeting, Name, Location & Verification Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Greeting & Name (Single Row, Ellipsis-protected)
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$_timeGreeting, $firstName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('👋', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Subtitle Row: Geolocation & Verification Status Pill
                        Row(
                          children: [
                            // Geolocation Dropdown Pill
                            GestureDetector(
                              onTap: _showLocationPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 11, color: AppColors.accentOrange),
                                    const SizedBox(width: 3),
                                    Text(
                                      _userLocation,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Verification Badge Pill
                            GestureDetector(
                              onTap: () {
                                if (_user?.isVerified == true && _user?.accountNumber != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Your dedicated Living Escrow bank account is active and verified.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                } else {
                                  VerificationModal.show(context, onSuccess: (updated) {
                                    setState(() => _user = updated);
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: _user?.isVerified == true
                                      ? AppColors.primaryLight.withValues(alpha: 0.12)
                                      : AppColors.accentOrange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _user?.isVerified == true
                                        ? AppColors.primaryLight.withValues(alpha: 0.4)
                                        : AppColors.accentOrange.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _user?.isVerified == true ? Icons.verified : Icons.shield_outlined,
                                      size: 10,
                                      color: _user?.isVerified == true ? AppColors.primaryLight : AppColors.accentOrange,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _user?.isVerified == true ? 'VERIFIED' : 'UNVERIFIED',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: _user?.isVerified == true ? AppColors.primary : AppColors.accentOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Right Side: Action Icons (Messages & Notification Bell - Guaranteed Visible)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chat / Messages Button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MessagesScreen()),
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderDark),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.chat_bubble_outline_rounded, size: 17, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Notification Bell Button with Indicator
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderDark),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.notifications_none_rounded, size: 18, color: AppColors.textPrimary),
                              ValueListenableBuilder<int>(
                                valueListenable: NotificationService.unreadCountNotifier,
                                builder: (context, count, _) {
                                  if (count <= 0) return const SizedBox.shrink();
                                  return Positioned(
                                    top: 7,
                                    right: 7,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentOrange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. The Living Wallet Card (Deep Emerald Teal with Amber Highlights)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0D5C46),
                        Color(0xFF07382B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'RENTILLY LIVING ESCROW',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              accNum != null ? bank.toUpperCase() : 'PENDING ACTIVATION',
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

                      // Balance Section (Real Data Only)
                      Text(
                        'TOTAL AVAILABLE BALANCE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.9,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            _hideBalance ? '₦ • • • • • •' : '₦${_currencyFormat.format(balance)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _hideBalance = !_hideBalance),
                            child: Icon(
                              _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Virtual Account Number (Real Data Only - Never Spills)
                      if (accNum != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'DEDICATED ACCOUNT NUMBER',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$accNum • $bank',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _copyAccount,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Copy',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            VerificationModal.show(context, onSuccess: (updated) {
                              setState(() => _user = updated);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'VIRTUAL ACCOUNT',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Pending Verification',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Activate',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 3 Quick Action Buttons on Card
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCardQuickAction(Icons.add_rounded, 'Add Money', _copyAccount),
                          _buildCardQuickAction(Icons.north_east_rounded, 'Transfer', () {
                            if (_user == null || !_user!.isVerified) {
                              VerificationModal.show(context, onSuccess: (updated) {
                                setState(() => _user = updated);
                              });
                              return;
                            }
                            WithdrawalModal.show(
                              context,
                              user: _user!,
                              onWithdrawalSuccess: (newBal) {
                                setState(() => _user = _user!.copyWith(walletBalance: newBal));
                              },
                            );
                          }),
                          _buildCardQuickAction(Icons.savings_rounded, 'Living Vault', () {
                            MainNavigationScreen.of(context)?.switchTab(3);
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 3. Circular Grid-Based Quick Hub (The 4 Core Action Pods)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CORE SERVICES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Zero Middlemen',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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
                  // Pod 1: Properties -> Switches directly to Tab 1 (Bottom Nav persists!)
                  _buildCircularGridPod(
                    title: 'Properties',
                    subtitle: 'Rent & Buy Direct',
                    icon: Icons.apartment_rounded,
                    color: AppColors.primary,
                    badge: 'Zero 20% Fee',
                    onTap: () {
                      MainNavigationScreen.of(context)?.switchTab(1);
                    },
                  ),

                  // Pod 2: My Spaces
                  _buildCircularGridPod(
                    title: 'My Spaces',
                    subtitle: 'Active Lease & Deeds',
                    icon: Icons.vpn_key_rounded,
                    color: AppColors.accentOrange,
                    badge: 'Real Escrow',
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
                    color: const Color(0xFF0284C7),
                    badge: 'Instant Token',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BillsScreen()),
                      );
                    },
                  ),

                  // Pod 4: Living Vaults -> Switches directly to Tab 3 (Bottom Nav persists!)
                  _buildCircularGridPod(
                    title: 'Living Vaults',
                    subtitle: 'Target Savings',
                    icon: Icons.savings_rounded,
                    color: AppColors.primaryLight,
                    badge: '11.5% Yield',
                    onTap: () {
                      MainNavigationScreen.of(context)?.switchTab(3);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dollar Cards Desk - Full Width Quick Action
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CardsScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Virtual Dollar Card',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'USD Visa • Shop globally, subscribe & pay online',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Daily Motivational Quotes Carousel (Life, Habits, Marriage, Finance - 15s Auto-refresh)
              const DailyQuotesCard(),
              const SizedBox(height: 20),

              // Split-the-Scroll Co-Living & Roommate Finder Hero Card
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoommatesScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF064E3B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'SPLIT-THE-SCROLL 👥',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '2 - 3 PERSONS (50% / 33%)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Find a Roommate & Split Rent',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Verified flatmates splitting luxury 2-bed and 3-bed apartments in Lekki, Yaba, Ikeja & Abuja.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Explore Split-the-Scroll',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentOrange,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.accentOrange),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Center(
                          child: Icon(Icons.people_alt_rounded, size: 26, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 4. Quick Action Utilities Hub (Flutterwave Bills Suite)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 16, color: AppColors.accentOrange),
                      const SizedBox(width: 4),
                      Text(
                        'QUICK UTILITY ACTIONS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Instant Delivery',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4x2 Grid of Circular Bill Payment Pods
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
                children: [
                  _buildQuickUtilityIcon('Electricity', Icons.bolt_rounded, AppColors.accentOrange, () => _openBills('electricity')),
                  _buildQuickUtilityIcon('Data Bundle', Icons.wifi_rounded, const Color(0xFF0284C7), () => _openBills('data')),
                  _buildQuickUtilityIcon('Airtime VTU', Icons.phone_android_rounded, AppColors.primary, () => _openBills('airtime')),
                  _buildQuickUtilityIcon('Cable TV', Icons.tv_rounded, const Color(0xFF7C3AED), () => _openBills('cable')),
                  _buildQuickUtilityIcon('Water Bill', Icons.water_drop_rounded, const Color(0xFF0D9488), () => _openBills('water')),
                  _buildQuickUtilityIcon('Broadband', Icons.router_rounded, const Color(0xFFD97706), () => _openBills('internet')),
                  _buildQuickUtilityIcon('Tolls/Transit', Icons.directions_car_rounded, const Color(0xFF4F46E5), () => _openBills('toll')),
                  _buildQuickUtilityIcon('Waste Mgmt', Icons.delete_outline_rounded, AppColors.primaryLight, () => _openBills('waste')),
                ],
              ),
              const SizedBox(height: 22),

              // 5. Slidable Hero Banner Carousel
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderDark),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(b['icon'] as IconData, size: 22, color: color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  b['tag'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b['title'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
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
                    width: _currentBanner == i ? 16 : 6,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _currentBanner == i ? AppColors.primary : AppColors.borderDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5. Verification Notice
              GestureDetector(
                onTap: () {
                  if (_user?.isVerified != true) {
                    VerificationModal.show(context, onSuccess: (updated) {
                      setState(() => _user = updated);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_user_rounded, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?.isVerified == true ? 'Tier-3 Identity & Bank Verification' : 'Tier 1 Account (Unverified)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _user?.isVerified == true
                                  ? 'Full banking and direct lease execution enabled.'
                                  : 'Tap to complete NIN / BVN check & unlock bank account.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
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
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: Colors.white),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(icon, size: 20, color: color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
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
      backgroundColor: Colors.white,
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
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                        color: isSelected ? AppColors.accentOrange : AppColors.textMuted,
                      ),
                      title: Text(
                        loc,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, size: 16, color: AppColors.primary) : null,
                      onTap: () {
                        setState(() => _userLocation = loc);
                        if (_user != null) {
                          final stateOnly = loc.split(',')[0].trim();
                          final updated = _user!.copyWith(state: stateOnly);
                          AuthService.updateUser(updated);
                        }
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

  void _openBills(String category) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: category)),
    );
  }

  Widget _buildQuickUtilityIcon(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

