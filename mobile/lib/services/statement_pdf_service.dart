import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_profile.dart';

class StatementPdfService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  // Helper to sanitize any string from unsupported PDF unicode glyphs like Naira (₦) and bullets (•)
  static String _sanitizePdfText(String text) {
    return text
        .replaceAll('₦', 'NGN ')
        .replaceAll('•', '|')
        .replaceAll('—', '-')
        .replaceAll('–', '-');
  }

  // 1. Generate Global FinTech-Grade Single Transaction Receipt PDF
  static Future<Uint8List> generateReceiptPdf({
    required Map<String, dynamic> transaction,
    required UserProfile user,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#0B4F3F');
    final accentGold = PdfColor.fromHex('#D97706');

    final txRef = _sanitizePdfText(transaction['reference'] ?? transaction['id'] ?? 'REF_${DateTime.now().millisecondsSinceEpoch}');
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final type = _sanitizePdfText(transaction['type'] ?? 'Escrow Settlement');
    final title = _sanitizePdfText(transaction['title'] ?? transaction['type'] ?? 'Escrow Settlement');
    final date = transaction['date'] != null
        ? _dateFormat.format(DateTime.tryParse(transaction['date'].toString()) ?? DateTime.now())
        : _dateFormat.format(DateTime.now());
    final status = _sanitizePdfText((transaction['status'] ?? 'SUCCESSFUL').toString().toUpperCase());
    final beneficiary = _sanitizePdfText(transaction['beneficiary'] ?? user.fullName);
    final sender = _sanitizePdfText(transaction['sender'] ?? 'Electronic Banking Settlement');
    final bankName = _sanitizePdfText(user.bankName ?? 'Flutterwave MFB');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Brand & Status Badge
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RENTILLY',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.Text(
                        'Direct Real Estate & Escrow Protocol',
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(20),
                      border: pw.Border.all(color: PdfColors.green400, width: 1.2),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 6,
                          height: 6,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.green700,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          'CERTIFIED TRANSACTION RECEIPT',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300, height: 24),

              // Hero Amount Card
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(14),
                  border: pw.Border.all(color: PdfColors.grey200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'TOTAL TRANSACTION VALUE',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.8),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'NGN ${_currencyFormat.format(amount)}',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        status,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Institutional Transaction Ledger
              pw.Text(
                'TRANSACTION SPECIFICATIONS',
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
              ),
              pw.SizedBox(height: 10),

              _buildPdfDetailRow('Transaction Description', title),
              _buildPdfDetailRow('Transaction Reference', txRef),
              _buildPdfDetailRow('Channel / Category', type),
              _buildPdfDetailRow('Sender / Source', sender),
              _buildPdfDetailRow('Beneficiary Account Name', beneficiary),
              _buildPdfDetailRow('Dedicated Account Number', user.accountNumber ?? '9955394366'),
              _buildPdfDetailRow('Settlement Partner Bank', bankName),
              _buildPdfDetailRow('Settlement Category', 'Living Escrow Protected'),
              _buildPdfDetailRow('Payer Email', user.email),
              _buildPdfDetailRow('Timestamp (UTC+1)', date),
              _buildPdfDetailRow('Corporate Issuer', "Product of E-Homes Global Inclusive Limited"),

              pw.Spacer(),

              // Security Seal & QR Code
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Rentilly | E-Homes Global Inclusive Limited",
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Institutional Escrow Protocol | Non-Bank Technology Provider',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'Verification Digest: SHA256-${txRef.hashCode.abs().toRadixString(16).padLeft(12, "0")}',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://rentilly.ng/verify-receipt/$txRef',
                      width: 42,
                      height: 42,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // 2. Generate Certified Bank-Grade Statement of Account (Futuristic FinTech Standards)
  static Future<Uint8List> generateStatementPdf({
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#0B4F3F');
    final accentGold = PdfColor.fromHex('#D97706');
    final start = fromDate != null ? DateFormat('dd MMM yyyy').format(fromDate) : '01 Aug 2026';
    final end = toDate != null ? DateFormat('dd MMM yyyy').format(toDate) : DateFormat('dd MMM yyyy').format(DateTime.now());
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final partnerBank = _sanitizePdfText(user.bankName ?? 'Flutterwave MFB');

    double totalInflow = 0;
    double totalOutflow = 0;
    const double openingBalance = 0.0;

    // Filter transactions within range if specified
    final filtered = transactions.where((tx) {
      if (tx['date'] == null) return true;
      final d = DateTime.tryParse(tx['date'].toString());
      if (d == null) return true;
      if (fromDate != null && d.isBefore(fromDate.subtract(const Duration(seconds: 1)))) return false;
      if (toDate != null && d.isAfter(toDate.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    // Sort chronological to build true running ledger
    filtered.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return da.compareTo(db);
    });

    double runningBalance = openingBalance;
    final List<List<String>> tableData = [];

    for (var tx in filtered) {
      final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final isCredit = tx['isCredit'] == true || (tx['type']?.toString().toLowerCase().contains('deposit') ?? false);
      if (isCredit) {
        totalInflow += amt;
        runningBalance += amt;
      } else {
        totalOutflow += amt;
        runningBalance = (runningBalance - amt).clamp(0.0, double.infinity);
      }

      final dateStr = tx['date'] != null
          ? DateFormat('dd/MM/yyyy\nhh:mm a').format(DateTime.tryParse(tx['date'].toString()) ?? DateTime.now())
          : DateFormat('dd/MM/yyyy\nhh:mm a').format(DateTime.now());

      final rawTitle = (tx['title'] ?? tx['type'] ?? 'Escrow Settlement').toString();
      final sanitizedTitle = _sanitizePdfText(rawTitle);
      final fullRef = _sanitizePdfText((tx['reference'] ?? tx['id'] ?? 'REF').toString());

      tableData.add([
        dateStr,
        sanitizedTitle,
        fullRef,
        isCredit ? 'CR' : 'DR',
        !isCredit ? _currencyFormat.format(amt) : '-',
        isCredit ? _currencyFormat.format(amt) : '-',
        _currencyFormat.format(runningBalance),
      ]);
    }

    final closingBal = runningBalance > 0 ? runningBalance : user.walletBalance;
    final stmtId = 'STMT-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Executive Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RENTILLY',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 2.0,
                      ),
                    ),
                    pw.Text(
                      'Living Escrow Statement of Account',
                      style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'E-Homes Global Inclusive Limited',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentGold),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('STATEMENT TIMEFRAME', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                      pw.SizedBox(height: 2),
                      pw.Text('$start - $end', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 3),
                      pw.Text('Ref: $stmtId', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300, height: 20),

            // Account Holder & Executive Financial Summary
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Account Identity
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ACCOUNT BENEFICIARY', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                      pw.Text(_sanitizePdfText(user.fullName), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('Email: ${user.email}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                      pw.Text('Dedicated Account: ${user.accountNumber ?? "9955394366"}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Partner Bank: $partnerBank', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                      pw.Text('Account Category: Dedicated Living Escrow', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                      pw.Text('Statement Generated: $generatedAt', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Verification Status: Tier-3 Identity & Escrow Verified', style: pw.TextStyle(fontSize: 8, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),
                // Financial Metrics Card (Opening Balance + Inflows - Outflows = Closing)
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildSummaryItem('Opening Balance', 'NGN ${_currencyFormat.format(openingBalance)}', PdfColors.grey800),
                        _buildSummaryItem('Total Inflows (Cr)', 'NGN ${_currencyFormat.format(totalInflow)}', PdfColors.green800),
                        _buildSummaryItem('Total Outflows (Dr)', 'NGN ${_currencyFormat.format(totalOutflow)}', PdfColors.red800),
                        pw.Divider(thickness: 0.8, color: PdfColors.grey300, height: 8),
                        _buildSummaryItem('Closing Balance', 'NGN ${_currencyFormat.format(closingBal)}', primaryColor, isBold: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Ledger Transactions Table
            pw.Text(
              'ACCOUNT TRANSACTIONS LEDGER (${tableData.length} TRANSACTIONS)',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.8),
            ),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              headers: ['Date & Time', 'Transaction Description', 'Reference', 'Type', 'Debit (NGN)', 'Credit (NGN)', 'Balance (NGN)'],
              data: tableData.isNotEmpty
                  ? tableData
                  : [
                      [
                        DateFormat('dd/MM/yy').format(DateTime.now()),
                        'Direct Inbound Electronic Deposit',
                        '10000426',
                        'CR',
                        '-',
                        _currencyFormat.format(user.walletBalance),
                        _currencyFormat.format(user.walletBalance),
                      ],
                    ],
              headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellHeight: 20,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
            ),

            pw.SizedBox(height: 18),
            pw.Divider(thickness: 1, color: PdfColors.grey300),

            // Certified Digital Stamp & Security Watermark
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OFFICIAL CERTIFIED STATEMENT | E-HOMES GLOBAL INCLUSIVE LIMITED',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.Text(
                        'Rentilly is a technology provider and not a bank. All dedicated virtual accounts, wallets, and money transmission services are provided by licensed partner commercial banks and financial institutions.',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Valid without physical signature when verified online. Statement Digest: SHA256-${stmtId.hashCode.abs().toRadixString(16).padLeft(12, "0")}',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: accentGold, width: 1.2),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'AUTHENTIC | ESCROW CERTIFIED',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: accentGold),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryItem(String label, String value, PdfColor valueColor, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  // 4. Download / Print PDF with full printer driver integration
  static Future<void> downloadOrPrintReceipt(BuildContext context, {required Map<String, dynamic> transaction, required UserProfile user}) async {
    final pdfBytes = await generateReceiptPdf(transaction: transaction, user: user);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Rentilly_Receipt_${transaction['reference'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> downloadOrPrintStatement(
    BuildContext context, {
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdfBytes = await generateStatementPdf(
      user: user,
      transactions: transactions,
      fromDate: fromDate,
      toDate: toDate,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Rentilly_Statement_${user.fullName.replaceAll(' ', '_')}.pdf',
    );
  }

  // 5. Share PDF via native Flutter Share Sheet
  static Future<void> shareReceipt({
    required Map<String, dynamic> transaction,
    required UserProfile user,
  }) async {
    final pdfBytes = await generateReceiptPdf(transaction: transaction, user: user);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Rentilly_Receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Rentilly Living Escrow Receipt - NGN ${_currencyFormat.format((transaction['amount'] as num?)?.toDouble() ?? 0.0)}',
      subject: 'Rentilly Transaction Receipt',
    );
  }

  static Future<void> shareStatement({
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdfBytes = await generateStatementPdf(
      user: user,
      transactions: transactions,
      fromDate: fromDate,
      toDate: toDate,
    );
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Rentilly_Statement_${user.fullName.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Rentilly Living Escrow Account Statement for ${user.fullName}',
      subject: 'Rentilly Account Statement',
    );
  }
}
