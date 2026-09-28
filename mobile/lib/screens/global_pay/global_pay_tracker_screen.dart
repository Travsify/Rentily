import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../widgets/rentilly_bottom_bar.dart';

class GlobalPayTrackerScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const GlobalPayTrackerScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isTuition = order['orderType'] == 'tuition';
    final status = order['status'] ?? 'PROCESSING';

    final stages = [
      {
        'title': 'Pre-Auth Wallet Hold Secured',
        'subtitle': '₦${currencyFormat.format(order['totalDebitedNgn'] ?? 0)} locked with zero-risk atomic accounting.',
        'icon': Icons.lock_clock,
        'completed': true,
      },
      {
        'title': 'Compliance & Sanctions Screening Cleared',
        'subtitle': 'AML OFAC checks passed. CBN documentation matched.',
        'icon': Icons.verified_user,
        'completed': true,
      },
      {
        'title': 'Dispatched via Rentilly International Clearing Rail',
        'subtitle': 'Route: ${(order['paymentScheme'] ?? 'SWIFT').toString().toUpperCase()} clearing network.',
        'icon': Icons.send_rounded,
        'completed': status == 'PROCESSING' || status == 'COMPLETED',
      },
      {
        'title': isTuition ? 'Tuition Credited to University' : 'Supplier Bank Received Wire',
        'subtitle': status == 'COMPLETED'
            ? 'Delivered and confirmed by beneficiary bank.'
            : 'Estimated delivery: 2 to 24 hours depending on country rail.',
        'icon': Icons.check_circle_rounded,
        'completed': status == 'COMPLETED',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      bottomNavigationBar: const RentillyBottomBar(currentIndex: 3),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transfer Tracker',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Status Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (status == 'COMPLETED' ? AppColors.mint : AppColors.accentGold).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'COMPLETED' ? Icons.check : Icons.hourglass_top,
                      color: status == 'COMPLETED' ? AppColors.mint : AppColors.accentGoldDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${order['destinationCurrency']} ${currencyFormat.format(order['destinationAmount'] ?? 0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTuition
                        ? (order['institutionName'] ?? 'University Tuition')
                        : (order['beneficiary']?['name'] ?? 'Overseas Supplier'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (status == 'COMPLETED' ? AppColors.mint : AppColors.accentGold).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'STATUS: $status',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status == 'COMPLETED' ? AppColors.mint : AppColors.accentGoldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4-Stage Timeline
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transfer Lifecycle',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (int i = 0; i < stages.length; i++) ...[
                    _buildTimelineStep(
                      title: stages[i]['title'] as String,
                      subtitle: stages[i]['subtitle'] as String,
                      icon: stages[i]['icon'] as IconData,
                      isCompleted: stages[i]['completed'] as bool,
                      isLast: i == stages.length - 1,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Remittance Certificate Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remittance Certificate Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Reference:', order['reference'] ?? 'N/A'),
                  if (order['fincraPayoutReference'] != null)
                    _buildDetailRow('Clearing Rail Ref:', (order['fincraPayoutReference'] ?? '').toString().replaceAll('FINCRA_', 'RTLY_').replaceAll('fincra_', 'rtly_')),
                  if (isTuition && order['studentMatricId'] != null)
                    _buildDetailRow('Student ID:', order['studentMatricId']),
                  if (!isTuition && order['invoiceNumber'] != null)
                    _buildDetailRow('Invoice #:', order['invoiceNumber']),
                  _buildDetailRow(
                    'Rate Locked:',
                    '1 ${order['destinationCurrency']} = ₦${currencyFormat.format(order['customerRate'] ?? 0)}',
                  ),
                  _buildDetailRow(
                    'Corridor Rail Fee:',
                    '₦${currencyFormat.format(order['corridorFeeNgn'] ?? 0)}',
                  ),
                  const Divider(color: AppColors.borderDark, height: 20),
                  _buildDetailRow(
                    'Total Naira Debited:',
                    '₦${currencyFormat.format(order['totalDebitedNgn'] ?? 0)}',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Official PDF Remittance Certificate Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _generateAndSharePdfReceipt(context),
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                label: Text(
                  'Download Official Remittance Advice (PDF)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndSharePdfReceipt(BuildContext context) async {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isTuition = order['orderType'] == 'tuition';
    final pdf = pw.Document();

    pdf.addPage(
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
                      pw.Text('RENTILLY GLOBAL PAY', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                      pw.Text('Official Cross-Border Remittance Certificate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text('VERIFIED DISPATCH', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey300, thickness: 1, height: 24),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Remittance Reference:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text('${order['reference'] ?? 'RGP_TRANSFER'}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Issue Date & Timestamp:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text('${DateTime.now().toUtc().toString().split('.')[0]} UTC', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TRANSACTION SUMMARY', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Remittance Type:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(isTuition ? 'Tuition & University Fees' : 'Commercial Supplier Payment', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Beneficiary Institution / Entity:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('${order['beneficiary']?['name'] ?? order['institutionName'] ?? 'Beneficiary'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    if (isTuition && order['studentMatricId'] != null) ...[
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Student Matric / App ID:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${order['studentMatricId']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                    if (!isTuition && order['invoiceNumber'] != null) ...[
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Proforma Invoice #:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${order['invoiceNumber']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Clearing Rail & Route:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('${(order['paymentScheme'] ?? 'SWIFT').toString().toUpperCase()} Clearing Network', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Settlement Currency & Amount:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('${order['destinationCurrency']} ${currencyFormat.format(order['destinationAmount'] ?? 0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Locked FX Exchange Rate:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('1 ${order['destinationCurrency']} = NGN ${currencyFormat.format(order['customerRate'] ?? 0)}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Divider(color: PdfColors.grey300, height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Source Debited:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('NGN ${currencyFormat.format(order['totalDebitedNgn'] ?? 0)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'This document serves as official remittance proof issued by Rentilly Global Pay. Remitted funds are cleared via licensed Central Bank and international correspondent rails.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Rentilly_Remittance_${order['reference'] ?? 'Certificate'}.pdf',
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.primary : AppColors.borderDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isCompleted ? Colors.white : AppColors.textMuted,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? AppColors.primary : AppColors.borderDark,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isHighlight ? 14 : 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
