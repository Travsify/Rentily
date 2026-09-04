import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/statement_pdf_service.dart';

class TransactionReceiptModal extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final UserProfile user;
  final String currency;

  const TransactionReceiptModal({
    super.key,
    required this.transaction,
    required this.user,
    this.currency = 'NGN',
  });

  static void show(BuildContext context, {
    required Map<String, dynamic> transaction,
    required UserProfile user,
    String currency = 'NGN',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionReceiptModal(
        transaction: transaction,
        user: user,
        currency: currency,
      ),
    );
  }

  @override
  State<TransactionReceiptModal> createState() => _TransactionReceiptModalState();
}

class _TransactionReceiptModalState extends State<TransactionReceiptModal> {
  bool _isExporting = false;
  static final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');

  String _getCurrencySymbol(String curr) {
    switch (curr.toUpperCase()) {
      case 'USDT':
      case 'USD':
      case 'CARD_USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'EUR':
        return '€';
      case 'NGN':
      default:
        return '₦';
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _isExporting = true);
    try {
      await StatementPdfService.downloadOrPrintReceipt(
        context,
        transaction: widget.transaction,
        user: widget.user,
        currency: widget.currency,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate receipt PDF: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isExporting = true);
    try {
      await StatementPdfService.shareReceipt(
        transaction: widget.transaction,
        user: widget.user,
        currency: widget.currency,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share receipt: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final rawAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final isCredit = tx['isCredit'] == true ||
        (tx['type'] ?? '').toString().toLowerCase().contains('credit') ||
        (tx['type'] ?? '').toString().toLowerCase().contains('inflow') ||
        (tx['type'] ?? '').toString().toLowerCase().contains('deposit') ||
        (tx['type'] ?? '').toString().toLowerCase().contains('commission') ||
        (tx['type'] ?? '').toString().toLowerCase().contains('top');

    final rawTitle = (tx['title'] ?? tx['narration'] ?? tx['type'] ?? (isCredit ? 'Escrow Inflow' : 'Wallet Withdrawal')).toString();

    // Extract any transaction fee so that shared receipts strictly contain the sent amount
    double feeAmount = 0.0;
    if (tx['fee'] != null) {
      feeAmount = (tx['fee'] as num).toDouble();
    } else {
      final feeMatch = RegExp(r'(?:Incl\.\s*₦?|Fee:\s*₦?|Fee\s*\(?₦?)([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(rawTitle);
      if (feeMatch != null) {
        final feeStr = feeMatch.group(1)!.replaceAll(',', '');
        feeAmount = double.tryParse(feeStr) ?? 0.0;
      }
    }

    final sentAmount = (rawAmount > feeAmount && feeAmount > 0) ? (rawAmount - feeAmount) : rawAmount;
    final cleanTitle = rawTitle
        .replaceAll(RegExp(r'\s*[•·-]\s*Incl\.\s*₦?[0-9,]+(?:\.[0-9]+)?\s*Fee', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Incl\.\s*₦?[0-9,]+(?:\.[0-9]+)?\s*Fee\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Fee:\s*₦?[0-9,]+(?:\.[0-9]+)?\)', caseSensitive: false), '')
        .trim();

    final ref = tx['reference'] ?? tx['id'] ?? 'REF_${DateTime.now().millisecondsSinceEpoch}';
    final dateStr = tx['date'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(tx['date'].toString()) ?? DateTime.now())
        : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final status = (tx['status'] ?? 'SUCCESSFUL').toString().toUpperCase();
    final sym = _getCurrencySymbol(widget.currency);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Receipt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Rentilly Living Protocol Certified',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCredit
                    ? [const Color(0xFF064E3B), const Color(0xFF0D9488)]
                    : [const Color(0xFF1E293B), const Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isCredit ? const Color(0xFF064E3B) : const Color(0xFF1E293B)).withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  isCredit ? 'TOTAL INFLOW SETTLEMENT' : 'AMOUNT SENT (EXCL. FEES)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '$sym${_currencyFormat.format(sentAmount)}${widget.currency.toUpperCase() == 'USDT' ? ' USDT' : ''}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Detail Rows Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildRow('Description', cleanTitle.isNotEmpty ? cleanTitle : rawTitle),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildCopyableRow('Reference ID', ref),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow('Timestamp', dateStr),
                if (feeAmount > 0) ...[
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildRow('Transaction Fee', '$sym${_currencyFormat.format(feeAmount)} (In-app only)'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildRow('Total Account Debit', '$sym${_currencyFormat.format(rawAmount)}'),
                ],
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow('Currency / Account', '${widget.currency} Wallet (${widget.user.bankName ?? "Flutterwave MFB"})'),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow('Protection Level', 'Escrow Guarded (E-Homes Global)'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons: Download PDF & Share
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExporting ? null : _handleShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(
                    'Share Receipt',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _handleDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isExporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'Download PDF',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reference ID copied to clipboard! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.length > 20 ? '${value.substring(0, 18)}...' : value,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.copy_rounded, size: 13, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}
