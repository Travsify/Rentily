import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../widgets/rentilly_bottom_bar.dart';

class GlobalPayTrackerScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const GlobalPayTrackerScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isTuition = order['orderType'] == 'tuition';
    final status = order['status'] ?? 'PROCESSING';

    final stages = [
      {
        'title': 'Pre-Auth Wallet Hold Secured',
        'subtitle': '₦${currencyFormat.format(order['totalDebitedNgn'] ?? 0)} locked with zero-risk atomic accounting.',
        'icon': Icons.lock_clock,
        'completed': true,
      },
      {
        'title': 'Compliance & Sanctions Screening Cleared',
        'subtitle': 'AML OFAC checks passed. CBN documentation matched.',
        'icon': Icons.verified_user,
        'completed': true,
      },
      {
        'title': 'Dispatched via Rentilly International Clearing Rail',
        'subtitle': 'Route: ${(order['paymentScheme'] ?? 'SWIFT').toString().toUpperCase()} clearing network.',
        'icon': Icons.send_rounded,
        'completed': status == 'PROCESSING' || status == 'COMPLETED',
      },
      {
        'title': isTuition ? 'Tuition Credited to University' : 'Supplier Bank Received Wire',
        'subtitle': status == 'COMPLETED'
            ? 'Delivered and confirmed by beneficiary bank.'
            : 'Estimated delivery: 2 to 24 hours depending on country rail.',
        'icon': Icons.check_circle_rounded,
        'completed': status == 'COMPLETED',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      bottomNavigationBar: const RentillyBottomBar(currentIndex: 3),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transfer Tracker',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Status Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (status == 'COMPLETED' ? AppColors.mint : AppColors.accentGold).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'COMPLETED' ? Icons.check : Icons.hourglass_top,
                      color: status == 'COMPLETED' ? AppColors.mint : AppColors.accentGoldDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${order['destinationCurrency']} ${currencyFormat.format(order['destinationAmount'] ?? 0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTuition
                        ? (order['institutionName'] ?? 'University Tuition')
                        : (order['beneficiary']?['name'] ?? 'Overseas Supplier'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (status == 'COMPLETED' ? AppColors.mint : AppColors.accentGold).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'STATUS: $status',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status == 'COMPLETED' ? AppColors.mint : AppColors.accentGoldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4-Stage Timeline
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transfer Lifecycle',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (int i = 0; i < stages.length; i++) ...[
                    _buildTimelineStep(
                      title: stages[i]['title'] as String,
                      subtitle: stages[i]['subtitle'] as String,
                      icon: stages[i]['icon'] as IconData,
                      isCompleted: stages[i]['completed'] as bool,
                      isLast: i == stages.length - 1,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Remittance Certificate Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remittance Certificate Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Reference:', order['reference'] ?? 'N/A'),
                  if (order['fincraPayoutReference'] != null)
                    _buildDetailRow('Clearing Rail Ref:', (order['fincraPayoutReference'] ?? '').toString().replaceAll('FINCRA_', 'RTLY_').replaceAll('fincra_', 'rtly_')),
                  if (isTuition && order['studentMatricId'] != null)
                    _buildDetailRow('Student ID:', order['studentMatricId']),
                  if (!isTuition && order['invoiceNumber'] != null)
                    _buildDetailRow('Invoice #:', order['invoiceNumber']),
                  _buildDetailRow(
                    'Rate Locked:',
                    '1 ${order['destinationCurrency']} = ₦${currencyFormat.format(order['customerRate'] ?? 0)}',
                  ),
                  _buildDetailRow(
                    'Corridor Rail Fee:',
                    '₦${currencyFormat.format(order['corridorFeeNgn'] ?? 0)}',
                  ),
                  const Divider(color: AppColors.borderDark, height: 20),
                  _buildDetailRow(
                    'Total Naira Debited:',
                    '₦${currencyFormat.format(order['totalDebitedNgn'] ?? 0)}',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.primary : AppColors.borderDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isCompleted ? Colors.white : AppColors.textMuted,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? AppColors.primary : AppColors.borderDark,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isHighlight ? 14 : 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
