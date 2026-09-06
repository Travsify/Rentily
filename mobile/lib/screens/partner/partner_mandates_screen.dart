import 'dart:io';
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

class PartnerMandatesScreen extends StatefulWidget {
  const PartnerMandatesScreen({super.key});

  @override
  State<PartnerMandatesScreen> createState() => _PartnerMandatesScreenState();
}

class _PartnerMandatesScreenState extends State<PartnerMandatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _user;
  List<Property> _allMandates = [];
  List<Property> _publicProperties = [];
  bool _isLoading = true;
  bool _isLoadingPublic = true;

  // Filters for exclusive mandates
  String _filterStatus = 'all'; // 'all', 'verified', 'pending_kyp', 'leased'
  String _searchQuery = '';

  // Filters for public marketplace
  String _selectedPublicPurpose = 'all'; // 'all', 'rent', 'sale'
  String _selectedPublicState = 'All Nigeria';
  String _publicSearchQuery = '';

  static const List<String> _popularStates = [
    'All Nigeria',
    'Lagos',
    'Abuja (FCT)',
    'Rivers (Port Harcourt)',
    'Oyo (Ibadan)',
  ];

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) setState(() => _user = user);
    await Future.wait([
      _loadMandates(user),
      _loadPublicProperties(),
    ]);
  }

  Future<void> _loadMandates([UserProfile? currentUser]) async {
    final user = currentUser ?? _user ?? await AuthService.getCurrentUser();
    final allProps = await ApiService.fetchProperties();

    if (mounted) {
      setState(() {
        _user = user;
        if (user != null) {
          // Strictly isolate this partner's exclusive portfolio:
          _allMandates = allProps.where((p) {
            final matchesPartner = (p.partnerId != null && p.partnerId == user.id) ||
                p.ownerId == user.id ||
                (p.ownerPhone.isNotEmpty && p.ownerPhone == user.phoneNumber);

            return matchesPartner && (p.listedByRole == 'verified_partner' || p.partnerId != null || p.ownerId == user.id);
          }).toList();
        } else {
          _allMandates = [];
        }
        _isLoading = false;
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
        _publicProperties = props.where((p) => p.status != 'unlisted').toList();
        _isLoadingPublic = false;
      });
    }
  }

  List<Property> get _filteredMandates {
    return _allMandates.where((p) {
      final matchesStatus = _filterStatus == 'all' ||
          (_filterStatus == 'verified' && (p.status == 'verified' || p.status == 'active')) ||
          (_filterStatus == 'pending_kyp' && p.status == 'pending_kyp') ||
          (_filterStatus == 'leased' && (p.status == 'rented' || p.status == 'sold' || p.status == 'leased'));

      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          p.title.toLowerCase().contains(query) ||
          p.neighborhood.toLowerCase().contains(query) ||
          p.address.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<Property> get _filteredPublicProperties {
    return _publicProperties.where((p) {
      final query = _publicSearchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return p.title.toLowerCase().contains(query) ||
          p.neighborhood.toLowerCase().contains(query) ||
          p.address.toLowerCase().contains(query) ||
          p.state.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final totalCount = _allMandates.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Mandate Portfolio & Public Feed',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 22),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _isLoadingPublic = true;
              });
              _loadAllData();
            },
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
            Tab(text: 'My Mandates ($totalCount)'),
            const Tab(text: 'Public Marketplace 🌍'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_user != null) {
            PartnerListingModal.show(context, user: _user!, onListingCreated: _loadAllData);
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_home_work_rounded, color: Colors.white, size: 20),
        label: Text(
          'Add Mandate',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMyMandatesTab(),
            _buildPublicMarketplaceTab(),
          ],
        ),
      ),
    );
  }

  // ── Tab 0: Exclusive Mandates ──────────────────────────────────────────────
  Widget _buildMyMandatesTab() {
    final totalCount = _allMandates.length;
    final verifiedCount = _allMandates.where((p) => p.status == 'verified' || p.status == 'active').length;
    final pendingCount = _allMandates.where((p) => p.status == 'pending_kyp').length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadMandates(_user),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // KPI Header
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  label: 'EXCLUSIVE MANDATES',
                  value: '$totalCount',
                  color: AppColors.primary,
                  icon: Icons.holiday_village_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  label: 'TITLE VERIFIED',
                  value: '$verifiedCount',
                  color: const Color(0xFF16A34A),
                  icon: Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  label: 'PENDING KYP',
                  value: '$pendingCount',
                  color: AppColors.accentOrange,
                  icon: Icons.pending_actions_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search exclusive mandates by title, estate or location...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Status Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Mandates ($totalCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('verified', 'Verified ($verifiedCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('pending_kyp', 'Pending Audit ($pendingCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('leased', 'Leased / Closed'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Listings List
          if (_filteredMandates.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.apartment_rounded, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Exclusive Mandates Found',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You currently have no properties under this filter. Tap "Add Mandate" to register a new direct landlord property.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._filteredMandates.map((prop) => _buildMandateCard(prop)),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Tab 1: Public Marketplace across Nigeria ──────────────────────────────
  Widget _buildPublicMarketplaceTab() {
    if (_isLoadingPublic) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final filtered = _filteredPublicProperties;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadPublicProperties,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Public Market Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.public_rounded, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All active residential & commercial units currently live across Nigeria.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _publicSearchQuery = val),
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search by estate, city, or property name...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Purpose Filter Pills
          Row(
            children: [
              _buildPublicPurposeChip('all', 'All Purpose'),
              const SizedBox(width: 8),
              _buildPublicPurposeChip('rent', 'For Rent 🔑'),
              const SizedBox(width: 8),
              _buildPublicPurposeChip('sale', 'For Sale 🏷️'),
            ],
          ),
          const SizedBox(height: 10),

          // Popular Nigerian States Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _popularStates.map((st) {
                final isSelected = _selectedPublicState == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      st,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.borderDark,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedPublicState = st);
                      _loadPublicProperties();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Listings List
          if (filtered.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No Properties Found',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try changing your state or purpose filter above.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...filtered.map((prop) => _buildPublicPropertyCard(prop)),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPublicPurposeChip(String key, String label) {
    final isSelected = _selectedPublicPurpose == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedPublicPurpose = key);
        _loadPublicProperties();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPublicPropertyCard(Property prop) {
    final isRent = prop.purpose == 'rent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (prop.images.isNotEmpty && prop.images[0].startsWith('http'))
                    ? Image.network(prop.images[0], width: 75, height: 75, fit: BoxFit.cover)
                    : (prop.images.isNotEmpty && File(prop.images[0]).existsSync())
                        ? Image.file(File(prop.images[0]), width: 75, height: 75, fit: BoxFit.cover)
                        : Container(
                            width: 75,
                            height: 75,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.apartment_rounded, color: AppColors.textMuted, size: 28),
                          ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isRent ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isRent ? 'FOR RENT' : 'FOR SALE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isRent ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                            ),
                          ),
                        ),
                        Text(
                          '${prop.bedrooms} Bed • ${prop.bathrooms} Bath',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted),
                        ),
                      ],
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
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₦${_currencyFormat.format(prop.basePrice)} ${isRent ? '/yr' : ''}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filterStatus == key;
    return InkWell(
      onTap: () => setState(() => _filterStatus = key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMandateCard(Property prop) {
    final isVerified = prop.status == 'verified' || prop.status == 'active';
    final commRate = prop.purpose == 'rent' ? '2.5% (Rent)' : '2.0% (Sale)';
    final commPayout = prop.purpose == 'rent' ? prop.basePrice * 0.025 : prop.basePrice * 0.02;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (prop.images.isNotEmpty && prop.images[0].startsWith('http'))
                    ? Image.network(prop.images[0], width: 75, height: 75, fit: BoxFit.cover)
                    : (prop.images.isNotEmpty && File(prop.images[0]).existsSync())
                        ? Image.file(File(prop.images[0]), width: 75, height: 75, fit: BoxFit.cover)
                        : Container(
                            width: 75,
                            height: 75,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.apartment_rounded, color: AppColors.textMuted, size: 28),
                          ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            isVerified ? 'TITLE AUDITED ✓' : 'KYP PENDING',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$commRate COMM',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
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
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₦${_currencyFormat.format(prop.basePrice)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                        Text(
                          'Yield: ₦${_currencyFormat.format(commPayout)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
