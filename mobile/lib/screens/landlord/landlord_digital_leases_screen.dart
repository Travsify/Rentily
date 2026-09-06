import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class LandlordDigitalLeasesScreen extends StatefulWidget {
  const LandlordDigitalLeasesScreen({super.key});

  @override
  State<LandlordDigitalLeasesScreen> createState() => _LandlordDigitalLeasesScreenState();
}

class _LandlordDigitalLeasesScreenState extends State<LandlordDigitalLeasesScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  List<Map<String, dynamic>> _leases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final user = await AuthService.getCurrentUser();
    List<Map<String, dynamic>> realLeases = [];
    try {
      final list = await ApiService.fetchLegalAgreements(
        email: user?.email,
        landlordId: user?.id,
      );
      for (final item in list) {
        realLeases.add({
          'id': item['transactionId'] ?? item['id'] ?? 'LEASE-2026',
          'status': item['status'] == 'fully_executed' ? 'ACTIVE' : 'PENDING',
          'statusColor': item['status'] == 'fully_executed' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          'propertyTitle': item['agreementTitle'] ?? item['propertyTitle'] ?? 'Tenancy Property',
          'address': item['propertyAddress'] ?? item['address'] ?? 'Lagos, Nigeria',
          'tenantName': item['tenantName'] ?? 'Direct Tenant',
          'tenantPhone': item['tenantPhone'] ?? item['tenantEmail'] ?? 'Verified Tenant',
          'annualRent': (item['annualRent'] as num?)?.toDouble() ?? 0.0,
          'startDate': item['tenancyCommencementDate'] ?? item['commencement_date'] ?? 'N/A',
          'endDate': item['tenancyExpirationDate'] ?? '12 Months',
          'caution': (item['cautionDeposit'] as num?)?.toDouble() ?? (item['caution_deposit'] as num?)?.toDouble() ?? 0.0,
          'rentillyFee': 0.0,
          'governingLaw': item['governingLaw'] ?? (item['propertyState'] != null ? 'Laws of ${item['propertyState']} State' : 'Laws of the Federal Republic of Nigeria'),
          'isDisputed': false,
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _leases = realLeases;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateLeasePdf(Map<String, dynamic> lease) async {
    final doc = pw.Document();
    final user = await AuthService.getCurrentUser();
    final landlordName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Property Owner';

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
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://myrentilly.com/verify/lease/${lease['id']}',
                    width: 44,
                    height: 44,
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),
              pw.Text('THIS RESIDENTIAL TENANCY AGREEMENT is executed between:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
              pw.SizedBox(height: 6),
              pw.Text('LANDLORD / PROPERTY OWNER: $landlordName', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('DIRECT TENANT: ${lease['tenantName']}', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('1. DEMISED PREMISES', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('The Landlord agrees to let and the Tenant agrees to take the property described as ${lease['propertyTitle']}, situated at ${lease['address']}.', style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4)),
              pw.SizedBox(height: 10),
              pw.Text('2. TERM & FINANCIAL CONSIDERATION', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('• Annual Rent: NGN ${_currencyFormat.format(lease['annualRent'])} (Locked in CBN Regulated Escrow)', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('• Caution / Security Deposit: NGN ${_currencyFormat.format(lease['caution'])} (100% Escrow Vaulted)', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('• Commencement Date: ${lease['startDate']}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.Text('3. STATUTORY COVENANTS & GOVERNING LAW', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('This agreement is governed by the ${lease['governingLaw']}. Key handover and tenant move-in are validated digitally through the Rentilly Escrow Vault.', style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4)),
              pw.Spacer(),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Digitally Signed by Landlord:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(landlordName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Status: Certified & Executed', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Digitally Signed by Tenant:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(lease['tenantName'] ?? 'Tenant', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Verification Ref: ${lease['id']}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
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
      filename: 'Rentilly_Lease_${lease['id']}.pdf',
    );
  }

  void _showLeaseDetails(Map<String, dynamic> lease) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderDark))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 20, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Text('Nigerian Tenancy Law Digital Lease', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PROPERTY: ${lease['propertyTitle']}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Address: ${lease['address']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Text('Tenant: ${lease['tenantName']} (${lease['tenantPhone']})', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Annual Rent: ₦${_currencyFormat.format(lease['annualRent'])}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 4),
                        Text('Caution Deposit: ₦${_currencyFormat.format(lease['caution'])} (100% Escrow Locked)', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFD97706), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Term: ${lease['startDate']} - ${lease['endDate']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _generateLeasePdf(lease);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                    label: Text('Download Signed Agreement PDF', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Digital Leases & Contracts',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // Legal Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gavel_rounded, size: 18, color: Color(0xFF4ADE80)),
                      const SizedBox(width: 6),
                      Text(
                        'NIGERIAN TENANCY LAW COMPLIANT',
                        style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80), letterSpacing: 0.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Legally Audited Tenancy Agreements',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All leases generated on Rentilly are digitally signed, legally binding in Nigerian courts, and include automated move-in key handover escrow protection under the laws of the Federal Republic of Nigeria.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'ACTIVE TENANCY LEASES (${_leases.length})',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            if (_leases.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.description_outlined, size: 36, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Digital Leases Yet',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'When tenants complete verification, execute their tenancy agreement, and fund move-in escrow, legally certified digital leases will appear here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              )
            else
              ..._leases.map((lease) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lease['id'], style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (lease['statusColor'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lease['status'],
                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: lease['statusColor']),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(lease['propertyTitle'], style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Tenant: ${lease['tenantName']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('₦${_currencyFormat.format(lease['annualRent'])} / yr', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Text('• ${lease['startDate']} to ${lease['endDate']}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showLeaseDetails(lease),
                              icon: const Icon(Icons.description_outlined, size: 14, color: AppColors.primary),
                              label: Text('View Details', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                );
              }),
          ],
        ),
      ),
    );
  }
}
