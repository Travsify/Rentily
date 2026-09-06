import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/nigerian_states_cities.dart';
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
  String _selectedLga = 'All LGAs';
  String _selectedType = 'All Types';
  int _selectedBeds = 0; // 0 = Any, 1, 2, 3, 4 (4+ Beds)
  String _selectedPriceBracket = 'all';
  double? _minPrice;
  double? _maxPrice;
  String _selectedFurnishing = 'All'; // 'All', 'Fully Furnished', 'Semi-Furnished', 'Unfurnished'
  String _selectedListedBy = 'All'; // 'All', 'direct_landlord', 'verified_partner'
  String _sortBy = 'newest'; // 'newest', 'price_asc', 'price_desc', 'bedrooms'
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
    'Rivers (Port Harcourt)',
  ];

  static const List<String> _propertyTypes = [
    'All Types',
    'Flats & Apartments',
    'Duplexes & Terraces',
    'Detached Mansions',
    'Self-Contain / Studio',
    'Commercial & Offices',
    'Land & Plots',
  ];

  static const List<Map<String, dynamic>> _priceBrackets = [
    {'id': 'all', 'label': 'Any Budget', 'min': null, 'max': null},
    {'id': 'under_1m', 'label': 'Under ₦1M', 'min': null, 'max': 1000000.0},
    {'id': '1m_3m', 'label': '₦1M - ₦3M', 'min': 1000000.0, 'max': 3000000.0},
    {'id': '3m_5m', 'label': '₦3M - ₦5M', 'min': 3000000.0, 'max': 5000000.0},
    {'id': '5m_10m', 'label': '₦5M - ₦10M', 'min': 5000000.0, 'max': 10000000.0},
    {'id': '10m_25m', 'label': '₦10M - ₦25M', 'min': 10000000.0, 'max': 25000000.0},
    {'id': '25m_50m', 'label': '₦25M - ₦50M', 'min': 25000000.0, 'max': 50000000.0},
    {'id': '50m_plus', 'label': '₦50M+', 'min': 50000000.0, 'max': null},
  ];

  static const List<String> _furnishingOptions = [
    'All',
    'Fully Furnished',
    'Semi-Furnished',
    'Unfurnished',
  ];

  static const List<Map<String, String>> _listingSourceOptions = [
    {'id': 'All', 'label': 'All Listings 🌐'},
    {'id': 'direct_landlord', 'label': 'Direct Landlords (0% Agency) 🛡️'},
    {'id': 'verified_partner', 'label': 'Corporate Partners (Escorted) 🏢'},
  ];

  static const List<Map<String, String>> _sortOptions = [
    {'id': 'newest', 'label': 'Newest Listed ⚡'},
    {'id': 'price_asc', 'label': 'Price: Low to High 📈'},
    {'id': 'price_desc', 'label': 'Price: High to Low 📉'},
    {'id': 'bedrooms', 'label': 'Bedrooms: Most First 🛏️'},
  ];

  int get _activeFilterCount {
    int count = 0;
    if (_selectedState != 'All Nigeria') count++;
    if (_selectedLga != 'All LGAs') count++;
    if (_selectedType != 'All Types') count++;
    if (_selectedBeds > 0) count++;
    if (_minPrice != null || _maxPrice != null) count++;
    if (_selectedFurnishing != 'All') count++;
    if (_selectedListedBy != 'All') count++;
    if (_sortBy != 'newest') count++;
    return count;
  }

  void _resetAllFilters() {
    setState(() {
      _selectedState = 'All Nigeria';
      _selectedLga = 'All LGAs';
      _selectedPurpose = 'all';
      _selectedBeds = 0;
      _selectedType = 'All Types';
      _selectedPriceBracket = 'all';
      _minPrice = null;
      _maxPrice = null;
      _selectedFurnishing = 'All';
      _selectedListedBy = 'All';
      _sortBy = 'newest';
      _searchQuery = '';
    });
  }

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
    final filtered = _allProperties.where((p) {
      // 1. Purpose filter (Rent vs Sale)
      if (_selectedPurpose != 'all') {
        if (_selectedPurpose == 'rent' && p.purpose != 'rent') return false;
        if (_selectedPurpose == 'sale' && p.purpose != 'sale') return false;
      }

      // 2. State filter
      if (_selectedState != 'All Nigeria') {
        final stToken = _selectedState.split(' ')[0].replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
        final stateMatch = p.state.toLowerCase().contains(stToken) ||
            p.neighborhood.toLowerCase().contains(stToken) ||
            p.lga.toLowerCase().contains(stToken);
        if (!stateMatch) return false;
      }

      // 3. LGA filter
      if (_selectedLga != 'All LGAs') {
        final lgaToken = _selectedLga.toLowerCase().trim();
        final lgaMatch = p.lga.toLowerCase().contains(lgaToken) ||
            p.neighborhood.toLowerCase().contains(lgaToken) ||
            p.address.toLowerCase().contains(lgaToken);
        if (!lgaMatch) return false;
      }

      // 4. Property Category
      if (_selectedType != 'All Types') {
        final pt = p.propertyType.toLowerCase();
        if (_selectedType == 'Flats & Apartments') {
          if (!pt.contains('flat') && !pt.contains('apartment') && !pt.contains('self_contain') && !pt.contains('studio') && !pt.contains('penthouse') && !pt.contains('maisonette')) {
            return false;
          }
        } else if (_selectedType == 'Duplexes & Terraces') {
          if (!pt.contains('duplex') && !pt.contains('terrace') && !pt.contains('terraced') && !pt.contains('semi_detached')) {
            return false;
          }
        } else if (_selectedType == 'Detached Mansions') {
          if (!pt.contains('mansion') && !pt.contains('fully_detached') && !pt.contains('detached')) {
            return false;
          }
        } else if (_selectedType == 'Self-Contain / Studio') {
          if (!pt.contains('self_contain') && !pt.contains('studio')) {
            return false;
          }
        } else if (_selectedType == 'Commercial & Offices') {
          if (!pt.contains('commercial') && !pt.contains('office') && !pt.contains('warehouse') && !pt.contains('shop')) {
            return false;
          }
        } else if (_selectedType == 'Land & Plots') {
          if (!pt.contains('land') && !pt.contains('plot')) {
            return false;
          }
        }
      }

      // 5. Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = p.title.toLowerCase().contains(q) ||
            p.neighborhood.toLowerCase().contains(q) ||
            p.state.toLowerCase().contains(q) ||
            p.lga.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
        if (!match) return false;
      }

      // 6. Beds filter (0 = Any, 4 = 4+ Beds)
      if (_selectedBeds > 0) {
        if (_selectedBeds >= 4) {
          if (p.bedrooms < 4) return false;
        } else {
          if (p.bedrooms != _selectedBeds) return false;
        }
      }

      // 7. Price Range filter
      if (_minPrice != null && p.basePrice < _minPrice!) return false;
      if (_maxPrice != null && p.basePrice > _maxPrice!) return false;

      // 8. Furnishing filter
      if (_selectedFurnishing != 'All') {
        final f = p.furnishing.toLowerCase();
        if (_selectedFurnishing == 'Fully Furnished') {
          if (!f.contains('fully') && !f.contains('furnished')) return false;
        } else if (_selectedFurnishing == 'Semi-Furnished') {
          if (!f.contains('semi')) return false;
        } else if (_selectedFurnishing == 'Unfurnished') {
          if (!f.contains('unfurnished')) return false;
        }
      }

      // 9. Listed By filter
      if (_selectedListedBy != 'All') {
        if (p.listedByRole != _selectedListedBy) return false;
      }

      return true;
    }).toList();

    // 10. Sort
    if (_sortBy == 'price_asc') {
      filtered.sort((a, b) => a.basePrice.compareTo(b.basePrice));
    } else if (_sortBy == 'price_desc') {
      filtered.sort((a, b) => b.basePrice.compareTo(a.basePrice));
    } else if (_sortBy == 'bedrooms') {
      filtered.sort((a, b) => b.bedrooms.compareTo(a.bedrooms));
    }

    return filtered;
  }

  void _showFilterModal() {
    String tempState = _selectedState;
    String tempLga = _selectedLga;
    int tempBeds = _selectedBeds;
    String tempType = _selectedType;
    String tempPriceBracket = _selectedPriceBracket;
    double? tempMinPrice = _minPrice;
    double? tempMaxPrice = _maxPrice;
    String tempFurnishing = _selectedFurnishing;
    String tempListedBy = _selectedListedBy;
    String tempSortBy = _sortBy;

    String stateSearch = '';
    final TextEditingController minPriceCtrl = TextEditingController(
      text: tempMinPrice != null ? tempMinPrice.toInt().toString() : '',
    );
    final TextEditingController maxPriceCtrl = TextEditingController(
      text: tempMaxPrice != null ? tempMaxPrice.toInt().toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Normalize Nigerian states list
          final allStates = ['All Nigeria', ...NigerianStatesLgas.states];
          final filteredStates = allStates.where((s) {
            if (stateSearch.isEmpty) return true;
            return s.toLowerCase().contains(stateSearch.toLowerCase());
          }).toList();

          // Get LGAs for selected state
          String lookupState = tempState;
          if (lookupState.contains('Abuja')) lookupState = 'FCT (Abuja)';
          if (lookupState.contains('Oyo')) lookupState = 'Oyo';
          if (lookupState.contains('Rivers')) lookupState = 'Rivers';
          if (lookupState.contains('Ogun')) lookupState = 'Ogun';

          final List<String> availableLgas = ['All LGAs', ...(NigerianStatesLgas.stateToLgas[lookupState] ?? [])];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
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
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempState = 'All Nigeria';
                              tempLga = 'All LGAs';
                              tempBeds = 0;
                              tempType = 'All Types';
                              tempPriceBracket = 'all';
                              tempMinPrice = null;
                              tempMaxPrice = null;
                              minPriceCtrl.clear();
                              maxPriceCtrl.clear();
                              tempFurnishing = 'All';
                              tempListedBy = 'All';
                              tempSortBy = 'newest';
                            });
                          },
                          child: Text(
                            'Reset All',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentOrange,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Scrollable filter categories
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. SELECT NIGERIAN STATE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '1. NIGERIAN STATE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (tempState != 'All Nigeria')
                              GestureDetector(
                                onTap: () => setModalState(() {
                                  tempState = 'All Nigeria';
                                  tempLga = 'All LGAs';
                                }),
                                child: Text(
                                  'Reset to All Nigeria',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                            hintText: 'Search 36 states + FCT (e.g. Lagos, Rivers, Kano)...',
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
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: filteredStates.map((st) {
                                final isSel = tempState == st;
                                return GestureDetector(
                                  onTap: () => setModalState(() {
                                    tempState = st;
                                    tempLga = 'All LGAs';
                                  }),
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
                        const SizedBox(height: 16),

                        // 2. LGA / LOCALITY (Only if a specific state is selected)
                        if (tempState != 'All Nigeria' && availableLgas.length > 1) ...[
                          Text(
                            '2. LOCAL GOVERNMENT AREA (LGA) IN $tempState',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 110),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: availableLgas.map((lga) {
                                  final isSel = tempLga == lga;
                                  return GestureDetector(
                                    onTap: () => setModalState(() => tempLga = lga),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: isSel ? const Color(0xFF0F172A) : AppColors.borderDark),
                                      ),
                                      child: Text(
                                        lga,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
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
                          const SizedBox(height: 16),
                        ],

                        // 3. PROPERTY CATEGORY
                        Text(
                          '3. PROPERTY CATEGORY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
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
                        const SizedBox(height: 16),

                        // 4. BUDGET & PRICE RANGE
                        Text(
                          '4. PRICE & BUDGET (₦ NAIRA)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _priceBrackets.map((b) {
                            final isSel = tempPriceBracket == b['id'];
                            return GestureDetector(
                              onTap: () => setModalState(() {
                                tempPriceBracket = b['id'];
                                tempMinPrice = b['min'] as double?;
                                tempMaxPrice = b['max'] as double?;
                                minPriceCtrl.text = tempMinPrice != null ? tempMinPrice!.toInt().toString() : '';
                                maxPriceCtrl.text = tempMaxPrice != null ? tempMaxPrice!.toInt().toString() : '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                                ),
                                child: Text(
                                  b['label'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),

                        // Custom Min / Max Inputs
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minPriceCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Min Price (₦)',
                                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                                ),
                                onChanged: (v) {
                                  final val = double.tryParse(v.replaceAll(',', '').trim());
                                  setModalState(() {
                                    tempMinPrice = val;
                                    tempPriceBracket = 'custom';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: maxPriceCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Max Price (₦)',
                                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                                ),
                                onChanged: (v) {
                                  final val = double.tryParse(v.replaceAll(',', '').trim());
                                  setModalState(() {
                                    tempMaxPrice = val;
                                    tempPriceBracket = 'custom';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. BEDROOMS
                        Text(
                          '5. BEDROOMS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
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

                        // 6. FURNISHING STATUS
                        Text(
                          '6. FURNISHING STATUS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _furnishingOptions.map((f) {
                            final isSel = tempFurnishing == f;
                            return GestureDetector(
                              onTap: () => setModalState(() => tempFurnishing = f),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                                ),
                                child: Text(
                                  f,
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
                        const SizedBox(height: 16),

                        // 7. LISTED BY (DIRECT OWNER VS PARTNER)
                        Text(
                          '7. LISTED BY / VERIFICATION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _listingSourceOptions.map((opt) {
                            final isSel = tempListedBy == opt['id'];
                            return GestureDetector(
                              onTap: () => setModalState(() => tempListedBy = opt['id']!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                                ),
                                child: Text(
                                  opt['label']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // 8. SORT ORDER
                        Text(
                          '8. SORT ORDER',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _sortOptions.map((opt) {
                            final isSel = tempSortBy == opt['id'];
                            return GestureDetector(
                              onTap: () => setModalState(() => tempSortBy = opt['id']!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSel ? const Color(0xFF0F172A) : AppColors.borderDark),
                                ),
                                child: Text(
                                  opt['label']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Apply Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedState = tempState;
                        _selectedLga = tempLga;
                        _selectedBeds = tempBeds;
                        _selectedType = tempType;
                        _selectedPriceBracket = tempPriceBracket;
                        _minPrice = tempMinPrice;
                        _maxPrice = tempMaxPrice;
                        _selectedFurnishing = tempFurnishing;
                        _selectedListedBy = tempListedBy;
                        _sortBy = tempSortBy;
                      });
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
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
                      // Filter Button with Active Count Badge
                      IconButton(
                        onPressed: _showFilterModal,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _activeFilterCount > 0 ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _activeFilterCount > 0 ? AppColors.primary : AppColors.borderDark),
                              ),
                              child: Icon(Icons.tune_rounded, size: 18, color: _activeFilterCount > 0 ? AppColors.primary : AppColors.textPrimary),
                            ),
                            if (_activeFilterCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$_activeFilterCount',
                                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
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

                  // Active Filter Pills Bar (Shows whenever any filter is applied)
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_selectedState != 'All Nigeria')
                            _buildActiveFilterChip('📍 $_selectedState', () {
                              setState(() {
                                _selectedState = 'All Nigeria';
                                _selectedLga = 'All LGAs';
                              });
                            }),
                          if (_selectedLga != 'All LGAs')
                            _buildActiveFilterChip('🏙️ $_selectedLga', () {
                              setState(() => _selectedLga = 'All LGAs');
                            }),
                          if (_selectedType != 'All Types')
                            _buildActiveFilterChip('🏠 $_selectedType', () {
                              setState(() => _selectedType = 'All Types');
                            }),
                          if (_selectedBeds > 0)
                            _buildActiveFilterChip('🛏️ ${_selectedBeds == 4 ? "4+ Beds" : "$_selectedBeds Bed"}', () {
                              setState(() => _selectedBeds = 0);
                            }),
                          if (_minPrice != null || _maxPrice != null)
                            _buildActiveFilterChip(
                              _minPrice != null && _maxPrice != null
                                  ? '💰 ₦${_currencyFormat.format(_minPrice)} - ₦${_currencyFormat.format(_maxPrice)}'
                                  : _minPrice != null
                                      ? '💰 ≥ ₦${_currencyFormat.format(_minPrice)}'
                                      : '💰 ≤ ₦${_currencyFormat.format(_maxPrice)}',
                              () {
                                setState(() {
                                  _minPrice = null;
                                  _maxPrice = null;
                                  _selectedPriceBracket = 'all';
                                });
                              },
                            ),
                          if (_selectedFurnishing != 'All')
                            _buildActiveFilterChip('🛋️ $_selectedFurnishing', () {
                              setState(() => _selectedFurnishing = 'All');
                            }),
                          if (_selectedListedBy != 'All')
                            _buildActiveFilterChip(
                              _selectedListedBy == 'direct_landlord' ? '🛡️ Direct Landlord' : '🏢 Partner Escort',
                              () {
                                setState(() => _selectedListedBy = 'All');
                              },
                            ),
                          if (_sortBy != 'newest')
                            _buildActiveFilterChip(
                              _sortOptions.firstWhere((s) => s['id'] == _sortBy)['label']!,
                              () {
                                setState(() => _sortBy = 'newest');
                              },
                            ),
                          GestureDetector(
                            onTap: _resetAllFilters,
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                'Clear All ✕',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        color: prop.listedByRole == 'verified_partner' ? const Color(0xFFFBBF24) : const Color(0xFF22C55E),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          prop.listedByRole == 'verified_partner' ? Icons.business_rounded : Icons.vpn_key_rounded,
                          size: 11,
                          color: prop.listedByRole == 'verified_partner' ? const Color(0xFFFBBF24) : const Color(0xFF22C55E),
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

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(9, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
