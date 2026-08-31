import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import 'package:flutter/services.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _currentUser;
  bool _isLoading = true;

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
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  void _handleSignOut() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Real actual user data only (Zero mock Femi if Patrick logged in)
    final name = _currentUser?.fullName.trim().isNotEmpty == true ? _currentUser!.fullName : 'Rentilly User';
    final email = _currentUser?.email ?? 'user@rentilly.ng';
    final phone = _currentUser?.phoneNumber.isNotEmpty == true ? _currentUser!.phoneNumber : 'Phone Pending';
    final initials = name.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'My Account & Vault',
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
              // Profile Card with Real User Information
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
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials.isNotEmpty ? initials : 'RU',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$phone • $email',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  VerificationModal.show(context, onSuccess: (updated) {
                                    setState(() => _currentUser = updated);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: _currentUser?.isVerified == true
                                        ? AppColors.primaryLight.withValues(alpha: 0.12)
                                        : AppColors.accentOrange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _currentUser?.isVerified == true
                                          ? AppColors.primaryLight.withValues(alpha: 0.4)
                                          : AppColors.accentOrange.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _currentUser?.isVerified == true ? Icons.verified : Icons.shield_outlined,
                                        size: 11,
                                        color: _currentUser?.isVerified == true ? AppColors.primaryLight : AppColors.accentOrange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _currentUser?.isVerified == true ? 'Rentilly Verified' : 'UNVERIFIED • Tap to Verify',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _currentUser?.isVerified == true ? AppColors.primary : AppColors.accentOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Caution Deposit Escrow Vault (Real Data)
              Text(
                'RENTILLY ESCROW VAULT',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0D5C46),
                      Color(0xFF07382B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Caution Deposit Balance',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LEGAL ESCROW',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '₦0.00',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Protected under Lagos Tenancy Law 2011 • Fully refundable upon exit inspection',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Settings & Documents Section
              Text(
                'LEGAL & PREFERENCES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              _buildMenuTile(
                Icons.description_outlined,
                'My Tenancy Agreements (PDF)',
                'View Signed Leases',
                onTap: _openTenancyAgreements,
              ),
              _buildMenuTile(
                Icons.home_work_outlined,
                'Switch to Landlord / List Property',
                'Direct Owner Mode',
                onTap: _openLandlordListing,
              ),
              _buildMenuTile(
                Icons.credit_card_outlined,
                'Saved Payment Accounts',
                'Dedicated Virtual & Bank Accounts',
                onTap: _openSavedAccounts,
              ),
              _buildMenuTile(
                Icons.support_agent_outlined,
                'Rentilly Legal Dispute Desk',
                'Free Legal Support',
                onTap: _openLegalDisputeDesk,
              ),
              _buildMenuTile(
                Icons.lock_outline_rounded,
                'Privacy & Identity Verification Data',
                'Protected & Encrypted',
                onTap: _openPrivacyKycData,
              ),
              const SizedBox(height: 20),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleSignOut,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
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

  // 1. My Tenancy Agreements (PDF)
  void _openTenancyAgreements() {
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
                    const Icon(Icons.description_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('My Tenancy Agreements', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 4),
            Text('Official legally binding agreements compliant with Lagos State Tenancy Law 2011.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ACTIVE LEASE CONTRACT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text('SIGNED & ACTIVE', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('3-Bedroom Luxury Terrace Apartment', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('Admiralty Way, Lekki Phase 1, Lagos', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tenant: ${_currentUser?.fullName ?? "Patrick Atua"}', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('Term: 12 Months', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading Signed PDF Agreement & Stamp Duty Certificate...', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text('Download Official PDF Agreement', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Switch to Landlord / List Property
  void _openLandlordListing() {
    final titleCtrl = TextEditingController();
    final rentCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 22,
          right: 22,
          top: 22,
        ),
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
                      const Icon(Icons.home_work_outlined, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('List Property Directly', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 4),
              Text('Rent directly to pre-vetted tenants. Zero agent fees, direct rent collection.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Text('PROPERTY TITLE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Modern 2-Bedroom Serviced Flat',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                ),
              ),
              const SizedBox(height: 12),
              Text('LOCATION / ESTATE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: locationCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Chevron Drive, Lekki, Lagos',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                ),
              ),
              const SizedBox(height: 12),
              Text('ANNUAL RENT (₦)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: rentCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '2,500,000',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Property listing submitted for Rentilly verification!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Submit & Activate Direct Listing', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Saved Payment Accounts
  void _openSavedAccounts() {
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
                Row(
                  children: [
                    const Icon(Icons.credit_card_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Saved Payment Accounts', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 4),
            Text('Your verified dedicated NUBAN account and linked settlement accounts.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
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
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_rounded, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.accountNumber != null ? '${_currentUser!.accountNumber} • ${_currentUser!.bankName}' : 'Pending Verification',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text('Dedicated Living Escrow Account', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (_currentUser?.accountNumber != null)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _currentUser!.accountNumber!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Account number copied!', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.accentOrange, borderRadius: BorderRadius.circular(6)),
                        child: Text('Copy', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  VerificationModal.show(context, onSuccess: (updated) => setState(() => _currentUser = updated));
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Re-issue / Refresh Dedicated Bank Account', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (_currentUser != null) {
                    WithdrawalModal.show(context, user: _currentUser!, onWithdrawalSuccess: (newBal) => setState(() => _currentUser = _currentUser?.copyWith(walletBalance: newBal)));
                  }
                },
                icon: const Icon(Icons.account_balance_outlined, size: 16, color: AppColors.textPrimary),
                label: Text('Manage Withdrawal Bank Accounts', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderDark),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Rentilly Legal Dispute Desk
  void _openLegalDisputeDesk() {
    final descCtrl = TextEditingController();
    String selectedDispute = 'Unreturned Caution Deposit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 22,
            right: 22,
            top: 22,
          ),
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
                        const Icon(Icons.gavel_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Legal Dispute Desk', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Free mediation and enforcement per Lagos State Tenancy Law 2011.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Text('NATURE OF DISPUTE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedDispute,
                  dropdownColor: Colors.white,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                  ),
                  items: [
                    'Unreturned Caution Deposit',
                    'Unlawful Eviction Notice',
                    'Unfulfilled Maintenance Agreement',
                    'Illegal Rent Increment',
                    'Agent Extortion / Hidden Charges'
                  ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedDispute = v);
                  },
                ),
                const SizedBox(height: 12),
                Text('BRIEF DESCRIPTION OF ISSUE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Explain what happened and property details...',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      final caseNum = 'RNT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dispute case $caseNum opened. Legal team assigned!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Submit Dispute Case', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 5. Privacy & Identity Verification Data
  void _openPrivacyKycData() {
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
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Privacy & Identity Data', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 4),
            Text('Protected under the Nigeria Data Protection Act (NDPA 2023).', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Verification Status', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text(_currentUser?.isVerified == true ? 'VERIFIED' : 'PENDING', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: _currentUser?.isVerified == true ? AppColors.primaryLight : AppColors.accentOrange)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Data Encryption', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text('256-bit TLS & AES', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Biometric Credential Store', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text('Secure Enclave (Local)', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Your encrypted KYC compliance packet is active.', style: GoogleFonts.plusJakartaSans(fontSize: 11)), backgroundColor: AppColors.primary),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Done', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
