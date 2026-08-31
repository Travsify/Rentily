import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/withdrawal_modal.dart';
import '../bills/bills_screen.dart';
import '../home/property_detail_screen.dart';
import '../vaults/vaults_screen.dart';
import '../wallet/wallet_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Property> _results = [];
  bool _isLoading = false;
  UserProfile? _currentUser;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  final List<String> _quickFilters = [
    'All Properties',
    '⚡ Light Bill',
    '📺 DStv / GOtv',
    '🎯 Living Vaults',
    '💸 Transfer Money',
    '📶 Data & Wifi',
    'Lekki Phase 1',
    'Maitama',
    'Ikoyi',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _performSearch('');
  }

  void _loadUser() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) setState(() => _currentUser = u);
  }

  void _performSearch(String query) async {
    setState(() => _isLoading = true);
    final props = await ApiService.asyncFetchProperties(search: query);
    if (mounted) {
      setState(() {
        _results = props;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMatchingQuickActions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final actions = <Map<String, dynamic>>[];

    if (q.contains('transfer') || q.contains('send') || q.contains('withdraw') || q.contains('wallet') || q.contains('payout') || q.contains('bank')) {
      actions.add({
        'title': 'Instant Transfer & Bank Payout',
        'subtitle': 'Transfer funds to GTBank, Zenith, Access, Kuda, PalmPay & OPay',
        'icon': Icons.account_balance_rounded,
        'color': AppColors.primary,
        'onTap': () {
          if (_currentUser != null) {
            WithdrawalModal.show(context, user: _currentUser!, onWithdrawalSuccess: (b) {});
          } else {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
          }
        }
      });
    }

    if (q.contains('vault') || q.contains('save') || q.contains('stash') || q.contains('yield') || q.contains('target')) {
      actions.add({
        'title': 'Living Vaults (Target Savings)',
        'subtitle': 'Lock funds aside with up to 11.5% annual yield for rent or bills',
        'icon': Icons.savings_rounded,
        'color': AppColors.accentOrange,
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaultsScreen())),
      });
    }

    if (q.contains('light') || q.contains('electric') || q.contains('nepa') || q.contains('token') || q.contains('ekedc') || q.contains('ikedc') || q.contains('aedc') || q.contains('ibedc') || q.contains('power')) {
      actions.add({
        'title': 'Buy Prepaid Electricity (STS Token)',
        'subtitle': 'EKEDC, IKEDC, AEDC, IBEDC, PHED, EEDC instant meter recharge',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFD97706),
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'electricity'))),
      });
    }

    if (q.contains('dstv') || q.contains('gotv') || q.contains('startimes') || q.contains('showmax') || q.contains('cable') || q.contains('tv')) {
      actions.add({
        'title': 'Renew Cable TV Subscription',
        'subtitle': 'Instant reconnection for DStv, GOtv, StarTimes & Showmax decoders',
        'icon': Icons.tv_rounded,
        'color': const Color(0xFF2563EB),
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'cable'))),
      });
    }

    if (q.contains('data') || q.contains('bundle') || q.contains('gig') || q.contains('internet') || q.contains('wifi') || q.contains('spectranet') || q.contains('smile') || q.contains('fiberone')) {
      actions.add({
        'title': 'Buy Mobile Data / Broadband Internet',
        'subtitle': 'MTN, Airtel, Glo, 9mobile, Spectranet, Smile & FiberOne',
        'icon': Icons.wifi_rounded,
        'color': const Color(0xFF0D9488),
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'data'))),
      });
    }

    if (q.contains('airtime') || q.contains('recharge') || q.contains('vtu') || q.contains('credit')) {
      actions.add({
        'title': 'Instant Airtime Recharge (+2% Cashback)',
        'subtitle': 'Automated VTU top-up for all Nigerian network operators',
        'icon': Icons.phone_android_rounded,
        'color': const Color(0xFF16A34A),
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'airtime'))),
      });
    }

    if (q.contains('toll') || q.contains('lcc') || q.contains('lekki toll') || q.contains('cowry')) {
      actions.add({
        'title': 'Estate Tolls & Cowry Transit Card',
        'subtitle': 'LCC Lekki Toll Gate, Lekki-Ikoyi Link Bridge & Cowry Transit',
        'icon': Icons.toll_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'tolls'))),
      });
    }

    if (q.contains('water') || q.contains('lwc')) {
      actions.add({
        'title': 'Water Utility Settlement',
        'subtitle': 'Lagos Water Corporation (LWC) & FCT Water Board',
        'icon': Icons.water_drop_rounded,
        'color': const Color(0xFF0284C7),
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'water'))),
      });
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final matchedActions = _getMatchingQuickActions(_searchController.text);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Universal Smart Search',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search properties, transfer money, living vaults, or pay utility bills.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    setState(() {});
                    _performSearch(v);
                  },
                  onSubmitted: _performSearch,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                    hintText: 'Try "Transfer", "DStv", "Light bill", "Vault", or "Lekki"...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                    border: InputBorder.none,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _performSearch('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Filter Chips
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickFilters.length,
                  itemBuilder: (context, index) {
                    final f = _quickFilters[index];
                    return GestureDetector(
                      onTap: () {
                        if (f == '⚡ Light Bill') {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'electricity')));
                        } else if (f == '📺 DStv / GOtv') {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'cable')));
                        } else if (f == '🎯 Living Vaults') {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaultsScreen()));
                        } else if (f == '💸 Transfer Money') {
                          if (_currentUser != null) {
                            WithdrawalModal.show(context, user: _currentUser!, onWithdrawalSuccess: (b) {});
                          } else {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
                          }
                        } else if (f == '📶 Data & Wifi') {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'data')));
                        } else if (f == 'All Properties') {
                          _searchController.clear();
                          _performSearch('');
                        } else {
                          _searchController.text = f;
                          _performSearch(f);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Text(
                          f,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Matched Quick Actions (Bills, Transfers, Vaults)
              if (matchedActions.isNotEmpty) ...[
                Text(
                  'QUICK ACTIONS & SERVICES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...matchedActions.map((act) {
                  final Color c = act['color'] as Color;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: act['onTap'] as VoidCallback,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                              child: Icon(act['icon'] as IconData, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    act['title'] as String,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    act['subtitle'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],

              // Results Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_results.length} Verified Properties Found',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Results List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 36, color: AppColors.textMuted),
                                const SizedBox(height: 10),
                                Text(
                                  'No matching properties found',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try searching for another neighborhood, utility bill, or action.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final prop = _results[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.borderDark),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          prop.images.isNotEmpty ? prop.images[0] : '',
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prop.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${prop.neighborhood}, ${prop.state}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '₦${_currencyFormat.format(prop.basePrice)}',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                Text(
                                                  '${prop.bedrooms} Bed • ${prop.bathrooms} Bath',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondary,
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
