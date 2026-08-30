import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../services/api_service.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  bool _isBooking = false;
  String? _generatedGatePass;

  void _showInspectionModal() {
    String selectedDate = '2026-09-02';
    String selectedTime = '11:00 AM - 12:00 PM';
    final nameController = TextEditingController(text: 'Femi Adesanya');
    final phoneController = TextEditingController(text: '+234 812 345 6789');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Book Physical Inspection',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Get a 6-digit security gate pass code for estate security entry. Zero inspection fee charged.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  Text(
                    'SELECT INSPECTION DATE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.calendar_month, size: 16, color: AppColors.primaryLight),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Time Slot
                  Text(
                    'SELECT TIME SLOT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTimeSlotChip('10:00 AM', selectedTime, (t) => setModalState(() => selectedTime = t)),
                      const SizedBox(width: 8),
                      _buildTimeSlotChip('11:00 AM', selectedTime, (t) => setModalState(() => selectedTime = t)),
                      const SizedBox(width: 8),
                      _buildTimeSlotChip('02:00 PM', selectedTime, (t) => setModalState(() => selectedTime = t)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Submit Booking Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isBooking
                          ? null
                          : () async {
                              setModalState(() => _isBooking = true);
                              final res = await ApiService.bookInspection(
                                propertyId: widget.property.id,
                                scheduledDate: selectedDate,
                                scheduledTimeSlot: selectedTime,
                                prospectName: nameController.text,
                                prospectPhone: phoneController.text,
                              );
                              setModalState(() => _isBooking = false);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                if (res != null) {
                                  _showPassCodeDialog(res.inspectionPassCode);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _isBooking ? 'Generating Security Pass...' : 'Confirm & Generate Gate Pass',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeSlotChip(String time, String current, Function(String) onSelect) {
    final isSelected = current.startsWith(time);
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect('$time - ${time.startsWith('10') ? '11:00 AM' : '12:00 PM'}'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight.withOpacity(0.2) : AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : AppColors.borderDark,
            ),
          ),
          child: Center(
            child: Text(
              time,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPassCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, size: 36, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),
              Text(
                'Inspection Confirmed!',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Show this 6-digit gate code to the estate security guard upon arrival:',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prop = widget.property;
    final isRent = prop.purpose == 'rent';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // Collapsible HDR Photo Gallery AppBar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.backgroundDark,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bookmark_border_rounded, size: 18, color: Colors.white),
                ),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    prop.images.isNotEmpty ? prop.images[0] : '',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KYP Badge & Purpose
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 13, color: AppColors.primaryLight),
                            const SizedBox(width: 4),
                            Text(
                              'C OF O & TITLE AUDITED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isRent ? 'FOR RENT' : 'FOR SALE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isRent ? AppColors.primaryLight : const Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    prop.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primaryLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${prop.address}, ${prop.neighborhood}, ${prop.state}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Specs Grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetailSpec(Icons.bed_rounded, '${prop.bedrooms}', 'Bedrooms'),
                        _buildDetailSpec(Icons.bathtub_rounded, '${prop.bathrooms}', 'Bathrooms'),
                        _buildDetailSpec(Icons.chair_rounded, prop.furnishing.replaceAll('_', ' '), 'Furnishing'),
                        _buildDetailSpec(Icons.electric_meter_rounded, 'Verified', 'Disco Meter'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Transparent Anti-Agent Financial Breakdown
                  Text(
                    'TRANSPARENT FINANCIAL BREAKDOWN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Direct Owner Base Rent', '₦${_currencyFormat.format(prop.basePrice)}'),
                        if (prop.cautionFee > 0)
                          _buildPriceRow('Caution Deposit (Escrow Vault)', '₦${_currencyFormat.format(prop.cautionFee)}'),
                        if (prop.serviceCharge > 0)
                          _buildPriceRow('Service Charge', '₦${_currencyFormat.format(prop.serviceCharge)}'),
                        _buildPriceRow(
                          'Rentilly Legal & Tenancy Contract Fee (10%)',
                          '₦${_currencyFormat.format(prop.rentillyFee)}',
                          highlight: true,
                        ),
                        const Divider(color: AppColors.borderDark, height: 20),
                        _buildPriceRow(
                          'Total Move-In Escrow Payment',
                          '₦${_currencyFormat.format(prop.totalInitialPayment)}',
                          isBold: true,
                        ),
                        const SizedBox(height: 12),

                        // Anti-Agent Savings Banner
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Traditional 20% Agent Extortion:',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                              ),
                              Text(
                                '̶₦̶${_currencyFormat.format(prop.traditionalAgentCommission)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Direct Landlord Identity & Prembly Shield
                  Text(
                    'VERIFIED PROPERTY OWNER',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            prop.ownerName.isNotEmpty ? prop.ownerName[0] : 'O',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    prop.ownerName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_circle, size: 14, color: AppColors.primaryLight),
                                ],
                              ),
                              Text(
                                'Direct Landlord • NIN & BVN Verified via Prembly',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'ABOUT THIS PROPERTY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prop.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),

      // Sticky Bottom Action Bar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(top: BorderSide(color: AppColors.borderDark.withOpacity(0.5))),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showInspectionModal,
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: Text(
                  'Book Inspection',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSpec(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryLight),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: highlight ? AppColors.primaryLight : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isBold ? 13 : 11,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? AppColors.primaryLight : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
