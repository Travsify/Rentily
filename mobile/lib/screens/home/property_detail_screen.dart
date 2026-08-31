import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/property.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  bool _isBooking = false;
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) setState(() => _currentUser = u);
  }

  void _showInspectionModal() {
    String selectedDate = '2026-09-03';
    String selectedTime = '11:00 AM - 12:00 PM';
    final nameController = TextEditingController(text: _currentUser?.fullName ?? 'Rentilly Prospect');
    final phoneController = TextEditingController(text: _currentUser?.phoneNumber ?? '+234 812 000 0000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text('YOUR FULL NAME', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  Text('PHONE NUMBER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: phoneController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date
                  Text('PREFERRED DATE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedDate, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Time Slot
                  Text('SELECT TIME SLOT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
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
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            color: isSelected ? AppColors.primary : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
          ),
          child: Center(
            child: Text(
              time,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Security Pass Generated',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Show this 6-digit code to the estate security guards upon arrival.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
          // Photo Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textPrimary),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                prop.images.isNotEmpty ? prop.images[0] : '',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Details Body (All text in sharp Ink Black)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'C OF O & TITLE AUDITED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isRent ? 'FOR RENT' : 'FOR SALE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title (Ink Black)
                  Text(
                    prop.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: AppColors.accentOrange),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
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

                  // Financial Breakdown
                  Text(
                    'TRANSPARENT FINANCIAL BREAKDOWN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Direct Owner Base Price', '₦${_currencyFormat.format(prop.basePrice)}'),
                        if (prop.cautionFee > 0)
                          _buildPriceRow('Caution Deposit (Escrow Vault)', '₦${_currencyFormat.format(prop.cautionFee)}'),
                        if (prop.serviceCharge > 0)
                          _buildPriceRow('Service Charge', '₦${_currencyFormat.format(prop.serviceCharge)}'),
                        _buildPriceRow(
                          'Rentilly Legal & Escrow Fee (10%)',
                          '₦${_currencyFormat.format(prop.rentillyFee)}',
                          highlight: true,
                        ),
                        const Divider(color: AppColors.borderDark, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL PAYABLE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '₦${_currencyFormat.format(prop.totalInitialPayment)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Anti-Agent Savings Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.savings_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You save ₦${_currencyFormat.format(prop.totalNairaSavedOnRentilly)} in agent & agreement fees on Rentilly.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borderDark)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Landlord Price',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    Text(
                      '₦${_currencyFormat.format(prop.basePrice)}${isRent ? ' /yr' : ''}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _showInspectionModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Book Inspection', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSpec(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: highlight ? AppColors.primary : AppColors.textSecondary, fontWeight: highlight ? FontWeight.bold : FontWeight.w500)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: highlight ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }
}
