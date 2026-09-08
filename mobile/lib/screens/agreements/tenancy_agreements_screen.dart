import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
      if (mounted) {
        setState(() {
          _userAgreements.clear();
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
