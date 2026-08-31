import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
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
  String _selectedIdType = 'nin'; // 'nin', 'voters_card', 'drivers_license', 'passport'
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _bvnController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(text: '14/08/1994');
  bool _isLoading = false;
  String? _errorMessage;

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
        return 'Enter 11-digit NIN (e.g. 1092 8471 920)';
      case 'voters_card':
        return "Enter Voter's Identification Number (VIN)";
      case 'drivers_license':
        return "Enter Driver's License Number (e.g. AAA12345AA0)";
      case 'passport':
        return 'Enter Passport Number (e.g. A12345678)';
      default:
        return 'Enter ID Number';
    }
  }

  void _handleVerify() async {
    final idNum = _idController.text.trim();
    final bvn = _bvnController.text.trim();
    final dob = _dobController.text.trim();

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
      final updatedUser = res['user'] as UserProfile;
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
                child: const Icon(Icons.verified, size: 40, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 14),
              Text(
                'Identity Verified! 🎉',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Your dedicated virtual account is now active and ready to receive funds.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    Text(
                      'ACCOUNT NAME',
                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rentilly - ${user.fullName.isNotEmpty ? user.fullName : "User"}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'DEDICATED ACCOUNT NUMBER',
                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.accountNumber ?? '0291847291',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SETTLEMENT: DEDICATED ESCROW',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '💡 Use your dedicated account number to fund your Living Escrow balance from any bank app.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Done & View My Account', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
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
                    const Icon(Icons.shield_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Identity & Bank Verification',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select your preferred ID, enter your BVN, and confirm your Date of Birth to activate your live dedicated bank account.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Error Box
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 1. Select Means of Identification (4 Options)
            Text(
              '1. CHOOSE MEANS OF IDENTIFICATION',
              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeChip('nin', 'NIN', Icons.badge_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeChip('voters_card', "Voter's Card", Icons.how_to_vote_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeChip('drivers_license', "Driver's License", Icons.drive_eta_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeChip('passport', "Int'l Passport", Icons.flight_takeoff_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. ID Document Number Input
            Text(
              '2. ENTER ${_idTypeLabel.toUpperCase()} NUMBER',
              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _idController,
              keyboardType: _selectedIdType == 'nin' ? TextInputType.number : TextInputType.text,
              maxLength: _selectedIdType == 'nin' ? 11 : 25,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                hintText: _idInputHint,
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                prefixIcon: const Icon(Icons.assignment_ind_rounded, size: 18, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Bank Verification Number (BVN) Input
            Text(
              '3. ENTER 11-DIGIT BANK VERIFICATION NUMBER (BVN)',
              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bvnController,
              keyboardType: TextInputType.number,
              maxLength: 11,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Enter 11-digit BVN (e.g. 2219 4820 183)',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Date of Birth (Interactive Calendar Picker)
            Text(
              '4. CONFIRM DATE OF BIRTH (TAP CALENDAR)',
              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(1996, 1, 1),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          onSurface: AppColors.textPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  final formatted = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                  setState(() => _dobController.text = formatted);
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: _dobController,
                  readOnly: true,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'DD/MM/YYYY (Tap to select date)',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                    suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Security note
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 13, color: AppColors.primaryLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bank-grade security compliance. Securely validated against official identity databases.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Verify ID & Activate Dedicated Bank Account',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String id, String label, IconData icon) {
    final isSelected = _selectedIdType == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIdType = id;
          _idController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
