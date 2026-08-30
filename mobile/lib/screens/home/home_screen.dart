import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../services/api_service.dart';
import 'property_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedPurpose = 'all'; // 'all', 'rent', 'sale'
  String _selectedLocation = 'Lekki Phase 1, Lagos';
  List<Property> _properties = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  final List<String> _locations = [
    'Lekki Phase 1, Lagos',
    'Old Ikoyi, Lagos',
    'Victoria Island, Lagos',
    'Ikeja GRA, Lagos',
    'Maitama, Abuja (FCT)',
    'Wuse 2, Abuja (FCT)',
    'Jabi, Abuja (FCT)',
  ];

  final List<Map<String, dynamic>> _directLandlords = [
    {
      'name': 'Chief Falana',
      'location': 'Ikoyi / Lekki',
      'verified': true,
      'deals': '12 Leased',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
    },
    {
      'name': 'Dr. Somto Eze',
      'location': 'Maitama, Abuja',
      'verified': true,
      'deals': '5 Sold',
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    },
    {
      'name': 'Mrs. Folashade',
      'location': 'Victoria Island',
      'verified': true,
      'deals': '8 Leased',
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    },
    {
      'name': 'Barr. Alabi',
      'location': 'Ikeja GRA',
      'verified': true,
      'deals': '4 Leased',
      'image': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=200&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  void _loadProperties() async {
    setState(() => _isLoading = true);
    final props = await ApiService.asyncFetchProperties(
      purpose: _selectedPurpose == 'all' ? null : _selectedPurpose,
    );
    setState(() {
      _properties = props;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadProperties(),
          color: AppColors.primaryLight,
          backgroundColor: AppColors.surfaceDark,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 1. Top App Bar with Location Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Location Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primaryLight),
                              const SizedBox(width: 4),
                              Text(
                                'CURRENT REGION',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLocation,
                              dropdownColor: AppColors.surfaceDark,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              items: _locations.map((loc) {
                                return DropdownMenuItem(value: loc, child: Text(loc));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedLocation = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Notification Bell with Badge
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderDark.withOpacity(0.6)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Anti-Agent Live Savings Ticker Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryLight.withOpacity(0.18),
                          AppColors.surfaceDark,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₦48,500,000+ SAVED FROM AGENT COMMISSIONS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryLight,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Direct landlords receive 100% rent. Flat 10% legal fee for tenants.',
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
                  ),
                ),
              ),

              // 3. Rent vs Buy Purpose Toggle Switcher
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildPurposeButton('all', 'All Listings'),
                        ),
                        Expanded(
                          child: _buildPurposeButton('rent', 'For Rent (10% Legal)'),
                        ),
                        Expanded(
                          child: _buildPurposeButton('sale', 'For Sale (5% Escrow)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. "Direct Verified Landlords" Stories Horizontal Carousel
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Verified Direct Owners',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Zero Middlemen',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 84,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _directLandlords.length,
                        itemBuilder: (context, index) {
                          final l = _directLandlords[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderDark.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: NetworkImage(l['image']),
                                    ),
                                    const Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Icon(Icons.check_circle, size: 14, color: AppColors.primaryLight),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l['name'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      l['deals'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        color: AppColors.primaryLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Featured Property Inventory Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Verified Direct Properties',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_properties.length} Available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Properties List
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primaryLight),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final prop = _properties[index];
                            return _buildPropertyCard(context, prop);
                          },
                          childCount: _properties.length,
                        ),
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeButton(String purpose, String label) {
    final isSelected = _selectedPurpose == purpose;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPurpose = purpose);
        _loadProperties();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Property prop) {
    final isRent = prop.purpose == 'rent';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(property: prop),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Badges
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  color: AppColors.cardDark,
                  child: Image.network(
                    prop.images.isNotEmpty ? prop.images[0] : '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.cardDark,
                      child: const Center(child: Icon(Icons.home_work_rounded, size: 40, color: Colors.grey)),
                    ),
                  ),
                ),

                // Top Tag Badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRent ? AppColors.primaryLight : const Color(0xFF0D9488),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isRent ? 'FOR RENT' : 'FOR SALE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          prop.propertyType.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // KYP Verified Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F382A).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 12, color: AppColors.primaryLight),
                        const SizedBox(width: 4),
                        Text(
                          'KYP AUDITED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Gradient Overlay for Title
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Location
                  Text(
                    prop.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.pin_drop_rounded, size: 12, color: AppColors.primaryLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${prop.neighborhood}, ${prop.state}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Specs (Bed, Bath, Toilets, Disco)
                  Row(
                    children: [
                      _buildSpecItem(Icons.bed_rounded, '${prop.bedrooms} Beds'),
                      const SizedBox(width: 14),
                      _buildSpecItem(Icons.bathtub_rounded, '${prop.bathrooms} Baths'),
                      const SizedBox(width: 14),
                      _buildSpecItem(Icons.electric_meter_rounded, 'Disco Verified'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Anti-Agent Savings Comparison Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDark.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Direct Owner Price',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '₦${_currencyFormat.format(prop.basePrice)}${isRent ? ' /yr' : ''}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),

                        // Green Savings Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'YOU SAVE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              Text(
                                '₦${_currencyFormat.format(prop.totalNairaSavedOnRentilly)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Card Actions (Book Inspection & Direct Call/Chat)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PropertyDetailScreen(property: prop),
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primaryLight),
                          label: Text(
                            'Book Inspection',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryLight.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PropertyDetailScreen(property: prop),
                              ),
                            );
                          },
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

  Widget _buildSpecItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
