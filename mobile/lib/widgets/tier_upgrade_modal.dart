import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class TierUpgradeModal extends StatefulWidget {
  final UserProfile user;
  final int currentTier;
  final VoidCallback? onSuccess;

  const TierUpgradeModal({
    super.key,
    required this.user,
    this.currentTier = 1,
    this.onSuccess,
  });

  static void show(
    BuildContext context, {
    required UserProfile user,
    int currentTier = 1,
    VoidCallback? onSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TierUpgradeModal(
        user: user,
        currentTier: currentTier,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<TierUpgradeModal> createState() => _TierUpgradeModalState();
}

class _TierUpgradeModalState extends State<TierUpgradeModal> {
  late int _tier;
  bool _isLoading = false;

  // Tier 2 Form Controllers
  final _addressController = TextEditingController();
  final _lgaController = TextEditingController();
  final _stateController = TextEditingController();

  // Tier 3 Form Controllers
  final _idNumberController = TextEditingController();
  String _selectedIdType = 'NIN';

  @override
  void initState() {
    super.initState();
    _tier = widget.currentTier;
    _refreshTier();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _lgaController.dispose();
    _stateController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _refreshTier() async {
    final status = await ApiService.fetchTierStatus(widget.user.email);
    if (mounted) {
      final serverTier = (status['tier'] as num?)?.toInt() ?? 0;
      if (serverTier > 0) {
        setState(() => _tier = serverTier);
      }
    }
  }

  Future<void> _handleTier2Upgrade() async {
    final address = _addressController.text.trim();
    final lga = _lgaController.text.trim();
    final state = _stateController.text.trim();

    if (address.isEmpty || lga.isEmpty || state.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in your address, LGA, and state.', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final res = await ApiService.upgradeTier2(
      email: widget.user.email,
      address: address,
      lga: lga,
      state: state,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() => _tier = 2);
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Successfully upgraded to Tier 2! Now you can unlock Tier 3 (₦5,000,000 limit).', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Tier 2 upgrade failed. Please try again.', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleTier3Upgrade() async {
    final idNumber = _idNumberController.text.trim();
    if (idNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your document / identity number.', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final res = await ApiService.upgradeTier3(
      email: widget.user.email,
      idType: _selectedIdType,
      idNumber: idNumber,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() => _tier = 3);
      widget.onSuccess?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? '🎉 Account upgraded to Tier 3! Your daily limit is now ₦5,000,000 with unlimited monthly volume.', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
          backgroundColor: const Color(0xFF0D5C46),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Tier 3 upgrade failed. Please check your document details.', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAlreadyTier3 = _tier >= 3;
    final bool isTier2 = _tier == 2;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0D5C46), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAlreadyTier3
                            ? 'Tier 3 Fully Verified'
                            : isTier2
                                ? 'Upgrade to Tier 3 (₦5,000,000)'
                                : 'Upgrade to Tier 2 (₦200,000)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAlreadyTier3
                            ? 'Maximum limit active • High-volume escrow enabled'
                            : 'CBN & Rentilly Settlement Rail Compliance',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tier Benefits Comparison Grid
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIMIT COMPARISON',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tier >= 3
                              ? const Color(0xFF0D5C46).withValues(alpha: 0.12)
                              : _tier == 2
                                  ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                                  : const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YOUR STATUS: TIER $_tier',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: _tier >= 3
                                ? const Color(0xFF0D5C46)
                                : _tier == 2
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTierPill('Tier 1', '₦50,000', 'Basic', _tier == 1),
                      const SizedBox(width: 8),
                      _buildTierPill('Tier 2', '₦200,000', 'Standard', _tier == 2),
                      const SizedBox(width: 8),
                      _buildTierPill('Tier 3', '₦5,000,000', 'Unlimited', _tier >= 3, isHighlight: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Already Tier 3 State
            if (isAlreadyTier3) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your account is at the highest institutional tier. You can transact up to ₦5,000,000 daily with zero interruptions.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF065F46),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // Tier 3 Upgrade Form (For users who are at Tier 2)
            else if (isTier2) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFF059669), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tier 2 verified! Upgrade to Tier 3 now to jump from ₦200,000 to ₦5,000,000 daily.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: const Color(0xFF065F46),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Government Issued ID Document',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedIdType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'NIN', child: Text('National Identity (NIN Slip)')),
                      DropdownMenuItem(value: 'PASSPORT', child: Text('International Passport')),
                      DropdownMenuItem(value: 'VOTERS_CARD', child: Text("Voter's Card (INEC)")),
                      DropdownMenuItem(value: 'DRIVERS_LICENSE', child: Text("Driver's License (FRSC)")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedIdType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildInputField('Document / ID Number', 'Enter your document or NIN number', _idNumberController),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleTier3Upgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Submit & Unlock ₦5,000,000 Limit',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ]
            // Tier 2 Form (For users who are Tier 0 or 1)
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Step 1 of 2: Upgrade to Tier 2 (₦200,000 limit), then immediately unlock Tier 3 (₦5,000,000 limit).',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildInputField('Residential Address', 'E.g. 15 Admiralty Way, Lekki Phase 1', _addressController),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildInputField('LGA', 'E.g. Eti-Osa', _lgaController)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInputField('State', 'E.g. Lagos', _stateController)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleTier2Upgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Upgrade to Tier 2 (₦200,000)',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierPill(String title, String limit, String desc, bool isCurrent, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight
              ? const Color(0xFFECFDF5)
              : isCurrent
                  ? Colors.white
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlight
                ? const Color(0xFF059669)
                : isCurrent
                    ? AppColors.primary
                    : const Color(0xFFE2E8F0),
            width: isHighlight || isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isHighlight ? const Color(0xFF059669) : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              limit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: isHighlight ? const Color(0xFF0D5C46) : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
