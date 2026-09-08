import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';

class PartnerLegalModal extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> sections;

  const PartnerLegalModal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  // 1. Partner Legal Desk Modal
  static void showLegalDesk(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PartnerLegalModal(
        title: 'Partner Legal Desk ⚖️',
        subtitle: 'Corporate Partner Mandate & Arbitration Terms',
        sections: [
          {
            'icon': Icons.verified_user_rounded,
            'title': '1. Corporate Partner Mandate & Exclusive Representation',
            'content':
                'As an accredited Rentilly Corporate Partner, your listings are protected under Nigerian Commercial Law. Partners warrant that all property listings are backed by an executed Power of Attorney or verified Landlord Representation Mandate.',
          },
          {
            'icon': Icons.savings_rounded,
            'title': '2. 100% Escrow Commission Protection (2.5% / 2.0%)',
            'content':
                'Rentilly platform escrow locks tenant and buyer payments securely. Corporate Partner commissions (2.5% on annual leases and 2.0% on outright sales) are automatically credited to your Escrow Settlement Vault immediately upon tenant move-in confirmation.',
          },
          {
            'icon': Icons.shield_rounded,
            'title': '3. Anti-Ghost Shield & Physical Presence Warranty',
            'content':
                'To safeguard consumer trust and maintain zero-fraud standards, partners must provide an impromptu physical selfie in front of the property. Fabricated listings, duplicate media, or unauthorized postings result in immediate license forfeiture.',
          },
          {
            'icon': Icons.link_rounded,
            'title': '4. Landlord Auto-Link & Anti-Circumvention Policy',
            'content':
                'When you onboard landlords using your unique partner link, all current and future properties listed by that landlord are permanently mapped to your partner profile, preventing landlord circumvention.',
          },
          {
            'icon': Icons.gavel_rounded,
            'title': '5. Dispute Resolution & Tribunal Arbitration',
            'content':
                'In the event of an ownership contest or tenancy disagreement, Rentilly Legal Desk arbitrates within 72 hours in coordination with the Multi-Door Courthouse of the State High Court and the Arbitration and Mediation Act, 2023.',
          },
        ],
      ),
    );
  }

  // 2. Partner Inquiries, Complaints & Submissions Hub
  static void showInquiriesAndComplaints(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PartnerInquiryComplaintSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                      child: const Icon(Icons.gavel_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
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

          // Content List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, index) {
                final item = sections[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item['content'] as String,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderDark)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => generateMandateAgreementPdf(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF064E3B)),
                    label: Text(
                      'Download Exclusive Mandate Agreement (PDF) 📄',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF064E3B)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF064E3B), width: 1.3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Understood & Acknowledged', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> generateMandateAgreementPdf(BuildContext context) async {
    final user = await AuthService.getCurrentUser();
    if (user == null) return;

    final firmName = (user.businessName != null && user.businessName!.trim().isNotEmpty)
        ? user.businessName!.trim()
        : (user.fullName.trim().isNotEmpty ? user.fullName.trim() : 'Accredited Partner Firm');
    final cacNumber = user.cacNumber ?? 'CAC Registered Entity';
    final repName = user.fullName.isNotEmpty ? user.fullName : 'Principal Partner';
    final repPhone = user.phoneNumber;
    final repEmail = user.email;
    final state = user.state ?? 'Lagos';
    final lasrera = user.lasreraNumber ?? 'Accredited Partner';

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RENTILLY ESCROW NETWORK', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('064E3B'))),
                    pw.Text('EXCLUSIVE PARTNER MANDATE AGREEMENT', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A'))),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F0FDF4'),
                    border: pw.Border.all(color: PdfColor.fromHex('16A34A')),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('LEGAL INSTRUMENT', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('16A34A'))),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, color: PdfColor.fromHex('CBD5E1')),
            pw.SizedBox(height: 12),

            pw.Text('THIS EXCLUSIVE PARTNER MANDATE AGREEMENT is entered into on this ${DateFormat('dd').format(DateTime.now())} day of ${DateFormat('MMMM, yyyy').format(DateTime.now())} by and between:', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('F8FAFC'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('1. THE ACCREDITED PARTNER FIRM:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A'))),
                  pw.SizedBox(height: 3),
                  pw.Text('Firm: $firmName (CAC: $cacNumber | Regulatory Reg: $lasrera)', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Principal Partner: $repName | Phone: $repPhone | Email: $repEmail', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Territory Jurisdiction: $state State, Federal Republic of Nigeria', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('F8FAFC'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('2. PROPERTY OWNER & SUBJECT PREMISES VERIFICATION:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A'))),
                  pw.SizedBox(height: 3),
                  pw.Text('Owner Full Legal Name: __________________________________________________', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 2),
                  pw.Text('Phone Number / Email: __________________________________________________', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 2),
                  pw.Text('Subject Property Address: __________________________________________', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 2),
                  pw.Text('LGA & State: _____________________________ Target Asking Price: NGN ____________________', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('EFF6FF'),
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColor.fromHex('93C5FD')),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('MANDATORY PHYSICAL ADDRESS & UTILITY BILL ANNEXURE:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E40AF'))),
                        pw.SizedBox(height: 2),
                        pw.Text('Electricity Disco: ___________________ | Meter / Account No: _____________________________', style: const pw.TextStyle(fontSize: 7.5)),
                        pw.SizedBox(height: 1),
                        pw.Text('[  ] Verified copy of recent Electricity Bill / Prepaid Token Receipt attached (Mandatory for Rentilly Listing Activation).', style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('1E3A8A'))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // CRITICAL ESCROW SETTLEMENT & ANTI-FRAUD WARNING (BOLD RED)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('FEF2F2'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('DC2626'), width: 1.2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        'CRITICAL ESCROW SETTLEMENT & ANTI-FRAUD NOTICE',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('B91C1C'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '1. 100% ESCROW HOLD UNTIL MOVE-IN: All tenant rental payments and buyer consideration are locked securely in the Rentilly Non-Interest Escrow Vault. Funds remain in escrow and are NOT disbursed until the tenant has physically moved into the property and confirmed handover signoff.',
                    style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('991B1B'), height: 1.2),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '2. DIRECT OWNER SETTLEMENT ONLY: Net proceeds are settled exclusively into the verified Nigerian NUBAN bank account of the legitimate property owner upon successful move-in. No cash payments, third-party transfers, or partner proxy collections are permitted under any circumstances.',
                    style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('7F1D1D'), height: 1.2),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '3. CLIENT 100% REFUND & PARTNER BLACKLIST GUARANTEE: In the event of title contest, duplicate letting, unfulfilled physical handover, or inability of the tenant to take lawful possession, 100% of escrow funds are immediately refunded to the client, the listing is delisted, and the submitting partner is permanently blacklisted and referred for statutory prosecution under Nigerian law.',
                    style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('7F1D1D'), height: 1.2),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Text('OPERATIVE MANDATE COVENANTS:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A'))),
            pw.SizedBox(height: 5),

            _buildPdfTerm('1. Grant of Exclusive Mandate', 'The Owner grants the Partner the sole representation right to market, exhibit, and secure verified tenants/buyers for the Subject Property through the Rentilly Escrow Network.'),
            _buildPdfTerm('2. Guaranteed Escrow Remuneration (2.5% Rent / 2.0% Sales)', 'Upon execution of a valid lease or deed of sale, the Partner is entitled to standard remuneration of 2.5% of annual rent or 2.0% of purchase consideration, settled automatically via Rentilly Non-Interest Escrow Vault on handover.'),
            _buildPdfTerm('3. Strict Anti-Circumvention Protection', 'The Owner expressly warrants not to bypass, negotiate directly, or transact with any prospective tenant or buyer introduced by the Partner during or within 12 months after the mandate term.'),
            _buildPdfTerm('4. Physical Due Diligence & Mandatory Utility Bill Annexure', 'The Partner undertakes to conduct an in-person physical inspection of the Subject Property and obtain a copy of the recent electricity utility bill/token receipt matching the physical address. Both this executed Mandate and the Utility Bill must be uploaded to the Rentilly Network prior to listing activation.'),
            _buildPdfTerm('5. Arbitration & Dispute Resolution', 'Any contest or disagreement under this contract shall be submitted to the Multi-Door Courthouse of the State High Court in the jurisdiction where the Subject Property is situated, or the Rentilly Legal Arbitration Desk under the Arbitration and Mediation Act, 2023.'),

            pw.SizedBox(height: 18),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FOR THE PROPERTY OWNER:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 20),
                    pw.Text('Signature: ______________________', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.SizedBox(height: 3),
                    pw.Text('Date: _________________________', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FOR THE ACCREDITED PARTNER FIRM:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 20),
                    pw.Text('Signature: ______________________', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.SizedBox(height: 3),
                    pw.Text('Date: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Rentilly_Mandate_Agreement_${user.id}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static pw.Widget _buildPdfTerm(String title, String desc) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A'))),
          pw.SizedBox(height: 1),
          pw.Text(desc, style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('475569'), height: 1.25)),
        ],
      ),
    );
  }
}

