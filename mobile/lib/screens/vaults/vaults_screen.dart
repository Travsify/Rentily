import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

class VaultsScreen extends StatefulWidget {
  const VaultsScreen({super.key});

  @override
  State<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends State<VaultsScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  final List<Map<String, dynamic>> _vaults = [
    {
      'title': 'Annual Rent Vault 2027',
      'target': 4000000,
      'saved': 2850000,
      'yieldRate': '11.5% p.a.',
      'icon': Icons.home_work_rounded,
      'color': Color(0xFF10B981),
      'rule': 'Auto-Deduct 10% on every inflow',
      'daysLeft': 142,
    },
    {
      'title': 'Electricity & Disco Stash',
      'target': 60000,
      'saved': 45000,
      'yieldRate': '8% p.a.',
      'icon': Icons.electric_meter_rounded,
      'color': Color(0xFFF59E0B),
      'rule': 'Auto-recharges meter when units fall below 10kWh',
      'daysLeft': null,
    },
    {
      'title': 'Monthly Foodstuff & Groceries',
      'target': 150000,
      'saved': 120000,
      'yieldRate': 'Locked',
      'icon': Icons.shopping_basket_rounded,
      'color': Color(0xFF3B82F6),
      'rule': 'Weekly allowance release every Monday',
      'daysLeft': null,
    },
    {
      'title': 'Internet & High-Speed Data',
      'target': 35000,
      'saved': 35000,
      'yieldRate': 'Ready',
      'icon': Icons.wifi_rounded,
      'color': Color(0xFF8B5CF6),
      'rule': 'Auto-renews 1st of every month',
      'daysLeft': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final double totalVaultSavings = _vaults.fold(0.0, (sum, v) => sum + (v['saved'] as num));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Living Vaults (Target Savings)',
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
              // Total Savings Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F382A).withValues(alpha: 0.8),
                      AppColors.surfaceDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL LOCKED IN LIVING VAULTS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'UP TO 12% YIELD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${_currencyFormat.format(totalVaultSavings)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automated living reserves across rent, power, data, and groceries.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Salary Splitter Rule Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_fix_high_rounded, size: 16, color: AppColors.accentGold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salary Splitter Active (10% to Rent)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Whenever you receive money into your Rentilly account, 10% is automatically routed to your Rent Vault.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Vaults List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACTIVE LIVING POCKETS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.primaryLight),
                    label: Text(
                      'New Vault',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _vaults.length,
                itemBuilder: (context, index) {
                  final v = _vaults[index];
                  final double saved = (v['saved'] as num).toDouble();
                  final double target = (v['target'] as num).toDouble();
                  final double progress = (saved / target).clamp(0.0, 1.0);
                  final Color color = v['color'] as Color;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(v['icon'] as IconData, size: 16, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v['title'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    v['rule'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v['yieldRate'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progress Bar
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),

                        // Target vs Saved
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₦${_currencyFormat.format(saved)} saved',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Target: ₦${_currencyFormat.format(target)} (${(progress * 100).toInt()}%)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
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
}
