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
    final businessName = isPartner
        ? (user.businessName ?? 'Apex Realty Partners Ltd')
        : (user.fullName.isNotEmpty ? user.fullName : 'Verified Property Owner');
    final cacNumber = user.cacNumber ?? (isPartner ? 'RC 1928374' : 'Verified Property Owner');
    final prefix = isPartner ? 'RNT-PTR' : 'RNT-LLD';
    final digitalId = '$prefix-${user.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4)}';
    final state = user.state ?? 'Lagos';
    final officeAddress = isPartner
        ? (user.officeAddress ?? 'Admiralty Way, Lekki Phase 1')
        : 'Direct Property Owner (Title & Deed Audited)';

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('064E3B'),
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: PdfColor.fromHex('4ADE80'), width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Top Branding
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RENTILLY ACCREDITED CREDENTIAL',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('4ADE80'),
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            isPartner ? 'CORPORATE BROKERAGE ID' : 'DIRECT PROPERTY OWNER ID',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('16A34A'),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          isPartner ? 'CAC VERIFIED' : 'TITLE AUDITED',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // Middle Identity
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('042F2E'),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          businessName,
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          isPartner ? 'CAC Reg: $cacNumber' : 'Title: Audited & Guaranteed by Rentilly Legal',
                          style: pw.TextStyle(color: PdfColor.fromHex('38BDF8'), fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'ID: $digitalId • Jurisdiction: $state State, Nigeria',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Operating Address: $officeAddress',
                          style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Footer & Policy
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ZERO-AGENT ESCROW GUARANTEED',
                            style: pw.TextStyle(color: PdfColor.fromHex('4ADE80'), fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Caution is 100% locked in escrow • 0% agency fees to tenants',
                            style: pw.TextStyle(color: PdfColors.grey400, fontSize: 8),
                          ),
                        ],
                      ),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'https://rentilly.ng/verify/id/$digitalId',
                        width: 44,
                        height: 44,
                        color: PdfColors.white,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Rentilly_Digital_ID_$digitalId.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF ID: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPartner = user.role == 'partner';
    final businessName = isPartner
        ? (user.businessName ?? 'Apex Realty Partners Ltd')
        : (user.fullName.isNotEmpty ? user.fullName : 'Verified Property Owner');
    final cacNumber = user.cacNumber ?? (isPartner ? 'RC 1928374' : 'Verified Property Owner');
    final prefix = isPartner ? 'RNT-PTR' : 'RNT-LLD';
    final digitalId = '$prefix-${user.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4)}';
    final state = user.state ?? 'Lagos';
    final officeAddress = isPartner
        ? (user.officeAddress ?? 'Admiralty Way, Lekki Phase 1')
        : 'Direct Property Owner (Title & Deed Audited)';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
                          isPartner ? 'Rentilly Corporate Partner ID' : 'Rentilly Verified Landlord ID',
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
                // The Official Digital Badge Card (Styled in Rentilly Green)
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
                      color: const Color(0xFF4ADE80),
                      width: 1.5,
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
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Bar of the Card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF4ADE80)),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RENTILLY ACCREDITATION',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: const Color(0xFF4ADE80),
                                      ),
                                    ),
                                    Text(
                                      isPartner ? 'CORPORATE PARTNER' : 'DIRECT PROPERTY OWNER',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF4ADE80)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 11, color: Color(0xFF4ADE80)),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPartner ? 'CAC VERIFIED' : 'TITLE AUDITED',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF4ADE80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Center Details
                        Text(
                          businessName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPartner ? 'CAC Reg: $cacNumber' : 'Title: Audited & Guaranteed by Rentilly Legal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ID & Location Grid
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('DIGITAL ACCREDITATION ID', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white60)),
                                      Text(digitalId, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80))),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('JURISDICTION', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white60)),
                                      Text('$state State, Nigeria', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1, color: Colors.white12),
                              const SizedBox(height: 8),
                              Text('REGISTERED ADDRESS', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white60)),
                              Text(officeAddress, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Share PDF Action Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _generateAndShareIdPdf(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Share Digital ID as PDF 📄',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
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
}
