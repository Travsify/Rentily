import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class DateOfBirthModal extends StatefulWidget {
  final UserProfile user;
  final Function(UserProfile updatedUser) onSuccess;

  const DateOfBirthModal({super.key, required this.user, required this.onSuccess});

  static void show(BuildContext context, {required UserProfile user, required Function(UserProfile) onSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DateOfBirthModal(user: user, onSuccess: onSuccess),
    );
  }

  @override
  State<DateOfBirthModal> createState() => _DateOfBirthModalState();
}

class _DateOfBirthModalState extends State<DateOfBirthModal> {
  DateTime? _selectedDate;
  final TextEditingController _bvnController = TextEditingController();
  final TextEditingController _ninController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bvnController.text = widget.user.bvn ?? '';
    _ninController.text = widget.user.ninNumber ?? '';
    // Default to a 25-year-old if no existing dob
    if (widget.user.dob != null && widget.user.dob!.isNotEmpty) {
      try {
        final parts = widget.user.dob!.split('-');
        if (parts.length == 3) {
          _selectedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _bvnController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  String get _formattedDob {
    if (_selectedDate == null) return '';
    return DateFormat('dd-MM-yyyy').format(_selectedDate!);
  }

  void _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? DateTime(now.year - 25, 1, 1);
    final first = DateTime(now.year - 100);
    final last = DateTime(now.year - 18, now.month, now.day); // At least 18 years old

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
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
      setState(() {
        _selectedDate = picked;
        _errorMessage = null;
      });
    }
  }

  void _handleSubmit() async {
    final bvnVal = _bvnController.text.trim();
    if (bvnVal.length != 11) {
      setState(() => _errorMessage = 'Please enter your valid 11-digit Bank Verification Number (BVN).');
      return;
    }

    final ninVal = _ninController.text.trim();
    if (ninVal.length != 11) {
      setState(() => _errorMessage = 'Please enter your valid 11-digit National Identity Number (NIN).');
      return;
    }

    if (_selectedDate == null) {
      setState(() => _errorMessage = 'Please select your Date of Birth.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dobStr = _formattedDob;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/verification/complete-maplerad-kyc');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.user.email,
          'dob': dobStr,
          'fullName': widget.user.fullName,
          'phoneNumber': widget.user.phoneNumber,
          'bvn': bvnVal,
          'nin': ninVal,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(res.body);
      setState(() => _isSubmitting = false);

      if (res.statusCode == 200 && data['status'] == true) {
        final newAccount = data['accountNumber']?.toString() ?? widget.user.accountNumber;
        final newBank = data['bankName']?.toString() ?? widget.user.bankName ?? '9PSB (Rentilly)';

        final updatedUser = widget.user.copyWith(
          dob: dobStr,
          bvn: bvnVal,
          ninNumber: ninVal,
          accountNumber: newAccount,
          bankName: newBank,
          rekycRequired: false,
          isVerified: true,
        );

        await AuthService.updateUser(updatedUser);
        widget.onSuccess(updatedUser);

        if (!mounted) return;
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newAccount != null
                  ? '🎉 Dedicated Account Activated: $newAccount ($newBank)!'
                  : 'Date of Birth recorded! Rentilly is processing your account activation.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _errorMessage = data['message'] ?? data['error'] ?? 'Could not activate account. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Network connection issue. Please check your internet and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cake_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Date of Birth',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Activate your dedicated 9PSB account & Dollar Card',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your wallet balance is 100% safe. Linking your Date of Birth activates your dedicated 9PSB settlement account & Virtual Dollar Card immediately.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF15803D), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Text(
            'BANK VERIFICATION NUMBER (BVN) *',
            style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _bvnController,
            keyboardType: TextInputType.number,
            maxLength: 11,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter 11-digit BVN',
              counterText: '',
              prefixIcon: const Icon(Icons.account_balance_rounded, size: 20, color: AppColors.primary),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'NATIONAL IDENTITY NUMBER (NIN) *',
            style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ninController,
            keyboardType: TextInputType.number,
            maxLength: 11,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter 11-digit NIN',
              counterText: '',
              prefixIcon: const Icon(Icons.fingerprint_rounded, size: 20, color: AppColors.primary),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'SELECT DATE OF BIRTH',
            style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedDate != null ? AppColors.primary : AppColors.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDate != null ? _formattedDob : 'Tap to select Date of Birth (DD-MM-YYYY)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: _selectedDate != null ? FontWeight.bold : FontWeight.w500,
                        color: _selectedDate != null ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Submit & Activate Dedicated Account ⚡',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
