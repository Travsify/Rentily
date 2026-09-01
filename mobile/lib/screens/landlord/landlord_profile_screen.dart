import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
            const Icon(Icons.lock_outline_rounded, color: AppColors.accentOrange, size: 22),
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
              backgroundColor: AppColors.accentOrange,
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
    final name = _user?.fullName ?? 'Property Owner';
    final landlordId = 'RNT-LLD-${_user?.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4) ?? "0018"}';

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
            // 1. Landlord Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : 'LL',
                        style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D)),
                          ),
                          child: Text(
                            isVerified ? 'TITLE & IDENTITY VERIFIED 🔑' : 'TIER-1 (UNVERIFIED)',
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

            // 2. Identity Verification & Digital ID
            Text(
              'CREDENTIALS & COMPLIANCE',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            _buildTile(
              icon: Icons.badge_rounded,
              title: 'My Landlord Digital ID Card 🪪',
              subtitle: 'Official title audited digital badge to present to prospective tenants',
              trailing: const Icon(Icons.qr_code_2_rounded, size: 22, color: AppColors.primary),
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
              subtitle: 'Zero-Agent Dispute Protocol & Lagos State Tenancy Law arbitration',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Legal desk is active. Zero open disputes on your properties.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                );
              },
            ),

            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy & Escrow Terms',
              subtitle: 'Strict title confidentiality & 256-bit financial encryption',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('All owner title documents are 256-bit encrypted and confidential.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                );
              },
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
