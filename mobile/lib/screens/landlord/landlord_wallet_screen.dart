import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../bills/bills_screen.dart';

class LandlordWalletScreen extends StatefulWidget {
  const LandlordWalletScreen({super.key});

  @override
  State<LandlordWalletScreen> createState() => _LandlordWalletScreenState();
}

class _LandlordWalletScreenState extends State<LandlordWalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  bool _isLoading = true;
  String _selectedLedgerFilter = 'All';
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndTransactions();
    AuthService.currentUserNotifier.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) {
      setState(() {
        _user = AuthService.currentUserNotifier.value;
      });
      _loadTransactions();
    }
  }

  void _loadUserAndTransactions() async {
    final user = await AuthService.getCurrentUser();
    await _loadTransactions();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTxnsJson = prefs.getString('rentilly_landlord_transactions');
    final user = await AuthService.getCurrentUser();
    final acc = user?.accountNumber ?? '9254090338';

    if (savedTxnsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(savedTxnsJson);
        _transactions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    // Default verified funding transaction for 9254090338
    if (_transactions.isEmpty) {
      _transactions = [
        {
          'id': 'TXN-RNT-9254090338-001',
          'title': 'Wallet Funding (Bank Transfer)',
          'subtitle': 'Direct deposit into Flutterwave MFB virtual account $acc',
          'amount': 2000.0,
          'type': 'inflow',
          'status': 'Completed',
          'date': '01 Sep 2026, 03:45 AM',
          'reference': 'FLW-FUND-9254090338-2000',
          'channel': 'Flutterwave MFB / Core Settlement',
          'session': 'SES-FLW-984210984712',
        },
      ];
      await prefs.setString('rentilly_landlord_transactions', json.encode(_transactions));
    }
    if (mounted) setState(() {});
  }

  void _copyAccount(String accountNumber) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account Number $accountNumber copied! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- 1. DOWNLOAD INDIVIDUAL TRANSACTION RECEIPT PDF ---
  Future<void> _generateAndShareReceiptPdf(Map<String, dynamic> txn) async {
    final name = _user?.fullName ?? 'Property Owner';
    final acc = _user?.accountNumber ?? '9254090338';
    final amount = txn['amount'] as double;
    final isPositive = amount > 0;
    final formattedAmount = '${isPositive ? "+" : "-"}NGN ${_currencyFormat.format(amount.abs())}';
    final ref = txn['reference'] ?? txn['id'] ?? 'REF-9254090338';
    final title = txn['title'] as String;
    final date = txn['date'] as String;
    final channel = txn['channel'] ?? 'Flutterwave Settlement Account';
    final session = txn['session'] ?? 'SES-${DateTime.now().millisecondsSinceEpoch}';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(120 * PdfPageFormat.mm, 180 * PdfPageFormat.mm, marginAll: 8 * PdfPageFormat.mm),
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColor.fromHex('064E3B'), width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('064E3B'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RENTILLY ESCROW NETWORK', style: pw.TextStyle(color: PdfColor.fromHex('4ADE80'), fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('TRANSACTION RECEIPT', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('16A34A'), borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text('SUCCESSFUL', style: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Amount
                pw.Text(formattedAmount, style: pw.TextStyle(color: isPositive ? PdfColor.fromHex('064E3B') : PdfColor.fromHex('DC2626'), fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.SizedBox(height: 8),

                // Breakdown Table
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F8FAFC'),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColor.fromHex('E2E8F0')),
                  ),
                  child: pw.Column(
                    children: [
                      _buildReceiptRow('Transaction Ref', ref),
                      _buildReceiptRow('Settlement Account', '$acc (Flutterwave MFB)'),
                      _buildReceiptRow('Account Holder', name),
                      _buildReceiptRow('Payment Channel', channel),
                      _buildReceiptRow('Session Reference', session),
                      _buildReceiptRow('Transaction Date', date),
                      _buildReceiptRow('Escrow Guarantee', '100% Protected (CBN Regulated)'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Barcode & QR Code
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: ref,
                          width: 130,
                          height: 22,
                          drawText: false,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('OFFICIAL AUDIT SERIAL: $ref', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://rentilly.ng/receipt/$ref',
                      width: 32,
                      height: 32,
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),

                pw.Text('Digitally verified and certified by Rentilly Trust & Escrow Desk.', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Rentilly_Receipt_$ref.pdf');
  }

  pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 7.5)),
          pw.Text(value, style: pw.TextStyle(color: PdfColors.black, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // --- 2. SHOW TRANSACTION RECEIPT MODAL ---
  void _showTransactionReceiptModal(BuildContext context, Map<String, dynamic> txn) {
    final amount = txn['amount'] as double;
    final isPositive = amount > 0;
    final formattedAmount = '${isPositive ? "+" : "-"}₦${_currencyFormat.format(amount.abs())}';
    final ref = txn['reference'] ?? txn['id'] ?? 'REF-9254090338';
    final title = txn['title'] as String;
    final date = txn['date'] as String;
    final channel = txn['channel'] ?? 'Flutterwave Settlement Account';
    final session = txn['session'] ?? 'SES-FLW-984210984712';
    final acc = _user?.accountNumber ?? '9254090338';
    final name = _user?.fullName ?? 'Property Owner';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle bar
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),

            // Success Icon & Amount
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, size: 36, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 10),
            Text(
              formattedAmount,
              style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: isPositive ? const Color(0xFF16A34A) : Colors.red),
            ),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // Itemized Breakdown
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _buildModalRow('Status', 'SUCCESSFUL (COMPLETED)', isSuccess: true),
                  const Divider(height: 14),
                  _buildModalRow('Transaction Ref', ref),
                  const Divider(height: 14),
                  _buildModalRow('Settlement Account', '$acc (Flutterwave MFB)'),
                  const Divider(height: 14),
                  _buildModalRow('Account Holder', name),
                  const Divider(height: 14),
                  _buildModalRow('Payment Channel', channel),
                  const Divider(height: 14),
                  _buildModalRow('Session Reference', session),
                  const Divider(height: 14),
                  _buildModalRow('Date & Time', date),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Download PDF Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _generateAndShareReceiptPdf(txn);
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
                label: Text('Download PDF Receipt (Brand Certified)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, {bool isSuccess = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isSuccess ? const Color(0xFF16A34A) : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. DOWNLOAD FULL ACCOUNT STATEMENT PDF ---
  void _downloadStatement() async {
    final name = _user?.fullName ?? 'Property Owner';
    final balance = _user?.walletBalance ?? 2000.0;
    final acc = _user?.accountNumber ?? '9254090338';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RENTILLY ESCROW & SETTLEMENT NETWORK', style: pw.TextStyle(color: PdfColor.fromHex('064E3B'), fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text('OFFICIAL LANDLORD ACCOUNT STATEMENT', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://rentilly.ng/statement/$acc',
                    width: 44,
                    height: 44,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F0FDF4'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('86EFAC')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ACCOUNT HOLDER: $name', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('VIRTUAL SETTLEMENT ACCOUNT: $acc (Flutterwave MFB)', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('NET OPERATING BALANCE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.Text('NGN ${_currencyFormat.format(balance)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('064E3B'))),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('TRANSACTION & DISBURSEMENT LEDGER', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('064E3B')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('DATE', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('DESCRIPTION', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TYPE', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('AMOUNT (NGN)', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('STATUS', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ..._transactions.map((t) {
                    final isPos = (t['amount'] as double) > 0;
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(t['date'] ?? 'Today', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(t['title'] ?? '', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(t['type'] ?? 'Inflow', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${isPos ? "+" : "-"} ${_currencyFormat.format((t['amount'] as double).abs())}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: isPos ? PdfColor.fromHex('16A34A') : PdfColor.fromHex('DC2626')))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(t['status'] ?? 'COMPLETED', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green700))),
                      ],
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Rentilly_Statement_$acc.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isVerified = _user?.isVerified ?? true;
    final name = _user?.fullName ?? 'Property Owner';
    final operationalBalance = _user?.walletBalance ?? 2000.0;
    final escrowBalance = 0.00;
    final accountNumber = _user?.accountNumber ?? '9254090338';
    final bankName = _user?.bankName ?? 'Flutterwave MFB';

    final filteredTransactions = _selectedLedgerFilter == 'All'
        ? _transactions
        : _selectedLedgerFilter == 'Inflows'
            ? _transactions.where((t) => (t['amount'] as double) > 0).toList()
            : _selectedLedgerFilter == 'Outflows'
                ? _transactions.where((t) => (t['amount'] as double) < 0).toList()
                : _transactions.where((t) => t['type'] == 'escrow').toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Settlement & Escrow Vault',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: AppColors.primary),
            onPressed: _downloadStatement,
            tooltip: 'Download Statement',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _loadUserAndTransactions();
          },
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Dual Balance Card (Styled 100% in Rentilly Brand Green with Emerald & Gold Accents)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF042F2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.35), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF4ADE80)),
                            const SizedBox(width: 6),
                            Text(
                              'LANDLORD OPERATING VAULT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: const Color(0xFF4ADE80),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4ADE80)),
                          ),
                          child: Text(
                            'VERIFIED VAULT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4ADE80),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operational Funded Balance
                    Text('AVAILABLE OPERATING FUNDS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text('₦${_currencyFormat.format(operationalBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 14),

                    // Divider
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),

                    // Escrow Balance (Rent & Sales Proceeds)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACTIVE SETTLEMENT FUNDS IN ESCROW', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text('₦${_currencyFormat.format(escrowBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RELEASES ON KEY CONFIRMATION',
                            style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Virtual Bank Account Section (Rentilly Brand Green Accent)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'DEDICATED SETTLEMENT BANK ACCOUNT',
                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AUTOMATED SETTLEMENT',
                            style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(accountNumber, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                            Text('$bankName • $name / Rentilly', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                          onPressed: () => _copyAccount(accountNumber),
                          tooltip: 'Copy Account Number',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_user != null) {
                                AddMoneyModal.show(context, user: _user!, onAccountUpdated: (u) async {
                                  setState(() => _user = u);
                                  await _loadTransactions();
                                });
                              }
                            },
                            icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                            label: Text('Fund Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (_user != null) {
                                WithdrawalModal.show(
                                  context,
                                  user: _user!,
                                  onWithdrawalSuccess: (newBal) async {
                                    setState(() => _user = _user!.copyWith(walletBalance: newBal));
                                    await _loadTransactions();
                                  },
                                );
                              }
                            },
                            icon: const Icon(Icons.north_east_rounded, size: 14, color: AppColors.primary),
                            label: Text('Withdraw', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Unit Utilities & Maintenance Pod
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'UNIT UTILITIES & MAINTENANCE',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                  ),
                  Text(
                    'INSTANT DISPATCH',
                    style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    _buildUtilityButton(
                      Icons.electric_bolt_rounded,
                      'Electricity',
                      'Prepaid DisCo',
                      AppColors.accentOrange,
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'electricity')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.phone_android_rounded,
                      'Airtime',
                      'Quick Top-Up',
                      AppColors.primary,
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'airtime')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.wifi_rounded,
                      'Data Bundle',
                      '4K Video Tours',
                      const Color(0xFFF59E0B),
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'data')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.tv_rounded,
                      'Cable TV',
                      'DSTV/GOTV',
                      const Color(0xFF7C3AED),
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'cable')));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Verified Recent Disbursements & Transaction History Ledger (Clickable to PDF Receipt)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT DISBURSEMENTS & LEDGER',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: _downloadStatement,
                    icon: const Icon(Icons.download_rounded, size: 13, color: AppColors.primary),
                    label: Text('Full Statement PDF', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Inflows'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Outflows'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Escrow'),
                ],
              ),
              const SizedBox(height: 10),

              ...filteredTransactions.map((tx) {
                final amount = tx['amount'] as double;
                final isPositive = amount > 0;
                final formatted = isPositive ? '+₦${_currencyFormat.format(amount)}' : '-₦${_currencyFormat.format(amount.abs())}';

                return InkWell(
                  onTap: () => _showTransactionReceiptModal(context, tx),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isPositive ? const Color(0xFF16A34A) : Colors.red).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: isPositive ? const Color(0xFF16A34A) : Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(tx['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text('${tx['date']} • Tap for PDF Receipt 📄', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatted, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: isPositive ? const Color(0xFF16A34A) : Colors.red)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(tx['status'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedLedgerFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedLedgerFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityButton(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
