import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/partner_listing_modal.dart';
import '../home/property_detail_screen.dart';

class LandlordPropertiesScreen extends StatefulWidget {
  const LandlordPropertiesScreen({super.key});

  @override
  State<LandlordPropertiesScreen> createState() => _LandlordPropertiesScreenState();
}

class _LandlordPropertiesScreenState extends State<LandlordPropertiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');

  UserProfile? _user;
  List<Property> _myProperties = [];
  List<Property> _publicProperties = [];
  bool _isLoadingMy = true;
  bool _isLoadingPublic = true;

  // Filters for public marketplace
  String _selectedPublicPurpose = 'all';
  String _selectedPublicState = 'All Nigeria';

  static const List<String> _popularStates = [
    'All Nigeria',
    'Lagos',
    'Abuja (FCT)',
    'Rivers (Port Harcourt)',
    'Oyo (Ibadan)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) setState(() => _user = user);
    await Future.wait([
      _loadMyProperties(user),
      _loadPublicProperties(),
    ]);
  }

  Future<void> _loadMyProperties(UserProfile? user) async {
    if (user == null) {
      if (mounted) setState(() => _isLoadingMy = false);
      return;
    }
    setState(() => _isLoadingMy = true);
    final props = await ApiService.fetchProperties(ownerId: user.id);
    if (mounted) {
      setState(() {
        _myProperties = props;
        _isLoadingMy = false;
      });
    }
  }

  Future<void> _loadPublicProperties() async {
    setState(() => _isLoadingPublic = true);
    final stateQuery = _selectedPublicState == 'All Nigeria' ? null : _selectedPublicState.split(' ').first;
    final props = await ApiService.fetchProperties(
      purpose: _selectedPublicPurpose == 'all' ? null : _selectedPublicPurpose,
      search: stateQuery,
    );
    if (mounted) {
      setState(() {
        // Only show active / verified units in public marketplace
        _publicProperties = props.where((p) => p.status != 'unlisted').toList();
        _isLoadingPublic = false;
      });
    }
  }

  void _openAddListing() {
    if (_user == null) return;
    PartnerListingModal.show(
      context,
      user: _user!,
      onListingCreated: () => _loadMyProperties(_user),
    );
  }

  Future<void> _toggleAvailability(Property prop) async {
    final newStatus = prop.status == 'unlisted' ? 'verified' : 'unlisted';
    final ok = await ApiService.updatePropertyStatus(
      propertyId: prop.id,
      status: newStatus,
    );
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'unlisted'
                ? 'Unit "${prop.title}" unlisted from public market.'
                : 'Unit "${prop.title}" relisted as active! 🚀',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: newStatus == 'unlisted' ? Colors.black87 : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadMyProperties(_user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Properties & Public Market',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_work_rounded, color: AppColors.primary, size: 22),
            tooltip: 'List New Unit',
            onPressed: _openAddListing,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'My Units & Leases (${_myProperties.length})'),
            const Tab(text: 'Public Marketplace 🌐'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMyUnitsTab(),
            _buildPublicMarketplaceTab(),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: My Units ────────────────────────────────────────────────────────
  Widget _buildMyUnitsTab() {
    if (_isLoadingMy) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadMyProperties(_user),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL UNITS MANAGED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4ADE80),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_myProperties.length} Properties',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openAddListing,
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'List Unit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_myProperties.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.real_estate_agent_rounded, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Properties Listed Yet',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'List your direct apartments, duplexes, or land on Rentilly with ₦0 agent commission and 100% legal title protection.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _openAddListing,
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'List Your First Property 🔑',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._myProperties.map((prop) => _buildMyPropertyCard(prop)),
        ],
      ),
    );
  }

  Widget _buildMyPropertyCard(Property prop) {
    final isUnlisted = prop.status == 'unlisted';
    final isRented = prop.status == 'rented';
    final isPendingKyp = prop.status == 'pending_kyp';

    String statusBadge = 'TITLE AUDITED ✓';
    Color badgeColor = const Color(0xFF16A34A);
    Color badgeBg = const Color(0xFFF0FDF4);

    if (isPendingKyp) {
      statusBadge = 'PENDING TITLE AUDIT ⏳';
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFFFBEB);
    } else if (isRented) {
      statusBadge = 'OCCUPIED / RENTED 🏠';
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
    } else if (isUnlisted) {
      statusBadge = 'UNLISTED / OFF MARKET';
      badgeColor = const Color(0xFF64748B);
      badgeBg = const Color(0xFFF1F5F9);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: prop.images.isNotEmpty && prop.images[0].startsWith('http')
                      ? Image.network(
                          prop.images[0],
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 70,
                            height: 70,
                            color: AppColors.backgroundDark,
                            child: const Icon(Icons.apartment_rounded, color: AppColors.textMuted),
                          ),
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.apartment_rounded, color: AppColors.textMuted),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusBadge,
                          style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w900, color: badgeColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prop.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${prop.neighborhood}, ${prop.state}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${_currencyFormat.format(prop.basePrice)} / yr',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 14, color: AppColors.primary),
                  label: Text('Preview', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                OutlinedButton(
                  onPressed: () => _toggleAvailability(prop),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(color: isUnlisted ? const Color(0xFF16A34A) : Colors.red.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isUnlisted ? 'Relist Unit 🚀' : 'Unlist Unit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isUnlisted ? const Color(0xFF16A34A) : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Public Marketplace (Platform-Wide Active Listings) ──────────────
  Widget _buildPublicMarketplaceTab() {
    return Column(
      children: [
        // State and Purpose filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPublicState,
                          isExpanded: true,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          items: _popularStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPublicState = val);
                              _loadPublicProperties();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPublicPurpose,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Listings')),
                          DropdownMenuItem(value: 'rent', child: Text('Rent')),
                          DropdownMenuItem(value: 'sale', child: Text('Sale')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPublicPurpose = val);
                            _loadPublicProperties();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingPublic
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadPublicProperties,
                  child: _publicProperties.isEmpty
                      ? Center(
                          child: Text(
                            'No active properties found in $_selectedPublicState',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _publicProperties.length,
                          itemBuilder: (ctx, i) {
                            final p = _publicProperties[i];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: p)),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: p.images.isNotEmpty && p.images[0].startsWith('http')
                                          ? Image.network(p.images[0], width: 64, height: 64, fit: BoxFit.cover)
                                          : Container(width: 64, height: 64, color: AppColors.backgroundDark, child: const Icon(Icons.apartment_rounded, color: AppColors.textMuted)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text('${p.neighborhood}, ${p.state}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('₦${_currencyFormat.format(p.basePrice)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                                                child: Text(
                                                  p.purpose == 'rent' ? 'FOR RENT' : 'FOR SALE',
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
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
        ),
      ],
    );
  }
}
