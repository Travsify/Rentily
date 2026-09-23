import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final GlobalKey _receiptKey = GlobalKey();
  bool _isExporting = false;
  String? _exportActionName;
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

  Future<Uint8List?> _captureReceiptImage() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing receipt image: $e');
      return null;
    }
  }

  // 1. Share as Image (PNG) - Guaranteed Uniformity with PDF Receipt
  Future<void> _handleShareImage() async {
    setState(() {
      _isExporting = true;
      _exportActionName = 'image';
    });
    try {
      Uint8List? rasterBytes;
      try {
        rasterBytes = await StatementPdfService.generateReceiptImageBytes(
          transaction: widget.transaction,
          user: widget.user,
          currency: widget.currency,
          dpi: 288.0,
        );
      } catch (e) {
        debugPrint('Raster generator fallback: $e');
        rasterBytes = await _captureReceiptImage();
      }

      await StatementPdfService.shareReceiptImage(
        transaction: widget.transaction,
        user: widget.user,
        currency: widget.currency,
        imageBytes: rasterBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share receipt image: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // 2. Share as PDF
  Future<void> _handleSharePdf() async {
    setState(() {
      _isExporting = true;
      _exportActionName = 'pdf';
    });
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
            content: Text('Could not share receipt PDF: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // 3. Save / Download as Image (PNG)
  Future<void> _handleSaveImage() async {
    setState(() {
      _isExporting = true;
      _exportActionName = 'save_img';
    });
    try {
      Uint8List? rasterBytes;
      try {
        rasterBytes = await StatementPdfService.generateReceiptImageBytes(
          transaction: widget.transaction,
          user: widget.user,
          currency: widget.currency,
          dpi: 288.0,
        );
      } catch (e) {
        debugPrint('Raster generator fallback: $e');
        rasterBytes = await _captureReceiptImage();
      }

      await StatementPdfService.saveReceiptImageToDevice(
        transaction: widget.transaction,
        user: widget.user,
        currency: widget.currency,
        imageBytes: rasterBytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Receipt image saved to device! 📸',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0D5C46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save receipt image: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // 4. Download / Print PDF
  Future<void> _handleDownloadPdf() async {
    setState(() {
      _isExporting = true;
      _exportActionName = 'print_pdf';
    });
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

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final rawAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final isCredit = tx['isCredit'] == true ||
        (tx['type'] ?? '').toString().toLowerCase() == 'credit' ||
        (tx['entry'] ?? '').toString().toLowerCase() == 'credit' ||
        (tx['type'] ?? '').toString().toLowerCase().contains('inflow') ||
        (tx['type'] ?? '').toString().toLowerCase().contains('deposit') ||
        (tx['type'] ?? '').toString().toLowerCase().contains('top');

    final rawTitle = (tx['title'] ?? tx['narration'] ?? tx['merchantName'] ?? tx['description'] ?? tx['type'] ?? (isCredit ? 'Escrow Inflow' : 'Wallet Withdrawal')).toString();
    final isNairaDest = rawTitle.contains('-> ₦') || rawTitle.contains('₦') || rawTitle.toLowerCase().contains('to naira') || (tx['currency']?.toString().toUpperCase() == 'NGN');
    final isCardTx = !isNairaDest && (widget.currency.toUpperCase() == 'USD' ||
        widget.currency.toUpperCase() == 'CARD_USD' ||
        tx['cardId'] != null ||
        tx['merchantName'] != null);
    final effectiveCurrency = isNairaDest ? 'NGN' : widget.currency;

    final merchantName = (tx['merchantName'] ?? tx['merchant']?['name'] ?? tx['description'] ?? rawTitle).toString();

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
    final rawDate = DateTime.tryParse(tx['date']?.toString() ?? tx['createdAt']?.toString() ?? '') ?? DateTime.now();
    final gmtPlus1 = rawDate.toUtc().add(const Duration(hours: 1));
    final dateStr = '${DateFormat('dd MMM yyyy, hh:mm a').format(gmtPlus1)} (GMT+1)';
    final status = (tx['status'] ?? 'SUCCESSFUL').toString().toUpperCase();
    final sym = _getCurrencySymbol(effectiveCurrency);

    // Extract recipient name & account number from description / title if present
    final rawDesc = (tx['title'] ?? tx['description'] ?? tx['narration'] ?? '').toString();
    String? extractedAccount;
    String? extractedBeneficiary;

    final accountRegex = RegExp(r'\((\d{10})\)|[-–:]\s*(\d{10})|\b(\d{10})\b');
    final match = accountRegex.firstMatch(rawDesc);
    if (match != null) {
      extractedAccount = match.group(1) ?? match.group(2) ?? match.group(3);
    }

    final nameMatch = RegExp(r'(?:Payout to|Transfer to|Payment to|Disbursement to)\s+([^(–-]+)', caseSensitive: false).firstMatch(rawDesc);
    if (nameMatch != null) {
      extractedBeneficiary = nameMatch.group(1)!.trim();
    }

    final recipientAccountNum = (tx['recipientAccount'] ??
        tx['destinationAccount'] ??
        tx['accountNumber'] ??
        extractedAccount ??
        (isCredit ? widget.user.accountNumber : ''))
        .toString()
        .trim();

    final recipientBeneficiaryName = (tx['beneficiary'] ??
        tx['recipientName'] ??
        extractedBeneficiary ??
        (isCredit ? widget.user.fullName : (merchantName.isNotEmpty ? merchantName : widget.user.fullName)))
        .toString()
        .trim();

    String rawDestBank = (tx['recipientBank'] ??
        tx['bankName'] ??
        tx['destinationBank'] ??
        (tx['bank'] is Map ? tx['bank']['name'] : null) ??
        (isCredit ? (widget.user.bankName ?? 'Rentilly Escrow') : 'Commercial Settlement Rail'))
        .toString()
        .replaceAll(RegExp(r'\(?fincra[^)]*\)?', caseSensitive: false), '')
        .trim();

    if (isCredit) {
      rawDestBank = rawDestBank.replaceAll(RegExp(r'Wema Bank(\s*\(Rentilly Escrow\))?', caseSensitive: false), 'Rentilly Escrow').trim();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
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
            const SizedBox(height: 14),

            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: (isCardTx
                                ? (isCredit ? const Color(0xFF0D9488) : const Color(0xFFE11D48))
                                : AppColors.primary).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCardTx ? (isCredit ? Icons.add_card_rounded : Icons.credit_card_rounded) : Icons.receipt_long_rounded,
                            color: isCardTx ? (isCredit ? const Color(0xFF0D9488) : const Color(0xFFE11D48)) : AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCardTx ? 'Card Purchase Receipt' : 'Transaction Receipt',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          isCardTx ? 'Rentilly Platinum Virtual USD Card' : 'Rentilly Living Protocol Certified',
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
            const SizedBox(height: 12),

            // RepaintBoundary for high-definition receipt image export (Exact Mirror of Certified PDF Receipt)
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Receipt Header: Brand & Certified Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 32,
                                height: 32,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0B4F3F),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RENTILLY',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0B4F3F),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  'Direct Real Estate & Escrow Protocol',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'CERTIFIED RECEIPT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0B4F3F),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 14),

                    // Amount Card (Identical styling to PDF)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            isCardTx
                                ? (isCredit ? 'CARD INFLOW (CREDIT)' : 'ONLINE CARD PURCHASE (DEBIT)')
                                : 'TOTAL TRANSACTION VALUE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isCardTx && !isCredit ? const Color(0xFF991B1B) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${isCardTx ? (isCredit ? "+" : "-") : ""}$sym${_currencyFormat.format(sentAmount)}${widget.currency.toUpperCase() == "USDT" ? " USDT" : (isCardTx ? " USD" : "")}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: isCardTx
                                  ? (isCredit ? const Color(0xFF0B4F3F) : const Color(0xFFDC2626))
                                  : const Color(0xFF0B4F3F),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCardTx
                                  ? (isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2))
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCardTx
                                  ? (isCredit ? 'CREDIT - SETTLED' : 'DEBIT - SETTLED')
                                  : status,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isCardTx
                                    ? (isCredit ? const Color(0xFF14532D) : const Color(0xFF7F1D1D))
                                    : const Color(0xFF14532D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Institutional Ledger Specifications Header
                    Text(
                      isCardTx ? 'CARD TRANSACTION SPECIFICATIONS' : 'TRANSACTION SPECIFICATIONS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B4F3F),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Detail Rows
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          if (isCardTx) ...[
                            _buildRow('Transaction Type', isCredit ? 'CREDIT (+) - Card Funding / Top-Up' : 'DEBIT (-) - Online Card Purchase'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Merchant / Platform', merchantName),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Transaction Purpose', cleanTitle.isNotEmpty ? cleanTitle : rawTitle),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Card Rail / Issuer', 'Rentilly Platinum Virtual USD Card (Visa)'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Cardholder Name', widget.user.fullName),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Billing Country & City', 'San Francisco, CA 94104, USA'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildCopyableRow('Authorization Reference', ref),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Settlement Currency', 'USD (United States Dollar)'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Security Authentication', '3D-Secure 2.0 Dynamic OTP Verified'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Transaction Date (UTC+1)', dateStr),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Settlement Status', status == 'SUCCESS' ? 'SETTLED / COMPLETED' : status),
                          ] else ...[
                            _buildRow('Transaction Description', cleanTitle.isNotEmpty ? cleanTitle : rawTitle),
                            if ((tx['description'] ?? tx['remark'] ?? tx['reason']) != null &&
                                (tx['description'] ?? tx['remark'] ?? tx['reason']).toString().trim().isNotEmpty &&
                                !(tx['description'] ?? tx['remark'] ?? tx['reason']).toString().trim().toLowerCase().contains('rentilly payout')) ...[
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildRow('Remark / Narration', (tx['description'] ?? tx['remark'] ?? tx['reason']).toString().trim()),
                            ],
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildCopyableRow('Transaction Reference', ref),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Transaction Nature', isCredit ? 'CREDIT (+) - Inbound Bank Settlement' : 'DEBIT (-) - Outbound Bank Transfer Payout'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Transaction Category', (tx['type'] ?? 'Escrow Settlement').toString()),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow(isCredit ? 'Sender / Source' : 'Originating Account', isCredit ? (tx['sender'] ?? 'Electronic Banking Settlement').toString() : '${widget.user.fullName} (Rentilly Escrow Vault)'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow(isCredit ? 'Beneficiary Name' : 'Recipient Beneficiary', recipientBeneficiaryName),
                            if (recipientAccountNum.isNotEmpty) ...[
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildCopyableRow(isCredit ? 'Receiving Virtual Account' : 'Destination Account Number', recipientAccountNum),
                            ],
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow(
                              isCredit ? 'Receiving Partner Bank' : 'Destination Bank',
                              rawDestBank.isNotEmpty ? rawDestBank : (isCredit ? 'Rentilly Escrow' : 'Commercial Settlement Rail'),
                            ),
                            if (tx['token'] != null && tx['token'].toString().isNotEmpty) ...[
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildCopyableRow('Prepaid Token ⚡', tx['token'].toString()),
                              if (tx['units'] != null && tx['units'].toString().isNotEmpty) ...[
                                const Divider(height: 14, color: Color(0xFFE2E8F0)),
                                _buildRow('Units Vended', tx['units'].toString()),
                              ],
                            ],
                            if (feeAmount > 0) ...[
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildRow('Principal Transfer Amount', '$sym${_currencyFormat.format(sentAmount)}'),
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildRow('Processing Fee', '$sym${_currencyFormat.format(feeAmount)}'),
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildRow('Total Settlement Debited', '$sym${_currencyFormat.format(rawAmount)}'),
                            ],
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Settlement Category', 'Rentilly Escrow Protected'),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Timestamp (GMT+1)', dateStr),
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            _buildRow('Corporate Issuer', 'Product of E-Homes Global Inclusive Limited'),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Security Seal & QR Code Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rentilly | E-Homes Global Inclusive Limited',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0B4F3F),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Institutional Escrow Protocol | Non-Bank Technology Provider',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 7.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'Verification Digest: SHA256-${ref.hashCode.abs().toRadixString(16).padLeft(12, "0")}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 7,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              size: 28,
                              color: Color(0xFF0B4F3F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons: Share (Image/PDF) and Download (Image/PDF)
            Row(
              children: [
                // Share as Image
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _handleShareImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: (_isExporting && _exportActionName == 'image')
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_outlined, size: 17),
                    label: Text(
                      'Share Image',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Share as PDF
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _handleSharePdf,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D5C46),
                      side: const BorderSide(color: Color(0xFF0D5C46), width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: (_isExporting && _exportActionName == 'pdf')
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D5C46)))
                        : const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: Text(
                      'Share PDF',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                // Save Image to Device
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _handleSaveImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    icon: (_isExporting && _exportActionName == 'save_img')
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                        : const Icon(Icons.download_rounded, size: 17),
                    label: Text(
                      'Save Image',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Print / Download PDF
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _handleDownloadPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: (_isExporting && _exportActionName == 'print_pdf')
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print_rounded, size: 17),
                    label: Text(
                      'Print / PDF',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                content: Text('$label copied to clipboard! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.length > 22 ? '${value.substring(0, 20)}...' : value,
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
