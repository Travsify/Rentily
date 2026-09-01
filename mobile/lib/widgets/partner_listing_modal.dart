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

  double get _basePrice => double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0;
  double get _inspectionFee => double.tryParse(_inspectionFeeController.text.replaceAll(',', '')) ?? 3000.0;
  double get _partnerCommission => _purpose == 'rent' ? _basePrice * 0.025 : _basePrice * 0.02; // 2.5% on rent, 2.0% on sale

  void _handleSubmit() async {
    final title = _titleController.text.trim();
    final address = _addressController.text.trim();
    final price = _basePrice;
    final inspection = _inspectionFee;

    if (title.isEmpty || address.isEmpty || price <= 0) {
      _showToast('Please fill in property title, full address, and price.');
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

    final prefs = await SharedPreferences.getInstance();
    final existingHashes = prefs.getStringList('rentilly_listed_address_hashes') ?? [];

    if (existingHashes.contains(addressHash)) {
      setState(() => _isSubmitting = false);
      _showToast('This property has already been exclusively registered by a verified partner.');
      return;
    }

    final newProperty = Property(
      id: 'PROP_${DateTime.now().millisecondsSinceEpoch}',
      ownerId: widget.user.id,
      ownerName: widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Direct Property Owner',
      ownerPhone: widget.user.phoneNumber,
      title: title,
      description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : 'Verified luxury property listed with 0% tenant agency fee.',
      purpose: _purpose,
      propertyType: _propertyType,
      basePrice: price,
      cautionFee: double.tryParse(_cautionController.text.replaceAll(',', '')) ?? (price * 0.10),
      serviceCharge: double.tryParse(_serviceChargeController.text.replaceAll(',', '')) ?? 0.0,
      rentillyFee: price * 0.10,
      totalInitialPayment: price * 1.10,
      paymentFrequency: 'yearly',
      address: address,
      state: _selectedState,
      lga: 'Eti-Osa',
      neighborhood: address.split(',').first,
      bedrooms: _bedrooms,
      bathrooms: _bathrooms,
      toilets: _bathrooms,
      furnishing: 'semi-furnished',
      amenities: ['24/7 Power', 'Gated Security', 'Treated Water', 'Dedicated Parking'],
      images: [
        'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800',
        'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
      ],
      status: 'active',
      verifiedAt: DateTime.now().toIso8601String(),
      listedByRole: widget.user.role == 'partner' ? 'verified_partner' : 'direct_landlord',
      partnerId: widget.user.role == 'partner' ? widget.user.id : null,
      partnerName: widget.user.role == 'partner' ? (widget.user.businessName ?? widget.user.fullName) : null,
      partnerCommissionRate: _purpose == 'rent' ? 0.025 : 0.01,
      partnerPresencePhotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      powerOfAttorneyUrl: 'https://rentilly.ng/docs/mandate_verified.pdf',
      inspectionFee: inspection > 5000 ? 5000 : inspection,
      propertyAddressHash: addressHash,
    );

    // Save property to locally persisted list
    final savedProps = prefs.getString('rentilly_custom_properties');
    List<Map<String, dynamic>> propList = [];
    if (savedProps != null) {
      try {
        final List<dynamic> decoded = json.decode(savedProps);
        propList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    propList.insert(0, newProperty.toJson());
    await prefs.setString('rentilly_custom_properties', json.encode(propList));

    existingHashes.add(addressHash);
    await prefs.setStringList('rentilly_listed_address_hashes', existingHashes);

    await NotificationService.addNotification(
      title: 'Property Listing Submitted 🏢📋',
      message: 'Your listing for "$title" in $_selectedState was submitted. 2.5% Partner Commission: ₦${_currencyFormat.format(_partnerCommission)} upon tenant key handover.',
      category: 'property',
      metadata: {
        'property_title': title,
        'commission_share': '₦${_currencyFormat.format(_partnerCommission)}',
        'inspection_cap': '₦${_currencyFormat.format(inspection)} (Escrow)',
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onListingCreated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Property listing registered under single-partner exclusivity!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.accentOrange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'List Property (Landlord / Partner) 🏢',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '2.5% Rental / 1.0% Sales Commission • ₦0 Tenant Agency',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
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

          // Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Purpose (Rent vs Sale)
                Text('1. LISTING PURPOSE', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _purpose = 'rent'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _purpose == 'rent' ? AppColors.primary : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _purpose == 'rent' ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Column(
                            children: [
                              Text('For Rent / Lease 🔑', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: _purpose == 'rent' ? Colors.white : AppColors.textPrimary)),
                              Text('2.5% Partner Share', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: _purpose == 'rent' ? Colors.white70 : AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _purpose = 'sale'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _purpose == 'sale' ? AppColors.primary : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _purpose == 'sale' ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Column(
                            children: [
                              Text('For Outright Sale 🏡', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: _purpose == 'sale' ? Colors.white : AppColors.textPrimary)),
                              Text('2.0% Partner (3% Platform)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: _purpose == 'sale' ? Colors.white70 : AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Title & Type
                Text('2. PROPERTY TITLE & TYPE', style: _labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: _inputDeco(hint: 'e.g. Luxury 3 Bedroom Serviced Apartment'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _propertyType,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(),
                        items: const [
                          DropdownMenuItem(value: 'flat_apartment', child: Text('Flat / Apartment')),
                          DropdownMenuItem(value: 'duplex', child: Text('Duplex / Terrace')),
                          DropdownMenuItem(value: 'mini_flat', child: Text('Self-Contained Mini Flat')),
                          DropdownMenuItem(value: 'commercial', child: Text('Commercial Office / Shop')),
                        ],
                        onChanged: (v) => setState(() => _propertyType = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedState,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _inputDeco(),
                        items: ['Lagos', 'Abuja FCT', 'Rivers', 'Oyo', 'Ogun', 'Enugu'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedState = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Price & Strict Inspection Fee Cap (Max ₦5,000)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('3. BASE PRICE & INSPECTION FEE', style: _labelStyle),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                      child: Text('MAX INSPECTION: ₦5,000', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: const Color(0xFFB45309))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: _inputDeco(hint: 'Rent: e.g. 3,500,000'),
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
                Text('4. CAUTION DEPOSIT & ITEMIZED SERVICE CHARGE', style: _labelStyle),
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
                Text('5. EXACT PHYSICAL ADDRESS (SINGLE-PARTNER EXCLUSIVITY)', style: _labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                  decoration: _inputDeco(hint: 'e.g. Flat 3B, Plot 14 Admiralty Way, Lekki Phase 1'),
                ),
                const SizedBox(height: 18),

                // 6. Anti-Ghost Listing Shield (Admin-Only Proof)
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
                          Text('ANTI-GHOST LISTING SHIELD (ADMIN ONLY)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'To protect renters against ghost listings and stolen photos, partners must upload physical proof. Visible ONLY to Rentilly Admin.',
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
                const SizedBox(height: 18),

                // 7. Live Partner Payout Calculation Box
                if (_basePrice > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Partner Payout (${_purpose == 'rent' ? '2.5% from Rentilly' : '2.0% from Seller 5%'}):',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₦${_currencyFormat.format(_partnerCommission)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _purpose == 'rent'
                              ? '• Tenant pays 10% platform fee (2.5% to you, 2.5% platform, 5% state legal stamp).'
                              : '• Seller pays 5% (2.0% to you, 3.0% platform). Buyer pays 5% exclusively for legal & title documents.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_rounded, size: 18, color: AppColors.accentOrange),
                            const SizedBox(width: 8),
                            Text(
                              'Submit Listing for Verification',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  InputDecoration _inputDeco({String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
    );
  }
}
