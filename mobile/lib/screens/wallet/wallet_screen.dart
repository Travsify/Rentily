import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  bool _hideBalance = false;
  double _balance = 2450000.00;
  final String _accountNumber = '9948291038';
  final String _bankName = 'Wema Bank (Rentilly Escrow)';
  final String _accountName = 'Rentilly / Femi Adesanya';

  final List<Map<String, dynamic>> _recentTransactions = [
    {
      'title': 'Rent Vault Auto-Deduct (10%)',
      'category': 'Living Vault',
      'amount': -150000.00,
      'date': 'Today, 09:15 AM',
      'icon': Icons.savings_rounded,
      'isCredit': false,
    },
    {
      'title': 'Salary Inflow (Direct Transfer)',
      'category': 'Deposit',
      'amount': 1500000.00,
      'date': 'Yesterday, 04:30 PM',
      'icon': Icons.arrow_downward_rounded,
      'isCredit': true,
    },
    {
      'title': 'EKEDC Prepaid Light Token',
      'category': 'Utility',
      'amount': -25000.00,
      'date': '28 Aug 2026',
      'icon': Icons.electric_meter_rounded,
      'isCredit': false,
    },
    {
      'title': 'Rent Savings Monthly Yield (11.5%)',
      'category': 'Interest Earned',
      'amount': 28750.00,
      'date': '25 Aug 2026',
      'icon': Icons.trending_up_rounded,
      'isCredit': true,
    },
  ];

  void _copyAccount() {
    Clipboard.setData(ClipboardData(text: _accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Account Number Copied! Send money from any Nigerian banking app.',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Rentilly Living Wallet',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Wallet Debit Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F382A),
                      Color(0xFF061E16),
                      Color(0xFF0B0F17),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Card Brand & Bank
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded, size: 18, color: AppColors.primaryLight),
                            const SizedBox(width: 6),
                            Text(
                              'RENTILLY LIVING VAULT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'WEMA BANK',
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
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _hideBalance ? '₦ • • • • • •' : '₦${_currencyFormat.format(_balance)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _hideBalance = !_hideBalance),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Dedicated NUBAN Virtual Account
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEDICATED NUBAN (RECEIVE ANYWHERE)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                '$_accountNumber • $_bankName',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
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
                                color: AppColors.primaryLight.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Wallet Action Buttons (Add Money, Transfer, Pay Bills)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.add_rounded,
                      label: 'Add Money',
                      onTap: _copyAccount,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.north_east_rounded,
                      label: 'Send Money',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Instant transfer to all 701 Nigerian banks active.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11),
                            ),
                            backgroundColor: AppColors.surfaceDark,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.lock_outline_rounded,
                      label: 'Lock Stash',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Transaction History
              Text(
                'RECENT TRANSACTIONS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTransactions.length,
                itemBuilder: (context, index) {
                  final tx = _recentTransactions[index];
                  final isCredit = tx['isCredit'] as bool;
                  final double amt = tx['amount'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCredit
                                ? AppColors.primaryLight.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            tx['icon'] as IconData,
                            size: 16,
                            color: isCredit ? AppColors.primaryLight : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx['title'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${tx['category']} • ${tx['date']}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isCredit ? '+' : ''}₦${_currencyFormat.format(amt.abs())}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isCredit ? AppColors.primaryLight : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryLight),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
