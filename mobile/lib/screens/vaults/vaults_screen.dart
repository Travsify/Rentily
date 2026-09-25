import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/credit_loan.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/smart_salary_splitter_modal.dart';
import '../../widgets/credit_borrow_modal.dart';
import '../../widgets/credit_repay_modal.dart';

class VaultsScreen extends StatefulWidget {
  const VaultsScreen({super.key});

  @override
  State<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends State<VaultsScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  List<Map<String, dynamic>> _userVaults = [];
  bool _isLoading = true;
  bool _isSplitterEnabled = true;
  int _splitterRentPct = 30;
  int _splitterStartDay = 24;
  int _splitterEndDay = 31;
  String _splitterDateMode = 'range';
  String _splitterTargetVault = 'Annual Rent Stash';

  UserProfile? _currentUser;
  CreditLoan? _activeCreditLoan;
  bool _isLoadingCredit = false;

  @override
  void initState() {
    super.initState();
    _loadVaults();
    _loadSplitterConfig();
    _loadCreditStatus();
  }

  Future<void> _loadCreditStatus() async {
    final u = await AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() => _currentUser = u);
    if (u != null) {
      setState(() => _isLoadingCredit = true);
      final loans = await ApiService.fetchUserCreditLoans(userId: u.id, email: u.email);
      if (mounted) {
        final active = loans.where((l) => l.status == 'active' || l.status == 'overdue').toList();
        setState(() {
          _activeCreditLoan = active.isNotEmpty ? active.first : null;
          _isLoadingCredit = false;
        });
      }
    }
  }

  void _loadSplitterConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('rentilly_salary_splitter_config');
    if (data != null) {
      try {
        final map = json.decode(data);
        if (mounted) {
          setState(() {
            _isSplitterEnabled = map['isEnabled'] ?? true;
            _splitterRentPct = ((map['rentPercentage'] as num?)?.toDouble() ?? 30.0).toInt();
            _splitterStartDay = (map['startDay'] as num?)?.toInt() ?? 24;
            _splitterEndDay = (map['endDay'] as num?)?.toInt() ?? 31;
            _splitterDateMode = map['dateWindowMode'] ?? 'range';
            _splitterTargetVault = map['targetVaultTitle'] ?? 'Annual Rent Stash';
          });
        }
      } catch (_) {}
    }
  }

  bool _isVaultLoading = false;

  void _loadVaults() async {
    final u = await AuthService.getCurrentUser();
    if (!mounted) return;
    if (u == null) {
      setState(() { _userVaults = []; _isLoading = false; });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final vaults = await ApiService.fetchUserVaults(userId: u.id, email: u.email);
      if (mounted) {
        setState(() {
          _userVaults = vaults;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Fallback to local prefs
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('rentilly_user_vaults');
      if (saved != null && mounted) {
        try {
          final List<dynamic> list = json.decode(saved);
          setState(() {
            _userVaults = list.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoading = false;
          });
          return;
        } catch (_) {}
      }
      if (mounted) setState(() { _userVaults = []; _isLoading = false; });
    }
  }

  void _saveVaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rentilly_user_vaults', json.encode(_userVaults));
  }

  void _showSaveToVaultSheet(Map<String, dynamic> vault, int index) {
    final TextEditingController amountCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text('Save to Vault', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ]),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(vault['title'] ?? 'Living Vault', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Text('AMOUNT TO SAVE (₦)', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    prefixStyle: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                    hintText: '0',
                    hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Amount will be deducted from your Rentilly wallet balance.', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.'), backgroundColor: AppColors.error));
                        return;
                      }
                      setSheet(() => isSaving = true);
                      final u = await AuthService.getCurrentUser();
                      if (u == null) { setSheet(() => isSaving = false); return; }
                      final vaultId = vault['id']?.toString() ?? '';
                      final res = await ApiService.depositToVault(userId: u.id, email: u.email, vaultId: vaultId, amount: amt);
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      if (res['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('₦${_currencyFormat.format(amt)} saved to "${vault['title']}"!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11)),
                          backgroundColor: AppColors.primary,
                        ));
                        _loadVaults();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(res['error'] ?? 'Deposit failed. Check your wallet balance.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                          backgroundColor: AppColors.error,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save to Vault', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }


  void _showBreakVaultModal(Map<String, dynamic> vault, int index) {
    final double saved = ((vault['saved'] ?? vault['savedAmount'] ?? 0.0) as num).toDouble();
    if (saved <= 0) return;

    final double accruedYield = ((vault['accruedYield'] ?? (saved * 0.05 * (30.0 / 365.0))) as num).roundToDouble();
    final double breakFee = (saved * 0.01).roundToDouble();
    final double netPayout = saved - breakFee;
    final int daysRemaining = ((vault['daysRemaining'] ?? 365) as num).toInt();
    final bool isMatured = vault['isMatured'] == true || daysRemaining <= 0;

    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20,
              ),
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
                              color: isMatured ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isMatured ? Icons.celebration_rounded : Icons.warning_amber_rounded,
                              color: isMatured ? AppColors.primary : const Color(0xFFEF4444),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isMatured ? 'Matured Vault Payout 🎉' : 'Break Vault Early ⚠️',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMatured
                      ? 'Congratulations! Your 1-year disciplined goal has reached full maturity.'
                      : 'You are breaking this vault before the 1-year tenure ($daysRemaining days remaining). To maintain savings discipline, breaking early forfeits your interest and incurs a 1% early break fee.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // Financial Breakdown Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Principal Saved:', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary)),
                            Text('₦${_currencyFormat.format(saved)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Accrued Yield (5% p.a.):', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary)),
                            Text(
                              isMatured ? '+₦${_currencyFormat.format(accruedYield)}' : '-₦${_currencyFormat.format(accruedYield)} (Forfeited)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMatured ? const Color(0xFF059669) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Early Liquidation Fee (1%):', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary)),
                            Text(
                              isMatured ? '₦0 (Matured)' : '-₦${_currencyFormat.format(breakFee)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMatured ? AppColors.textSecondary : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Net Payout to Wallet:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            Text(
                              '₦${_currencyFormat.format(isMatured ? saved + accruedYield : netPayout)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      // Keep Saving Button (Recommended)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Keep Saving', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Confirm Break Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing ? null : () async {
                            setModal(() => isProcessing = true);
                            final u = await AuthService.getCurrentUser();
                            if (u == null) return;
                            final vaultId = vault['id']?.toString() ?? '';
                            final res = await ApiService.withdrawFromVault(
                              userId: u.id,
                              email: u.email,
                              vaultId: vaultId,
                              amount: saved,
                            );
                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                            if (res['success'] == true) {
                              _loadVaults();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                  isMatured
                                    ? 'Matured vault liquidated! ₦${_currencyFormat.format(saved + accruedYield)} credited to your wallet.'
                                    : 'Vault broken early. ₦${_currencyFormat.format(netPayout)} credited to wallet (1% fee of ₦${_currencyFormat.format(breakFee)} deducted; interest forfeited).',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                backgroundColor: isMatured ? AppColors.primary : const Color(0xFFEF4444),
                              ));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(res['error'] ?? 'Could not break vault.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                                backgroundColor: AppColors.error,
                              ));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMatured ? AppColors.primary : const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isProcessing
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                isMatured ? 'Collect Payout' : 'Break (1% Fee)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRemoveVault(Map<String, dynamic> vault, int index) {
    final saved = ((vault['saved'] ?? vault['savedAmount'] ?? 0.0) as num).toDouble();

    // RULE: Cannot delete vault with active running funds!
    if (saved > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.lock_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('Active Funds Running 🔒', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15))),
          ]),
          content: Text(
            'Cannot delete "${vault['title']}" while it has active running savings of ₦${_currencyFormat.format(saved)}.\n\nTo protect your 1-year financial discipline, only empty vaults (₦0 balance) can be deleted. Please withdraw funds first or hold until the 1-year maturity.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Understood', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
      return;
    }

    // Only empty vaults can be deleted
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Delete Empty Vault?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15))),
        ]),
        content: Text(
          'Are you sure you want to delete the empty vault "${vault['title']}"? Since it has ₦0 running balance, it will be permanently deleted.',
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final u = await AuthService.getCurrentUser();
              if (u == null) return;
              final vaultId = vault['id']?.toString() ?? '';
              final res = await ApiService.deleteVault(userId: u.id, email: u.email, vaultId: vaultId);
              if (!mounted) return;
              if (res['success'] == true) {
                setState(() => _userVaults.removeAt(index));
                _saveVaults();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Empty vault "${vault['title']}" removed successfully.', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11)),
                  backgroundColor: AppColors.primary,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res['error'] ?? 'Could not remove vault.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete Empty Vault', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showCreateVaultDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController targetController = TextEditingController();
    String selectedCategory = 'Personal Goal Stash';

    final suggestions = [
      {'name': 'Annual Rent Renewal', 'category': 'Rent Savings', 'icon': '🏠'},
      {'name': 'Emergency Living Buffer', 'category': 'Emergency', 'icon': '🚨'},
      {'name': 'Children School Fees', 'category': 'Education', 'icon': '🎓'},
      {'name': 'Home Furniture & Setup', 'category': 'Lifestyle', 'icon': '🛋️'},
      {'name': 'Solar & Power Inverter', 'category': 'Utility & Energy', 'icon': '☀️'},
      {'name': 'Business Seed Capital', 'category': 'Business', 'icon': '🚀'},
      {'name': 'Vacation & Travel Fund', 'category': 'Leisure', 'icon': '🌴'},
      {'name': 'Caution Deposit & Service', 'category': 'Caution Escrow', 'icon': '🛡️'},
      {'name': 'New Car & Mobility Fund', 'category': 'Asset Acquisition', 'icon': '🚗'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.savings_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Create Living Vault 🎯',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Save towards any personal target, rent, project, or emergency fund with a disciplined 1-year tenure.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    // 1-Year Duration & Yield Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFF059669).withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.timer_outlined, color: Color(0xFF059669), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('SAVINGS TENURE:', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF065F46), letterSpacing: 0.5)),
                                    const SizedBox(width: 4),
                                    Text('1 YEAR (365 DAYS)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF047857))),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Earns 5% annual yield. Funds remain safely running for 1 year to maximize financial discipline.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF065F46)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('VAULT NAME / SAVINGS PURPOSE', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Enter any name of your choice (e.g. My New Home)',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('OR CHOOSE FROM SUGGESTIONS', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                    const SizedBox(height: 8),

                    // Suggestion Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestions.map((sug) {
                        final isSelected = titleController.text == sug['name'];
                        return GestureDetector(
                          onTap: () => setModalState(() {
                            titleController.text = sug['name']!;
                            selectedCategory = sug['category']!;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(sug['icon']!, style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Text(
                                  sug['name']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    Text('TARGET GOAL AMOUNT (₦)', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: '₦ ',
                        prefixStyle: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold),
                        hintText: '1,500,000',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final t = titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'My Living Vault';
                          final amt = double.tryParse(targetController.text.replaceAll(',', '').trim()) ?? 0;
                          if (amt > 0) {
                            final u = await AuthService.getCurrentUser();
                            if (u != null) {
                              final res = await ApiService.createVault(
                                userId: u.id,
                                email: u.email,
                                title: t,
                                category: selectedCategory,
                                targetAmount: amt,
                              );
                              if (!mounted) return;
                              if (res['success'] == true) {
                                Navigator.of(ctx).pop();
                                _loadVaults();
                                NotificationService.addNotification(
                                  title: 'Living Vault Created: $t 🎯',
                                  message: '1-Year goal amount of ₦${_currencyFormat.format(amt)} set for $t (5% Annual Yield).',
                                  category: 'vault',
                                  metadata: {
                                    'vault': t,
                                    'target': '₦${_currencyFormat.format(amt)}',
                                    'duration': '1 Year',
                                  },
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Living Vault "$t" (1-Year Duration) created successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res['error'] ?? 'Failed to create vault.'), backgroundColor: AppColors.error),
                                );
                              }
                            } else {
                              setState(() {
                                _userVaults.add({
                                  'title': t,
                                  'category': selectedCategory,
                                  'target': amt,
                                  'saved': 0.0,
                                  'durationLabel': '1 Year',
                                  'yieldRate': '5% p.a.',
                                  'yieldNote': '5% Annual Yield',
                                });
                              });
                              _saveVaults();
                              Navigator.of(ctx).pop();
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid target goal amount.'), backgroundColor: AppColors.error),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Create 1-Year Living Vault', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalVaultSavings = _userVaults.fold(0.0, (sum, v) => sum + ((v['saved'] ?? 0.0) as num));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Living Vaults (Target Savings)',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'TOTAL LOCKED IN LIVING VAULTS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '5% ANNUAL YIELD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                      'Disciplined living reserves. Caution deposit protection is strictly interest-free (0%); living vaults earn 5% annual yield to beat inflation.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SAVINGS-BACKED CREDIT ADVANCE CARD (80% LTV, 2.5%/mo)
              if (_activeCreditLoan != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _activeCreditLoan!.isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB), size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Active Credit Advance',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _activeCreditLoan!.isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _activeCreditLoan!.isOverdue ? 'OVERDUE' : '${_activeCreditLoan!.daysRemaining} DAYS LEFT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _activeCreditLoan!.isOverdue ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('OUTSTANDING DUE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.6)),
                              const SizedBox(height: 2),
                              Text(
                                '₦${_currencyFormat.format(_activeCreditLoan!.outstandingBalance)}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          Text(
                            'Due: ${DateFormat('dd MMM yyyy').format(_activeCreditLoan!.dueDate)}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _activeCreditLoan!.totalRepaymentDue > 0
                              ? (_activeCreditLoan!.amountRepaid / _activeCreditLoan!.totalRepaymentDue).clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₦${_currencyFormat.format(_activeCreditLoan!.collateralLocked)} locked in savings',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                          ),
                          Text(
                            '${_activeCreditLoan!.tenureDays}d @ 2.5%/mo',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_currentUser != null) {
                              CreditRepayModal.show(
                                context,
                                user: _currentUser!,
                                loan: _activeCreditLoan!,
                                onRepaid: () {
                                  _loadCreditStatus();
                                  _loadVaults();
                                },
                              );
                            }
                          },
                          icon: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.white),
                          label: Text('Repay from Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Savings-Backed Credit Advance',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '80% LTV • 2.5%/MO',
                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF38BDF8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Borrow up to 80% (up to ₦${_currencyFormat.format(totalVaultSavings * 0.80)}) of your locked savings instantly into your Rentilly Wallet for 30, 60, or 90 days. Your full savings continues earning 5% p.a. yield!',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8), height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_currentUser != null) {
                              CreditBorrowModal.show(
                                context,
                                user: _currentUser!,
                                totalSavingsBalance: totalVaultSavings,
                                onCreditDisbursed: () {
                                  _loadCreditStatus();
                                  _loadVaults();
                                },
                              );
                            }
                          },
                          icon: const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF0F172A)),
                          label: Text(
                            totalVaultSavings >= 20000
                                ? 'Borrow Up To ₦${_currencyFormat.format(totalVaultSavings * 0.80)} ⚡'
                                : 'Save ₦20,000+ to Unlock 80% Advance',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Smart Salary Splitter Interactive Hub Card
              InkWell(
                onTap: () {
                  SmartSalarySplitterModal.show(
                    context,
                    userVaults: _userVaults,
                    onConfigSaved: _loadSplitterConfig,
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _isSplitterEnabled ? const Color(0xFFBBF7D0) : AppColors.borderDark,
                      width: _isSplitterEnabled ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isSplitterEnabled ? const Color(0xFF16A34A).withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isSplitterEnabled ? const Color(0xFF16A34A).withValues(alpha: 0.12) : AppColors.accentOrange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_fix_high_rounded,
                          size: 20,
                          color: _isSplitterEnabled ? const Color(0xFF16A34A) : AppColors.accentOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Smart Salary Splitter',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isSplitterEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _isSplitterEnabled ? 'ACTIVE • ${_splitterRentPct}%' : 'OFF',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: _isSplitterEnabled ? const Color(0xFF15803D) : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isSplitterEnabled
                                  ? (_splitterDateMode == 'range'
                                      ? 'Sweeps $_splitterRentPct% of deposits between Day $_splitterStartDay - Day $_splitterEndDay to "$_splitterTargetVault".'
                                      : 'Sweeps $_splitterRentPct% of every incoming deposit to "$_splitterTargetVault".')
                                  : 'Tap to configure custom split percentage & payday date window.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: _isSplitterEnabled ? const Color(0xFF15803D) : AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Active Living Vaults Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACTIVE LIVING VAULTS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showCreateVaultDialog,
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      'Add New Vault',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Blank state until user adds a vault
              if (_userVaults.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.savings_outlined, size: 36, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No Active Living Vaults',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You currently have no active living vaults. Tap below to create your customized annual rent stash, utility pocket, or caution deposit vault.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _showCreateVaultDialog,
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: Text('Add New Vault', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userVaults.length,
                  itemBuilder: (context, index) {
                    final v = _userVaults[index];
                    final double saved = ((v['saved'] ?? 0.0) as num).toDouble();
                    final double target = ((v['target'] ?? 0.0) as num).toDouble();
                    final double progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
                    final yieldStr = v['yieldRate'] ?? (v['yieldNote'] ?? '5% p.a.');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.savings_rounded, size: 18, color: AppColors.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v['title'] ?? 'Living Vault',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (v['category'] != null)
                                      Text(
                                        v['category'],
                                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 11, color: Color(0xFF059669)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '1 Year • 5% p.a.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₦${_currencyFormat.format(saved)} saved',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  if (saved > 0)
                                    Text(
                                      '+₦${_currencyFormat.format(((v['accruedYield'] ?? (saved * 0.05 * (30.0 / 365.0))) as num).roundToDouble())} accrued',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Target: ₦${_currencyFormat.format(target)}',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                                  if (saved > 0)
                                    Text(
                                      '${v['daysRemaining'] ?? 365} days to maturity',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showSaveToVaultSheet(v, index),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_circle_rounded, color: Colors.white, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Save to Vault',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => saved > 0 ? _showBreakVaultModal(v, index) : _confirmRemoveVault(v, index),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: saved > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: saved > 0 ? const Color(0xFFFDE68A) : const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        saved > 0 ? Icons.broken_image_outlined : Icons.delete_outline_rounded,
                                        color: saved > 0 ? const Color(0xFFD97706) : AppColors.error,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        saved > 0 ? 'Break Vault' : 'Remove',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: saved > 0 ? const Color(0xFFB45309) : AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
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
