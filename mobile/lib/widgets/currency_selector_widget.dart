import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class CurrencySelectorWidget extends StatelessWidget {
  final String selectedCurrency;
  final Function(String) onCurrencySelected;

  const CurrencySelectorWidget({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencySelected,
  });

  static const List<Map<String, String>> currencies = [
    {'code': 'NGN', 'symbol': '₦', 'flag': '🇳🇬', 'name': 'Naira'},
    {'code': 'USD', 'symbol': '\$', 'flag': '🇺🇸', 'name': 'Dollar'},
    {'code': 'GBP', 'symbol': '£', 'flag': '🇬🇧', 'name': 'Pound'},
    {'code': 'EUR', 'symbol': '€', 'flag': '🇪🇺', 'name': 'Euro'},
  ];

  @override
  Widget build(BuildContext context) {
    // When multi-currency is toggled off by Admin, foreign accounts (USD, GBP, EUR) disappear,
    // leaving only Nigerian Naira (NGN). Since only 1 currency remains, hide the switcher.
    if (!ApiService.featureFlags.enableMultiCurrencyVault) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: currencies.map((curr) {
          final isSelected = selectedCurrency == curr['code'];
          return Expanded(
            child: GestureDetector(
              onTap: () => onCurrencySelected(curr['code']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      curr['flag']!,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      curr['code']!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
