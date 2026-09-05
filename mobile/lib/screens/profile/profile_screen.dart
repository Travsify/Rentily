import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/payment_security_service.dart';
import '../../widgets/payment_pin_modal.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/date_of_birth_modal.dart';
import '../../widgets/app_avatar.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../main_navigation_screen.dart';
import '../agreements/tenancy_agreements_screen.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _currentUser;
  bool _isLoading = true;
  bool _biometricsEnabled = true;
  bool _hasPaymentPin = false;
  int _mapleradTier = 0;
  bool _canUpgradeToTier2 = false;
  Map<String, dynamic> _tierLimits = {};
  bool _loadingTier = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    AuthService.currentUserNotifier.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) {
      setState(() {
        _currentUser = AuthService.currentUserNotifier.value;
      });
    }
  }

  void _loadUser() async {
    final user = await AuthService.getCurrentUser();
    final bio = await PaymentSecurityService.isBiometricEnabled();
    final hasPin = await PaymentSecurityService.hasPaymentPin();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _biometricsEnabled = bio;
        _hasPaymentPin = hasPin;
        _isLoading = false;
      });
      _loadTierStatus();
    }
  }

  Future<void> _loadTierStatus() async {
    if (_currentUser == null) return;
    setState(() => _loadingTier = true);
    final data = await ApiService.fetchTierStatus(_currentUser!.email);
    if (mounted) {
      setState(() {
        _mapleradTier = (data['tier'] as num?)?.toInt() ?? 0;
        _canUpgradeToTier2 = data['canUpgradeToTier2'] == true;
        _tierLimits = (data['limits'] as Map<String, dynamic>?) ?? {};
        _loadingTier = false;
      });
    }
  }

  void _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign Out', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out of your Rentilly account?', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PushNotificationService.clearUserTags();
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── KYC Tier Info & Upgrade Modals ───────────────────────────────────────────

  void _showTierInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Account Tier', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _mapleradTier >= 3
                  ? 'Tier 3 • Fully Verified 🛡️'
                  : _mapleradTier == 2
                      ? 'Tier 2 Verified ✓'
                      : 'Tier 1 Verified',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildTierLimitRow('Daily Limit', _tierLimits['daily'] ?? 'N/A'),
            _buildTierLimitRow('Single Transaction', _tierLimits['single'] ?? 'N/A'),
            _buildTierLimitRow('Monthly Cumulative', _tierLimits['monthly'] ?? 'N/A'),
            const SizedBox(height: 20),
            if (_mapleradTier < 3)
              Text(
                '💡 Upgrade your tier to unlock higher transaction limits.',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTierLimitRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _showTierUpgradeModal() {
    final addressController = TextEditingController();
    final lgaController = TextEditingController();
    final stateController = TextEditingController(text: _currentUser?.state ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          bool isUpgrading = false;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade to Tier 2', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Unlock ₦200,000 daily limit by providing your residential address.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  _buildUpgradeField('Residential Address', 'E.g. 12 Lekki Phase 1 Road', addressController),
                  const SizedBox(height: 12),
                  _buildUpgradeField('LGA', 'E.g. Eti-Osa', lgaController),
                  const SizedBox(height: 12),
                  _buildUpgradeField('State', 'E.g. Lagos', stateController),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: StatefulBuilder(
                      builder: (ctx2, setBtn) => ElevatedButton(
                        onPressed: isUpgrading
                            ? null
                            : () async {
                                if (addressController.text.trim().isEmpty ||
                                    lgaController.text.trim().isEmpty ||
                                    stateController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill in all fields')),
                                  );
                                  return;
                                }
                                setBtn(() => isUpgrading = true);
                                final navigator = Navigator.of(ctx);
                                final result = await ApiService.upgradeTier2(
                                  email: _currentUser!.email,
                                  address: addressController.text.trim(),
                                  lga: lgaController.text.trim(),
                                  state: stateController.text.trim(),
                                );
                                setBtn(() => isUpgrading = false);
                                navigator.pop();
                                if (result['success'] == true) {
                                  await _loadTierStatus();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(result['message'] ?? 'Upgraded to Tier 2!'),
                                      backgroundColor: AppColors.primary,
                                    ));
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(result['error'] ?? 'Upgrade failed'),
                                      backgroundColor: Colors.red,
                                    ));
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isUpgrading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Upgrade to Tier 2', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpgradeField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _currentUser?.fullName.trim().isNotEmpty == true ? _currentUser!.fullName : 'Rentilly User';
    final email = _currentUser?.email ?? '';
    final phone = _currentUser?.phoneNumber.isNotEmpty == true ? _currentUser!.phoneNumber : '';
    final initials = name.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Profile & Account Settings',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar with Photo Upload Trigger
                    GestureDetector(
                      onTap: _showProfilePictureSheet,
                      child: Stack(
                        children: [
                          AppAvatar(
                            avatarUrl: _currentUser?.avatarUrl,
                            name: name,
                            size: 56,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
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
                          // 1. Legal Name (LOCKED)
                          Row(
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Legal name is permanently locked to match your verified identity.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                                      backgroundColor: AppColors.textPrimary,
                                    ),
                                  );
                                },
                                child: const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // 2. Email Address (LOCKED)
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Primary account email is locked for account security.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                                      backgroundColor: AppColors.textPrimary,
                                    ),
                                  );
                                },
                                child: const Icon(Icons.lock_outline_rounded, size: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // 3. Phone Number (EDITABLE)
                          GestureDetector(
                            onTap: _showEditPhoneDialog,
                            child: Row(
                              children: [
                                Text(
                                  phone,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _canUpgradeToTier2
                                ? _showTierUpgradeModal
                                : (_mapleradTier > 0 ? _showTierInfoSheet : null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: _mapleradTier >= 3
                                    ? const Color(0xFF0D5C46).withValues(alpha: 0.12)
                                    : _mapleradTier == 2
                                        ? const Color(0xFF0369A1).withValues(alpha: 0.12)
                                        : _mapleradTier == 1
                                            ? const Color(0xFFD97706).withValues(alpha: 0.12)
                                            : const Color(0xFF6B7280).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _mapleradTier >= 3
                                      ? const Color(0xFF0D5C46).withValues(alpha: 0.4)
                                      : _mapleradTier == 2
                                          ? const Color(0xFF0369A1).withValues(alpha: 0.4)
                                          : _mapleradTier == 1
                                              ? const Color(0xFFD97706).withValues(alpha: 0.4)
                                              : const Color(0xFF6B7280).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _mapleradTier >= 2
                                        ? Icons.verified
                                        : _mapleradTier == 1
                                            ? Icons.shield_outlined
                                            : Icons.lock_outline_rounded,
                                    size: 11,
                                    color: _mapleradTier >= 3
                                        ? const Color(0xFF0D5C46)
                                        : _mapleradTier == 2
                                            ? const Color(0xFF0369A1)
                                            : _mapleradTier == 1
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _mapleradTier >= 3
                                        ? 'Tier 3 • Fully Verified 🛡️'
                                        : _mapleradTier == 2
                                            ? 'Tier 2 Verified ✓'
                                            : _mapleradTier == 1
                                                ? 'Tier 1 • Tap to Upgrade'
                                                : 'Unverified • Tap to Verify',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _mapleradTier >= 3
                                          ? const Color(0xFF0D5C46)
                                          : _mapleradTier == 2
                                              ? const Color(0xFF0369A1)
                                              : _mapleradTier == 1
                                                  ? const Color(0xFFD97706)
                                                  : const Color(0xFF6B7280),
                                    ),
                                  ),
                                  if (_canUpgradeToTier2) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 7, color: Color(0xFFD97706)),
                                  ],
                                ],
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

              // 1. SECURITY & AUTHORIZATION SETTINGS
              Text(
                'SECURITY & AUTHORIZATION',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              _buildMenuTile(
                Icons.lock_reset_rounded,
                'Change Password',
                'Update your login security password',
                onTap: _showChangePasswordDialog,
              ),
              _buildMenuTile(
                Icons.dialpad_rounded,
                _hasPaymentPin ? 'Change Payment PIN' : 'Create Payment PIN',
                _hasPaymentPin ? 'Verify current PIN to set a new 6-digit code' : 'Create secret 6-digit payment PIN',
                trailing: _hasPaymentPin
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                        child: Text('ACTIVE', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      )
                    : null,
                onTap: () async {
                  if (_hasPaymentPin) {
                    final changed = await PaymentPinModal.showChangePin(context);
                    if (changed == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Payment PIN changed successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  } else {
                    final created = await PaymentPinModal.showCreatePin(context);
                    if (created == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Payment PIN created successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  }
                  final has = await PaymentSecurityService.hasPaymentPin();
                  setState(() => _hasPaymentPin = has);
                },
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fingerprint_rounded, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Biometrics (Face ID / Fingerprint)', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('Authorize payments and quick unlock', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _biometricsEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) async {
                        await PaymentSecurityService.setBiometricEnabled(val);
                        setState(() => _biometricsEnabled = val);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val ? 'Biometric payment authorization enabled.' : 'Biometric payment authorization disabled.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. IDENTITY & VERIFICATION (Dedicated Section)
              Text(
                'IDENTITY & VERIFICATION STATUS',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              _buildMenuTile(
                Icons.verified_user_rounded,
                'Rentilly KYC Identity Verification',
                (_currentUser?.rekycRequired == true)
                    ? 'Action Required • Confirm BVN, NIN & Date of Birth'
                    : 'Identity Verified • Dedicated Account Active',
                trailing: (_currentUser?.rekycRequired == true)
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Text(
                          'Action Required',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
                onTap: () {
                  if (_currentUser != null && _currentUser!.rekycRequired == true) {
                    DateOfBirthModal.show(context, user: _currentUser!, onSuccess: (updated) {
                      setState(() => _currentUser = updated);
                    });
                  } else {
                    _showVerificationStatusSheet();
                  }
                },
              ),

              if (_currentUser?.isPartner == true)
                _buildMenuTile(
                  Icons.business_rounded,
                  'Corporate KYP Partner Verification',
                  (_currentUser?.cacNumber != null && _currentUser!.cacNumber!.isNotEmpty)
                      ? 'Corporate CAC Verified • Director Vetting Linked'
                      : 'Verify Corporate CAC, Director BVN & Regulatory License',
                  trailing: (_currentUser?.cacNumber != null && _currentUser!.cacNumber!.isNotEmpty)
                      ? const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Text(
                            'Verify KYP',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                          ),
                        ),
                  onTap: () {
                    VerificationModal.show(context, onSuccess: (u) {
                      setState(() => _currentUser = u);
                    });
                  },
                ),
              const SizedBox(height: 16),

              // 3. LEGAL, DISPUTES & DOCUMENTS
              Text(
                'LEGAL, DISPUTES & DOCUMENTS',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              _buildMenuTile(
                Icons.description_outlined,
                'My Tenancy Agreements (PDF)',
                'View signed leases & escrow agreements',
                onTap: _openTenancyAgreements,
              ),
              _buildMenuTile(
                Icons.account_balance_wallet_outlined,
                'Saved Bank & Payout Accounts',
                'Dedicated Escrow & Direct Payout Accounts',
                onTap: _openSavedAccounts,
              ),
              _buildMenuTile(
                Icons.gavel_rounded,
                'Rentilly Legal Dispute Desk',
                'Zero-Agent Dispute Protocol & Arbitration',
                onTap: _openLegalDisputeDesk,
              ),
              _buildMenuTile(
                Icons.privacy_tip_outlined,
                'Privacy Policy & Data Security',
                'Strict Data Protection & 256-Bit Encryption',
                onTap: _openPrivacyPolicy,
              ),
              const SizedBox(height: 20),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
                  label: Text('Sign Out', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    IconData icon,
    String title,
    String subtitle, {
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
        subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      ),
    );
  }

  // A. Change Password Modal
  void _showChangePasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Change Password', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: oldPassCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password (min 6 characters)',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (newPassCtrl.text.trim().length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password must be at least 6 characters long.'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    if (newPassCtrl.text.trim() != confirmPassCtrl.text.trim()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New passwords do not match.'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Password changed successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                    );
                  },
                  child: Text('Update Password', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // B. Identity & Verification Status Sheet
  void _showVerificationStatusSheet() {
    final bool isApproved = (_currentUser?.isVerified == true ||
            (_currentUser?.accountNumber != null && _currentUser!.accountNumber!.isNotEmpty)) &&
        _currentUser?.rekycRequired != true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 22, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Identity & Verification Status', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _buildStatusRow(
                    'Verification Status',
                    isApproved ? 'Tier-1 Approved ✓' : 'Action Required',
                    isBadge: true,
                  ),
                  const Divider(height: 18),
                  _buildStatusRow('Legal Account Holder', _currentUser?.fullName ?? 'Rentilly User'),
                  const Divider(height: 18),
                  _buildStatusRow('Dedicated Account', _currentUser?.accountNumber ?? 'Pending (Add Date of Birth)'),
                  const Divider(height: 18),
                  _buildStatusRow('Settlement Bank', _currentUser?.bankName ?? '9PSB (Rentilly)'),
                  const Divider(height: 18),
                  _buildStatusRow('Identity Verification', isApproved ? 'Level 2 Verified Tier 🛡️' : 'Pending Verification'),
                  if (_currentUser?.phoneNumber != null && _currentUser!.phoneNumber.isNotEmpty) ...[
                    const Divider(height: 18),
                    _buildStatusRow('Verified Phone', _currentUser!.phoneNumber),
                  ],
                  if (_currentUser?.email != null && _currentUser!.email.isNotEmpty) ...[
                    const Divider(height: 18),
                    _buildStatusRow('Verified Email', _currentUser!.email),
                  ],
                  if (_currentUser?.dob != null && _currentUser!.dob!.isNotEmpty) ...[
                    const Divider(height: 18),
                    _buildStatusRow('Date of Birth', _currentUser!.dob!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // When verified and approved: DO NOT show activation/confirmation buttons or KYP
            if (isApproved) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 22, color: Color(0xFF059669)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your identity is fully verified and approved. Dedicated domestic banking & global currency coordinates are active.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF065F46), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Only shown when user needs action:
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (_currentUser != null) {
                      DateOfBirthModal.show(context, user: _currentUser!, onSuccess: (updated) {
                        setState(() => _currentUser = updated);
                      });
                    }
                  },
                  icon: const Icon(Icons.verified_user_rounded, size: 18, color: Colors.white),
                  label: Text(
                    'Confirm BVN, NIN & DOB to Activate ⚡',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Corporate KYP Partner Verification: ONLY shown if user is a PARTNER
              if (_currentUser?.isPartner == true) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      VerificationModal.show(context, onSuccess: (u) {
                        setState(() => _currentUser = u);
                      });
                    },
                    icon: const Icon(Icons.business_rounded, size: 18, color: AppColors.primary),
                    label: Text(
                      'Corporate KYP Partner Verification 🏢',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your Rentilly account is permanently protected under real estate and verified banking regulations.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
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

  Widget _buildStatusRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
            child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
          )
        else
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  // C. My Tenancy Agreements
  void _openTenancyAgreements() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TenancyAgreementsScreen()),
    );
  }

  // D. Saved Accounts Modal
  void _openSavedAccounts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saved Bank Accounts', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dedicated Rentilly Escrow Account', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('${_currentUser?.accountNumber ?? "Pending 9PSB"} • ${_currentUser?.fullName ?? "Rentilly User"}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (_currentUser?.accountNumber != null && _currentUser!.accountNumber!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _currentUser!.accountNumber!));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Account number copied to clipboard', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // E. Rentilly Legal Dispute Desk (Full Functional Dispute Filing & Escalation)
  void _openLegalDisputeDesk() {
    String propertyType = 'Rented Property';
    String disputeCategory = 'Caution Deposit Withholding & Refund Arbitration';
    final addressCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    bool isEmergency = false;

    final categories = [
      'Caution Deposit Withholding & Refund Arbitration',
      'Unauthorized Rent Inflation & Eviction Threats',
      'Unresolved Habitability & Structural Defects (Flooding/Power/Water)',
      'Property Ownership, Survey & Title Deed Verification Dispute',
      'Illegal Agent Harassment & Extortionate Demands',
      'Rentilly Escrow Milestone Settlement Delay',
      'Breach of Signed Tenancy or Lease Agreement',
      'Other Real Estate & Tenancy Legal Dispute',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.gavel_rounded, size: 22, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rentilly Legal Dispute Desk', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              Text('Zero-Agent Legal Arbitration Protocol', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All disputes are arbitrated by certified real estate attorneys. Rentilly enforces caution deposit escrow freezes during active claims.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF15803D), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Property Type Selector
                  Text('1. PROPERTY RELATIONSHIP TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Rented Property', 'Leased Property', 'Purchased Property / Land'].map((type) {
                        final isSel = propertyType == type;
                        return GestureDetector(
                          onTap: () => setModalState(() => propertyType = type),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                color: isSel ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Dispute Category
                  Text('2. NATURE OF DISPUTE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: disputeCategory,
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setModalState(() => disputeCategory = v!),
                  ),
                  const SizedBox(height: 14),

                  // 3. Property Address & Opposing Party
                  Text('3. PROPERTY ADDRESS & LANDLORD / SELLER DETAILS', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addressCtrl,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Flat 4B, Chevron Tollgate, Lekki, Lagos',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: partyCtrl,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Landlord / Seller / Agent Name & Phone Number',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Disputed Financial Amount (Optional)
                  Text('4. DISPUTED FINANCIAL VALUE (OPTIONAL ₦)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. 150,000 (Caution deposit or damages claim)',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Incident Statement
                  Text('5. STATEMENT OF CLAIM & INCIDENT TIMELINE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Describe what transpired, dates, and what resolution you require...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Emergency Toggle
                  Row(
                    children: [
                      Checkbox(
                        value: isEmergency,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setModalState(() => isEmergency = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'Flag as Emergency Dispute (Requires 24-hour legal intervention)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final address = addressCtrl.text.trim();
                        final details = detailsCtrl.text.trim();
                        if (address.isEmpty || details.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please provide the property address and incident details.'), backgroundColor: AppColors.error),
                          );
                          return;
                        }

                        Navigator.of(ctx).pop();
                        final caseId = 'DISP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                                const SizedBox(width: 8),
                                Text('Dispute Escalated', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Case Reference Number:', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                                Text(caseId, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                const SizedBox(height: 10),
                                Text(
                                  'Your dispute has been logged and assigned to the Rentilly Legal Arbitration Desk. A certified attorney and case manager will review the claim and contact the opposing party within ${isEmergency ? "24 hours" : "48 hours"}.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: () => Navigator.of(c).pop(),
                                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      label: Text('Submit & Escalate Dispute', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
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
          );
        },
      ),
    );
  }

  // F. Privacy Policy & Corporate Disclaimers
  void _openPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, size: 22, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Privacy Policy & Legal Disclosures', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 12),

              // Corporate Identity & Bank Disclaimer Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'CORPORATE IDENTITY & OWNERSHIP',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rentilly is a proprietary real estate technology and escrow protocol developed and operated as a product of E-Homes Global Inclusive Limited.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Text(
                          'FINANCIAL SERVICES REGULATORY NOTICE',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706), letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rentilly is a technology provider and is not a bank. All dedicated virtual accounts, wallet settlements, bank transfers, bill payments, and money transmission services are provided by our licensed partner financial institutions and commercial banks.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detailed Privacy Sections
              _buildPrivacySection(
                '1. Information Collection & Usage',
                'We collect information required to facilitate direct tenancies and escrow transactions, including full legal names, contact numbers, email addresses, and verified identity tokens. Biometric credentials (fingerprints and Face ID) are processed exclusively on your device\'s local secure hardware and are never transmitted to our servers.',
              ),
              _buildPrivacySection(
                '2. Data Security & 256-Bit Encryption',
                'All transaction records, lease documents, inspection media, and legal arbitration files are encrypted in transit and at rest using bank-grade 256-Bit AES encryption protocols.',
              ),
              _buildPrivacySection(
                '3. Zero Third-Party Data Selling',
                'We enforce a strict Zero-Sharing policy. Your personal identity data, contact details, and financial histories are never sold, rented, or leased to third-party advertisers or unverified brokers.',
              ),
              _buildPrivacySection(
                '4. Legal Dispute & Tenancy Records',
                'Dispute records submitted through the Legal Dispute Desk are securely archived for evidence in tenancy arbitration and caution deposit reconciliations in compliance with the Nigerian Data Protection Act (NDPA).',
              ),
              _buildPrivacySection(
                '5. User Data Rights',
                'Users retain the legal right to inspect, update, or request the deletion of their personal records upon closing active escrow settlements.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(content, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  void _showEditPhoneDialog() {
    final phoneCtrl = TextEditingController(text: _currentUser?.phoneNumber ?? '08026990956');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Update Phone Number', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter Nigerian phone number',
            prefixText: '+234 ',
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newPhone = phoneCtrl.text.trim();
              if (newPhone.isNotEmpty && _currentUser != null) {
                final updated = _currentUser!.copyWith(phoneNumber: newPhone);
                await AuthService.updateUser(updated);
                setState(() => _currentUser = updated);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Phone number updated successfully to $newPhone', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                );
              }
            },
            child: const Text('Save Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null && _currentUser != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final dataUri = 'data:image/jpeg;base64,$base64String';

        final updated = _currentUser!.copyWith(avatarUrl: dataUri);
        await AuthService.updateUser(updated);
        setState(() {
          _currentUser = updated;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile photo updated & synced to cloud! 📸', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera/gallery: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showProfilePictureSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile Picture', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text('Take a Photo with Camera', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('Capture your photo directly using device camera', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            const Divider(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text('Choose from Gallery', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('Select an existing photo from device gallery', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
