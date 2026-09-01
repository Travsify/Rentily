import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/otp_service.dart';

class InlineOtpVerificationWidget extends StatefulWidget {
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final TextEditingController textController;
  final TextInputType keyboardType;
  final String channel; // 'email' | 'sms'
  final bool isVerified;
  final ValueChanged<bool> onVerifiedChanged;
  final String? Function(String?)? validator;

  const InlineOtpVerificationWidget({
    super.key,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    required this.textController,
    this.keyboardType = TextInputType.text,
    required this.channel,
    required this.isVerified,
    required this.onVerifiedChanged,
    this.validator,
  });

  @override
  State<InlineOtpVerificationWidget> createState() => _InlineOtpVerificationWidgetState();
}

class _InlineOtpVerificationWidgetState extends State<InlineOtpVerificationWidget> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());

  bool _isSending = false;
  bool _isBoxExpanded = false;
  bool _isVerifying = false;
  String? _statusError;
  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  void _sendOtp() async {
    final value = widget.textController.text.trim();
    if (value.isEmpty) {
      setState(() => _statusError = 'Please enter your ${widget.label.toLowerCase()} first.');
      return;
    }

    if (widget.channel == 'email' && (!value.contains('@') || !value.contains('.'))) {
      setState(() => _statusError = 'Please enter a valid email address.');
      return;
    }

    if (widget.channel == 'sms' && value.length < 10) {
      setState(() => _statusError = 'Please enter a valid 11-digit mobile number.');
      return;
    }

    setState(() {
      _isSending = true;
      _statusError = null;
    });

    final res = await OtpService.sendOtp(
      email: widget.channel == 'email' ? value : null,
      phoneNumber: widget.channel == 'sms' ? value : null,
      channel: widget.channel,
      purpose: '${widget.label} Verification',
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (res['success'] == true) {
        setState(() {
          _isBoxExpanded = true;
        });
        _startTimer();
        _otpNodes[0].requestFocus();
      } else {
        setState(() => _statusError = res['message'] ?? 'Failed to send verification code.');
      }
    }
  }

  void _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _statusError = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusError = null;
    });

    final value = widget.textController.text.trim();
    final res = await OtpService.verifyOtp(
      email: widget.channel == 'email' ? value : null,
      phoneNumber: widget.channel == 'sms' ? value : null,
      code: code,
    );

    if (mounted) {
      setState(() => _isVerifying = false);
      if (res['success'] == true) {
        setState(() {
          _isBoxExpanded = false;
        });
        widget.onVerifiedChanged(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${widget.label} Verified! ✅', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _statusError = res['message'] ?? 'Invalid verification code.');
      }
    }
  }

  void _onDigitChanged(int index, String val) {
    if (val.isNotEmpty) {
      if (val.length > 1) {
        final digits = val.replaceAll(RegExp(r'[^0-9]'), '').split('');
        for (int i = 0; i < 6; i++) {
          if (i < digits.length) _otpControllers[i].text = digits[i];
        }
        if (digits.length >= 6) {
          _otpNodes[5].unfocus();
          _verifyOtp();
        } else {
          _otpNodes[digits.length].requestFocus();
        }
        return;
      }

      if (index < 5) {
        _otpNodes[index + 1].requestFocus();
      } else {
        _otpNodes[index].unfocus();
        if (_otpControllers.map((c) => c.text).join().length == 6) {
          _verifyOtp();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: AppColors.textSecondary,
              ),
            ),
            if (widget.isVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      'VERIFIED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Input Field with integrated Verify Button
        Container(
          decoration: BoxDecoration(
            color: widget.isVerified ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isVerified ? const Color(0xFF16A34A) : AppColors.borderDark,
              width: widget.isVerified ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  widget.isVerified ? Icons.check_circle_rounded : widget.prefixIcon,
                  size: 18,
                  color: widget.isVerified ? const Color(0xFF16A34A) : AppColors.primary,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.textController,
                  enabled: !widget.isVerified,
                  keyboardType: widget.keyboardType,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: widget.isVerified ? const Color(0xFF166534) : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (_) {
                    if (widget.isVerified) {
                      widget.onVerifiedChanged(false);
                    }
                  },
                ),
              ),
              if (!widget.isVerified) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextButton(
                    onPressed: _isSending ? null : _sendOtp,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSending
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                        : Text(
                            'Verify',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Expandable Inline OTP Entry Pod
        if (_isBoxExpanded && !widget.isVerified) ...[
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.channel == 'email' ? Icons.mark_email_read_rounded : Icons.sms_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.channel == 'email'
                              ? 'Enter 6-Digit Email Code'
                              : 'Enter 6-Digit Twilio SMS Code',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isBoxExpanded = false),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 6 Cells
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 36,
                      height: 44,
                      child: TextField(
                        controller: _otpControllers[i],
                        focusNode: _otpNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        onChanged: (val) => _onDigitChanged(i, val),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Confirm Action Row
                Row(
                  children: [
                    Expanded(
                      child: _countdown > 0
                          ? Text(
                              'Resend in ${_countdown}s',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            )
                          : GestureDetector(
                              onTap: _isSending ? null : _sendOtp,
                              child: Text(
                                'Resend Code 🔄',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                    ),
                    ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isVerifying
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Confirm Code',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        if (_statusError != null) ...[
          const SizedBox(height: 4),
          Text(
            _statusError!,
            style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.red.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
