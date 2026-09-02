import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
    String inspectionType = 'video'; // 'video' or 'in_person'
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Schedule Property Inspection',
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

                    // Inspection Mode Selector (4K Live Video vs In-Person Only)
                    Text('INSPECTION TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => inspectionType = 'video'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: inspectionType == 'video' ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: inspectionType == 'video' ? AppColors.primary : AppColors.borderDark,
                                  width: inspectionType == 'video' ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.videocam_rounded, size: 20, color: AppColors.primary),
                                  const SizedBox(height: 4),
                                  Text('4K Live Video', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('Landlord broadcast', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => inspectionType = 'in_person'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: inspectionType == 'in_person' ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: inspectionType == 'in_person' ? AppColors.primary : AppColors.borderDark,
                                  width: inspectionType == 'in_person' ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.directions_walk_rounded, size: 20, color: AppColors.primary),
                                  const SizedBox(height: 4),
                                  Text('In-Person Tour', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('Physical walkthrough', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Name
                    Text('YOUR FULL NAME', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
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
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date & Time
                    Text(
                      inspectionType == 'video' ? 'SCHEDULED BROADCAST WINDOW' : 'PREFERRED VISIT DATE',
                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
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
                          Text(
                            inspectionType == 'video' ? 'Today, 4:30 PM (WAT) Broadcast' : selectedDate,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          Icon(inspectionType == 'video' ? Icons.videocam_rounded : Icons.calendar_month, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit Booking Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isBooking
                            ? null
                            : () async {
                                setModalState(() => _isBooking = true);
                                if (inspectionType == 'video') {
                                  await Future.delayed(const Duration(milliseconds: 600));
                                  setModalState(() => _isBooking = false);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Registered for "${widget.property.title}" 4K Live Broadcast! You will receive notification before the landlord goes live.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                } else {
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
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isBooking
                              ? 'Booking...'
                              : (inspectionType == 'video' ? 'Confirm 4K Live Video Slot' : 'Confirm & Generate Gate Pass'),
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
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
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),

              // Mandatory Host Digital ID Directive Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_rounded, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Safety Directive: Always demand to see the host\'s official Rentilly Digital ID upon arrival. If they cannot produce their matching Digital ID, do NOT enter.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF78350F), fontWeight: FontWeight.w600, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Share Itinerary Button
              OutlinedButton.icon(
                onPressed: () {
                  Share.share(
                    '🛡️ RENTILLY PROPERTY INSPECTION SAFETY ITINERARY\n\n'
                    'I am currently going for a verified in-person property inspection. Details for safety tracking:\n\n'
                    '📍 Property: ${widget.property.title}\n'
                    '🏢 Address: ${widget.property.address}, ${widget.property.state}\n'
                    '🔑 Gate Pass Code: $code\n'
                    '👤 Listed By: ${widget.property.listedByRole == "verified_partner" ? "Corporate Partner (" + (widget.property.partnerBusinessName ?? "Verified Partner") + " • " + (widget.property.partnerCacNumber ?? "CAC Verified") + ")" : "Direct Landlord"}\n'
                    '🛡️ Safety Rule: I will demand the host presents their official Rentilly Digital ID before entry.\n\n'
                    'Live Verification: https://myrentilly.com/safety/inspection/$code',
                  );
                },
                icon: const Icon(Icons.share_location_rounded, size: 16, color: AppColors.primary),
                label: Text('Share Itinerary with Family / Friends 🛡️', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                  const SizedBox(height: 14),

                  // Listed By Attribution Card (Landlord vs Corporate Partner)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: prop.listedByRole == 'verified_partner' ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: prop.listedByRole == 'verified_partner' ? const Color(0xFFD97706).withValues(alpha: 0.1) : const Color(0xFF16A34A).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            prop.listedByRole == 'verified_partner' ? Icons.business_rounded : Icons.vpn_key_rounded,
                            size: 20,
                            color: prop.listedByRole == 'verified_partner' ? const Color(0xFFD97706) : const Color(0xFF16A34A),
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
                                    prop.listedByRole == 'verified_partner' ? 'Listed by Corporate Partner' : 'Listed by Landlord',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: prop.listedByRole == 'verified_partner' ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      prop.listedByRole == 'verified_partner' ? 'VERIFIED PARTNER 🏢' : 'DIRECT OWNER 🔑',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: prop.listedByRole == 'verified_partner' ? const Color(0xFF0369A1) : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                prop.listedByRole == 'verified_partner'
                                    ? '${prop.partnerBusinessName ?? "Rentilly Verified Corporate Partner"} • CAC: ${prop.partnerCacNumber ?? "RC 1928374"}'
                                    : 'Direct property owner verified via title audit and physical GPS inspection.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                        _buildPriceRow(isRent ? 'Direct Owner Rent' : 'Direct Property Purchase Price', '₦${_currencyFormat.format(prop.basePrice)}'),
                        if (isRent && prop.cautionFee > 0)
                          _buildPriceRow('Caution Deposit (100% Locked in Escrow Vault)', '₦${_currencyFormat.format(prop.cautionFee)}'),
                        if (prop.serviceCharge > 0)
                          _buildPriceRow('Itemized Service Charge', '₦${_currencyFormat.format(prop.serviceCharge)}'),
                        if (isRent)
                          _buildPriceRow(
                            'Rentilly Protocol & State Legal Stamp (10%)',
                            '₦${_currencyFormat.format(prop.rentillyFee)}',
                            highlight: true,
                          )
                        else
                          _buildPriceRow(
                            'Buyer Legal & Title Perfection Fee (5%)',
                            '₦${_currencyFormat.format(prop.buyerSalesLegalFee)}',
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
                              isRent
                                  ? '₦${_currencyFormat.format(prop.totalInitialPayment)}'
                                  : '₦${_currencyFormat.format(prop.basePrice + prop.buyerSalesLegalFee)}',
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
                            isRent
                                ? 'You pay ₦0 agency fee. Caution deposit is 100% held in Rentilly escrow and refunded at lease end.'
                                : 'You pay ₦0 agency fee. Seller pays 5% (2.0% Partner, 3.0% Platform); your 5% goes 100% to legal title perfection & Deed of Assignment.',
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
