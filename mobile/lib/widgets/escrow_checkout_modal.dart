import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/property.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/payment_security_service.dart';
import '../screens/my_spaces/my_spaces_screen.dart';
import 'add_money_modal.dart';
import 'verification_modal.dart';

class EscrowCheckoutModal extends StatefulWidget {
  final Property property;
  final UserProfile user;
  final VoidCallback? onEscrowSuccess;

  const EscrowCheckoutModal({
    super.key,
    required this.property,
    required this.user,
    this.onEscrowSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required Property property,
    required UserProfile user,
    VoidCallback? onEscrowSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EscrowCheckoutModal(
        property: property,
        user: user,
        onEscrowSuccess: onEscrowSuccess,
      ),
    );
  }

  @override
  State<EscrowCheckoutModal> createState() => _EscrowCheckoutModalState();
}

class _EscrowCheckoutModalState extends State<EscrowCheckoutModal> {
  final NumberFormat _currency = NumberFormat('#,###.00', 'en_US');
  final NumberFormat _currencyShort = NumberFormat('#,###', 'en_US');

  bool _isProcessing = false;
  UserProfile? _liveUser;
  final int _tenancyMonths = 12;

  @override
  void initState() {
    super.initState();
    _liveUser = widget.user;
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final fresh = await AuthService.refreshCurrentUser();
    if (fresh != null && mounted) {
      setState(() => _liveUser = fresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prop = widget.property;
    final user = _liveUser ?? widget.user;
    final isRent = prop.purpose.toLowerCase() == 'rent';

    final double basePrice = prop.basePrice;
    final double cautionFee = isRent ? prop.cautionFee : 0.0;
    final double serviceCharge = prop.serviceCharge;
    final double legalFee = isRent ? (basePrice * 0.10) : (basePrice * 0.05);
    final double totalPayable = basePrice + cautionFee + serviceCharge + legalFee;
    final double userBalance = user.walletBalance;
    final bool hasSufficientFunds = userBalance >= totalPayable;
    final double shortfall = totalPayable - userBalance;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle pill
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRent ? 'Rentilly Escrow Checkout' : 'Property Purchase Escrow',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '100% Guaranteed Anti-Scam Protection',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Property Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: prop.images.isNotEmpty
                        ? Image.network(
                            prop.images.first,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.apartment_rounded, color: AppColors.primary),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.apartment_rounded, color: AppColors.primary),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prop.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ', ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'TITLE VERIFIED',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ' Bed •  Bath',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: AppColors.textMuted,
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
            const SizedBox(height: 18),

            // Itemized Financial Breakdown
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
                  _buildCostRow(isRent ? 'Direct Owner Rent' : 'Direct Property Purchase', '₦'),
                  if (cautionFee > 0)
                    _buildCostRow('Caution Deposit (100% Escrow Vault)', '₦'),
                  if (serviceCharge > 0)
                    _buildCostRow('Itemized Service Charge', '₦'),
                  _buildCostRow(
                    isRent
                        ? 'Rentilly Protocol & State Legal Stamp (10%)'
                        : 'Buyer Legal & Title Perfection Fee (5%)',
                    '₦',
                    isHighlight: true,
                  ),
                  const Divider(color: AppColors.borderDark, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL AMOUNT DUE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '₦',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Wallet Balance Status Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasSufficientFunds ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasSufficientFunds ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasSufficientFunds ? Icons.account_balance_wallet_rounded : Icons.info_outline_rounded,
                            size: 16,
                            color: hasSufficientFunds ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Your Rentilly Wallet Balance',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasSufficientFunds ? const Color(0xFF15803D) : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₦',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: hasSufficientFunds ? const Color(0xFF15803D) : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  if (!hasSufficientFunds) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Shortfall: ₦. Top up your dedicated account or wallet to lock this property into escrow.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: const Color(0xFFB45309),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Anti-Scam Assurance Note
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your funds are held in CBN-regulated escrow. The landlord does NOT get paid until you inspect and accept the physical keys.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Button
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (hasSufficientFunds)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _executeEscrowLock(totalPayable, basePrice, cautionFee, serviceCharge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Pay & Lock ₦ in Escrow',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AddMoneyModal.show(context, user: user);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Top Up Wallet to Pay Escrow',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String title, String amount, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeEscrowLock(
    double totalPayable,
    double basePrice,
    double cautionFee,
    double serviceCharge,
  ) async {
    final user = _liveUser ?? widget.user;

    // 1. Check Identity Verification
    if (!user.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your BVN / NIN before locking funds in escrow.'),
          backgroundColor: Colors.orange,
        ),
      );
      VerificationModal.show(context, onSuccess: (updated) {
        setState(() => _liveUser = updated);
      });
      return;
    }

    // 2. Authorize via PIN or Biometrics
    final authorized = await PaymentSecurityService.authorizeTransaction(
      context,
      title: 'Lock Rent in Escrow',
      amount: totalPayable,
      recipient: widget.property.title,
    );

    if (!authorized) return;

    setState(() => _isProcessing = true);

    try {
      final res = await ApiService.payRentEscrow(
        propertyId: widget.property.id,
        tenantEmail: user.email,
        tenantName: user.fullName.isNotEmpty ? user.fullName : user.email.split('@')[0],
        basePrice: basePrice,
        cautionFee: cautionFee,
        serviceCharge: serviceCharge,
        tenancyDurationMonths: _tenancyMonths,
      );

      setState(() => _isProcessing = false);

      if (res['success'] == true) {
        HapticFeedback.heavyImpact();
        if (!mounted) return;

        // Close modal and show Escrow Certificate
        Navigator.of(context).pop();
        _showEscrowSuccessDialog(res['escrowReference'] ?? 'ESCROW-LOCK-2026', totalPayable);
        widget.onEscrowSuccess?.call();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Could not lock escrow payment.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unexpected error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEscrowSuccessDialog(String ref, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Rent Locked in Escrow!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₦ has been safely held in Rentilly Escrow for "".',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Ref: ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MySpacesScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'View in My Spaces',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
