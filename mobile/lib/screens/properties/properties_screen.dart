import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../services/api_service.dart';
import '../home/property_detail_screen.dart';

class PropertiesScreen extends StatefulWidget {
  final String initialPurpose; // 'rent' or 'sale'

  const PropertiesScreen({super.key, this.initialPurpose = 'rent'});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  late String _selectedPurpose;
  String _selectedState = 'All Nigeria';
  List<Property> _properties = [];
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
    'Cross River (Calabar)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPurpose = widget.initialPurpose;
    _loadProperties();
  }

  void _loadProperties() async {
    setState(() => _isLoading = true);
    final data = await ApiService.asyncFetchProperties(purpose: _selectedPurpose);
    setState(() {
      _properties = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Zero-Agent Properties Hub',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Purpose Selector (Rent / Lease vs Outright Sale)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPurposeChip('rent', 'For Rent / Lease (10% Legal)'),
                    ),
                    Expanded(
                      child: _buildPurposeChip('sale', 'For Sale (5% Escrow)'),
                    ),
                  ],
                ),
              ),
            ),

            // Nationwide State Filter Horizontal Chips
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: _states.length,
                  itemBuilder: (context, index) {
                    final st = _states[index];
                    final isSelected = _selectedState == st;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedState = st);
                        _loadProperties();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.2) : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryLight : AppColors.borderDark.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          st,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Property Listings View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      itemCount: _properties.length,
                      itemBuilder: (context, index) {
                        final prop = _properties[index];
                        final isRent = prop.purpose == 'rent';

                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: prop)),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Photo with Title Document Pill
                                Stack(
                                  children: [
                                    Container(
                                      height: 160,
                                      width: double.infinity,
                                      color: AppColors.cardDark,
                                      child: Image.network(
                                        prop.images.isNotEmpty ? prop.images[0] : '',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isRent ? 'RENTAL' : 'OUTRIGHT SALE',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.verified_user_rounded, size: 10, color: AppColors.primaryLight),
                                            const SizedBox(width: 4),
                                            Text(
                                              'C OF O VERIFIED',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Content Details
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prop.title,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${prop.neighborhood}, ${prop.state}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 10),

                                      // Pricing
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Direct Landlord Price',
                                                style: GoogleFonts.plusJakartaSans(fontSize: 8, color: AppColors.textMuted),
                                              ),
                                              Text(
                                                '₦${_currencyFormat.format(prop.basePrice)}${isRent ? ' /yr' : ''}',
                                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'SAVE ₦${_currencyFormat.format(prop.totalNairaSavedOnRentilly)}',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
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

  Widget _buildPurposeChip(String id, String label) {
    final isSelected = _selectedPurpose == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPurpose = id);
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
}
