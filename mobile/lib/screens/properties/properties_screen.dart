import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../services/api_service.dart';
import '../../widgets/rentilly_bottom_bar.dart';
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
    if (mounted) {
      setState(() {
        _properties = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Zero-Agent Properties Hub',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: const RentillyBottomBar(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            // Top Purpose Selector (Rent vs Outright Sale)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
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

            // Nationwide State Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                height: 34,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.borderDark,
                          ),
                        ),
                        child: Text(
                          st,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      height: 160,
                                      width: double.infinity,
                                      color: const Color(0xFFF3F4F6),
                                      child: Image.network(
                                        prop.images.isNotEmpty ? prop.images[0] : '',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isRent ? 'RENTAL' : 'OUTRIGHT SALE',
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
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.verified, size: 12, color: AppColors.primaryLight),
                                            const SizedBox(width: 4),
                                            Text(
                                              'VERIFIED OWNER',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prop.title,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${prop.neighborhood}, ${prop.state}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Direct Landlord Price',
                                                style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textMuted),
                                              ),
                                              Text(
                                                '₦${_currencyFormat.format(prop.basePrice)}${isRent ? ' /yr' : ''}',
                                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentOrange.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'SAVE ₦${_currencyFormat.format(prop.totalNairaSavedOnRentilly)}',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
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
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
