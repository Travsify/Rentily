import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/payment_security_service.dart';

class WithdrawalModal extends StatefulWidget {
  final UserProfile user;
  final Function(double newBalance) onWithdrawalSuccess;

  const WithdrawalModal({super.key, required this.user, required this.onWithdrawalSuccess});

  static void show(BuildContext context, {required UserProfile user, required Function(double) onWithdrawalSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WithdrawalModal(user: user, onWithdrawalSuccess: onWithdrawalSuccess),
    );
  }

  @override
  State<WithdrawalModal> createState() => _WithdrawalModalState();
}

class _WithdrawalModalState extends State<WithdrawalModal> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedBankCode = '058'; // Default GTBank
  String _selectedBankName = 'Guaranty Trust Bank';
  String? _resolvedAccountName;
  bool _isResolving = false;
  bool _isProcessing = false;
  bool _isLoadingBanks = false;
  String? _errorMessage;

  List<Map<String, String>> _banks = [
    {'name': 'Guaranty Trust Bank (GTBank)', 'code': '058'},
    {'name': 'Zenith Bank', 'code': '057'},
    {'name': 'Access Bank', 'code': '044'},
    {'name': 'First Bank of Nigeria', 'code': '011'},
    {'name': 'United Bank for Africa (UBA)', 'code': '033'},
    {'name': 'Kuda Microfinance Bank', 'code': '50211'},
    {'name': 'OPay Digital Services (OPay)', 'code': '999992'},
    {'name': 'PalmPay', 'code': '999991'},
    {'name': 'Wema Bank', 'code': '035'},
    {'name': 'Providus Bank', 'code': '101'},
    {'name': 'Fidelity Bank', 'code': '070'},
    {'name': 'Stanbic IBTC Bank', 'code': '221'},
    {'name': 'Moniepoint Microfinance Bank', 'code': '50515'},
    {'name': 'Sterling Bank', 'code': '232'},
    {'name': 'Union Bank of Nigeria', 'code': '032'},
    {'name': 'Ecobank Nigeria', 'code': '050'},
    {'name': 'FCMB (First City Monument Bank)', 'code': '214'},
    {'name': 'Polaris Bank', 'code': '076'},
    {'name': 'VFD Microfinance Bank', 'code': '566'},
    {'name': 'Jaiz Bank', 'code': '301'},
    {'name': 'TAJ Bank', 'code': '302'},
    {'name': 'Standard Chartered Bank', 'code': '068'},
    {'name': 'Citibank Nigeria', 'code': '023'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPaystackBanks();
  }

  void _fetchPaystackBanks() async {
    setState(() => _isLoadingBanks = true);
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/payments/paystack-banks');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['status'] == true && data['data'] is List) {
        final List rawList = data['data'];
        final List<Map<String, String>> formatted = [];
        for (var b in rawList) {
          if (b['name'] != null && b['code'] != null) {
            formatted.add({
              'name': b['name'].toString(),
              'code': b['code'].toString(),
            });
          }
        }
        if (formatted.isNotEmpty) {
          setState(() {
            _banks = formatted;
            _isLoadingBanks = false;
          });
          return;
        }
      }
    } catch (_) {}

    setState(() => _isLoadingBanks = false);
  }

  void _openBankSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredBanks = _banks.where((b) {
              final q = searchQuery.toLowerCase();
              return b['name']!.toLowerCase().contains(q) || b['code']!.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Destination Bank (${_banks.length} Banks)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search Nigerian bank (e.g. GTBank, Kuda, PalmPay, Zenith)...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                    ),
                    onChanged: (val) {
                      setSheetState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredBanks.isEmpty
                        ? Center(
                            child: Text(
                              'No banks matching "$searchQuery"',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredBanks.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderDark),
                            itemBuilder: (context, idx) {
                              final bank = filteredBanks[idx];
                              final isSelected = bank['code'] == _selectedBankCode;
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.account_balance_rounded, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                                ),
                                title: Text(
                                  bank['name']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  'Bank Code: ${bank['code']}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                ),
                                trailing: isSelected ? const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedBankCode = bank['code']!;
                                    _selectedBankName = bank['name']!;
                                  });
                                  Navigator.of(sheetCtx).pop();
                                  if (_accountController.text.trim().length == 10) {
                                    _resolveAccount();
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _resolveAccount() async {
    final accNum = _accountController.text.trim();
    if (accNum.length != 10) return;

    setState(() {
      _isResolving = true;
      _resolvedAccountName = null;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/payments/resolve-account?accountNumber=$accNum&bankCode=$_selectedBankCode');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['status'] == true && data['data'] != null) {
        final resolved = data['data']['accountName'] ?? data['data']['account_name'];
        if (resolved != null && resolved.toString().isNotEmpty) {
          setState(() {
            _resolvedAccountName = resolved.toString();
            _isResolving = false;
          });
          return;
        }
      }
    } catch (_) {}

    setState(() {
      _resolvedAccountName = widget.user.fullName;
      _isResolving = false;
    });
  }

  void _executeWithdrawal() async {
    final amountText = _amountController.text.replaceAll(',', '').trim();
    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid withdrawal amount.');
      return;
    }

    if (amount > widget.user.walletBalance) {
      setState(() => _errorMessage = 'Amount exceeds available balance (₦${NumberFormat('#,###.00').format(widget.user.walletBalance)}).');
      return;
    }

    final accNum = _accountController.text.trim();
    if (accNum.length != 10) {
      setState(() => _errorMessage = 'Please enter a 10-digit Nigerian account number.');
      return;
    }

    // Dual Security: Biometric (FaceID / Fingerprint) OR 6-Digit Payment Code
    final authorized = await PaymentSecurityService.authorizeTransaction(
      context,
      title: 'Withdrawal to $_selectedBankName ($accNum)',
      amount: amount,
      recipient: _resolvedAccountName ?? widget.user.fullName,
    );
    if (!authorized) {
      setState(() => _errorMessage = 'Payment authorization cancelled or incorrect.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/payments/withdraw-paystack');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.user.id,
          'email': widget.user.email,
          'accountNumber': accNum,
          'bankCode': _selectedBankCode,
          'accountName': _resolvedAccountName ?? widget.user.fullName,
          'amount': amount,
          'reason': 'Rentilly Living Escrow Payout'
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(res.body);

      setState(() => _isProcessing = false);

      if (res.statusCode == 200 && data['status'] == true) {
        final newBal = (widget.user.walletBalance - amount).clamp(0.0, double.infinity);
        final updatedUser = widget.user.copyWith(walletBalance: newBal);
        await AuthService.updateUser(updatedUser);
        widget.onWithdrawalSuccess(newBal);

        NotificationService.addNotification(
          title: 'Bank Withdrawal Dispatched 💳',
          message: 'Payout of ₦${NumberFormat('#,###.00').format(amount)} to $_selectedBankName ($accNum - ${_resolvedAccountName ?? widget.user.fullName}) was processed.',
          category: 'transaction',
          metadata: {
            'amount': '₦${NumberFormat('#,###.00').format(amount)}',
            'bank': _selectedBankName,
            'account': accNum,
          },
        );

        if (!mounted) return;
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Withdrawal of ₦${NumberFormat('#,###.00').format(amount)} initiated successfully!',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? data['message'] ?? 'Withdrawal could not be processed. Please check your bank details.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Network connection timeout. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                Row(
                  children: [
                    const Icon(Icons.north_east_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Withdraw Funds',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Instant direct payout to any of Nigeria\'s 180+ verified commercial & microfinance banks.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(_errorMessage!, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
            ],

            // 1. Select Bank (Searchable 180+ Nigerian Banks)
            Text(
              '1. SELECT DESTINATION BANK (${_banks.length} AVAILABLE)',
              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _openBankSearchSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedBankName,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    if (_isLoadingBanks)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    else
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Account Number Input
            Text('2. ENTER 10-DIGIT ACCOUNT NUMBER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                hintText: '0123456789',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                suffixIcon: _isResolving
                    ? const SizedBox(width: 16, height: 16, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              ),
              onChanged: (val) {
                if (val.length == 10) {
                  _resolveAccount();
                } else {
                  setState(() => _resolvedAccountName = null);
                }
              },
            ),

            if (_resolvedAccountName != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primaryLight),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Account Name: $_resolvedAccountName',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // 3. Amount Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('3. WITHDRAWAL AMOUNT (₦)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                Text(
                  'Avail: ₦${NumberFormat('#,###.00').format(widget.user.walletBalance)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                hintText: '50,000',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              ),
            ),
            const SizedBox(height: 18),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _executeWithdrawal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Authorize & Withdraw Funds', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
