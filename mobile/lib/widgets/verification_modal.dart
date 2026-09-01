import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/verification_service.dart';

class VerificationModal extends StatefulWidget {
  final Function(UserProfile) onSuccess;

  const VerificationModal({super.key, required this.onSuccess});

  static void show(BuildContext context, {required Function(UserProfile) onSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VerificationModal(onSuccess: onSuccess),
    );
  }

  @override
  State<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends State<VerificationModal> {
  UserProfile? _currentUser;
  String _selectedIdType = 'nin'; // 'nin', 'voters_card', 'drivers_license', 'passport'
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _cacNumberController = TextEditingController();
  final TextEditingController _tinController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _bvnController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(text: '14/08/1994');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final u = await AuthService.getCurrentUser();
    if (mounted && u != null) {
      setState(() {
        _currentUser = u;
        if (u.businessName != null && u.businessName!.isNotEmpty) {
          _businessNameController.text = u.businessName!;
        } else if (u.role == 'partner' && u.fullName.isNotEmpty) {
          _businessNameController.text = u.fullName;
        }
        if (u.cacNumber != null && u.cacNumber!.isNotEmpty) {
          _cacNumberController.text = u.cacNumber!;
        }
        if (u.ninNumber != null && u.ninNumber!.isNotEmpty) {
          _idController.text = u.ninNumber!;
        }
      });
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _cacNumberController.dispose();
    _tinController.dispose();
    _idController.dispose();
    _bvnController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  bool get _isPartner => _currentUser?.role == 'partner';

  String get _idTypeLabel {
    switch (_selectedIdType) {
      case 'nin':
        return 'NIN (National Identity)';
      case 'voters_card':
        return "Voter's Card (VIN)";
      case 'drivers_license':
        return "Driver's License (FRSC)";
      case 'passport':
        return 'International Passport';
      default:
        return 'Identity Document';
    }
  }

  String get _idInputHint {
    switch (_selectedIdType) {
      case 'nin':
        return 'Enter 11-digit Director NIN';
      case 'voters_card':
        return "Enter Director Voter's ID Number";
      case 'drivers_license':
        return "Enter Director Driver's License";
      case 'passport':
        return 'Enter Director Passport Number';
      default:
        return 'Enter ID Number';
    }
  }

  void _handleVerify() async {
    final idNum = _idController.text.trim();
    final bvn = _bvnController.text.trim();
    final dob = _dobController.text.trim();
    final bName = _businessNameController.text.trim();
    final cac = _cacNumberController.text.trim();

    if (_isPartner) {
      if (bName.isEmpty) {
        setState(() => _errorMessage = 'Please enter your registered Business / Company Name.');
        return;
      }
      if (cac.isEmpty) {
        setState(() => _errorMessage = 'Please enter your CAC RC or Business Number (BN).');
        return;
      }
    }

    if (idNum.isEmpty || idNum.length < 6) {
      setState(() => _errorMessage = 'Please enter a valid $_idTypeLabel number.');
      return;
    }

    if (bvn.isEmpty || bvn.length != 11) {
      setState(() => _errorMessage = 'Please enter a valid 11-digit Bank Verification Number (BVN).');
      return;
    }

    if (dob.isEmpty) {
      setState(() => _errorMessage = 'Please select your Date of Birth.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await VerificationService.verifyAndProvision(
      idType: _selectedIdType,
      idNumber: idNum,
      bvn: bvn,
      dob: dob,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true && res['user'] != null) {
      var updatedUser = res['user'] as UserProfile;
      if (_isPartner) {
        updatedUser = updatedUser.copyWith(
          businessName: bName,
          cacNumber: cac,
          isVerified: true,
          bvnVerified: true,
        );
        await AuthService.updateUser(updatedUser);
      }
      widget.onSuccess(updatedUser);

      if (!mounted) return;
      Navigator.of(context).pop();

      _showSuccessDialog(updatedUser);
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Verification could not be completed. Please check your BVN and ID details.';
      });
    }
  }

  void _showSuccessDialog(UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                _isPartner ? 'Corporate KYB Verified! 🏢✓' : 'Identity Verified! 🛡️✓',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _isPartner
                    ? '${user.businessName ?? user.fullName} is now accredited. Your dedicated settlement vault is activated.'
                    : 'Your Tier-3 biometric and BVN verification is complete. Settlement account provisioned.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              if (user.accountNumber != null && user.accountNumber!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DEDICATED ESCROW VAULT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                            Text('${user.accountNumber} • ${user.bankName ?? "Flutterwave MFB"}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF14532D))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Continue', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_isPartner ? Icons.business_rounded : Icons.verified_user_rounded, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPartner ? 'Corporate CAC & Identity Audit (KYB)' : 'Identity & BVN Verification',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        _isPartner ? 'Accredit your corporate firm & activate commission settlements' : 'Tier-3 CBN compliance & dedicated escrow bank account',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Error Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // PARTNER CORPORATE KYB FIELDS
            if (_isPartner) ...[
              Text(
                '1. CORPORATE CAC REGISTRATION',
                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),

              // Business Name
              TextField(
                controller: _businessNameController,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Registered Business / Entity Name',
                  hintText: 'e.g. Eoms Global Inclusive Limited',
                  prefixIcon: const Icon(Icons.business_outlined, size: 18, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),

              // CAC Number & TIN
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cacNumberController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'CAC RC / BN Number',
                        hintText: 'e.g. RC 1928374',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tinController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Tax Number (TIN) - Optional',
                        hintText: 'e.g. 23819284-0001',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                '2. PRINCIPAL DIRECTOR / BROKER IDENTITY',
                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
            ],

            // ID Type Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedIdType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'nin', child: Text('National Identity Number (NIN)')),
                    DropdownMenuItem(value: 'voters_card', child: Text("Voter's Card (VIN)")),
                    DropdownMenuItem(value: 'drivers_license', child: Text("Driver's License (FRSC)")),
                    DropdownMenuItem(value: 'passport', child: Text('International Passport')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedIdType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ID Number Field
            TextField(
              controller: _idController,
              keyboardType: TextInputType.text,
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
              decoration: InputDecoration(
                labelText: _idTypeLabel,
                hintText: _idInputHint,
                prefixIcon: const Icon(Icons.credit_card_rounded, size: 18, color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),

            // BVN & DOB Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _bvnController,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: _isPartner ? 'Director BVN (11 digits)' : 'Bank Verification No. (BVN)',
                      hintText: '22XXXXXXXXX',
                      counterText: '',
                      prefixIcon: const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _dobController,
                    keyboardType: TextInputType.datetime,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'DOB (DD/MM/YYYY)',
                      hintText: '14/08/1994',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isPartner ? 'Submit Corporate KYB Verification' : 'Verify Identity & Provision Account',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
