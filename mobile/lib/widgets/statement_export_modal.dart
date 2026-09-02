import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/statement_pdf_service.dart';
import '../services/api_service.dart';

class StatementExportModal extends StatefulWidget {
  final UserProfile user;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>>? cardTransactions;
  final Map<String, dynamic>? cardDetails;
  final String initialCurrency;

  const StatementExportModal({
    super.key,
    required this.user,
    required this.transactions,
    this.cardTransactions,
    this.cardDetails,
    this.initialCurrency = 'NGN',
  });

  static void show(BuildContext context, {
    required UserProfile user,
    required List<Map<String, dynamic>> transactions,
    List<Map<String, dynamic>>? cardTransactions,
    Map<String, dynamic>? cardDetails,
    String initialCurrency = 'NGN',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatementExportModal(
        user: user,
        transactions: transactions,
        cardTransactions: cardTransactions,
        cardDetails: cardDetails,
        initialCurrency: initialCurrency,
      ),
    );
  }

  @override
  State<StatementExportModal> createState() => _StatementExportModalState();
}

class _StatementExportModalState extends State<StatementExportModal> {
  late String _selectedScope;
  int _selectedDays = 30;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedScope = widget.initialCurrency;
  }

  DateTime? get _fromDate {
    if (_selectedDays == 0) return null; // All time
    return DateTime.now().subtract(Duration(days: _selectedDays));
  }

  DateTime get _toDate => DateTime.now();

  Future<void> _handleDownload() async {
    setState(() => _isGenerating = true);
    try {
      if (_selectedScope == 'CARD' || _selectedScope == 'CARD_USD') {
        final cardTxs = widget.cardTransactions ?? [
          {
            'merchant': 'OpenAI API Subscription',
            'category': 'AI & SaaS Cloud',
            'amount': 20.00,
            'isCredit': false,
            'status': 'SUCCESSFUL',
            'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          },
          {
            'merchant': 'Card Wallet Top-Up (NGN -> USD)',
            'category': 'Bridgecard Inflow',
            'amount': 100.00,
            'isCredit': true,
            'status': 'SUCCESSFUL',
            'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          },
        ];
        await StatementPdfService.downloadOrPrintCardStatement(
          context,
          user: widget.user,
          cardTransactions: cardTxs,
          cardDetails: widget.cardDetails,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      } else {
        await StatementPdfService.downloadOrPrintStatement(
          context,
          user: widget.user,
          transactions: widget.transactions,
          currency: _selectedScope,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate statement: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isGenerating = true);
    try {
      if (_selectedScope == 'CARD' || _selectedScope == 'CARD_USD') {
        final cardTxs = widget.cardTransactions ?? [
          {
            'merchant': 'OpenAI API Subscription',
            'category': 'AI & SaaS Cloud',
            'amount': 20.00,
            'isCredit': false,
            'status': 'SUCCESSFUL',
            'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          },
          {
            'merchant': 'Card Wallet Top-Up (NGN -> USD)',
            'category': 'Bridgecard Inflow',
            'amount': 100.00,
            'isCredit': true,
            'status': 'SUCCESSFUL',
            'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          },
        ];
        await StatementPdfService.shareCardStatement(
          user: widget.user,
          cardTransactions: cardTxs,
          cardDetails: widget.cardDetails,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      } else {
        await StatementPdfService.shareStatement(
          user: widget.user,
          transactions: widget.transactions,
          currency: _selectedScope,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share statement: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Statement',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Export certified multi-currency / card records',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scope / Currency Selector
          Text(
            'SELECT STATEMENT TYPE / CURRENCY',
            style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                {'id': 'NGN', 'label': '🇳🇬 NGN Wallet'},
                if (ApiService.featureFlags.enableMultiCurrencyVault) ...[
                  {'id': 'USD', 'label': '🇺🇸 USD Wallet'},
                  {'id': 'GBP', 'label': '🇬🇧 GBP Wallet'},
                  {'id': 'EUR', 'label': '🇪🇺 EUR Wallet'},
                ],
                if (ApiService.featureFlags.enableVirtualCards)
                  {'id': 'CARD', 'label': '💳 Virtual Dollar Card'},
              ].map((opt) {
                final isSelected = _selectedScope == opt['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      opt['label']!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedScope = opt['id']!);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Date Range Selector
          Text(
            'SELECT TIMEFRAME',
            style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              {'days': 30, 'label': '30 Days'},
              {'days': 90, 'label': '90 Days'},
              {'days': 365, 'label': 'This Year'},
              {'days': 0, 'label': 'All Time'},
            ].map((opt) {
              final isSelected = _selectedDays == opt['days'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDays = opt['days'] as int),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.08) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        opt['label'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _handleShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(
                    'Share Statement',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _handleDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'Download PDF',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