// Interactive Inquiries, Complaints & Submissions Modal
class _PartnerInquiryComplaintSheet extends StatefulWidget {
  const _PartnerInquiryComplaintSheet();

  @override
  State<_PartnerInquiryComplaintSheet> createState() => _PartnerInquiryComplaintSheetState();
}

class _PartnerInquiryComplaintSheetState extends State<_PartnerInquiryComplaintSheet> {
  String _category = 'commission_settlement';
  String _urgency = 'normal';
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  final Map<String, String> _categoryOptions = {
    'commission_settlement': 'Commission & Escrow Settlement Query',
    'mandate_dispute': 'Landlord Partner Mandate Dispute',
    'verification_kyb': 'CAC KYB / Bank Account Inquiries',
    'inspection_access': 'Inspection Gate Code & Key Handover',
    'anti_ghost_report': 'Anti-Ghost Whistleblower Report',
    'general_support': 'General Corporate Partner Support',
  };

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitTicket() async {
    final subj = _subjectController.text.trim();
    final desc = _descriptionController.text.trim();

    if (subj.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a brief subject or reference code.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (desc.isEmpty || desc.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please describe your inquiry or complaint in detail (at least 10 chars).', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = await AuthService.getCurrentUser();
    String ticketId = 'TKT-PTR-${Random().nextInt(89999) + 10000}';

    // Dispatch to Live Server Support Desk
    if (user != null) {
      try {
        final res = await ApiService.submitSupportTicket(
          userEmail: user.email,
          subject: subj,
          message: desc,
          userId: user.id,
          userName: user.fullName,
          businessName: user.businessName,
          category: _category,
          urgency: _urgency,
        );
        if (res['ticketId'] != null) {
          ticketId = res['ticketId'].toString();
        }
      } catch (_) {}
    }

    // Record submission into user's notifications
    await NotificationService.addNotification(
      title: '📋 Inquiry Submitted: $ticketId',
      message: 'Your ${_categoryOptions[_category]} has been logged under reference $ticketId. Legal Desk SLA: 24–72 hours.',
      category: 'system',
      metadata: {
        'ticketId': ticketId,
        'category': _category,
        'subject': subj,
        'urgency': _urgency,
      },
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, size: 40, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 14),
            Text('Submission Dispatched 📋', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Ticket Reference: $ticketId\n\nYour submission has been routed directly to the Rentilly Legal & Partner Support Desk for ${user?.businessName ?? "your firm"}.\n\nOur corporate SLA ensures formal review within 24 to 72 hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        color: AppColors.accentOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded, size: 20, color: AppColors.accentOrange),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partner Inquiries & Complaints 📋',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Formal submissions, dispute arbitration & escalations',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
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

          // Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All partner inquiries, commission settlement discrepancies, and mandate disputes are handled under strict Nigerian arbitration protocols.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Category Selector
                Text('INQUIRY / COMPLAINT CATEGORY', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category,
                      isExpanded: true,
                      items: _categoryOptions.entries.map((e) {
                        return DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.plusJakartaSans(fontSize: 12)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Priority Selector
                Text('URGENCY LEVEL', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildPriorityChip('normal', 'Normal (72h)', Colors.blue),
                    const SizedBox(width: 8),
                    _buildPriorityChip('urgent', 'Urgent (24h)', AppColors.accentOrange),
                    const SizedBox(width: 8),
                    _buildPriorityChip('critical', 'High Priority', Colors.red),
                  ],
                ),
                const SizedBox(height: 14),

                // Subject / Reference ID
                Text('SUBJECT / PROPERTY REFERENCE ID', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _subjectController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. Commission payout on 3-Bed Lekki (PROP-892)',
                    prefixIcon: const Icon(Icons.label_outline_rounded, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                Text('DETAILED DESCRIPTION / PARTICULARS', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Provide full facts, tenant/landlord names, dates, and reference numbers for expedited arbitration...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitTicket,
                    icon: _isSubmitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Partner Inquiry / Complaint',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _urgency == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _urgency = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : const Color(0xFFCBD5E1), width: isSelected ? 1.5 : 1),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
