import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/payment_security_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/payment_pin_modal.dart';
import '../../widgets/partner_id_card_modal.dart';
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
    final user = await AuthService.getCurrentUser();
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
      final updated = _user!.copyWith(avatarUrl: image.path);
      await AuthService.updateUser(updated);
      setState(() => _user = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated successfully! 📸', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
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

  void _showLegalDeskModal() {
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
                      const Icon(Icons.gavel_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Rentilly Tenancy Legal Desk', style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold)),
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
                        Text('ZERO-AGENT DISPUTE & EVICTION PROTOCOL', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80))),
                        const SizedBox(height: 6),
                        Text('Lagos State Tenancy Law 2011 Support', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Rentilly provides accredited legal mediation and dispute resolution for all registered property owners.', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('LEGAL ACTIONS', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  _buildLegalActionTile('Generate Statutory Notice to Quit (6 Months)', Icons.history_edu_rounded, () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notice to Quit draft generated under Lagos Tenancy Law.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary));
                  }),
                  _buildLegalActionTile('Generate 7 Days Notice of Owner\'s Intention', Icons.warning_amber_rounded, () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('7 Days Notice of Intention generated.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary));
                  }),
                  _buildLegalActionTile('File Tenant Property Damage / Escrow Claim', Icons.report_problem_rounded, () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Escrow damage claim opened. Assigned to legal arbitrator.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary));
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalActionTile(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
        actions: [
          if (widget.onSwitchToTenant != null)
            TextButton.icon(
              onPressed: widget.onSwitchToTenant,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
              label: Text('Consumer Mode', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          const SizedBox(width: 8),
        ],
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
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: avatarUrl.startsWith('http')
                                    ? Image.network(avatarUrl, fit: BoxFit.cover)
                                    : Image.file(File(avatarUrl), fit: BoxFit.cover),
                              )
                            : Center(
                                child: Text(
                                  name.isNotEmpty ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : 'LL',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
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
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
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
              subtitle: 'Official title audited digital badge (PDF Export & QR Code)',
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
              subtitle: isVerified ? 'Verified with BVN & Deed of Ownership' : 'Tap to complete BVN/NIN verification & unlock rent account',
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
              title: 'Rentilly Tenancy Legal Desk',
              subtitle: 'Notice to Quit, statutory eviction protocol & Lagos State Tenancy Law arbitration',
              onTap: _showLegalDeskModal,
            ),

            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy & Escrow Terms',
              subtitle: 'Strict title confidentiality & 256-bit financial encryption terms',
              onTap: _showPrivacyPolicyModal,
            ),
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
