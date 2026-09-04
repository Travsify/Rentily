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

  // Helper to sanitize any string from unsupported PDF unicode glyphs
  static String _sanitizePdfText(String text) {
    return text
        .replaceAll('₦', 'NGN ')
        .replaceAll('\$', 'USD ')
        .replaceAll('£', 'GBP ')
        .replaceAll('€', 'EUR ')
        .replaceAll('•', '|')
        .replaceAll('—', '-')
        .replaceAll('–', '-');
  }

  static String _formatCurrencyPrefix(String curr) {
    switch (curr.toUpperCase()) {
      case 'USDT':
        return 'USDT ';
      case 'USD':
      case 'CARD_USD':
        return 'USD ';
      case 'GBP':
        return 'GBP ';
      case 'EUR':
        return 'EUR ';
      case 'NGN':
      default:
        return 'NGN ';
    }
  }

  // 1. Generate Certified Single Transaction Receipt PDF
  static Future<Uint8List> generateReceiptPdf({
    required Map<String, dynamic> transaction,
    required UserProfile user,
    String currency = 'NGN',
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#0B4F3F');
    final currPrefix = _formatCurrencyPrefix(currency);

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
                      '$currPrefix${_currencyFormat.format(amount)}',
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
              _buildPdfDetailRow('Dedicated Account Number', user.accountNumber ?? 'Pending 9PSB'),
              _buildPdfDetailRow('Settlement Partner Bank', bankName),
              _buildPdfDetailRow('Settlement Category', 'Rentilly Escrow Protected'),
              _buildPdfDetailRow('Payer Email', user.email),
              _buildPdfDetailRow('Timestamp (UTC+1)', date),
              _buildPdfDetailRow('Corporate Issuer', 'Product of E-Homes Global Inclusive Limited'),

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
                          'Rentilly | E-Homes Global Inclusive Limited',
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
                      data: 'https://myrentilly.com/verify-receipt/$txRef',
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

  // 2. Generate Certified Bank-Grade Statement of Account (Multi-Currency)
  static Future<Uint8List> generateStatementPdf({
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    String currency = 'NGN',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#0B4F3F');
    final currPrefix = _formatCurrencyPrefix(currency);
    final start = fromDate != null ? DateFormat('dd MMM yyyy').format(fromDate) : '01 Aug 2026';
    final end = toDate != null ? DateFormat('dd MMM yyyy').format(toDate) : DateFormat('dd MMM yyyy').format(DateTime.now());
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final partnerBank = _sanitizePdfText(user.bankName ?? 'Flutterwave MFB');

    double totalInflow = 0;
    double totalOutflow = 0;

    // Filter transactions within range and currency if specified
    final filtered = transactions.where((tx) {
      if (tx['date'] == null) return true;
      final d = DateTime.tryParse(tx['date'].toString());
      if (d == null) return true;
      if (fromDate != null && d.isBefore(fromDate.subtract(const Duration(seconds: 1)))) return false;
      if (toDate != null && d.isAfter(toDate.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    for (final tx in filtered) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final isCredit = tx['isCredit'] == true ||
          (tx['type'] ?? '').toString().toLowerCase().contains('credit') ||
          (tx['type'] ?? '').toString().toLowerCase().contains('inflow') ||
          (tx['type'] ?? '').toString().toLowerCase().contains('deposit') ||
          (tx['type'] ?? '').toString().toLowerCase().contains('commission') ||
          (tx['type'] ?? '').toString().toLowerCase().contains('top');
      if (isCredit) {
        totalInflow += amount;
      } else {
        totalOutflow += amount;
      }
    }

    final netMovement = totalInflow - totalOutflow;
    final closingBalance = user.walletBalance;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RENTILLY LIVING PROTOCOL',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.Text(
                        'E-Homes Global Inclusive Limited (RC: 1984209)',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Plot 12, Admiralty Way, Lekki Phase 1, Lagos, Nigeria',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('OFFICIAL ACCOUNT STATEMENT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('Currency: $currency', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('Period: $start - $end', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300, height: 16),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Account Holder & Settlement Details Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey200),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ACCOUNT HOLDER', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text(_sanitizePdfText(user.fullName), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        if (user.businessName != null && user.businessName!.isNotEmpty)
                          pw.Text(_sanitizePdfText(user.businessName!), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                        pw.Text(_sanitizePdfText(user.email), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(_sanitizePdfText(user.phoneNumber), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('COLLECTION COORDINATES', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text('Account Number: ${user.accountNumber ?? "Pending 9PSB"}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Settlement Bank: $partnerBank', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text('Account Type: Escrow / Wallet ($currency)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text('Generated: $generatedAt', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Performance / Metrics Summary Strip
            pw.Row(
              children: [
                _buildMetricBox('TOTAL INFLOW', '$currPrefix${_currencyFormat.format(totalInflow)}', PdfColors.green50, PdfColors.green800, PdfColors.green200),
                pw.SizedBox(width: 8),
                _buildMetricBox('TOTAL OUTFLOW', '$currPrefix${_currencyFormat.format(totalOutflow)}', PdfColors.red50, PdfColors.red800, PdfColors.red200),
                pw.SizedBox(width: 8),
                _buildMetricBox('NET MOVEMENT', '$currPrefix${_currencyFormat.format(netMovement)}', PdfColors.blue50, PdfColors.blue800, PdfColors.blue200),
                pw.SizedBox(width: 8),
                _buildMetricBox('AVAILABLE BALANCE', '$currPrefix${_currencyFormat.format(closingBalance)}', PdfColors.amber50, PdfColors.amber900, PdfColors.amber200),
              ],
            ),
            pw.SizedBox(height: 16),

            // Statement Ledger Table
            pw.Text(
              'TRANSACTION LEDGER HISTORY',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
            ),
            pw.SizedBox(height: 6),

            if (filtered.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 24),
                alignment: pw.Alignment.center,
                child: pw.Text('No transactions recorded during this statement period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.6),
                  1: const pw.FlexColumnWidth(3.0),
                  2: const pw.FlexColumnWidth(1.6),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.3),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableHeaderCell('DATE & TIME'),
                      _buildTableHeaderCell('DESCRIPTION / REF'),
                      _buildTableHeaderCell('CHANNEL'),
                      _buildTableHeaderCell('AMOUNT'),
                      _buildTableHeaderCell('STATUS'),
                    ],
                  ),
                  // Table Rows
                  ...filtered.map((tx) {
                    final d = tx['date'] != null
                        ? DateFormat('dd/MM/yy hh:mm a').format(DateTime.tryParse(tx['date'].toString()) ?? DateTime.now())
                        : 'Recent';
                    final title = _sanitizePdfText(tx['title'] ?? tx['type'] ?? 'Escrow Settlement');
                    final ref = _sanitizePdfText(tx['reference'] ?? tx['id'] ?? '');
                    final type = _sanitizePdfText(tx['type'] ?? 'Transfer');
                    final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                    final isCredit = tx['isCredit'] == true ||
                        (tx['type'] ?? '').toString().toLowerCase().contains('credit') ||
                        (tx['type'] ?? '').toString().toLowerCase().contains('inflow') ||
                        (tx['type'] ?? '').toString().toLowerCase().contains('deposit') ||
                        (tx['type'] ?? '').toString().toLowerCase().contains('commission') ||
                        (tx['type'] ?? '').toString().toLowerCase().contains('top');
                    final status = _sanitizePdfText((tx['status'] ?? 'SUCCESS').toString().toUpperCase());

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: filtered.indexOf(tx) % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: [
                        _buildTableCell(d, fontSize: 7),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                              if (ref.isNotEmpty)
                                pw.Text('Ref: $ref', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                        _buildTableCell(type, fontSize: 7),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '${isCredit ? "+" : "-"}$currPrefix${_currencyFormat.format(amt)}',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: isCredit ? PdfColors.green800 : PdfColors.red800,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            status,
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: status.contains('SUCC') || status.contains('PAID') ? PdfColors.green800 : PdfColors.orange800,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey300, height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Rentilly Escrow Protocol - Certified Non-Bank Electronic Financial Statement',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // 3. Generate Certified Virtual Dollar Card Statement
  static Future<Uint8List> generateCardStatementPdf({
    required UserProfile user,
    required List<Map<String, dynamic>> cardTransactions,
    Map<String, dynamic>? cardDetails,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#0B4F3F');
    final start = fromDate != null ? DateFormat('dd MMM yyyy').format(fromDate) : '01 Aug 2026';
    final end = toDate != null ? DateFormat('dd MMM yyyy').format(toDate) : DateFormat('dd MMM yyyy').format(DateTime.now());
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final last4 = cardDetails?['last4']?.toString() ?? '8842';
    final cardHolder = cardDetails?['name']?.toString() ?? user.fullName;
    final cardType = cardDetails?['brand']?.toString() ?? 'Visa USD Virtual Debit Card';
    final cardBalance = (cardDetails?['balance'] as num?)?.toDouble() ?? 1250.00;

    double totalFunding = 0;
    double totalMerchantSpend = 0;

    for (final tx in cardTransactions) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final isFunding = tx['isCredit'] == true ||
          (tx['type'] ?? '').toString().toLowerCase().contains('fund') ||
          (tx['type'] ?? '').toString().toLowerCase().contains('credit') ||
          (tx['type'] ?? '').toString().toLowerCase().contains('top');
      if (isFunding) {
        totalFunding += amount;
      } else {
        totalMerchantSpend += amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RENTILLY VIRTUAL DOLLAR CARD',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.Text(
                        'Bridgecard CaaS Cardholder Statement (USD Global Visa)',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('CARD ACCOUNT STATEMENT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('Card: **** **** **** $last4', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('Period: $start - $end', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300, height: 16),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Cardholder Specifications Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey200),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CARDHOLDER INFORMATION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text(_sanitizePdfText(cardHolder), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(_sanitizePdfText(user.email), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text('Issuer: Bridgecard CaaS / Lead Bank USA', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CARD SPECIFICATIONS', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text('Card Scheme: $cardType', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Currency: USD (United States Dollar)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text('Status: ACTIVE / 3D-SECURE ENABLED', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('Generated: $generatedAt', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Performance / Metrics Summary Strip
            pw.Row(
              children: [
                _buildMetricBox('TOTAL CARD FUNDING', 'USD ${_currencyFormat.format(totalFunding)}', PdfColors.green50, PdfColors.green800, PdfColors.green200),
                pw.SizedBox(width: 8),
                _buildMetricBox('TOTAL SPEND / POS', 'USD ${_currencyFormat.format(totalMerchantSpend)}', PdfColors.red50, PdfColors.red800, PdfColors.red200),
                pw.SizedBox(width: 8),
                _buildMetricBox('AVAILABLE CARD BALANCE', 'USD ${_currencyFormat.format(cardBalance)}', PdfColors.amber50, PdfColors.amber900, PdfColors.amber200),
              ],
            ),
            pw.SizedBox(height: 16),

            // Card Ledger Table
            pw.Text(
              'CARD SETTLEMENT & MERCHANT TRANSACTIONS',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
            ),
            pw.SizedBox(height: 6),

            if (cardTransactions.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 24),
                alignment: pw.Alignment.center,
                child: pw.Text('No card transactions recorded during this statement period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.6),
                  1: const pw.FlexColumnWidth(3.0),
                  2: const pw.FlexColumnWidth(1.6),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableHeaderCell('DATE & TIME'),
                      _buildTableHeaderCell('MERCHANT / DETAILS'),
                      _buildTableHeaderCell('CATEGORY'),
                      _buildTableHeaderCell('AMOUNT (USD)'),
                      _buildTableHeaderCell('STATUS'),
                    ],
                  ),
                  ...cardTransactions.map((tx) {
                    final d = tx['date'] != null
                        ? DateFormat('dd/MM/yy hh:mm a').format(DateTime.tryParse(tx['date'].toString()) ?? DateTime.now())
                        : 'Recent';
                    final merchant = _sanitizePdfText(tx['merchant'] ?? tx['title'] ?? 'International Merchant POS');
                    final cat = _sanitizePdfText(tx['category'] ?? tx['type'] ?? 'Subscription / POS');
                    final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                    final isCredit = tx['isCredit'] == true || (tx['type'] ?? '').toString().toLowerCase().contains('fund');
                    final status = _sanitizePdfText((tx['status'] ?? 'SUCCESSFUL').toString().toUpperCase());

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: cardTransactions.indexOf(tx) % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: [
                        _buildTableCell(d, fontSize: 7),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(merchant, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        ),
                        _buildTableCell(cat, fontSize: 7),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '${isCredit ? "+" : "-"}USD ${_currencyFormat.format(amt)}',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: isCredit ? PdfColors.green800 : PdfColors.red800,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            status,
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: status.contains('SUCC') || status.contains('PAID') ? PdfColors.green800 : PdfColors.orange800,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey300, height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Rentilly Card Protocol - Powered by Bridgecard CaaS',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Helper widgets for table and metrics
  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {double fontSize = 7.5}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey900)),
    );
  }

  static pw.Widget _buildMetricBox(String label, String value, PdfColor bgColor, PdfColor textColor, PdfColor borderColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: borderColor, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: textColor)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textColor), maxLines: 1),
          ],
        ),
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
  static Future<void> downloadOrPrintReceipt(
    BuildContext context, {
    required Map<String, dynamic> transaction,
    required UserProfile user,
    String currency = 'NGN',
  }) async {
    final pdfBytes = await generateReceiptPdf(transaction: transaction, user: user, currency: currency);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Rentilly_Receipt_${transaction['reference'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> downloadOrPrintStatement(
    BuildContext context, {
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    String currency = 'NGN',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdfBytes = await generateStatementPdf(
      user: user,
      transactions: transactions,
      currency: currency,
      fromDate: fromDate,
      toDate: toDate,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Rentilly_Statement_${currency}_${user.fullName.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<void> downloadOrPrintCardStatement(
    BuildContext context, {
    required UserProfile user,
    required List<Map<String, dynamic>> cardTransactions,
    Map<String, dynamic>? cardDetails,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdfBytes = await generateCardStatementPdf(
      user: user,
      cardTransactions: cardTransactions,
      cardDetails: cardDetails,
      fromDate: fromDate,
      toDate: toDate,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Rentilly_Card_Statement_${user.fullName.replaceAll(' ', '_')}.pdf',
    );
  }

  // 5. Share PDF via native Flutter Share Sheet
  static Future<void> shareReceipt({
    required Map<String, dynamic> transaction,
    required UserProfile user,
    String currency = 'NGN',
  }) async {
    final pdfBytes = await generateReceiptPdf(transaction: transaction, user: user, currency: currency);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Rentilly_Receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(pdfBytes);

    final currPrefix = _formatCurrencyPrefix(currency);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Rentilly Escrow Receipt - $currPrefix${_currencyFormat.format((transaction['amount'] as num?)?.toDouble() ?? 0.0)}',
      subject: 'Rentilly Transaction Receipt',
    );
  }

  static Future<void> shareStatement({
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    String currency = 'NGN',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdfBytes = await generateStatementPdf(
      user: user,
      transactions: transactions,
      currency: currency,
      fromDate: fromDate,
      toDate: toDate,
    );
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Rentilly_Statement_${currency}_${user.fullName.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Rentilly Escrow Account Statement ($currency) for ${user.fullName}',
      subject: 'Rentilly Account Statement',
    );
  }

  static Future<void> shareCardStatement({
    required UserProfile user,
    required List<Map<String, dynamic>> cardTransactions,
    Map<String, dynamic>? cardDetails,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdfBytes = await generateCardStatementPdf(
      user: user,
      cardTransactions: cardTransactions,
      cardDetails: cardDetails,
      fromDate: fromDate,
      toDate: toDate,
    );
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Rentilly_Card_Statement_${user.fullName.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Rentilly Virtual Dollar Card Statement for ${user.fullName}',
      subject: 'Rentilly Virtual Card Statement',
    );
  }
}
