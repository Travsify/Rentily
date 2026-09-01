import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';

class PartnerIdCardModal extends StatelessWidget {
  final UserProfile user;

  const PartnerIdCardModal({super.key, required this.user});

  static void show(BuildContext context, {required UserProfile user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartnerIdCardModal(user: user),
    );
  }

  Future<void> _generateAndShareIdPdf(BuildContext context) async {
    final isPartner = user.role == 'partner';
    final isVerified = user.isVerified || user.bvnVerified;

    final holderName = isPartner
        ? (user.businessName != null && user.businessName!.trim().isNotEmpty
            ? user.businessName!.trim()
            : (user.fullName.trim().isNotEmpty ? user.fullName.trim() : 'Partner Enterprise'))
        : (user.fullName.trim().isNotEmpty ? user.fullName.trim() : 'Property Owner');

    final cacOrTitle = isPartner
        ? (user.cacNumber != null && user.cacNumber!.trim().isNotEmpty
            ? user.cacNumber!.trim()
            : (isVerified ? 'CAC Registered' : 'Pending CAC KYB'))
        : (isVerified ? 'Deed & Land Registry Audited' : 'Pending Land Registry Audit');

    final prefix = isPartner ? 'RNT-PTR' : 'RNT-LLD';
    final digitalId = '$prefix-${user.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4)}';
    
    final rawState = (user.state != null && user.state!.trim().isNotEmpty) ? user.state!.trim() : 'Lagos';
    final cleanState = rawState.toLowerCase().contains('fct') || rawState.toLowerCase().contains('abuja')
        ? 'Abuja (FCT)'
        : (rawState.toLowerCase().contains('state') ? rawState : '$rawState State');
    final jurisdiction = '$cleanState, Nigeria';
    
    final designation = isPartner ? 'Corporate Brokerage Mandate' : 'Direct Property Owner / Lessor';

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(115 * PdfPageFormat.mm, 175 * PdfPageFormat.mm, marginAll: 8 * PdfPageFormat.mm),
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('064E3B'),
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: PdfColor.fromHex(isVerified ? '4ADE80' : 'FBBF24'), width: 1.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Top Security Header
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('042F2E'),
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColor.fromHex('14532D')),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'RENTILLY ESCROW NETWORK',
                              style: pw.TextStyle(
                                color: PdfColor.fromHex(isVerified ? '4ADE80' : 'FBBF24'),
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              isPartner ? 'CORPORATE BROKERAGE CREDENTIAL' : 'DIRECT PROPERTY OWNER CREDENTIAL',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex(isVerified ? '16A34A' : 'D97706'),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            isVerified
                                ? (isPartner ? 'CAC AUDITED' : 'TITLE VERIFIED')
                                : (isPartner ? 'PENDING KYB' : 'PENDING KYC'),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // 2. Smart Chip & Security Tier Indicator Bar
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Metallic EMV Chip Representation
                      pw.Container(
                        width: 34,
                        height: 26,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('D97706'),
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColor.fromHex('FDE68A'), width: 1),
                        ),
                        child: pw.Center(
                          child: pw.Container(
                            width: 22,
                            height: 14,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColor.fromHex('92400E'), width: 0.8),
                            ),
                          ),
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'ACCREDITATION ID NUMBER',
                            style: pw.TextStyle(color: PdfColor.fromHex(isVerified ? '86EFAC' : 'FDE68A'), fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            digitalId,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),

                  // 3. Credential Data Table (Real ID Layout)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('042F2E'),
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColor.fromHex('166534')),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Legal Name
                        pw.Text('LEGAL TITLE HOLDER / ENTITY', style: pw.TextStyle(color: PdfColor.fromHex(isVerified ? '4ADE80' : 'FBBF24'), fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 1),
                        pw.Text(holderName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),

                        // Two column data
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('ROLE / DESIGNATION', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 1),
                                  pw.Text(designation, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('JURISDICTION', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 1),
                                  pw.Text(jurisdiction, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),

                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('TITLE / COMPLIANCE AUDIT', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 1),
                                  pw.Text(cacOrTitle, style: pw.TextStyle(color: PdfColor.fromHex(isVerified ? 'FBBF24' : 'F87171'), fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('ESCROW SECURITY TIER', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 1),
                                  pw.Text(
                                    isVerified
                                        ? (isPartner ? 'Accredited Corporate Partner' : 'Class-A Verified Owner')
                                        : 'Tier-1 Pending Verification',
                                    style: pw.TextStyle(color: PdfColor.fromHex(isVerified ? '4ADE80' : 'FBBF24'), fontSize: 8, fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),

                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('ISSUE DATE', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 1),
                                  pw.Text('September 2026', style: pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('VALIDITY / REVIEW CYCLE', style: pw.TextStyle(color: PdfColor.fromHex('94A3B8'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 1),
                                  pw.Text('24 Months (2028)', style: pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // 4. Barcode & Security Strip
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.code128(),
                              data: digitalId,
                              width: 140,
                              height: 18,
                              drawText: false,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text('SECURITY ENCRYPTION: SHA-256 COMPLIANT', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.black)),
                          ],
                        ),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: 'https://rentilly.ng/verify/$digitalId',
                          width: 28,
                          height: 28,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Rentilly_Credential_${user.id}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPartner = user.role == 'partner';
    final isVerified = user.isVerified || user.bvnVerified;

    final holderName = isPartner
        ? (user.businessName != null && user.businessName!.trim().isNotEmpty
            ? user.businessName!.trim()
            : (user.fullName.trim().isNotEmpty ? user.fullName.trim() : 'Partner Enterprise'))
        : (user.fullName.trim().isNotEmpty ? user.fullName.trim() : 'Property Owner');

    final cacOrTitle = isPartner
        ? (user.cacNumber != null && user.cacNumber!.trim().isNotEmpty
            ? user.cacNumber!.trim()
            : (isVerified ? 'CAC Registered' : 'Pending CAC KYB'))
        : (isVerified ? 'Deed & Land Registry Audited' : 'Pending Land Registry Audit');

    final prefix = isPartner ? 'RNT-PTR' : 'RNT-LLD';
    final digitalId = '$prefix-${user.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4)}';
    
    final rawState = (user.state != null && user.state!.trim().isNotEmpty) ? user.state!.trim() : 'Lagos';
    final cleanState = rawState.toLowerCase().contains('fct') || rawState.toLowerCase().contains('abuja')
        ? 'Abuja (FCT)'
        : (rawState.toLowerCase().contains('state') ? rawState : '$rawState State');
    final jurisdiction = '$cleanState, Nigeria';
    
    final designation = isPartner ? 'Corporate Brokerage Mandate' : 'Direct Property Owner / Lessor';

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPartner ? 'Rentilly Partner ID Card' : 'Rentilly Landlord ID Card',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Official Field Inspection Credential',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scrollable Card Presentation Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // The Official Digital Badge Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF042F2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Security Header Strip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF042F2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF14532D)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: (isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)).withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.shield_rounded, size: 14, color: isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'RENTILLY ESCROW NETWORK',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                              color: isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                                            ),
                                          ),
                                          Text(
                                            isPartner ? 'CORPORATE BROKERAGE CREDENTIAL' : 'DIRECT PROPERTY OWNER CREDENTIAL',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isVerified
                                      ? (isPartner ? 'CAC AUDITED' : 'TITLE VERIFIED')
                                      : (isPartner ? 'PENDING KYB' : 'PENDING KYC'),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Smart EMV Chip & ID
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 44,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                              ),
                              child: Center(
                                child: Container(
                                  width: 28,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFF92400E), width: 0.9),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'ACCREDITATION ID NUMBER',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF86EFAC)),
                                ),
                                Text(
                                  digitalId,
                                  style: GoogleFonts.sourceCodePro(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Credential Data Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF042F2E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF166534)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LEGAL TITLE HOLDER / ENTITY',
                                style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                holderName.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDataField('ROLE / DESIGNATION', designation, Colors.white),
                                  ),
                                  Expanded(
                                    child: _buildDataField('JURISDICTION', jurisdiction, Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDataField('TITLE / COMPLIANCE AUDIT', cacOrTitle, const Color(0xFFFBBF24)),
                                  ),
                                  Expanded(
                                    child: _buildDataField(
                                      'ESCROW SECURITY TIER',
                                      isVerified
                                          ? (isPartner ? 'Class-A Accredited Partner' : 'Class-A Verified Owner')
                                          : 'Tier-1 Pending Verification',
                                      isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDataField('ISSUE DATE', 'September 2026', Colors.white70),
                                  ),
                                  Expanded(
                                    child: _buildDataField('VALIDITY / REVIEW CYCLE', '24 Months (2028)', Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Barcode & QR Code Security Strip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: List.generate(
                                      28,
                                      (index) => Container(
                                        margin: const EdgeInsets.only(right: 2),
                                        width: (index % 3 == 0) ? 3 : ((index % 2 == 0) ? 2 : 1),
                                        height: 22,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'SECURITY SERIAL: 8947-1928-LLD-SEC',
                                    style: GoogleFonts.sourceCodePro(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.qr_code_2_rounded, size: 28, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Download & Share PDF Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _generateAndShareIdPdf(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Download Printable Credential (PDF)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataField(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 1.5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
