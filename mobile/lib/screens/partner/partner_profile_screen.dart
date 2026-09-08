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
import '../support/support_chat_screen.dart';

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
  int _mapleradTier = 0;

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

    int tier = 0;
    if (user != null && user.email.isNotEmpty) {
      try {
        final tierData = await ApiService.fetchTierStatus(user.email);
        tier = (tierData['tier'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _user = user;
        _hasPaymentPin = hasPin;
        _mapleradTier = tier;
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

  void _showEditLasreraDialog() {
    final controller = TextEditingController(text: _user?.lasreraNumber ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'LASRERA / Regulatory Accreditation 🛡️',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Lagos State Real Estate Regulatory Authority (LASRERA) or State Regulatory License registration number to display on your accredited mandate credentials.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'LASRERA / State License Number',
                hintText: 'e.g. LASRERA/BRK/2026/089',
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
              final val = controller.text.trim();
              if (_user != null) {
                final updated = _user!.copyWith(lasreraNumber: val);
                setState(() => _user = updated);
                await AuthService.updateUser(updated);

                // Sync with server
                try {
                  await ApiService.updateProfile(
                    email: _user!.email,
                    lasreraNumber: val,
                  );
                } catch (_) {}

                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Regulatory accreditation updated! 🛡️', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Save License', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditCorporateDetailsDialog() {
    final bizCtrl = TextEditingController(text: _user?.businessName ?? '');
    final cacCtrl = TextEditingController(text: _user?.cacNumber ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Edit Corporate Details',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Text(
                    '⚠️ Changes to business name and CAC number are logged for audit compliance. Ensure details match your CAC certificate exactly.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF92400E), height: 1.35),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: bizCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Registered Business Name',
                    hintText: 'e.g. Zida Properties Ltd',
                    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
                    prefixIcon: const Icon(Icons.business_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cacCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'CAC Registration Number',
                    hintText: 'e.g. RC-1234567',
                    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newBiz = bizCtrl.text.trim();
                      final newCac = cacCtrl.text.trim();
                      if (newBiz.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Business name cannot be empty.')),
                        );
                        return;
                      }
                      setDlgState(() => isSaving = true);
                      try {
                        if (_user != null) {
                          final updated = _user!.copyWith(businessName: newBiz, cacNumber: newCac.isNotEmpty ? newCac : _user!.cacNumber);
                          setState(() => _user = updated);
                          await AuthService.updateUser(updated);
                          try {
                            await ApiService.updateProfile(
                              email: _user!.email,
                              businessName: newBiz,
                              cacNumber: newCac.isNotEmpty ? newCac : null,
                            );
                          } catch (_) {}
                        }
                        if (mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Corporate details updated! 🏢', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                              backgroundColor: const Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (_) {
                        setDlgState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Update failed. Please try again.')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
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
                            color: (_mapleradTier >= 2 || isVerified) ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (_mapleradTier >= 2 || isVerified) ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D)),
                          ),
                          child: Text(
                            (isVerified || _mapleradTier >= 1)
                                ? 'CAC ACCREDITED PARTNER 🛡️'
                                : 'PENDING CAC KYB/KYC',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: (_mapleradTier >= 2 || isVerified) ? const Color(0xFF166534) : const Color(0xFF92400E),
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

            _buildTile(
              icon: Icons.edit_note_rounded,
              title: 'Edit Corporate Details 🏢',
              subtitle: 'Update registered business name or CAC number (logged for compliance)',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
              onTap: _showEditCorporateDetailsDialog,
            ),

            _buildTile(
              icon: Icons.shield_outlined,
              title: 'LASRERA / State Regulatory License 🛡️',
              subtitle: (_user?.lasreraNumber != null && _user!.lasreraNumber!.isNotEmpty)
                  ? 'Registration No: ${_user!.lasreraNumber} ✓'
                  : 'Add your Lagos LASRERA or State Regulatory Broker license',
              trailing: (_user?.lasreraNumber != null && _user!.lasreraNumber!.isNotEmpty)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text('REGISTERED', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                    )
                  : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
              onTap: _showEditLasreraDialog,
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

            // Support Desk
            Text(
              'SUPPORT & ASSISTANCE',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            _buildTile(
              icon: Icons.support_agent_rounded,
              title: 'Rentilly Live Support Desk 💬',
              subtitle: 'Chat directly with Rentilly human agents & escrow support desk',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SupportChatScreen(user: _user),
                ));
              },
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
            const SizedBox(height: 12),

            // Delete Account Button (Required by Apple Guideline 5.1.1(v) & Google Play)
            Center(
              child: TextButton.icon(
                onPressed: _showDeleteAccountDialog,
                icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Color(0xFF94A3B8)),
                label: Text(
                  'Delete Account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text('Delete Account', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete your Partner / Brokerage account? All your company listings, client mandates, and verification credentials will be permanently removed.\n\nNote: Any outstanding commission settlements or active escrow holds must be cleared before account deletion.',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_user == null) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
              final res = await ApiService.deleteAccount(_user!.email);
              if (mounted) Navigator.of(context).pop();
              if (res['success'] == true) {
                await PushNotificationService.clearUserTags();
                await AuthService.logout();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your account has been deleted successfully.')),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['error'] ?? res['message'] ?? 'Could not delete account. Please try again.')),
                  );
                }
              }
            },
            child: const Text('Permanently Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
