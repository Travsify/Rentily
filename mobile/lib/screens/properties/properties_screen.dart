import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../services/api_service.dart';
import '../home/property_detail_screen.dart';

class PropertiesScreen extends StatefulWidget {
  final String initialPurpose; // 'all' | 'rent' | 'sale'

  const PropertiesScreen({
    super.key,
    this.initialPurpose = 'all',
  });

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  String _selectedPurpose = 'all'; // 'all', 'rent', 'sale'
  String _selectedState = 'All Nigeria';
  String _selectedType = 'All Types';
  int _selectedBeds = 0; // 0 = Any
  String _searchQuery = '';

  List<Property> _allProperties = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  // Default quick visible states on the top bar
  static const List<String> _defaultVisibleStates = [
    'All Nigeria',
    'Lagos',
    'Abuja (FCT)',
    'Ibadan (Oyo)',
  ];

  // Comprehensive Nigerian states list for the filter modal
  static const List<String> _allNigerianStates = [
    'All Nigeria',
    'Lagos',
    'Abuja (FCT)',
    'Ibadan (Oyo)',
    'Rivers (Port Harcourt)',
    'Ogun (Abeokuta / Sagamu)',
    'Enugu',
    'Delta (Asaba / Warri)',
    'Edo (Benin City)',
    'Kano',
    'Anambra (Awka / Onitsha)',
    'Kaduna',
    'Akwa Ibom (Uyo)',
    'Imo (Owerri)',
    'Plateau (Jos)',
    'Ondo (Akure)',
    'Kwara (Ilorin)',
    'Abia (Umuahia / Aba)',
    'Cross River (Calabar)',
    'Bayelsa (Yenagoa)',
    'Benue (Makurdi)',
    'Niger (Minna)',
    'Osun (Osogbo)',
    'Ekiti (Ado-Ekiti)',
    'Nasarawa (Lafia)',
    'Kogi (Lokoja)',
    'Bauchi',
    'Gombe',
    'Borno (Maiduguri)',
    'Sokoto',
    'Katsina',
    'Zamfara (Gusau)',
    'Kebbi (Birnin Kebbi)',
    'Adamawa (Yola)',
    'Taraba (Jalingo)',
    'Yobe (Damaturu)',
    'Jigawa (Dutse)',
  ];

  final List<String> _propertyTypes = [
    'All Types',
    'Flats & Apartments',
    'Duplexes & Terraces',
    'Detached Mansions',
    'Commercial & Offices',
    'Land & Plots',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPurpose = widget.initialPurpose;
    _loadProperties();
  }

