import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/api_service.dart';
import '../../services/payment_security_service.dart';
import '../../widgets/payment_pin_modal.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/partner_id_card_modal.dart';
import '../../widgets/partner_landlord_onboard_modal.dart';
import '../../widgets/partner_legal_modal.dart';
import '../../widgets/app_avatar.dart';
import '../../utils/id_utils.dart';
import '../auth/login_screen.dart';

class PartnerProfileScreen extends StatefulWidget {
  final VoidCallback? onSwitchToTenant;

  const PartnerProfileScreen({super.key, this.onSwitchToTenant});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  UserProfile? _user;
  bool _isLoading = true;
  bool _hasPaymentPin = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    AuthService.currentUserNotifier.addListener(_onUserChanged);
  }

  void _onUserChanged() {
    if (mounted) {
      final updated = AuthService.currentUserNotifier.value;
      if (updated != null) {
        setState(() => _user = updated);
      }
    }
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  void _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    var user = await AuthService.getCurrentUser();
    final savedLogo = prefs.getString('rentilly_persistent_partner_logo');
    if (user != null && (user.avatarUrl == null || user.avatarUrl!.isEmpty) && savedLogo != null && savedLogo.isNotEmpty) {
      user = user.copyWith(avatarUrl: savedLogo);
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

  void _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null && _user != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rentilly_persistent_partner_logo', dataUri);
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
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Corporate firm logo updated & saved permanently! 🏢📸',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
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
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final curP = currentPassController.text.trim();
              final newP = newPassController.text.trim();
              final confP = confirmPassController.text.trim();
              if (newP.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password must be at least 6 characters.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: Colors.red),
                );
                return;
              }
              if (newP != confP) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('New passwords do not match.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: Colors.red),
                );
                return;
              }
              if (_user != null) {
                final res = await ApiService.changePassword(
                  email: _user!.email,
                  currentPassword: curP,
                  newPassword: newP,
                );
                if (!mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? (res['success'] == true ? 'Password updated successfully! 🔒' : 'Failed to update password'), style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                    backgroundColor: res['success'] == true ? AppColors.primary : Colors.red,
                  ),
                );
              }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isVerified = _user?.isVerified ?? false;
    final businessName = _user?.businessName != null && _user!.businessName!.trim().isNotEmpty
        ? _user!.businessName!.trim()
        : (_user?.fullName.trim().isNotEmpty == true ? _user!.fullName.trim() : 'Partner Enterprise');
    final cacNumber = _user?.cacNumber != null && _user!.cacNumber!.trim().isNotEmpty
        ? _user!.cacNumber!.trim()
        : (isVerified ? 'CAC Verified' : 'Pending CAC KYB');
    final partnerId = IdUtils.formatOpsId(_user?.id, isPartner: true);
    final rawState = _user?.state ?? 'Lagos';
    final officeAddress = _user?.officeAddress != null && _user!.officeAddress!.trim().isNotEmpty
        ? _user!.officeAddress!.trim()
        : '$rawState, Nigeria';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Partner Profile',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // 1. Corporate Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Stack(
                      children: [
                        AppAvatar(
                          avatarUrl: _user?.avatarUrl,
                          name: businessName,
                          size: 60,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'CAC: $cacNumber • ID: $partnerId',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rep: ${_user?.fullName ?? "Principal Broker"} • $officeAddress',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D)),
                          ),
                          child: Text(
                            isVerified ? 'CAC & TIER-3 ACCREDITED 🛡️' : 'TIER-1 (PENDING KYB/KYC)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: isVerified ? const Color(0xFF166534) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Accreditation & Badges
            Text(
              'ACCREDITATION & MANDATES',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            _buildTile(
              icon: Icons.add_photo_alternate_rounded,
              title: 'Upload Corporate Firm Logo 📸',
              subtitle: (_user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty)
                  ? 'Tap to update or change your official company branding logo'
                  : 'Upload your company logo for ID credentials & client proposals',
              trailing: const Icon(Icons.upload_rounded, size: 20, color: AppColors.primary),
              onTap: _pickLogo,
            ),

            _buildTile(
              icon: Icons.badge_outlined,
              title: 'Partner Accreditation ID Card 🪪',
              subtitle: 'Official field credential for landlord pitching and tenant viewings',
              trailing: const Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.primary),
              onTap: () {
                if (_user != null) {
                  PartnerIdCardModal.show(context, user: _user!);
                }
              },
            ),

            _buildTile(
              icon: Icons.link_rounded,
              title: 'Onboard My Landlord 🔗',
              subtitle: 'Share your WhatsApp invite link to auto-link properties and lock 2.5%/2.0% commissions',
              trailing: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF16A34A)),
              onTap: () {
                if (_user != null) {
                  PartnerLandlordOnboardModal.show(context, user: _user!);
                }
              },
            ),

            _buildTile(
              icon: Icons.verified_user_rounded,
              title: 'Corporate CAC & Identity Audit (KYB)',
              subtitle: isVerified ? 'CAC RC/BN and Director BVN/NIN Verified ✓' : 'Tap to complete KYB verification and activate settlement account',
              trailing: Icon(
                isVerified ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                size: isVerified ? 20 : 14,
                color: isVerified ? const Color(0xFF16A34A) : AppColors.accentOrange,
              ),
              onTap: () {
                VerificationModal.show(context, onSuccess: (updated) {
                  setState(() => _user = updated);
                });
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
              icon: Icons.dialpad_rounded,
              title: _hasPaymentPin ? 'Change Payment PIN' : 'Create 6-Digit Payment PIN',
              subtitle: _hasPaymentPin ? 'Authorize commission withdrawals and utility top-ups' : 'Set a secret 6-digit payment PIN for wallet withdrawals',
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
              subtitle: 'Update your corporate account login security password',
              onTap: _showChangePasswordDialog,
            ),
            const SizedBox(height: 20),

            // 4. Legal Desk & Privacy Policy (FULLY FUNCTIONAL)
            Text(
              'LEGAL & DISPUTES',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            _buildTile(
              icon: Icons.gavel_rounded,
              title: 'Partner Legal Desk',
              subtitle: 'Brokerage mandate, commission escrow rules & arbitration protocol',
              onTap: () => PartnerLegalModal.showLegalDesk(context),
            ),

            _buildTile(
              icon: Icons.support_agent_rounded,
              title: 'Partner Inquiries, Complaints & Submissions',
              subtitle: 'Formal dispute submissions, commission queries & arbitration desk',
              onTap: () => PartnerLegalModal.showInquiriesAndComplaints(context),
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
                  await PushNotificationService.clearUserTags();
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                label: Text('Log Out of Partner Portal', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
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
