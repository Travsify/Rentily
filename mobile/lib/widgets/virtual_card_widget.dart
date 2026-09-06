import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class VirtualCardWidget extends StatefulWidget {
  final String? cardId;
  final String cardholderName;
  final String maskedPan;
  final String fullPan;
  final String expiryMonth;
  final String expiryYear;
  final String cvv;
  final double balance;
  final String currency;
  final String brand;
  final bool isFrozen;
  final VoidCallback onFundCard;
  final VoidCallback onToggleFreeze;

  const VirtualCardWidget({
    super.key,
    this.cardId,
    required this.cardholderName,
    required this.maskedPan,
    this.fullPan = '',
    this.expiryMonth = '08',
    this.expiryYear = '29',
    this.cvv = '819',
    required this.balance,
    this.currency = 'USD',
    this.brand = 'VISA',
    this.isFrozen = false,
    required this.onFundCard,
    required this.onToggleFreeze,
  });

  @override
  State<VirtualCardWidget> createState() => _VirtualCardWidgetState();
}

class _VirtualCardWidgetState extends State<VirtualCardWidget> {
  bool _showFullDetails = false;
  bool _isLoadingDetails = false;
  String? _revealedPan;
  String? _revealedCvv;
  String? _revealedExpM;
  String? _revealedExpY;

  @override
  void initState() {
    super.initState();
    _loadCachedCredentials();
  }

  Future<void> _loadCachedCredentials() async {
    final cid = widget.cardId;
    if (cid == null || cid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('rentilly_revealed_card_$cid');
      if (cached != null) {
        final map = json.decode(cached);
        if (mounted) {
          setState(() {
            _revealedPan = map['fullPan'];
            _revealedCvv = map['cvv'];
            _revealedExpM = map['expiryMonth'];
            _revealedExpY = map['expiryYear'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleReveal() async {
    HapticFeedback.lightImpact();
    if (_showFullDetails) {
      setState(() => _showFullDetails = false);
      return;
    }

    // Check if we already have real PAN
    final hasPan = (_revealedPan != null && _revealedPan!.isNotEmpty) ||
        (widget.fullPan.isNotEmpty && !widget.fullPan.contains('0000') && !widget.fullPan.contains('•'));

    if (hasPan) {
      setState(() => _showFullDetails = true);
      return;
    }

    // If cardId is available, call reveal-details endpoint
    final cid = widget.cardId;
    if (cid != null && cid.isNotEmpty) {
      setState(() => _isLoadingDetails = true);
      try {
        final details = await ApiService.revealCardDetails(cid);
        if (details != null && mounted) {
          final pan = details['fullPan']?.toString();
          final cvv = details['cvv']?.toString();
          final expM = details['expiryMonth']?.toString();
          final expY = details['expiryYear']?.toString();

          setState(() {
            _revealedPan = pan;
            _revealedCvv = cvv;
            _revealedExpM = expM;
            _revealedExpY = expY;
            _showFullDetails = true;
            _isLoadingDetails = false;
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('rentilly_revealed_card_$cid', json.encode(details));
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _showFullDetails = true;
        });
      }
    } else {
      setState(() => _showFullDetails = true);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label Copied: $text',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = widget.currency == 'USD' ? '\$' : '₦';
    final isVisa = widget.brand.toUpperCase().contains('VISA');

    return Column(
      children: [
        // 3D Obsidian-Emerald Virtual Card Container
        Container(
          width: double.infinity,
          height: 205,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF042018), // Deep Forest Obsidian
                Color(0xFF0D5C46), // Rentilly Deep Emerald
                Color(0xFF07382B), // Institutional Teal
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF042018).withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Card Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              'RENTILLY GLOBAL',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isFrozen) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withOpacity(0.4), width: 0.8),
                          ),
                          child: Text(
                            'FROZEN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    isVisa ? 'VISA' : 'Mastercard',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              // Chip & Contactless Row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5C07B),
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.wifi_tethering, size: 16, color: Colors.white.withOpacity(0.6)),
                ],
              ),

              // Card Number (PAN)
              Builder(builder: (context) {
                final displayPan = _showFullDetails
                    ? (_revealedPan ?? (widget.fullPan.isNotEmpty && !widget.fullPan.contains('0000') ? widget.fullPan : widget.maskedPan))
                    : widget.maskedPan;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _copyToClipboard(
                            _showFullDetails ? displayPan.replaceAll(' ', '') : widget.maskedPan,
                            'Card Number',
                          ),
                          child: Text(
                            displayPan,
                            style: GoogleFonts.shareTechMono(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoadingDetails ? null : _toggleReveal,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isLoadingDetails
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                  )
                                : Icon(
                                    _showFullDetails ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),

              // Card Footer: Cardholder Name, Expiry, CVV & Balance
              Builder(builder: (context) {
                final displayCvv = _showFullDetails
                    ? (_revealedCvv ?? (widget.cvv != '000' && widget.cvv.isNotEmpty ? widget.cvv : '•••'))
                    : '•••';
                final displayExpM = _revealedExpM ?? widget.expiryMonth;
                final displayExpY = _revealedExpY ?? widget.expiryYear;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CARDHOLDER',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.cardholderName.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPIRES',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$displayExpM/$displayExpY',
                              style: GoogleFonts.shareTechMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CVV',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              displayCvv,
                              style: GoogleFonts.shareTechMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'BALANCE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$currencySymbol${widget.balance.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Action Tray
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onFundCard,
                icon: const Icon(Icons.add_card_rounded, size: 14, color: AppColors.primary),
                label: Text(
                  'Fund Card',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onToggleFreeze,
                icon: Icon(
                  widget.isFrozen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  size: 14,
                  color: widget.isFrozen ? AppColors.accentOrange : AppColors.textSecondary,
                ),
                label: Text(
                  widget.isFrozen ? 'Unfreeze' : 'Freeze Card',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.isFrozen ? AppColors.accentOrange : AppColors.textSecondary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
