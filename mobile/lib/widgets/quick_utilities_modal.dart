import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../screens/bills/bills_screen.dart';

class QuickUtilitiesModal extends StatelessWidget {
  const QuickUtilitiesModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const QuickUtilitiesModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> utilityServices = [
      {
        'title': 'Electricity Bills',
        'subtitle': 'All 11 Nigerian Discos & 20-digit prepaid tokens',
        'icon': Icons.bolt_rounded,
        'category': 'electricity',
        'color': AppColors.accentOrange,
        'tag': 'INSTANT TOKEN',
      },
      {
        'title': 'Mobile Data Bundles',
        'subtitle': 'MTN, Airtel, Glo, and 9mobile high-speed bundles',
        'icon': Icons.wifi_rounded,
        'category': 'data',
        'color': const Color(0xFF0284C7),
        'tag': 'AUTOMATED',
      },
      {
        'title': 'Airtime VTU Recharge',
        'subtitle': 'Direct airtime top-up for all Nigerian telcos',
        'icon': Icons.phone_android_rounded,
        'category': 'airtime',
        'color': AppColors.primary,
        'tag': '2% CASHBACK',
      },
      {
        'title': 'Cable TV Subscription',
        'subtitle': 'DSTV, GOTV, and Startimes bouquet renewals',
        'icon': Icons.tv_rounded,
        'category': 'cable',
        'color': const Color(0xFF7C3AED),
        'tag': 'SAME-SEC RENEWAL',
      },
      {
        'title': 'Water & Utility Bills',
        'subtitle': 'Lagos Water Corp (LWC) & state utilities',
        'icon': Icons.water_drop_rounded,
        'category': 'water',
        'color': const Color(0xFF0D9488),
        'tag': 'RESIDENTIAL',
      },
      {
        'title': 'Broadband & Fiber',
        'subtitle': 'Spectranet, Smile, Swift 4G & FiberOne internet',
        'icon': Icons.router_rounded,
        'category': 'internet',
        'color': const Color(0xFFD97706),
        'tag': 'UNLIMITED',
      },
      {
        'title': 'Tolls & Transit',
        'subtitle': 'LCC Lekki Toll Gate top-up & Cowry transit card',
        'icon': Icons.directions_car_rounded,
        'category': 'toll',
        'color': const Color(0xFF4F46E5),
        'tag': 'EXPRESSWAY',
      },
      {
        'title': 'Waste Management',
        'subtitle': 'LAWMA residential & commercial sanitation',
        'icon': Icons.delete_outline_rounded,
        'category': 'waste',
        'color': AppColors.primaryLight,
        'tag': 'APPROVED',
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, size: 22, color: AppColors.accentOrange),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Payment',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Instant zero-fee utility bills, electricity, airtime & data',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: utilityServices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = utilityServices[i];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: item['category'] as String)),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'] as IconData, size: 20, color: item['color'] as Color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: (item['color'] as Color).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['tag'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w800,
                                        color: item['color'] as Color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
