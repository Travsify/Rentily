import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/property.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';

class PartnerListingModal extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onListingCreated;

  const PartnerListingModal({
    super.key,
    required this.user,
    required this.onListingCreated,
  });

  static void show(BuildContext context, {required UserProfile user, required VoidCallback onListingCreated}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartnerListingModal(user: user, onListingCreated: onListingCreated),
    );
  }

  @override
  State<PartnerListingModal> createState() => _PartnerListingModalState();
}

class _PartnerListingModalState extends State<PartnerListingModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _cautionController = TextEditingController();
  final TextEditingController _serviceChargeController = TextEditingController();
  final TextEditingController _inspectionFeeController = TextEditingController(text: '3,000');
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _purpose = 'rent'; // 'rent' | 'sale'
  String _propertyType = 'flat_apartment';
  String _selectedState = 'Lagos';
  int _bedrooms = 2;
  int _bathrooms = 2;

  // Direct Landlord Title Verification Fields
  String _selectedTitleDoc = 'deed_of_assignment'; // 'c_of_o', 'governors_consent', 'deed_of_assignment', 'gazette', 'developer_deed'
  bool _hasUploadedTitleDoc = true;
  bool _hasUploadedElectricityBill = true;
  bool _agreedToTitleWarranty = true;

  // Partner Mandate Fields
  bool _hasUploadedPresencePhoto = true;
  bool _hasUploadedPowerOfAttorney = true;
  bool _isSubmitting = false;

  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _cautionController.dispose();
    _serviceChargeController.dispose();
    _inspectionFeeController.dispose();
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isDirectLandlord => widget.user.role == 'owner' || widget.user.role == 'landlord';
  double get _basePrice => double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0;
  double get _inspectionFee => double.tryParse(_inspectionFeeController.text.replaceAll(',', '')) ?? 3000.0;
  double get _partnerCommission => _purpose == 'rent' ? _basePrice * 0.025 : _basePrice * 0.02;

  void _handleSubmit() async {
    final title = _titleController.text.trim();
    final address = _addressController.text.trim();
    final price = _basePrice;
    final inspection = _inspectionFee;

    if (title.isEmpty || address.isEmpty || price <= 0) {
      _showToast('Please fill in property title, full address, and price.');
      return;
    }

    if (_isDirectLandlord && !_agreedToTitleWarranty) {
      _showToast('Please accept the Landlord Ownership & Title Warranty declaration.');
      return;
    }

    if (inspection > 5000) {
      _showToast('Inspection fee cannot exceed the ₦5,000 Rentilly platform ceiling.');
      return;
    }

    setState(() => _isSubmitting = true);

    // Compute address hash for single-listing exclusivity
    final cleanAddr = address.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final addressHash = sha256.convert(utf8.encode('$cleanAddr-$_selectedState')).toString();

    // 1. Perceptual Image & Media Fingerprint Hashing
    final uploadedImages = [
      'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800',
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
    ];
    final mediaFingerprints = uploadedImages.map((img) => sha256.convert(utf8.encode(img)).toString()).toList();

    final prefs = await SharedPreferences.getInstance();
    final existingHashes = prefs.getStringList('rentilly_listed_address_hashes') ?? [];
    final occupiedMediaHashes = prefs.getStringList('rentilly_occupied_media_hashes') ?? [];
    final activeMediaHashes = prefs.getStringList('rentilly_active_media_hashes') ?? [];

    // Check if address is duplicate
    if (existingHashes.contains(addressHash)) {
      setState(() => _isSubmitting = false);
      _showToast('Address Conflict: This property has already been registered on Rentilly.');
      return;
    }

    // Check if image media fingerprint belongs to an active or currently occupied/leased apartment
    final matchesOccupied = mediaFingerprints.any((fp) => occupiedMediaHashes.contains(fp));
    final matchesActive = mediaFingerprints.any((fp) => activeMediaHashes.contains(fp));

    if (matchesOccupied) {
      setState(() => _isSubmitting = false);
      await NotificationService.addNotification(
        title: 'Duplicate Media Security Flag 🛡️⚠️',
        message: 'The uploaded property photos match an occupied tenancy in Rentilly records. Re-listing occupied units is prohibited.',
        category: 'security',
      );
      _showToast('Security Alert: Images match an occupied property currently under lease.');
      return;
    }

    if (matchesActive) {
      setState(() => _isSubmitting = false);
      _showToast('Duplicate Media: These photos already exist on another active listing.');
      return;
    }

    // Store hashes
    existingHashes.add(addressHash);
    activeMediaHashes.addAll(mediaFingerprints);
    await prefs.setStringList('rentilly_listed_address_hashes', existingHashes);
    await prefs.setStringList('rentilly_active_media_hashes', activeMediaHashes);

    await Future.delayed(const Duration(milliseconds: 900));

    final newProp = Property(
      id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
      ownerId: widget.user.id,
      ownerName: widget.user.fullName,
      ownerPhone: widget.user.phoneNumber,
      title: title,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : 'Verified listing on Rentilly with 100% escrow protection and direct landlord verification.',
      purpose: _purpose,
      propertyType: _propertyType,
      basePrice: price,
      cautionFee: double.tryParse(_cautionController.text.replaceAll(',', '')) ?? (price * 0.1),
      serviceCharge: double.tryParse(_serviceChargeController.text.replaceAll(',', '')) ?? 0.0,
      rentillyFee: price * 0.025,
      totalInitialPayment: price + (double.tryParse(_cautionController.text.replaceAll(',', '')) ?? (price * 0.1)),
      paymentFrequency: 'annually',
      address: address,
      state: _selectedState,
      lga: 'Eti-Osa',
      neighborhood: address.split(',').first.trim(),
      bedrooms: _bedrooms,
      bathrooms: _bathrooms,
      toilets: _bathrooms,
      furnishing: 'semi_furnished',
      amenities: ['24/7 Power', 'Treated Water', 'Security Guard', 'CCTV'],
      images: uploadedImages,
      videoWalkthroughUrl: 'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4',
      status: 'available',
      listedByRole: _isDirectLandlord ? 'direct_landlord' : 'verified_partner',
      partnerCommissionRate: _isDirectLandlord ? 0.0 : (_purpose == 'rent' ? 0.025 : 0.02),
      inspectionFee: inspection,
      propertyAddressHash: addressHash,
    );

    if (_isDirectLandlord) {
      await NotificationService.addNotification(
        title: 'Title Audit Submitted 🔑📄',
        message: 'Your listing "$title" has been submitted for Land Registry Deed verification. Rentilly Legal is auditing your title.',
        category: 'property',
      );
    } else {
      await NotificationService.addNotification(
        title: 'Mandate Listing Submitted 🏢🛡️',
        message: 'Your mandate listing "$title" is submitted with single-partner exclusivity and locked 2.5% commission.',
        category: 'property',
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      widget.onListingCreated();
      Navigator.of(context).pop();

      _showSuccessDialog(newProp);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(Property prop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isDirectLandlord ? 'Title Audit Submitted! 🔑' : 'Mandate Listing Submitted! 🏢',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isDirectLandlord
                  ? 'Your property title and ownership deed have been submitted to Rentilly Legal Desk. Once verified, your listing goes live with the "TITLE VERIFIED 🔑" badge.'
                  : 'Your mandate listing is submitted under your accredited firm. All rent escrow payments guarantee your 2.5% rent commission upon tenant key handover.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Listing Hash: ${(prop.propertyAddressHash ?? prop.id).substring(0, 12)}...', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleHeader = _isDirectLandlord ? 'List Property (Direct Owner Title Audit) 🔑' : 'Add Property Under Mandate (Corporate Broker) 🏢';
    final subtitleHeader = _isDirectLandlord ? 'Zero agent fees • Direct verified title audit' : '2.5% rent / 2.0% sale commission locked in escrow';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_isDirectLandlord ? Icons.real_estate_agent_rounded : Icons.business_center_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleHeader,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          subtitleHeader,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scrollable Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Purpose Selector (Rent vs Sale)
                Text('1. LISTING PURPOSE', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPurposeChip('For Rent', 'rent'),
                    const SizedBox(width: 10),
                    _buildPurposeChip('For Sale', 'sale'),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Property Title & Type
                Text('2. PROPERTY TITLE & TYPE', style: _labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: _inputDeco(hint: 'e.g. Luxury 3-Bedroom Serviced Apartment with Pool'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _propertyType,
                        decoration: _inputDeco(hint: 'Type'),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'flat_apartment', child: Text('Flat / Apartment')),
                          DropdownMenuItem(value: 'duplex', child: Text('Duplex / Terrace')),
                          DropdownMenuItem(value: 'self_contain', child: Text('Self Contain')),
                          DropdownMenuItem(value: 'commercial', child: Text('Office / Commercial')),
                        ],
                        onChanged: (val) => setState(() => _propertyType = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: _inputDeco(hint: 'State'),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'Lagos', child: Text('Lagos')),
                          DropdownMenuItem(value: 'Abuja', child: Text('Abuja (FCT)')),
                          DropdownMenuItem(value: 'Ogun', child: Text('Ogun')),
                          DropdownMenuItem(value: 'Rivers', child: Text('Rivers (PH)')),
                          DropdownMenuItem(value: 'Oyo', child: Text('Oyo (Ibadan)')),
                        ],
                        onChanged: (val) => setState(() => _selectedState = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Pricing
                Text('3. ANNUAL RENT / SALE PRICE & INSPECTION FEE', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: _inputDeco(hint: _purpose == 'rent' ? 'Annual Rent: e.g. 3,500,000' : 'Sale Price: e.g. 85,000,000'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _inspectionFeeController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: _inputDeco(hint: 'Max ₦5,000'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '💡 Inspection fees are held in escrow and released only after the verified tour is completed.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),

                // 4. Caution & Service Charge Disclosure
                Text('4. CAUTION DEPOSIT & SERVICE CHARGE', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cautionController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(hint: 'Caution: e.g. 350,000'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _serviceChargeController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(hint: 'Service: e.g. 200,000'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '🔒 100% of Caution Deposit is held in Rentilly Escrow. Neither the landlord nor partner touches it.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),

                // 5. Full Address (Used for Exclusivity Hash)
                Text('5. EXACT PHYSICAL ADDRESS', style: _labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                  decoration: _inputDeco(hint: 'e.g. Flat 3B, Plot 14 Admiralty Way, Lekki Phase 1'),
                ),
                const SizedBox(height: 18),

                // 6. Role-Tailored Verification Section
                if (_isDirectLandlord) ...[
                  // Direct Landlord Title & Deed Verification Standard
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Text('DIRECT OWNER TITLE AUDIT (ADMIN VERIFIED)', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF166534))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'To eliminate fake landlords and unauthorized agents, direct owners provide proof of ownership and meter access before listings go live.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF14532D), height: 1.35),
                        ),
                        const SizedBox(height: 12),

                        // Title Document Selector
                        Text('TITLE DOCUMENT TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedTitleDoc,
                          decoration: InputDecoration(
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'c_of_o', child: Text('Certificate of Occupancy (C of O)')),
                            DropdownMenuItem(value: 'governors_consent', child: Text('Governor\'s Consent')),
                            DropdownMenuItem(value: 'deed_of_assignment', child: Text('Deed of Assignment / Conveyance')),
                            DropdownMenuItem(value: 'gazette', child: Text('Land Purchase Receipt / Family Gazette')),
                            DropdownMenuItem(value: 'developer_deed', child: Text('Building Plan Approval / Developer Deed')),
                          ],
                          onChanged: (val) => setState(() => _selectedTitleDoc = val!),
                        ),
                        const SizedBox(height: 12),

                        // Upload Status Badges
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.description_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text('Title Document Attached 📄', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.electric_bolt_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text('Recent Meter Bill Attached ⚡', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Legal Warranty Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agreedToTitleWarranty,
                              activeColor: const Color(0xFF16A34A),
                              onChanged: (val) => setState(() => _agreedToTitleWarranty = val ?? true),
                            ),
                            Expanded(
                              child: Text(
                                'I legally warrant that I am the bonafide title owner with unencumbered authority to lease/sell this unit under Lagos Tenancy Law 2011.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF14532D), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Partner Mandate & Anti-Ghost Physical Proof
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('CORPORATE MANDATE & ANTI-GHOST SHIELD', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'To eliminate ghost listings and protect renters, corporate partners must upload an in-property selfie and signed Power of Attorney from the owner.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.35),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.camera_alt_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text('Partner in Property Photo', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.assignment_turned_in_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text('Power of Attorney / Mandate', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // 7. Payout Transparency Box
                if (_basePrice > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isDirectLandlord ? 'LANDLORD DIRECT ESCROW PAYOUT' : 'PARTNER COMMISSIONS DISBURSEMENT',
                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80), letterSpacing: 0.8),
                            ),
                            Text(
                              _isDirectLandlord ? '100% NET RENT' : (_purpose == 'rent' ? '2.5% ON RENT' : '2.0% ON SALE'),
                              style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isDirectLandlord
                              ? '₦${_currencyFormat.format(_basePrice)} Direct Rent Settlement'
                              : '₦${_currencyFormat.format(_partnerCommission)} Automated Commission',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isDirectLandlord
                              ? '100% of rent is disbursed into your dedicated virtual account upon tenant key confirmation. ₦0 agency deductions.'
                              : 'Disbursed automatically by Rentilly escrow upon tenant move-in and key confirmation. Zero paperwork.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            _isDirectLandlord ? 'Submit Property for Title Audit 🔑' : 'Submit Mandate Listing 🏢',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeChip(String label, String value) {
    final isSelected = _purpose == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _purpose = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      );
}
