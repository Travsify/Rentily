import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../services/payment_security_service.dart';

class PaymentPinModal {
  // 1. Enter 6-digit PIN Modal
  static Future<bool> showEnterPin(
    BuildContext context, {
    required String title,
    required double amount,
    String? recipient,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EnterPinSheet(
        title: title,
        amount: amount,
        recipient: recipient,
      ),
    );
    return result ?? false;
  }

  // 2. Create 6-digit PIN Modal
  static Future<bool> showCreatePin(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePinSheet(),
    );
    return result ?? false;
  }
}

class _EnterPinSheet extends StatefulWidget {
  final String title;
  final double amount;
  final String? recipient;

  const _EnterPinSheet({
    required this.title,
    required this.amount,
    this.recipient,
  });

  @override
  State<_EnterPinSheet> createState() => _EnterPinSheetState();
}

class _EnterPinSheetState extends State<_EnterPinSheet> {
  String _pin = '';
  String? _errorMessage;
  bool _isVerifying = false;

  void _onKeyPress(String val) {
    if (_pin.length < 6) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += val;
        _errorMessage = null;
      });

      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _verifyPin() async {
    setState(() => _isVerifying = true);
    final isValid = await PaymentSecurityService.verifyPaymentPin(_pin);
    setState(() => _isVerifying = false);

    if (isValid) {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _errorMessage = 'Incorrect 6-digit payment PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Authorization',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                    if (widget.recipient != null)
                      Text(widget.recipient!, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                Text(
                  '₦${NumberFormat('#,###.00').format(widget.amount)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Enter your 6-digit Payment Code',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // 6 PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? AppColors.primary : AppColors.borderDark,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
            ),

          const SizedBox(height: 16),

          // Numeric Keypad
          _buildKeypad(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'back'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 70, height: 50);
                }
                if (key == 'back') {
                  return InkWell(
                    onTap: _onBackspace,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 70,
                      height: 50,
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textPrimary),
                    ),
                  );
                }
                return InkWell(
                  onTap: () => _onKeyPress(key),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 70,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Text(
                      key,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _CreatePinSheet extends StatefulWidget {
  const _CreatePinSheet();

  @override
  State<_CreatePinSheet> createState() => _CreatePinSheetState();
}

class _CreatePinSheetState extends State<_CreatePinSheet> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onKeyPress(String val) {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_pin.length < 6) {
          _pin += val;
          if (_pin.length == 6) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += val;
          if (_confirmPin.length == 6) {
            _savePin();
          }
        }
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
        }
      }
    });
  }

  void _savePin() async {
    if (_pin == _confirmPin) {
      await PaymentSecurityService.setPaymentPin(_pin);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('6-digit Payment PIN created successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _confirmPin = '';
        _errorMessage = 'PINs do not match. Please enter again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePin = _isConfirming ? _confirmPin : _pin;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isConfirming ? 'Confirm 6-Digit Payment Code' : 'Create 6-Digit Payment Code',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isConfirming ? 'Re-enter your 6-digit code to confirm' : 'Set a secret 6-digit code for all transfers & payouts',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // 6 PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < activePin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? AppColors.primary : AppColors.borderDark,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null)
            Text(_errorMessage!, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),

          const SizedBox(height: 16),
          _buildKeypad(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'back'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 70, height: 50);
                }
                if (key == 'back') {
                  return InkWell(
                    onTap: _onBackspace,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 70,
                      height: 50,
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textPrimary),
                    ),
                  );
                }
                return InkWell(
                  onTap: () => _onKeyPress(key),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 70,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Text(
                      key,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
