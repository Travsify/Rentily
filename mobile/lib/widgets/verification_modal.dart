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
  String _selectedIdType = 'bvn'; // 'bvn' or 'nin'
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(text: '14/08/1994');
  bool _isLoading = false;
  String? _errorMessage;

  void _handleVerify() async {
    final idNum = _idController.text.trim();
    if (idNum.isEmpty || idNum.length < 11) {
      setState(() => _errorMessage = 'Please enter a valid 11-digit ${_selectedIdType.toUpperCase()}.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await VerificationService.verifyAndProvision(
      idType: _selectedIdType,
      idNumber: idNum,
      dob: _dobController.text.trim(),
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
        _errorMessage = res['message'] ?? 'Verification could not be completed.';
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
                'Your dedicated virtual bank account is now issued and ready to receive funds.',
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
                      'Rentilly Escrow - ${user.fullName.isNotEmpty ? user.fullName : 'Verified Tenant'}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ACCOUNT NUMBER (NUBAN)',
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
                        'BANK: ${user.bankName ?? 'Flutterwave MFB'}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '💡 Select "${user.bankName ?? 'Flutterwave MFB'}" in your banking app (GTBank, Access, Zenith, Kuda, PalmPay, etc.) when transferring funds.',
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
                  child: Text('Done & Start Transacting', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
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
              'Rentilly verifies your NIMC/NIBSS record and instantly issues your dedicated Living Escrow bank account.',
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

            // Select ID Type (BVN or NIN)
            Text('CHOOSE IDENTIFICATION TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeChip('bvn', 'BVN (Bank Verification)', Icons.account_balance_wallet_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTypeChip('nin', 'NIN (National Identity)', Icons.badge_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 11-Digit Number Input
            Text(
              'ENTER 11-DIGIT ${_selectedIdType.toUpperCase()}',
              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              maxLength: 11,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                hintText: _selectedIdType == 'bvn' ? '2219 4820 183' : '1092 8471 920',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              ),
            ),
            const SizedBox(height: 14),

            // Date of Birth (Interactive Calendar Picker)
            Text('DATE OF BIRTH (TAP TO SELECT FROM CALENDAR)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
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
            const SizedBox(height: 18),

            // Security note
            Row(
              children: [
                const Icon(Icons.lock, size: 12, color: AppColors.primaryLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '256-bit encrypted. We do not store your BVN or NIN; only verification tokens are retained.',
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
                        'Verify ID & Generate Bank Account',
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
      onTap: () => setState(() => _selectedIdType = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