  void _loadProperties() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchProperties();
    if (mounted) {
      setState(() {
        _allProperties = data;
        _isLoading = false;
      });
    }
  }

  List<Property> get _filteredProperties {
    return _allProperties.where((p) {
      // 1. Purpose filter (Rent vs Sale)
      if (_selectedPurpose != 'all') {
        if (_selectedPurpose == 'rent' && p.purpose != 'rent') return false;
        if (_selectedPurpose == 'sale' && p.purpose != 'sale') return false;
      }

      // 2. State filter
      if (_selectedState != 'All Nigeria') {
        final stToken = _selectedState.split(' ')[0].toLowerCase();
        final stateMatch = p.state.toLowerCase().contains(stToken) ||
            p.neighborhood.toLowerCase().contains(stToken) ||
            p.lga.toLowerCase().contains(stToken);
        if (!stateMatch) return false;
      }

      // 3. Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = p.title.toLowerCase().contains(q) ||
            p.neighborhood.toLowerCase().contains(q) ||
            p.state.toLowerCase().contains(q) ||
            p.lga.toLowerCase().contains(q);
        if (!match) return false;
      }

      // 4. Beds filter
      if (_selectedBeds > 0) {
        if (p.bedrooms != _selectedBeds) return false;
      }

      return true;
    }).toList();
  }

  void _showFilterModal() {
    String tempState = _selectedState;
    int tempBeds = _selectedBeds;
    String tempType = _selectedType;
    String stateSearch = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredStates = _allNigerianStates.where((s) {
            if (stateSearch.isEmpty) return true;
            return s.toLowerCase().contains(stateSearch.toLowerCase());
          }).toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Filter Properties',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. Filter by Nigerian State
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT NIGERIAN STATE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (tempState != 'All Nigeria')
                        GestureDetector(
                          onTap: () => setModalState(() => tempState = 'All Nigeria'),
                          child: Text(
                            'Reset to All Nigeria',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // State Search Input
                  TextField(
                    onChanged: (v) => setModalState(() => stateSearch = v.trim()),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search state (e.g. Rivers, Kano, Enugu)...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.location_searching_rounded, size: 16, color: AppColors.primary),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // State Chips Container
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: filteredStates.map((st) {
                          final isSel = tempState == st;
                          return GestureDetector(
                            onTap: () => setModalState(() => tempState = st),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.primary : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSel ? AppColors.primary : AppColors.borderDark,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                st,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                  color: isSel ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Bedrooms Selector
                  Text('BEDROOMS', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [0, 1, 2, 3, 4].map((b) {
                      final isSel = tempBeds == b;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => tempBeds = b),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                            ),
                            child: Center(
                              child: Text(
                                b == 0 ? 'Any' : (b == 4 ? '4+ Beds' : '$b Bed'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                  color: isSel ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 3. Property Category
                  Text('PROPERTY TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _propertyTypes.map((t) {
                      final isSel = tempType == t;
                      return GestureDetector(
                        onTap: () => setModalState(() => tempType = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Text(
                            t,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                              color: isSel ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedState = tempState;
                          _selectedBeds = tempBeds;
                          _selectedType = tempType;
                        });
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Apply Filters', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredProperties;

    // Determine the visible state chips list (defaults + currently active state if custom)
    final visibleChips = List<String>.from(_defaultVisibleStates);
    if (!visibleChips.contains(_selectedState)) {
      visibleChips.add(_selectedState);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Toolbar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nigerian Property Hub',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Direct Landlords • Zero Agent Fees • Legal Escrow',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      // Filter Button
                      IconButton(
                        onPressed: _showFilterModal,
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Purpose Toggle
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildPurposeSegment('all', 'All Properties'),
                        _buildPurposeSegment('rent', 'For Rent / Lease'),
                        _buildPurposeSegment('sale', 'For Sale / Buy'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search Field
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search city, neighborhood (Lekki, Maitama, GRA)...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Focused State Selector Row (All Nigeria, Lagos, Abuja, Ibadan + Filter Button)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ...visibleChips.map((st) {
                      final isSelected = _selectedState == st;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedState = st),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Text(
                            st,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                    // "More States" Pill Button
                    GestureDetector(
                      onTap: _showFilterModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_rounded, size: 12, color: AppColors.accentOrange),
                            const SizedBox(width: 4),
                            Text(
                              'More States 🗺️',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Properties Results Count Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${list.length} Verified Properties Found',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Zero Agent Fees 🛡️',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),

            // 4. Property Listings View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : list.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final prop = list[index];
                            return _buildPropertyCard(prop);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurposeSegment(String id, String label) {
    final isSelected = _selectedPurpose == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPurpose = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.home_work_outlined, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Properties Found',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'No properties match your active filters for "$_selectedState". Try resetting filters or expanding your search.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedState = 'All Nigeria';
                  _selectedPurpose = 'all';
                  _selectedBeds = 0;
                  _selectedType = 'All Types';
                  _searchQuery = '';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Reset Filters', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Property prop) {
    final bool isRent = prop.purpose == 'rent';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      prop.images.isNotEmpty ? prop.images[0] : 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.apartment_rounded, size: 40, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
                // Purpose Pill
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRent ? AppColors.primary : AppColors.accentOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isRent ? 'FOR RENT' : 'FOR SALE',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6),
                    ),
                  ),
                ),
                // Attribution Badge (Listed by Landlord vs Listed by Corporate Partner)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: prop.listedByRole == 'verified_partner' ? const Color(0xFF0F172A).withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: prop.listedByRole == 'verified_partner' ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          prop.listedByRole == 'verified_partner' ? Icons.business_rounded : Icons.vpn_key_rounded,
                          size: 11,
                          color: prop.listedByRole == 'verified_partner' ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          prop.listedByRole == 'verified_partner' ? 'CORPORATE PARTNER' : 'DIRECT LANDLORD',
                          style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prop.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${prop.neighborhood}, ${prop.state}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        prop.listedByRole == 'verified_partner' ? Icons.business_rounded : Icons.vpn_key_rounded,
                        size: 11,
                        color: prop.listedByRole == 'verified_partner' ? AppColors.primary : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          prop.listedByRole == 'verified_partner'
                              ? 'Listed by Corporate Partner: ${prop.partnerBusinessName ?? "Verified Partner"} (${prop.partnerCacNumber ?? "CAC Verified"})'
                              : 'Listed by Landlord • Direct Owner Verified',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: prop.listedByRole == 'verified_partner' ? AppColors.primary : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Specs Row (Beds, Baths, Parking)
                  Row(
                    children: [
                      _buildSpecChip(Icons.bed_rounded, '${prop.bedrooms} Beds'),
                      const SizedBox(width: 8),
                      _buildSpecChip(Icons.bathtub_outlined, '${prop.bathrooms} Baths'),
                      const SizedBox(width: 8),
                      _buildSpecChip(Icons.local_parking_rounded, 'Verified'),
                    ],
                  ),
                  const Divider(height: 20),

                  // Price Row & Savings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRent ? 'ANNUAL RENT' : 'TOTAL PRICE',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                          ),
                          Text(
                            '₦${_currencyFormat.format(prop.basePrice)}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.savings_outlined, size: 13, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Save ₦${_currencyFormat.format(prop.totalNairaSavedOnRentilly)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                            ),
                          ],
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
  }

  Widget _buildSpecChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
