import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/nigerian_states_cities.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class ExternalLegalOrderModal extends StatefulWidget {
  final UserProfile user;
  final String? preselectedService; // 'single_doc_50k' | 'multi_doc_100k' | 'doc_preparation_3pct'
  final VoidCallback onOrderSubmitted;

  const ExternalLegalOrderModal({
    super.key,
    required this.user,
    this.preselectedService,
    required this.onOrderSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    String? preselectedService,
    required VoidCallback onOrderSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => ExternalLegalOrderModal(
        user: user,
        preselectedService: preselectedService,
        onOrderSubmitted: onOrderSubmitted,
      ),
    );
  }

  @override
  State<ExternalLegalOrderModal> createState() => _ExternalLegalOrderModalState();
}

class _ExternalLegalOrderModalState extends State<ExternalLegalOrderModal> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  late String _selectedService; // 'single_doc_50k' | 'multi_doc_100k' | 'doc_preparation_3pct'

  final TextEditingController _propertyTitleController = TextEditingController();
  final TextEditingController _propertyAddressController = TextEditingController();
  final TextEditingController _propertyValueController = TextEditingController(text: '50,000,000');
  final TextEditingController _notesController = TextEditingController();

  String _selectedState = 'Lagos';
  String _selectedDocType = 'Deed of Assignment';
  bool _isLoading = false;

  final List<String> _docTypes = [
    'Deed of Assignment',
    'Registered Survey Plan',
    'Certificate of Occupancy (C of O)',
    'Governor\'s Consent Document',
    'Gazette / Excision Document',
    'Power of Attorney',
    'Purchase Receipt / Family Deed',
    'Probate / Letter of Administration',
  ];

  @override
  void initState() {
    super.initState();
    _selectedService = widget.preselectedService ?? 'single_doc_50k';
  }

  @override
  void dispose() {
    _propertyTitleController.dispose();
    _propertyAddressController.dispose();
    _propertyValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _propertyValuation {
    final raw = double.tryParse(_propertyValueController.text.replaceAll(',', '').trim()) ?? 0;
    return raw;
  }

  double get _calculatedFee {
    if (_selectedService == 'single_doc_50k') return 50000.0;
    if (_selectedService == 'multi_doc_100k') return 100000.0;
    // Exactly 3% of entered property worth (not pegged from ₦150,000)
    final fee = (_propertyValuation * 0.03).roundToDouble();
    return fee > 0 ? fee : 0.0;
  }

  bool get _hasSufficientBalance => widget.user.walletBalance >= _calculatedFee;
  double get _shortfall => _calculatedFee - widget.user.walletBalance;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final title = _propertyTitleController.text.trim();
    final address = _propertyAddressController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the external property title / name.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the external property location/address.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!_hasSufficientBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet balance. Please transfer ₦${_currencyFormat.format(_shortfall)} to your virtual account to settle fee.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ApiService.createExternalLegalOrder(
      userId: widget.user.id,
      email: widget.user.email,
      fullName: widget.user.fullName,
      phoneNumber: widget.user.phoneNumber,
      serviceType: _selectedService,
      propertyTitle: title,
      propertyAddress: address,
      propertyState: _selectedState,
      propertyValue: _selectedService == 'doc_preparation_3pct' ? _propertyValuation : null,
      documentType: _selectedDocType,
      additionalNotes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['status'] == true || res['success'] == true) {
      Navigator.of(context).pop();
      widget.onOrderSubmitted();

      NotificationService.addNotification(
        title: '⚖️ Legal Service Request Submitted!',
        message: '₦${_currencyFormat.format(_calculatedFee)} debited from wallet. Rentilly Legal Desk is now reviewing your docket.',
        category: 'legal',
      );

      // Success Dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Docket Opened & Assigned! ⚖️',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Your request has been routed to Rentilly Legal Desk & accredited NBA counsel. You can track progress and download your certified search report directly in the Legal Hub.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fee Settled from Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                    Text('₦${_currencyFormat.format(_calculatedFee)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Done', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? res['message'] ?? 'Failed to submit legal request.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'External Legal & Title Desk',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Independent due diligence & drafting for external deals',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Service Selector Cards (3 options)
            Text('SELECT EXTERNAL LEGAL SERVICE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),

            _buildServiceOption(
              id: 'single_doc_50k',
              title: 'Single Document Verification',
              priceTag: '₦50,000 Flat',
              desc: 'Check validity of 1 document (Deed, Survey Plan, Court Judgment, or Receipt)',
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: 8),

            _buildServiceOption(
              id: 'multi_doc_100k',
              title: 'Comprehensive Title & Registry Search',
              priceTag: '₦100,000 Flat',
              desc: 'Full Land Registry & Surveyor General charting search across Lagos/Abuja + Certified Opinion',
              icon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 8),

            _buildServiceOption(
              id: 'doc_preparation_3pct',
              title: 'Real Estate Legal Document Preparation',
              priceTag: '3% of Property Value',
              desc: 'Custom drafting of Deed of Assignment, Contract of Sale & Governor\'s Consent docket',
              icon: Icons.history_edu_rounded,
            ),
            const SizedBox(height: 16),

            // If 3% Document Preparation Selected -> Property Valuation Input
            if (_selectedService == 'doc_preparation_3pct') ...[
              Text('EXTERNAL PROPERTY VALUATION / PURCHASE PRICE (₦)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Text('₦', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _propertyValueController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '50,000,000'),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _propertyValuation > 0
                            ? '3% Fee: ₦${_currencyFormat.format(_calculatedFee)} (Auto-calculated)'
                            : 'Enter property worth above to auto-calculate the 3% legal drafting fee.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Property Details Input
            Text('EXTERNAL PROPERTY TITLE & LOCATION', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            TextField(
              controller: _propertyTitleController,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g. 4-Bedroom Duplex in Lekki Phase 1',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _propertyAddressController,
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Plot / Street Address / Landmark (e.g. Plot 12 Admiralty Way)',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),

            // State Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedState,
                  isExpanded: true,
                  items: NigerianStatesLgas.states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedState = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Document Type Selector
            Text('PRIMARY DOCUMENT TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDocType,
                  isExpanded: true,
                  items: _docTypes.map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 12.5)))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDocType = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Additional Notes
            Text('ADDITIONAL NOTES / SELLER CONTACT INFO (OPTIONAL)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Enter any family estate details, survey plan numbers, or specific covenants to include...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Wallet Balance Status & Shortfall Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasSufficientBalance ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _hasSufficientBalance ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _hasSufficientBalance ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _hasSufficientBalance ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rentilly Wallet Balance:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₦${_currencyFormat.format(widget.user.walletBalance)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _hasSufficientBalance ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // If Insufficient Wallet Balance -> Show Virtual Bank Transfer Details
            if (!_hasSufficientBalance) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Card payments disabled. Fund via Bank Transfer:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Bank Name', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                              Text(widget.user.bankName ?? 'Wema Bank / Rentilly MFB', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Account Number', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                              Row(
                                children: [
                                  Text(widget.user.accountNumber ?? '0123456789', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _copyToClipboard(widget.user.accountNumber ?? '0123456789', 'Account number'),
                                    child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Account Name', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                              Text(widget.user.fullName, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Transfer ₦${_currencyFormat.format(_shortfall)} to the account above to fund your wallet, then tap Submit.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF92400E), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading || !_hasSufficientBalance ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _hasSufficientBalance
                            ? 'Pay ₦${_currencyFormat.format(_calculatedFee)} from Wallet 🔒'
                            : 'Fund Wallet (Shortfall: ₦${_currencyFormat.format(_shortfall)})',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceOption({
    required String id,
    required String title,
    required String priceTag,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _selectedService == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedService = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? AppColors.primary : const Color(0xFF475569), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          priceTag,
                          style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
