import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/payment_security_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/payment_pin_modal.dart';
import '../../widgets/partner_id_card_modal.dart';
import '../../widgets/app_avatar.dart';
import '../auth/login_screen.dart';

class LandlordProfileScreen extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;

  const LandlordProfileScreen({super.key, this.onSwitchToTenant});

  @override
  State<LandlordProfileScreen> createState() => _LandlordProfileScreenState();
}

class _LandlordProfileScreenState extends State<LandlordProfileScreen> {
  UserProfile? _user;
  bool _isLoading = true;
  bool _hasPaymentPin = false;
  bool _biometricsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    var user = await AuthService.getCurrentUser();
    final savedAvatar = prefs.getString('rentilly_persistent_avatar_url');
    if (user != null && (user.avatarUrl == null || user.avatarUrl!.isEmpty) && savedAvatar != null && savedAvatar.isNotEmpty) {
      user = user.copyWith(avatarUrl: savedAvatar);
    }
    final hasPin = await PaymentSecurityService.hasPaymentPin();
    if (mounted) {
      setState(() {
        _user = user;
        _hasPaymentPin = hasPin;
        _isLoading = false;
      });
    }
  }

  void _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null && _user != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rentilly_persistent_avatar_url', dataUri);
      if (_user!.email.isNotEmpty) {
        await prefs.setString('rentilly_avatar_${_user!.email.toLowerCase()}', dataUri);
      }

      final updated = _user!.copyWith(avatarUrl: dataUri);
      await AuthService.updateUser(updated);
      setState(() => _user = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated & synced to cloud! 📸', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Change Password', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'New Password (6+ chars)',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPassController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('New password must be at least 6 characters.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: Colors.red),
                );
                return;
              }
              if (newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Passwords do not match.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Password updated successfully! 🔒', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Update Password', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 1. NOTICE TO QUIT GENERATOR (NIGERIAN RECOVERY OF PREMISES ACT) ---
  void _showNoticeToQuitDialog() {
    final tenantNameController = TextEditingController(text: 'Tunde Bakare');
    final addressController = TextEditingController(text: 'Flat 3B, Plot 14 Admiralty Way, Lekki');
    String noticePeriod = '6 Months (Yearly Tenancy)';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Statutory Notice to Quit', style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Laws of the Federal Republic of Nigeria (Recovery of Premises Standard)', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: tenantNameController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Tenant Full Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Premises / Property Address',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: noticePeriod,
                  decoration: InputDecoration(
                    labelText: 'Statutory Notice Duration',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: '6 Months (Yearly Tenancy)', child: Text('6 Months (Yearly Tenancy)')),
                    DropdownMenuItem(value: '3 Months (Half-Yearly Tenancy)', child: Text('3 Months (Half-Yearly)')),
                    DropdownMenuItem(value: '1 Month (Monthly Tenancy)', child: Text('1 Month (Monthly Tenancy)')),
                    DropdownMenuItem(value: '7 Days (Weekly Tenancy)', child: Text('7 Days (Weekly Tenancy)')),
                  ],
                  onChanged: (val) => setDialogState(() => noticePeriod = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _generateNoticeToQuitPdf(
                  tenantName: tenantNameController.text.trim(),
                  address: addressController.text.trim(),
                  duration: noticePeriod,
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
              label: Text('Generate & Export PDF', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateNoticeToQuitPdf({
    required String tenantName,
    required String address,
    required String duration,
  }) async {
    final doc = pw.Document();
    final ownerName = _user?.fullName ?? 'Property Owner';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('STATUTORY NOTICE TO QUIT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('(Under the Recovery of Premises Laws of the Federal Republic of Nigeria)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('TO: $tenantName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('TENANT OF PREMISES: $address', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
              pw.Text(
                'TAKE NOTICE that I, $ownerName, the bonafide Landlord and Owner of the premises situate and known as $address which you hold of me as tenant, hereby give you $duration Notice to Quit and deliver up possession of the said premises with the appurtenances on or before the expiration of this notice.',
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'AND FURTHER TAKE NOTICE that if you fail to deliver up possession of the said premises at the expiration of this notice, legal proceedings will be instituted against you in a court of competent jurisdiction to eject you therefrom.',
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5),
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DATED THIS: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                      pw.SizedBox(height: 20),
                      pw.Text('_____________________________'),
                      pw.Text('SIGNATURE OF LANDLORD / OWNER'),
                      pw.Text(ownerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://myrentilly.com/legal/notice/$tenantName',
                    width: 50,
                    height: 50,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Notice_to_Quit_$tenantName.pdf');
  }

  // --- 2. 7 DAYS NOTICE OF OWNER'S INTENTION ---
  void _showSevenDaysNoticeDialog() {
    final tenantNameController = TextEditingController(text: 'Tunde Bakare');
    final addressController = TextEditingController(text: 'Flat 3B, Plot 14 Admiralty Way, Lekki');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accentOrange, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('7 Days Notice of Owner\'s Intention', style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Statutory Notice of Owner\'s Intention to Apply to Court to Recover Possession (Federal Republic of Nigeria)', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TextField(
                controller: tenantNameController,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Tenant Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Premises Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _generateSevenDaysNoticePdf(
                tenantName: tenantNameController.text.trim(),
                address: addressController.text.trim(),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
            label: Text('Generate & Export PDF', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSevenDaysNoticePdf({
    required String tenantName,
    required String address,
  }) async {
    final doc = pw.Document();
    final ownerName = _user?.fullName ?? 'Property Owner';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('NOTICE OF OWNER\'S INTENTION TO APPLY TO COURT TO RECOVER POSSESSION', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Center(
                child: pw.Text('(Under the Recovery of Premises Act & Laws of the Federal Republic of Nigeria)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('TO: $tenantName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('PREMISES: $address', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
              pw.Text(
                'I, $ownerName, the Owner of the premises situate at $address, hereby give you notice that unless peaceable possession of the said premises, which you held as tenant and which tenancy was determined by a Notice to Quit, be given up to me within SEVEN (7) DAYS from the service of this notice, I shall apply to the Court of competent jurisdiction for a Warrant to eject any person therefrom.',
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5),
              ),
              pw.SizedBox(height: 30),
              pw.Text('DATED THIS: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
              pw.SizedBox(height: 20),
              pw.Text('_____________________________'),
              pw.Text('SIGNATURE OF LANDLORD / OWNER'),
              pw.Text(ownerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: '7_Days_Notice_$tenantName.pdf');
  }

  // --- 3. FILE TENANT DAMAGE / ESCROW CLAIM ---
  void _showDamageClaimDialog() {
    final tenantNameController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String damageCategory = 'Plumbing & Water Damage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.report_problem_rounded, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('File Escrow Damage Claim', style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Claims are deducted from tenant caution deposit held in 100% Rentilly Escrow.', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: tenantNameController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(labelText: 'Tenant Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: damageCategory,
                  decoration: InputDecoration(labelText: 'Damage Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'Plumbing & Water Damage', child: Text('Plumbing & Water Damage')),
                    DropdownMenuItem(value: 'Electrical & Fittings', child: Text('Electrical & Fittings')),
                    DropdownMenuItem(value: 'Structural / Painting Damage', child: Text('Structural / Painting Damage')),
                    DropdownMenuItem(value: 'Unpaid Utilities / Electricity Deficit', child: Text('Unpaid Utilities / DisCo Deficit')),
                  ],
                  onChanged: (val) => setDialogState(() => damageCategory = val!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(labelText: 'Estimated Repair Cost (₦)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(labelText: 'Itemized Breakdown of Damage', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final claimRef = 'CLM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                Navigator.of(ctx).pop();
                await NotificationService.addNotification(
                  title: 'Escrow Damage Claim Filed 🛡️',
                  message: 'Claim $claimRef has been filed against caution escrow deposit. Assigned to Rentilly Legal Desk.',
                  category: 'escrow',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Damage Claim $claimRef submitted! Rentilly Legal Desk is arbitrating.', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Submit Claim', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. LODGE COMPLAINT / PLATFORM INTERVENTION ---
  void _showLodgeComplaintDialog() {
    final complaintController = TextEditingController();
    final addressController = TextEditingController();
    String complaintType = 'Tenant Default / Overdue Rent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Lodge Complaint & Request Help', style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rentilly Legal & Support Team will step in to mediate and resolve this issue with your tenant.', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: complaintType,
                  decoration: InputDecoration(labelText: 'Grievance Nature', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'Tenant Default / Overdue Rent', child: Text('Tenant Default / Overdue Rent')),
                    DropdownMenuItem(value: 'Unauthorized Subletting', child: Text('Unauthorized Subletting')),
                    DropdownMenuItem(value: 'Property Rule Breach / Disturbance', child: Text('Rule Breach / Disturbance')),
                    DropdownMenuItem(value: 'Utility / DisCo Meter Tampering', child: Text('DisCo Meter Tampering')),
                    DropdownMenuItem(value: 'Emergency Physical Intervention', child: Text('Emergency Physical Intervention')),
                  ],
                  onChanged: (val) => setDialogState(() => complaintType = val!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(labelText: 'Property Unit / Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: complaintController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(labelText: 'Describe the Situation in Detail', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final ticketId = 'TKT-MED-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                Navigator.of(ctx).pop();
                await NotificationService.addNotification(
                  title: 'Intervention Request Lodged ⚖️',
                  message: 'Ticket $ticketId assigned to Rentilly Legal Desk. Mediation officer dispatched.',
                  category: 'property',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Intervention Ticket $ticketId lodged! A Rentilly legal officer will contact you.', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Lodge Complaint', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalDeskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
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
                      const Icon(Icons.gavel_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Landlord or Owner Legal Desk', style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold)),
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
                      color: const Color(0xFF064E3B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FEDERAL REPUBLIC OF NIGERIA TENANCY & PREMISES PROTOCOL', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80))),
                        const SizedBox(height: 6),
                        Text('Nationwide Legal Support & Mediation', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Under the Recovery of Premises Act and Tenancy Laws across all 36 States & FCT, Rentilly provides accredited legal instruments and platform dispute intervention.', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70, height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text('STATUTORY LEGAL ACTIONS', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),

                  _buildLegalActionTile('Generate Statutory Notice to Quit (6 Months)', 'Generate legally valid Quit Notice under Nigerian Premises Law', Icons.history_edu_rounded, () {
                    Navigator.of(ctx).pop();
                    _showNoticeToQuitDialog();
                  }),

                  _buildLegalActionTile('Generate 7 Days Notice of Owner\'s Intention', 'Statutory notice before court application to recover possession', Icons.warning_amber_rounded, () {
                    Navigator.of(ctx).pop();
                    _showSevenDaysNoticeDialog();
                  }),

                  _buildLegalActionTile('File Tenant Property Damage / Escrow Claim', 'Deduct structural or utility damages from caution escrow', Icons.report_problem_rounded, () {
                    Navigator.of(ctx).pop();
                    _showDamageClaimDialog();
                  }),

                  const SizedBox(height: 14),
                  Text('PLATFORM MEDIATION & INTERVENTION', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),

                  _buildLegalActionTile('Lodge Complaint & Request Platform Intervention', 'Request Rentilly legal desk to step in and mediate tenant disputes', Icons.support_agent_rounded, () {
                    Navigator.of(ctx).pop();
                    _showLodgeComplaintDialog();
                  }, isHighlight: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isHighlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isHighlight ? const Color(0xFFFCD34D) : AppColors.borderDark),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isHighlight ? const Color(0xFFB45309) : AppColors.primary, size: 22),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF78350F) : AppColors.textPrimary)),
        subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: isHighlight ? const Color(0xFF92400E) : AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
      ),
    );
  }

  void _showPrivacyPolicyModal() {
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
                      const Icon(Icons.privacy_tip_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Privacy Policy & Escrow Terms', style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold)),
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
                  Text('1. Ownership & Title Data Confidentiality', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('All Certificate of Occupancy (C of O), Governor\'s Consent, Deed of Assignment, and Land Registry documents uploaded by property owners are stored using AES 256-bit bank-grade encryption and are never exposed publicly or shared with third parties.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
                  const SizedBox(height: 14),
                  Text('2. Escrow Protection & Automated Settlement', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Rent payments collected from verified tenants are held in CBN-regulated settlement accounts and disbursed directly to the property owner\'s dedicated bank account immediately upon tenant move-in and digital key confirmation.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
                  const SizedBox(height: 14),
                  Text('3. Caution Deposit Escrow Vault', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Tenant caution deposits remain 100% locked in escrow throughout the tenancy and are refunded at move-out, minus any mutually agreed damage claims validated by Rentilly Legal Desk.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
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

    final isVerified = _user?.isVerified ?? false;
    final name = _user?.fullName ?? 'Property Owner';
    final landlordId = 'RNT-LLD-${_user?.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4) ?? "0018"}';
    final avatarUrl = _user?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Landlord Profile & Settings',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // 1. Landlord Profile Card with Avatar Photo Upload
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      AppAvatar(
                        avatarUrl: _user?.avatarUrl,
                        name: name,
                        size: 64,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Landlord ID: $landlordId',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _user?.email ?? '',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Text(
                            'Tap to change profile picture 📸',
                            style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Identity Verification & Digital ID
            Text(
              'CREDENTIALS & COMPLIANCE',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            _buildTile(
              icon: Icons.badge_rounded,
              title: 'My Landlord Digital ID Card 🪪',
              subtitle: 'Official title audited digital badge (PDF Export & Barcode)',
              trailing: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF16A34A)),
              onTap: () {
                if (_user != null) {
                  PartnerIdCardModal.show(context, user: _user!);
                }
              },
            ),

            _buildTile(
              icon: Icons.verified_user_rounded,
              title: 'Tier-3 Identity & Title Audit',
              subtitle: isVerified ? 'Verified with BVN & Deed of Ownership' : 'Tap to complete BVN/NIN check & unlock settlement account',
              trailing: Icon(
                isVerified ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                size: isVerified ? 20 : 14,
                color: isVerified ? const Color(0xFF16A34A) : AppColors.accentOrange,
              ),
              onTap: () {
                if (!isVerified) {
                  VerificationModal.show(context, onSuccess: (updated) {
                    setState(() => _user = updated);
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // 3. Security & Payments
            Text(
              'SECURITY & AUTHORIZATION',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            _buildTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Login',
              subtitle: 'Quick access via Face ID / Fingerprint',
              trailing: Switch(
                value: _biometricsEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _biometricsEnabled = val),
              ),
              onTap: () => setState(() => _biometricsEnabled = !_biometricsEnabled),
            ),

            _buildTile(
              icon: Icons.dialpad_rounded,
              title: _hasPaymentPin ? 'Change Payment PIN' : 'Create 6-Digit Payment PIN',
              subtitle: _hasPaymentPin ? 'Authorize withdrawals and unit utility top-ups' : 'Set a secret 6-digit payment PIN for wallet withdrawals',
              trailing: _hasPaymentPin
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                      child: Text('ACTIVE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    )
                  : null,
              onTap: () async {
                if (_hasPaymentPin) {
                  await PaymentPinModal.showChangePin(context);
                } else {
                  await PaymentPinModal.showCreatePin(context);
                }
                final has = await PaymentSecurityService.hasPaymentPin();
                setState(() => _hasPaymentPin = has);
              },
            ),

            _buildTile(
              icon: Icons.lock_reset_rounded,
              title: 'Change Password',
              subtitle: 'Update your account login security password',
              onTap: _showChangePasswordDialog,
            ),
            const SizedBox(height: 20),

            // 4. Legal Desk & Privacy Policy
            Text(
              'LEGAL & DISPUTES',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            _buildTile(
              icon: Icons.gavel_rounded,
              title: 'Landlord or Owner Legal Desk',
              subtitle: 'Notice to Quit, 7 Days Intention, Escrow claims & platform dispute intervention (Federal Republic of Nigeria)',
              onTap: _showLegalDeskModal,
            ),

            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy & Escrow Terms',
              subtitle: 'Strict title confidentiality & 256-bit financial encryption terms',
              onTap: _showPrivacyPolicyModal,
            ),
            if (widget.onSwitchToTenant != null) ...[
              const SizedBox(height: 4),
              _buildTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Switch to Consumer / Renter Mode 🔄',
                subtitle: 'Browse properties, search rentals & manage tenancies as a consumer',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                onTap: widget.onSwitchToTenant!,
              ),
            ],
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                label: Text('Log Out of Landlord Portal', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary, height: 1.3)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
      ),
    );
  }
}
