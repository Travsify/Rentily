import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../services/payment_security_service.dart';
import '../services/biometric_service.dart';

class PaymentPinModal {
  // 1. Enter Payment PIN Modal (With Quick Biometric Trigger)
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

  // 2. Create 4-digit PIN Modal
  static Future<bool> showCreatePin(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePinSheet(),
    );
    return result ?? false;
  }

  // 3. Change Payment PIN Modal (Verifies Current PIN First)
  static Future<bool> showChangePin(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePinSheet(),
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
    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += val;
        _errorMessage = null;
      });

      if (_pin.length == 4) {
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
        _errorMessage = 'Incorrect 4-digit payment PIN. Please try again.';
      });
    }
  }

  void _tryBiometricAuth() async {
    final passed = await BiometricService.authenticate(
      reason: 'Authorize payment of ₦${NumberFormat('#,###.00').format(widget.amount)} for ${widget.title}',
    );
    if (passed && mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      if (widget.recipient != null)
                        Text(widget.recipient!, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
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
            'Enter your 4-digit Payment PIN or use Biometrics',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // 4 PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
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

          // Numeric Keypad with Biometric Shortcut
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
          ['bio', '0', 'back'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key == 'bio') {
                  return InkWell(
                    onTap: _tryBiometricAuth,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 70,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.fingerprint_rounded, size: 24, color: AppColors.primary),
                    ),
                  );
                }
                if (key == 'back') {
                  return InkWell(
                    onTap: _onBackspace,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 70,
                      height: 50,
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, size: 20, color: AppColors.textPrimary),
                    ),
                  );
                }
                return InkWell(
                  onTap: () => _onKeyPress(key),
                  borderRadius: BorderRadius.circular(16),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

// ==================== CREATE PIN MODAL ====================
class _CreatePinSheet extends StatefulWidget {
  const _CreatePinSheet();

  @override
  State<_CreatePinSheet> createState() => _CreatePinSheetState();
}

class _CreatePinSheetState extends State<_CreatePinSheet> {
  int _step = 1; // 1 = Create, 2 = Confirm
  String _pin = '';
  String _confirmedPin = '';
  String? _errorMessage;

  void _onKeyPress(String val) {
    if (_step == 1 && _pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += val;
        _errorMessage = null;
      });

      if (_pin.length == 4) {
        setState(() {
          _step = 2;
        });
      }
    } else if (_step == 2 && _confirmedPin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _confirmedPin += val;
        _errorMessage = null;
      });

      if (_confirmedPin.length == 4) {
        _savePin();
      }
    }
  }

  void _onBackspace() {
    if (_step == 2) {
      if (_confirmedPin.isNotEmpty) {
        setState(() {
          _confirmedPin = _confirmedPin.substring(0, _confirmedPin.length - 1);
          _errorMessage = null;
        });
      } else {
        setState(() {
          _step = 1;
          _pin = '';
        });
      }
    } else if (_step == 1 && _pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _savePin() async {
    if (_pin == _confirmedPin) {
      final success = await PaymentSecurityService.setPaymentPin(_pin);
      if (success) {
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _step = 1;
        _pin = '';
        _confirmedPin = '';
        _errorMessage = 'PINs do not match. Please start again.';
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
            decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _step == 1 ? 'Create 4-Digit Payment PIN' : 'Confirm 4-Digit PIN',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop(false)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _step == 1
                ? 'Create a secret 4-digit code to authorize all withdrawals and utility payments.'
                : 'Re-enter your 4-digit PIN to confirm.',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = _step == 1 ? index < _pin.length : index < _confirmedPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: isFilled ? AppColors.primary : AppColors.borderDark, width: 2),
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

          // Keypad
          Column(
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
                      if (key.isEmpty) return const SizedBox(width: 70, height: 50);
                      if (key == 'back') {
                        return InkWell(
                          onTap: _onBackspace,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 70,
                            height: 50,
                            alignment: Alignment.center,
                            child: const Icon(Icons.backspace_outlined, size: 20, color: AppColors.textPrimary),
                          ),
                        );
                      }
                      return InkWell(
                        onTap: () => _onKeyPress(key),
                        borderRadius: BorderRadius.circular(16),
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
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ==================== CHANGE PIN MODAL ====================
class _ChangePinSheet extends StatefulWidget {
  const _ChangePinSheet();

  @override
  State<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends State<_ChangePinSheet> {
  int _step = 1; // 1 = Enter Current PIN, 2 = Enter New PIN, 3 = Confirm New PIN
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _errorMessage;

  void _onKeyPress(String val) async {
    HapticFeedback.lightImpact();
    if (_step == 1) {
      if (_currentPin.length < 4) {
        setState(() {
          _currentPin += val;
          _errorMessage = null;
        });

        if (_currentPin.length == 4) {
          final isValid = await PaymentSecurityService.verifyPaymentPin(_currentPin);
          if (isValid) {
            setState(() {
              _step = 2;
            });
          } else {
            HapticFeedback.heavyImpact();
            setState(() {
              _currentPin = '';
              _errorMessage = 'Incorrect current PIN. Please enter your correct payment code.';
            });
          }
        }
      }
    } else if (_step == 2) {
      if (_newPin.length < 4) {
        setState(() {
          _newPin += val;
          _errorMessage = null;
        });

        if (_newPin.length == 4) {
          setState(() {
            _step = 3;
          });
        }
      }
    } else if (_step == 3) {
      if (_confirmPin.length < 4) {
        setState(() {
          _confirmPin += val;
          _errorMessage = null;
        });

        if (_confirmPin.length == 4) {
          if (_newPin == _confirmPin) {
            await PaymentSecurityService.setPaymentPin(_newPin);
            HapticFeedback.mediumImpact();
            if (!mounted) return;
            Navigator.of(context).pop(true);
          } else {
            HapticFeedback.heavyImpact();
            setState(() {
              _step = 2;
              _newPin = '';
              _confirmPin = '';
              _errorMessage = 'New PINs do not match. Please try again.';
            });
          }
        }
      }
    }
  }

  void _onBackspace() {
    if (_step == 1 && _currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _errorMessage = null;
      });
    } else if (_step == 2 && _newPin.isNotEmpty) {
      setState(() {
        _newPin = _newPin.substring(0, _newPin.length - 1);
        _errorMessage = null;
      });
    } else if (_step == 3 && _confirmPin.isNotEmpty) {
      setState(() {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 1:
        return 'Enter Current Payment PIN';
      case 2:
        return 'Enter New 4-Digit PIN';
      case 3:
        return 'Confirm New 4-Digit PIN';
      default:
        return 'Change Payment PIN';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 1:
        return 'Please enter your current payment PIN to verify ownership before changing.';
      case 2:
        return 'Enter your new 4-digit payment PIN.';
      case 3:
        return 'Re-enter your new 4-digit payment PIN to confirm.';
      default:
        return '';
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
            decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _stepTitle,
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop(false)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _stepSubtitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = _step == 1
                  ? index < _currentPin.length
                  : _step == 2
                      ? index < _newPin.length
                      : index < _confirmPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: isFilled ? AppColors.primary : AppColors.borderDark, width: 2),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 16),

          // Keypad
          Column(
            children: [
              for (var row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['cancel', '0', 'back'],
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: row.map((key) {
                      if (key == 'cancel') {
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(false),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 70,
                            height: 50,
                            alignment: Alignment.center,
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      }
                      if (key == 'back') {
                        return InkWell(
                          onTap: _onBackspace,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 70,
                            height: 50,
                            alignment: Alignment.center,
                            child: const Icon(Icons.backspace_outlined, size: 20, color: AppColors.textPrimary),
                          ),
                        );
                      }
                      return InkWell(
                        onTap: () => _onKeyPress(key),
                        borderRadius: BorderRadius.circular(16),
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
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
