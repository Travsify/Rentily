import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../../widgets/quick_utilities_modal.dart';
import '../bills/bills_screen.dart';

class PartnerWalletScreen extends StatefulWidget {
  const PartnerWalletScreen({super.key});

  @override
  State<PartnerWalletScreen> createState() => _PartnerWalletScreenState();
}

class _PartnerWalletScreenState extends State<PartnerWalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  void _copyAccount(String accountNumber) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account Number $accountNumber copied! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isVerified = _user?.isVerified ?? false;
    final businessName = _user?.businessName ?? 'Apex Realty Partners Ltd';
    final cacNumber = _user?.cacNumber ?? 'RC 1928374';
    final operationalBalance = _user?.walletBalance ?? 0.0;
    final escrowCommission = 0.00; // 2.5% rent or 2.0% sales held in escrow before key confirmation
    final accountNumber = _user?.accountNumber ?? '9834192847';
    final bankName = _user?.bankName ?? 'Flutterwave with MFB';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Commissions & Escrow Wallet',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _loadUser(),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Dual Balance Card (Operational Balance vs Escrow Commission Balance)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                            const Icon(Icons.business_center_rounded, size: 16, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              'PARTNER OPERATING VAULT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFF22C55E).withValues(alpha: 0.2) : AppColors.accentOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isVerified ? const Color(0xFF4ADE80) : AppColors.accentOrange),
                          ),
                          child: Text(
                            isVerified ? 'CAC ACCREDITED 🛡️' : 'TIER 1 (UNVERIFIED)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isVerified ? const Color(0xFF4ADE80) : AppColors.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operational Funded Balance
                    Text('AVAILABLE OPERATING FUNDS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white60)),
                    const SizedBox(height: 2),
                    Text('₦${_currencyFormat.format(operationalBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 14),

                    // Divider
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),

                    // Escrow Commission Balance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('COMMISSIONS IN ESCROW (2.5% RENT / 2.0% SALE)', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                            const SizedBox(height: 2),
                            Text('₦${_currencyFormat.format(escrowCommission)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RELEASES ON KEY HANDOVER',
                            style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Virtual Bank Account Section (Strict KYC Gated)
              if (!isVerified) ...[
                // Unverified Warning Card (No Dummy Bank Account)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 20, color: Color(0xFFB45309)),
                          const SizedBox(width: 8),
                          Text(
                            'CAC & Identity Verification Required',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'To comply with CBN regulations and prevent ghost brokerage accounts, dedicated settlement bank accounts are only provisioned after completing CAC and Tier-3 BVN/NIN verification.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF78350F), height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () {
                          VerificationModal.show(context, onSuccess: (updated) {
                            setState(() => _user = updated);
                          });
                        },
                        icon: const Icon(Icons.verified_user_rounded, size: 16, color: Colors.white),
                        label: Text('Complete Tier-3 KYC Verification', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB45309),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Verified Virtual Bank Account Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                              const Icon(Icons.account_balance_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'DEDICATED COMMISSIONS BANK ACCOUNT',
                                style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AUTOMATED COMMISSION SETTLEMENT',
                              style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(accountNumber, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                              Text('$bankName • $businessName ($cacNumber) / Rentilly', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                            onPressed: () => _copyAccount(accountNumber),
                            tooltip: 'Copy Account Number',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  AddMoneyModal.show(context, user: _user!, onAccountUpdated: (u) {
                                    setState(() => _user = u);
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                              label: Text('Fund Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  WithdrawalModal.show(
                                    context,
                                    user: _user!,
                                    onWithdrawalSuccess: (newBal) {
                                      setState(() => _user = _user!.copyWith(walletBalance: newBal));
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.north_east_rounded, size: 14, color: AppColors.primary),
                              label: Text('Withdraw', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Partner Utilities Pod (High Speed Data, Airtime, Meter Tokens)
              Text(
                'FIELD UTILITIES & OPERATIONS',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildUtilityButton(Icons.electric_bolt_rounded, 'Electricity', 'Prepaid DisCo', () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'electricity')));
                        }),
                        _buildUtilityButton(Icons.phone_android_rounded, 'Airtime', 'Quick Top-Up', () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'airtime')));
                        }),
                        _buildUtilityButton(Icons.wifi_rounded, 'Data Bundle', '4K Video Tours', () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'data')));
                        }),
                        _buildUtilityButton(Icons.tv_rounded, 'Cable TV', 'DSTV/GOTV', () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'cable')));
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Commissions Ledger History
              Text(
                'COMMISSION SETTLEMENT LEDGER',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.history_rounded, size: 32, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text('No Recent Commission Settlements', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('When tenants complete rent payment and move-in key handover, 2.5% rent and 2.0% sale commission payouts appear here.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityButton(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
