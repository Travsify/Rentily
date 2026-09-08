import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../properties/properties_screen.dart';

class TenancyAgreementsScreen extends StatefulWidget {
  const TenancyAgreementsScreen({super.key});

  @override
  State<TenancyAgreementsScreen> createState() => _TenancyAgreementsScreenState();
}

class _TenancyAgreementsScreenState extends State<TenancyAgreementsScreen> {
  final List<Map<String, dynamic>> _userAgreements = [];
  final List<Map<String, dynamic>> _userDispatches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAgreements();
  }

  void _loadAgreements() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      final list = await ApiService.fetchLegalAgreements(email: user?.email);
      final dispatches = await ApiService.fetchLegalDispatches(email: user?.email);
      if (mounted) {
        setState(() {
          _userAgreements.clear();
          _userDispatches.clear();
          _userDispatches.addAll(dispatches);
          for (final item in list) {
            _userAgreements.add({
              'id': item['id'],
              'title': item['agreementTitle'] ?? item['propertyTitle'] ?? 'Tenancy Agreement',
              'ref': item['transactionId'] ?? item['id'] ?? 'RENT-2026',
              'landlord': item['landlordName'] ?? 'Direct Landlord',
              'tenant': item['tenantName'] ?? user?.fullName ?? 'Tenant',
              'rent': item['annualRent']?.toString() ?? '0.00',
              'caution': item['cautionDeposit']?.toString() ?? '0.00',
              'duration': '12 Months',
              'startDate': item['tenancyCommencementDate'] ?? 'Pending',
              'address': item['propertyAddress'] ?? item['propertyTitle'] ?? 'Property Location, Nigeria',
              'status': item['status'] == 'fully_executed' ? 'ACTIVE LEASE' : 'PENDING SIGNATURES',
            });
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _downloadAgreement(Map<String, dynamic> agreement) async {
    final doc = pw.Document();
    final ref = agreement['ref'] ?? 'RENT-ESCROW';
    final title = agreement['title'] ?? 'Tenancy Agreement';
    final landlord = agreement['landlord'] ?? 'Verified Landlord';
    final tenant = agreement['tenant'] ?? 'Tenant';
    final rent = agreement['rent'] ?? '0.00';
    final caution = agreement['caution'] ?? '0.00';
    final address = agreement['address'] ?? 'Nigeria';
    final startDate = agreement['startDate'] ?? '2026';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
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
                      pw.Text('RENTILLY DIGITAL LEASE AGREEMENT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Under the Tenancy Laws of the Federal Republic of Nigeria', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Reference: $ref', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://api.myrentilly.com/verify/credential/$ref',
                    width: 44,
                    height: 44,
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),
              pw.Text('PARTIES TO THIS AGREEMENT:', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('• LANDLORD / PROPERTY OWNER: $landlord', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('• TENANT: $tenant', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('1. DEMISED PREMISES', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('The Landlord lets and the Tenant takes the property described as: $title situated at $address.', style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4)),
              pw.SizedBox(height: 12),
              pw.Text('2. FINANCIAL CONSIDERATION & ESCROW', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('• Agreed Annual Rent: NGN $rent (Escrow Secured)', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('• Caution Deposit (Held): NGN $caution (Refundable under Rentilly Protocol)', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('• Tenancy Term: 12 Calendar Months commencing from $startDate', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('3. STATUTORY COVENANTS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('All payments are audited and secured through the Rentilly Escrow System. Disputes are subject to the Arbitration & Mediation Act 2023.', style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4)),
              pw.Spacer(),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Digitally Executed by Landlord:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(landlord, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Status: Certified & Bound', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Digitally Executed by Tenant:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(tenant, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Escrow Ref: $ref', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Rentilly-Lease-$ref.pdf',
    );
  }

  void _viewAgreementDetails(Map<String, dynamic> agreement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tenancy Contract Details',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agreement['title'] ?? 'Tenancy Agreement', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(agreement['address'] ?? 'Property Location, Nigeria', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                    const Divider(height: 20),
                    _buildContractRow('Contract Ref', agreement['ref'] ?? 'RENT-2026-01'),
                    _buildContractRow('Landlord / Lessor', agreement['landlord'] ?? 'Verified Landlord'),
                    _buildContractRow('Annual Rent', '₦${agreement['rent'] ?? '0.00'}'),
                    _buildContractRow('Caution Escrow', '₦${agreement['caution'] ?? '0.00'} (0.0% Protected)'),
                    _buildContractRow('Lease Duration', agreement['duration'] ?? '12 Months'),
                    _buildContractRow('Commencement Date', agreement['startDate'] ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _downloadAgreement(agreement);
                  },
                  icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                  label: Text('Download Signed PDF Contract', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _confirmReceipt(Map<String, dynamic> dispatch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Confirm Document Receipt',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: Text(
          'Do you confirm that you have physically received your original, stamped, and sealed legal agreements for ${dispatch['propertyTitle'] ?? 'this property'} via ${dispatch['courierPartner'] ?? 'Courier'}?',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Received', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiService.confirmLegalDispatchReceipt(dispatch['id']);
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            dispatch['recipientConfirmed'] = true;
            dispatch['status'] = 'delivered';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF16A34A),
              content: Text('✓ Document receipt confirmed! Updated in Rentilly Legal Ledger.'),
            ),
          );
        }
      }
    }
  }

  void _showDeliveryTrackerModal(Map<String, dynamic> dispatch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final courier = dispatch['courierPartner'] ?? 'GIG Logistics';
          final waybill = dispatch['waybillNumber'] ?? '';
          final status = dispatch['status'] ?? 'drafting';
          final isDiaspora = dispatch['isDiaspora'] == true;
          final docusign = dispatch['docusignStatus'] ?? 'not_applicable';
          final isConfirmed = dispatch['recipientConfirmed'] == true;

          int currentStep = 0;
          if (status == 'delivered' || isConfirmed) {
            currentStep = 4;
          } else if (status == 'in_transit' || status == 'dispatched') {
            currentStep = 3;
          } else if (status == 'stamped_and_sealed') {
            currentStep = 2;
          } else if (status == 'signed' || docusign == 'signed' || docusign == 'completed') {
            currentStep = 1;
          } else {
            currentStep = 0;
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDiaspora ? const Color(0xFFFAF5FF) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDiaspora ? const Color(0xFFC084FC) : const Color(0xFF86EFAC)),
                          ),
                          child: Icon(
                            isDiaspora ? Icons.public_rounded : Icons.local_shipping_rounded,
                            size: 20,
                            color: isDiaspora ? const Color(0xFF7E22CE) : const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDiaspora ? 'Diaspora Courier Conveyance' : 'Domestic Courier Conveyance',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              courier,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Waybill & Info Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WAYBILL / TRACKING REF', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                              const SizedBox(height: 2),
                              Text(
                                waybill.isEmpty ? 'Pending Courier Assignment' : waybill,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          if (waybill.isNotEmpty)
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Copy Waybill',
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: waybill));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Waybill number copied to clipboard!')),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Share Tracking',
                                  icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.primary),
                                  onPressed: () {
                                    Share.share(
                                      '📦 RENTILLY LEGAL DOSSIER SHIPMENT TRACKING\n\n'
                                      'Property: ${dispatch['propertyTitle']}\n'
                                      'Courier: $courier\n'
                                      'Waybill: $waybill\n'
                                      'Tracking Link: ${dispatch['trackingUrl'] ?? ''}',
                                    );
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Destination:', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            '${dispatch['deliveryCity'] ?? ''}, ${dispatch['deliveryCountry'] ?? 'Nigeria'}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      if (docusign != 'not_applicable') ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DocuSign Digital Lock:', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFC084FC)),
                              ),
                              child: Text(
                                docusign == 'signed' || docusign == 'completed' ? '✓ Digitally Executed' : 'Envelope Sent',
                                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF7E22CE)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('LEGAL CONVEYANCE PROGRESS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                // 5-step Stepper
                _buildTrackingStep(1, 'Prepared & Vetted by Legal', 'Lease & title covenants customized for property jurisdiction', currentStep >= 0),
                _buildTrackingStep(2, 'Digital Execution', isDiaspora ? 'DocuSign envelope executed across borders' : 'Landlord counter-signature registered', currentStep >= 1),
                _buildTrackingStep(3, 'Corporate Seal & Stamped', 'Physical hard copy embossed with Rentilly Corporate Seal', currentStep >= 2),
                _buildTrackingStep(4, 'Dispatched & In Transit', 'Handed over to $courier with door-to-door waybill', currentStep >= 3),
                _buildTrackingStep(5, 'Delivered & Received', isConfirmed ? 'Confirmed received by recipient' : 'Awaiting physical delivery confirmation', currentStep >= 4, isLast: true),
                const SizedBox(height: 20),
                // Action Button
                if (!isConfirmed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmReceipt(dispatch);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                      label: Text('I Have Received My Hard Copy Agreement', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Center(
                      child: Text(
                        '✓ Physical Document Receipt Confirmed & Ledgered',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackingStep(int stepNum, String title, String subtitle, bool isCompleted, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : Text('$stepNum', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.w600,
                    color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Tenancy Agreements',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _userAgreements.isEmpty
                ? _buildEmptyState()
                : _buildAgreementsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Active Tenancy Agreements',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have not rented an apartment or completed a lease on Rentilly yet. When you execute a lease with direct landlords, your legally binding Nigerian State Tenancy agreements with escrow certificates will appear here for PDF download.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PropertiesScreen(initialPurpose: 'rent')),
                );
              },
              icon: const Icon(Icons.search_rounded, size: 16, color: Colors.white),
              label: Text(
                'Explore Properties for Rent',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      itemCount: _userAgreements.length,
      itemBuilder: (context, index) {
        final agreement = _userAgreements[index];
        final matchingDispatch = _userDispatches.firstWhere(
          (d) => d['agreementId'] == agreement['id'] || (d['propertyTitle'] ?? '').toString().toLowerCase() == (agreement['title'] ?? '').toString().toLowerCase(),
          orElse: () => _userDispatches.isNotEmpty ? _userDispatches.first : <String, dynamic>{},
        );
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderDark),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ACTIVE LEASE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  Text(
                    agreement['ref'] ?? 'RENT-2026',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                agreement['title'] ?? 'Tenancy Agreement',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                agreement['address'] ?? 'Property Location, Nigeria',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              // Physical Hard Copy Courier Dispatch Section
              if (matchingDispatch.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              matchingDispatch['isDiaspora'] == true ? Icons.public_rounded : Icons.local_shipping_outlined,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${matchingDispatch['courierPartner'] ?? 'Courier'} • ${((matchingDispatch['status'] ?? 'drafting') as String).toUpperCase().replaceAll('_', ' ')}',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _showDeliveryTrackerModal(matchingDispatch),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Track 📦',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ANNUAL RENT', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      Text('₦${agreement['rent']}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _viewAgreementDetails(agreement),
                        icon: const Icon(Icons.visibility_outlined, size: 14, color: AppColors.primary),
                        label: Text('View', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _downloadAgreement(agreement),
                        icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                        label: Text('PDF', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
