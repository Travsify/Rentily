import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/withdrawal_modal.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  bool _hideBalance = false;
  UserProfile? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
        _user = AuthService.currentUserNotifier.value;
      });
    }
  }

  Future<void> _loadData() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = u;
        _isLoading = false;
      });
    }

    if (u != null) {
      try {
        final url = Uri.parse('${AppConstants.apiBaseUrl}/wallet/balance?userId=${u.id}&email=${u.email}');
        final res = await http.get(url).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == true && data['walletBalance'] != null) {
            final double serverBal = (data['walletBalance'] as num).toDouble();
            if (serverBal != u.walletBalance) {
              final updated = u.copyWith(walletBalance: serverBal);
              await AuthService.updateUser(updated);
              if (mounted) setState(() => _user = updated);
            }
          }
        }
      } catch (_) {}
    }
  }

  void _copyAccount() {
    final acc = _user?.accountNumber;
    if (acc == null || acc.isEmpty) {
      VerificationModal.show(context, onSuccess: (updated) {
        setState(() => _user = updated);
      });
      return;
    }
    Clipboard.setData(ClipboardData(text: acc));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Account Number Copied: $acc (${_user?.bankName ?? "Flutterwave MFB"})',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double balance = _user?.walletBalance ?? 0.00;
    final String? accNum = _user?.accountNumber;
    final String bank = _user?.bankName ?? 'Flutterwave MFB';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Rentilly Living Wallet',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      bottomNavigationBar: const RentillyBottomBar(currentIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Debit Wallet Card (Emerald Teal & Deep Pine with Gold/Amber Accents)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0D5C46),
                      Color(0xFF07382B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'RENTILLY LIVING ESCROW',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            accNum != null ? bank.toUpperCase() : 'PENDING ACTIVATION',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Balance Display
                    Text(
                      'TOTAL AVAILABLE BALANCE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _hideBalance ? '₦ • • • • • •' : '₦${_currencyFormat.format(balance)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          onPressed: () => setState(() => _hideBalance = !_hideBalance),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Real Account Status (Zero Fake Numbers)
                    if (accNum != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DEDICATED NUBAN',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                Text(
                                  '$accNum • $bank',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _copyAccount,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Copy',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          VerificationModal.show(context, onSuccess: (updated) {
                            setState(() => _user = updated);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VIRTUAL ACCOUNT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    Text(
                                      'Not Generated Yet',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Activate Now',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Wallet Actions (Add Money, Send Money, Living Vault)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(Icons.add_rounded, 'Add Money', _copyAccount),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(Icons.north_east_rounded, 'Withdraw', () {
                      if (_user == null || !_user!.isVerified) {
                        VerificationModal.show(context, onSuccess: (updated) {
                          setState(() => _user = updated);
                        });
                        return;
                      }
                      WithdrawalModal.show(
                        context,
                        user: _user!,
                        onWithdrawalSuccess: (newBal) {
                          setState(() => _user = _user!.copyWith(walletBalance: newBal));
                        },
                      );
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(Icons.savings_rounded, 'Living Vault', () {}),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actual Transaction History (Zero Dummy Data)
              Text(
                'TRANSACTION HISTORY',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Empty State for Real Data
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined, size: 32, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Transactions Yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your deposits, rent savings yields, and utility token receipts will appear here in real-time.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
