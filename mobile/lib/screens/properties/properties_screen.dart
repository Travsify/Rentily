import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../services/api_service.dart';
import '../home/property_detail_screen.dart';

class PropertiesScreen extends StatefulWidget {
  final String initialPurpose; // 'all', 'rent', or 'sale'

  const PropertiesScreen({super.key, this.initialPurpose = 'all'});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  late String _selectedPurpose;
  String _selectedState = 'All Nigeria';
  String _selectedType = 'All Types';
  int _selectedBeds = 0; // 0 = Any
  String _searchQuery = '';
  List<Property> _allProperties = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  final List<String> _states = [
    'All Nigeria',
    'Lagos',
    'Abuja (FCT)',
    'Rivers (Port Harcourt)',
    'Oyo (Ibadan)',
    'Enugu',
    'Delta (Asaba / Warri)',
    'Edo (Benin City)',
    'Ogun (Abeokuta)',
    'Kano',
    'Anambra (Awka/Onitsha)',
    'Kaduna',
    'Akwa Ibom (Uyo)',
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
        final stateMatch = p.state.toLowerCase().contains(_selectedState.split(' ')[0].toLowerCase()) ||
            p.neighborhood.toLowerCase().contains(_selectedState.split(' ')[0].toLowerCase()) ||
            p.lga.toLowerCase().contains(_selectedState.split(' ')[0].toLowerCase());
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filter Properties', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
                const SizedBox(height: 12),

                // Bedrooms Selector
                Text('BEDROOMS', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Row(
                  children: [0, 1, 2, 3, 4].map((b) {
                    final isSel = _selectedBeds == b;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedBeds = b);
                          setState(() => _selectedBeds = b);
                        },
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

                // Property Category
                Text('PROPERTY TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _propertyTypes.map((t) {
                    final isSel = _selectedType == t;
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => _selectedType = t);
                        setState(() => _selectedType = t);
                      },
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
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredProperties;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Properties Across Nigeria',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
            onPressed: _showFilterModal,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input & Purpose Selector
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  // Purpose Segmented Bar
                  Container(
                    padding: const EdgeInsets.all(4),
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

            // State Selector Carousel
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _states.length,
                  itemBuilder: (context, index) {
                    final st = _states[index];
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
                  },
                ),
              ),
            ),

            // Properties Results Count
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

            // Property Listings View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : list.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.home_work_outlined, size: 36, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 12),
                                Text('No Properties Found', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Try switching your state or search query.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final prop = list[index];
                            final isRent = prop.purpose == 'rent';

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderDark),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          height: 155,
                                          width: double.infinity,
                                          color: const Color(0xFFF3F4F6),
                                          child: Image.network(
                                            prop.images.isNotEmpty ? prop.images[0] : '',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined, size: 36, color: AppColors.textMuted)),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isRent ? AppColors.primary : const Color(0xFF0F172A),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isRent ? 'FOR RENT' : 'FOR SALE',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.verified, size: 12, color: AppColors.primary),
                                                const SizedBox(width: 4),
                                                Text('DIRECT OWNER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          left: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.videocam_rounded, size: 11, color: Color(0xFF22C55E)),
                                                const SizedBox(width: 4),
                                                Text('4K Live Video Ready', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    Padding(
                                      padding: const EdgeInsets.all(12),
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
                                          const SizedBox(height: 10),

                                          // Specs Row (Beds, Baths, Parking)
                                          Row(
                                            children: [
                                              _buildSpecChip(Icons.bed_rounded, '${prop.bedrooms} Beds'),
                                              const SizedBox(width: 8),
                                              _buildSpecChip(Icons.bathtub_outlined, '${prop.bathrooms} Baths'),
                                              const SizedBox(width: 8),
                                              _buildSpecChip(Icons.directions_car_outlined, 'Parking'),
                                            ],
                                          ),
                                          const Divider(height: 18),

                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Direct Price', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.textMuted)),
                                                  Text(
                                                    '₦${_currencyFormat.format(prop.basePrice)}${isRent ? ' / yr' : ' Outright'}',
                                                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accentOrange.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'ZERO AGENT FEE',
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
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
    );
  }

  Widget _buildPurposeSegment(String id, String label) {
    final isSelected = _selectedPurpose == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPurpose = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
