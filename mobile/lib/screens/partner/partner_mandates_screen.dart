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

class _PartnerMandatesScreenState extends State<PartnerMandatesScreen> {
  UserProfile? _user;
  List<Property> _allMandates = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'verified', 'pending_kyp', 'leased'
  String _searchQuery = '';
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadMandates();
  }

  Future<void> _loadMandates() async {
    final user = await AuthService.getCurrentUser();
    final allProps = await ApiService.fetchProperties();

    if (mounted) {
      setState(() {
        _user = user;
        if (user != null) {
          _allMandates = allProps.where((p) {
            final isOwn = p.partnerId == user.id ||
                p.ownerId == user.id ||
                (p.ownerPhone.isNotEmpty && p.ownerPhone == user.phoneNumber) ||
                (p.listedByRole == 'verified_partner');
            return isOwn;
          }).toList();
        } else {
          _allMandates = [];
        }
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final totalCount = _allMandates.length;
    final verifiedCount = _allMandates.where((p) => p.status == 'verified' || p.status == 'active').length;
    final pendingCount = _allMandates.where((p) => p.status == 'pending_kyp').length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'My Mandate Portfolio 🏢',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 22),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadMandates();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_user != null) {
            PartnerListingModal.show(context, user: _user!, onListingCreated: _loadMandates);
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
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadMandates,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // KPI Header
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'TOTAL MANDATES',
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
                    hintText: 'Search mandates by title, estate or location...',
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
                        'No Mandate Properties Found',
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
