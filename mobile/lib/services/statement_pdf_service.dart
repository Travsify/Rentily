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

  // 1. Generate Single Transaction Receipt PDF
  static Future<Uint8List> generateReceiptPdf({
    required Map<String, dynamic> transaction,
    required UserProfile user,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#0B4F3F');
    final accentOrange = PdfColor.fromHex('#F59E0B');

    final txRef = transaction['reference'] ?? transaction['id'] ?? 'REF_${DateTime.now().millisecondsSinceEpoch}';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final type = transaction['type'] ?? 'Escrow Transaction';
    final date = transaction['date'] != null
        ? _dateFormat.format(DateTime.tryParse(transaction['date'].toString()) ?? DateTime.now())
        : _dateFormat.format(DateTime.now());
    final status = transaction['status'] ?? 'SUCCESSFUL';
    final beneficiary = transaction['beneficiary'] ?? user.fullName;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RENTILLY',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        'Living Escrow & Direct Real Estate',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.green300),
                    ),
                    child: pw.Text(
                      'TRANSACTION RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300, height: 24),

              // Amount Card
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'TRANSACTION AMOUNT',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'NGN ${_currencyFormat.format(amount)}',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        status.toString().toUpperCase(),
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
              pw.SizedBox(height: 20),

              // Details Grid
              pw.Text(
                'TRANSACTION DETAILS',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 8),

              _buildPdfDetailRow('Transaction Reference', txRef),
              _buildPdfDetailRow('Description', type),
              _buildPdfDetailRow('Beneficiary / Sender', beneficiary),
              _buildPdfDetailRow('Payer Name', user.fullName),
              _buildPdfDetailRow('Payer Email', user.email),
              _buildPdfDetailRow('Account Number', user.accountNumber ?? '9955394366'),
              _buildPdfDetailRow('Bank Name', user.bankName ?? 'Flutterwave MFB'),
              _buildPdfDetailRow('Date & Time', date),
              _buildPdfDetailRow('Payment Channel', 'Paystack / Flutterwave NIBSS Switch'),

              pw.Spacer(),

              // Security & Verification Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Rentilly Living Technologies Ltd',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        pw.Text(
                          'CBN Licensed Escrow & Direct Payout Framework. Support: support@rentilly.ng',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://rentilly.ng/verify-receipt/$txRef',
                      width: 36,
                      height: 36,
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

  // 2. Generate Account Statement PDF (All Transactions)
  static Future<Uint8List> generateStatementPdf({
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#0B4F3F');
    final start = fromDate != null ? DateFormat('dd MMM yyyy').format(fromDate) : '01 Jan 2026';
    final end = toDate != null ? DateFormat('dd MMM yyyy').format(toDate) : DateFormat('dd MMM yyyy').format(DateTime.now());

    double totalInflow = 0;
    double totalOutflow = 0;
    for (var tx in transactions) {
      final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final isCredit = tx['isCredit'] == true || (tx['type']?.toString().toLowerCase().contains('deposit') ?? false);
      if (isCredit) {
        totalInflow += amt;
      } else {
        totalOutflow += amt;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RENTILLY',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      'Living Escrow Statement of Account',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('STATEMENT PERIOD', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('$start - $end', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300, height: 20),

            // Account Details & Summary
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ACCOUNT HOLDER', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text(user.fullName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text(user.email, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Account: ${user.accountNumber ?? "9955394366"} (${user.bankName ?? "Flutterwave MFB"})', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('CURRENT BALANCE: NGN ${_currencyFormat.format(user.walletBalance)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('Total Inflow: NGN ${_currencyFormat.format(totalInflow)}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.green800)),
                      pw.Text('Total Outflow: NGN ${_currencyFormat.format(totalOutflow)}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.red800)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Transaction Table
            pw.Text(
              'STATEMENT TRANSACTIONS (${transactions.length})',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 6),

            if (transactions.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                alignment: pw.Alignment.center,
                child: pw.Text('No transactions recorded during this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Description', 'Reference', 'Type', 'Amount (NGN)', 'Status'],
                data: transactions.map((tx) {
                  final isCredit = tx['isCredit'] == true || (tx['type']?.toString().toLowerCase().contains('deposit') ?? false);
                  final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                  return [
                    tx['date'] != null ? DateFormat('dd/MM/yy').format(DateTime.tryParse(tx['date'].toString()) ?? DateTime.now()) : DateFormat('dd/MM/yy').format(DateTime.now()),
                    tx['title'] ?? tx['type'] ?? 'Transfer',
                    (tx['reference'] ?? tx['id'] ?? 'REF').toString().substring(0, 8),
                    isCredit ? 'CREDIT' : 'DEBIT',
                    (isCredit ? '+ ' : '- ') + _currencyFormat.format(amt),
                    (tx['status'] ?? 'SUCCESS').toString().toUpperCase(),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: primaryColor),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellHeight: 22,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                },
              ),

            pw.SizedBox(height: 24),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by Rentilly Automated Financial Engine', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Official Certified Statement', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // 3. Helper Detail Row
  static pw.Widget _buildPdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  // 4. Download / Print PDF
  static Future<void> downloadOrPrintReceipt(BuildContext context, {required Map<String, dynamic> transaction, required UserProfile user}) async {
    final pdfBytes = await generateReceiptPdf(transaction: transaction, user: user);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Rentilly_Receipt_${transaction['reference'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> downloadOrPrintStatement(BuildContext context, {required UserProfile user, required List<Map<String, dynamic>> transactions}) async {
    final pdfBytes = await generateStatementPdf(user: user, transactions: transactions);
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
      text: 'Rentilly Living Escrow Receipt - ₦${_currencyFormat.format((transaction['amount'] as num?)?.toDouble() ?? 0.0)}',
      subject: 'Rentilly Transaction Receipt',
    );
  }

  static Future<void> shareStatement({
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdfBytes = await generateStatementPdf(user: user, transactions: transactions);
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
