import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/beneficiary_service.dart';
import '../services/notification_service.dart';
import '../services/payment_security_service.dart';
import '../services/security_telemetry_service.dart';
import '../screens/shared/qr_scanner_screen.dart';

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
  final TextEditingController _cryptoAddressController = TextEditingController();
  final TextEditingController _beneficiarySearchController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  String _withdrawalMode = 'NGN'; // 'NGN' or 'USDT'
  String _usdtDestinationType = 'BANK'; // 'BANK' (Convert to NGN) or 'CRYPTO' (Send on-chain)
  double _fxUsdtToNgn = 1400.0;
  double _usdtWithdrawalFeePct = 2.0; // Dynamic from Admin Fee Settings (default 2%)

  String _selectedBankCode = '058'; // Default GTBank
  String _selectedBankName = 'Guaranty Trust Bank';
  String? _resolvedAccountName;
  String? _accountResolutionError;
  bool _isResolving = false;
  bool _isProcessing = false;
  bool _isLoadingBanks = false;
  String? _errorMessage;

  // Beneficiary Management
  List<Map<String, dynamic>> _savedBeneficiaries = [];
  List<Map<String, dynamic>> _filteredBeneficiaries = [];
  bool _isLoadingBeneficiaries = false;
  Map<String, dynamic>? _selectedBeneficiary;

  double get _enteredAmount {
    return double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
  }

  double get _usdtFeeAmount {
    return (_enteredAmount * _usdtWithdrawalFeePct) / 100.0;
  }

  double get _usdtNetPayoutAmount {
    return (_enteredAmount - _usdtFeeAmount).clamp(0.0, double.infinity);
  }

  double get _computedNgnAmount {
    if (_withdrawalMode == 'NGN') {
      return _enteredAmount;
    } else {
      return _enteredAmount * _fxUsdtToNgn;
    }
  }

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
    _fetchSpreadRates();
    _fetchPlatformFees();
    _loadBeneficiaries();
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _beneficiarySearchController.dispose();
    _accountController.dispose();
    _amountController.dispose();
    _cryptoAddressController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  void _loadBeneficiaries() async {
    setState(() => _isLoadingBeneficiaries = true);
    final list = await BeneficiaryService.getBeneficiaries(userEmail: widget.user.email);
    if (mounted) {
      setState(() {
        _savedBeneficiaries = list;
        _filteredBeneficiaries = list;
        _isLoadingBeneficiaries = false;
      });
    }
  }

  void _onSearchBeneficiaries(String query) {
    setState(() {
      _filteredBeneficiaries = BeneficiaryService.search(query, _savedBeneficiaries);
    });
  }

  void _selectBeneficiary(Map<String, dynamic> b) {
    final bankCode = b['bankCode']?.toString() ?? '';
    final bankName = b['bankName']?.toString() ?? '';
    final accNum = b['accountNumber']?.toString() ?? '';
    final accName = b['accountName']?.toString() ?? '';

    setState(() {
      _selectedBeneficiary = b;
      if (b['type'] == 'crypto' && b['cryptoAddress'] != null) {
        _withdrawalMode = 'USDT';
        _usdtDestinationType = 'CRYPTO';
        _cryptoAddressController.text = b['cryptoAddress'].toString();
      } else {
        _withdrawalMode = 'NGN';
        final matchedBank = _banks.firstWhere(
          (bk) => (bankCode.isNotEmpty && bk['code'] == bankCode) || 
                  (bankName.isNotEmpty && bk['name']!.toLowerCase().contains(bankName.toLowerCase())),
          orElse: () => {
            'name': bankName.isNotEmpty ? bankName : 'Guaranty Trust Bank (GTBank)',
            'code': bankCode.isNotEmpty ? bankCode : '058'
          },
        );
        _selectedBankCode = matchedBank['code'] ?? (bankCode.isNotEmpty ? bankCode : '058');
        _selectedBankName = matchedBank['name'] ?? (bankName.isNotEmpty ? bankName : 'Guaranty Trust Bank (GTBank)');
        _accountController.text = accNum;
        _resolvedAccountName = accName.isNotEmpty ? accName : null;
        _accountResolutionError = null;
      }
      _errorMessage = null;
    });

    // Auto-focus on the amount field so the user can immediately type how much to send
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _amountFocusNode.requestFocus();
      }
    });
  }

  void _openBeneficiarySearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final results = BeneficiaryService.search(query, _savedBeneficiaries);

            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Past Recipients (${_savedBeneficiaries.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by recipient name, bank, or account...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () => setSheetState(() => query = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    onChanged: (val) => setSheetState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_search_rounded, size: 40, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  query.isEmpty
                                      ? 'No past recipients yet.\nRecipients will be saved here automatically whenever you send money.'
                                      : 'No recipients matching "$query"',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderDark),
                            itemBuilder: (context, idx) {
                              final b = results[idx];
                              final name = (b['accountName'] ?? 'Unknown Recipient').toString();
                              final bank = (b['bankName'] ?? 'Bank').toString();
                              final acc = (b['accountNumber'] ?? '').toString();
                              final initials = name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join('').toUpperCase();

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    initials.isNotEmpty ? initials : 'RP',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                subtitle: Text(
                                  '$bank • $acc',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textMuted),
                                  onPressed: () async {
                                    await BeneficiaryService.deleteBeneficiary(
                                      userEmail: widget.user.email,
                                      accountNumber: acc,
                                      bankCode: b['bankCode'] ?? '',
                                    );
                                    _loadBeneficiaries();
                                    setSheetState(() {});
                                  },
                                ),
                                onTap: () {
                                  Navigator.of(sheetCtx).pop();
                                  _selectBeneficiary(b);
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

  void _fetchPlatformFees() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/config/fees');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['fees'] != null && data['fees']['usdtWithdrawalFeePct'] != null) {
          if (mounted) {
            setState(() {
              _usdtWithdrawalFeePct = (data['fees']['usdtWithdrawalFeePct'] as num).toDouble();
            });
          }
        }
      }
    } catch (_) {}
  }

  void _fetchSpreadRates() async {
    final rates = await ApiService.fetchSpreadRates();
    if (mounted) {
      setState(() {
        _fxUsdtToNgn = (rates['buyRate'] as num?)?.toDouble() ?? 1400.0;
      });
    }
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
    if (accNum.length != 10) {
      setState(() {
        _resolvedAccountName = null;
        _accountResolutionError = null;
      });
      return;
    }

    setState(() {
      _isResolving = true;
      _resolvedAccountName = null;
      _accountResolutionError = null;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/payments/resolve-account?accountNumber=$accNum&bankCode=$_selectedBankCode');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['status'] == true && data['data'] != null) {
        final resolved = data['data']['accountName'] ?? data['data']['account_name'];
        if (resolved != null && resolved.toString().trim().isNotEmpty) {
          setState(() {
            _resolvedAccountName = resolved.toString().trim();
            _accountResolutionError = null;
            _isResolving = false;
          });
          return;
        }
      }

      // Explicit verification failure: NEVER fallback to user's own name
      final serverMsg = data['message'] ?? 'Could not resolve account details. Please check the account number and bank.';
      setState(() {
        _resolvedAccountName = null;
        _accountResolutionError = serverMsg.toString();
        _isResolving = false;
      });
    } catch (_) {
      setState(() {
        _resolvedAccountName = null;
        _accountResolutionError = 'Unable to verify account with bank. Please verify account number and selected bank.';
        _isResolving = false;
      });
    }
  }

  void _executeWithdrawal() async {
    final currentUser = await AuthService.getCurrentUser() ?? widget.user;
    final currentBal = currentUser.walletBalance;
    final availUsdt = currentUser.usdtBalance;

    final double entered = _enteredAmount;
    if (entered <= 0) {
      setState(() => _errorMessage = 'Please enter a valid withdrawal amount.');
      return;
    }

    if (_withdrawalMode == 'USDT') {
      if (entered > availUsdt) {
        setState(() => _errorMessage = 'Amount exceeds available USDT balance (\$${availUsdt.toStringAsFixed(2)} USDT).');
        return;
      }
    } else {
      final double totalNgnRequired = _computedNgnAmount;
      if (totalNgnRequired > currentBal) {
        setState(() => _errorMessage = 'Insufficient funds. Available balance: ₦${NumberFormat('#,###.00').format(currentBal)}');
        return;
      }
    }

    // Branch A: USDT On-chain Transfer to TRC20 Address
    if (_withdrawalMode == 'USDT' && _usdtDestinationType == 'CRYPTO') {
      final cryptoAddr = _cryptoAddressController.text.trim();
      if (cryptoAddr.length < 30 || !cryptoAddr.startsWith('T')) {
        setState(() => _errorMessage = 'Please enter a valid TRON TRC20 wallet address (starts with T).');
        return;
      }

      if (!mounted) return;
      final authorized = await PaymentSecurityService.authorizeTransaction(
        context,
        title: 'Transfer $entered USDT (TRC20)',
        amount: entered,
        recipient: '${cryptoAddr.substring(0, 6)}...${cryptoAddr.substring(cryptoAddr.length - 6)}',
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
        final url = Uri.parse('${AppConstants.apiBaseUrl}/payments/withdraw-crypto');
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': currentUser.id,
            'email': currentUser.email,
            'cryptoAddress': cryptoAddr,
            'chain': 'TRC20',
            'amountUsdt': entered,
            'feeUsdt': _usdtFeeAmount,
            'netPayoutUsdt': _usdtNetPayoutAmount,
          }),
        ).timeout(const Duration(seconds: 30));

        final data = json.decode(res.body);
        setState(() => _isProcessing = false);

        if (res.statusCode == 200 && data['status'] == true) {
          final serverNewBal = (data['newBalance'] != null)
              ? (data['newBalance'] as num).toDouble()
              : (availUsdt - entered).clamp(0.0, double.infinity);
          widget.onWithdrawalSuccess(serverNewBal);

          // Save crypto beneficiary
          BeneficiaryService.saveBeneficiary(
            userEmail: currentUser.email,
            accountName: 'TRC20 Wallet (${cryptoAddr.substring(0, 6)}...)',
            accountNumber: cryptoAddr,
            bankName: 'TRON TRC20',
            bankCode: 'TRON',
            type: 'crypto',
            cryptoAddress: cryptoAddr,
          );

          NotificationService.addNotification(
            title: 'USDT Withdrawal Dispatched 🚀',
            message: 'Transfer of $entered USDT to ${cryptoAddr.substring(0, 8)}... has been submitted to the blockchain.',
            category: 'transaction',
            metadata: {
              'amount': '\$$entered USDT',
              'address': cryptoAddr,
              'network': 'TRON TRC20',
            },
          );

          if (!mounted) return;
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Withdrawal of $entered USDT initiated successfully!',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        } else {
          setState(() {
            _errorMessage = data['error'] ?? data['message'] ?? 'Crypto withdrawal could not be processed.';
          });
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Network timeout. Please check your connection and try again.';
        });
      }
      return;
    }

    // Branch B: Bank Payout (either direct NGN or USDT-converted)
    final accNum = _accountController.text.trim();
    if (accNum.length != 10) {
      setState(() => _errorMessage = 'Please enter a 10-digit Nigerian account number.');
      return;
    }

    if (_isResolving) {
      setState(() => _errorMessage = 'Please wait for account verification to complete.');
      return;
    }

    if (_resolvedAccountName == null || _resolvedAccountName!.trim().isEmpty) {
      setState(() => _errorMessage = 'Cannot proceed: Recipient account is unverified. Please check account details.');
      return;
    }

    final confirmedRecipient = _resolvedAccountName!.trim();
    final double totalNgnRequired = _computedNgnAmount;

    if (!mounted) return;
    final authorized = await PaymentSecurityService.authorizeTransaction(
      context,
      title: _withdrawalMode == 'USDT' 
          ? 'Payout $entered USDT (₦${NumberFormat('#,###.00').format(totalNgnRequired)})'
          : 'Withdrawal to $_selectedBankName ($accNum)',
      amount: totalNgnRequired,
      recipient: confirmedRecipient,
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
          'userId': currentUser.id,
          'email': currentUser.email,
          'accountNumber': accNum,
          'bankCode': _selectedBankCode,
          'bankName': _selectedBankName,
          'accountName': confirmedRecipient,
          'senderName': currentUser.fullName.isNotEmpty ? currentUser.fullName : (currentUser.businessName ?? 'Rentilly User'),
          'amount': totalNgnRequired,
          'sourceCurrency': _withdrawalMode,
          'usdtAmount': _withdrawalMode == 'USDT' ? entered : null,
          'fxRate': _withdrawalMode == 'USDT' ? _fxUsdtToNgn : null,
          'reason': _narrationController.text.trim().isNotEmpty
              ? _narrationController.text.trim()
              : (_withdrawalMode == 'USDT' 
                  ? 'USDT Payout Converted to NGN' 
                  : 'Rentilly Payout'),
          'narration': _narrationController.text.trim().isNotEmpty
              ? _narrationController.text.trim()
              : null,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(res.body);
      setState(() => _isProcessing = false);

      if (res.statusCode == 200 && data['status'] == true) {
        final serverNewBal = (data['newBalance'] != null)
            ? (data['newBalance'] as num).toDouble()
            : (currentBal - totalNgnRequired).clamp(0.0, double.infinity);
        widget.onWithdrawalSuccess(serverNewBal);

        // Save beneficiary for future instant 1-tap searches & auto-fill
        BeneficiaryService.saveBeneficiary(
          userEmail: currentUser.email,
          accountName: confirmedRecipient,
          accountNumber: accNum,
          bankName: _selectedBankName,
          bankCode: _selectedBankCode,
          type: 'bank',
        );

        NotificationService.addNotification(
          title: 'Bank Withdrawal Dispatched 💳',
          message: 'Payout of ₦${NumberFormat('#,###.00').format(totalNgnRequired)} to $_selectedBankName ($accNum - $confirmedRecipient) was processed.',
          category: 'transaction',
          metadata: {
            'amount': '₦${NumberFormat('#,###.00').format(totalNgnRequired)}',
            'bank': _selectedBankName,
            'account': accNum,
          },
        );

        SecurityTelemetryService.recordActivity(
          title: 'Bank Withdrawal Dispatched 💳',
          message: 'Payout of ₦${NumberFormat('#,###.00').format(totalNgnRequired)} to $_selectedBankName ($accNum - $confirmedRecipient) was processed.',
          category: 'wallet',
          userEmail: currentUser.email,
          userName: currentUser.fullName,
          userId: currentUser.id,
          extraMetadata: {
            'amount': totalNgnRequired,
            'bankName': _selectedBankName,
            'accountNumber': accNum,
            'beneficiary': confirmedRecipient,
          },
        );

        if (!mounted) return;
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Withdrawal of ₦${NumberFormat('#,###.00').format(totalNgnRequired)} initiated successfully!',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? data['message'] ?? 'Withdrawal could not be processed.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Network timeout. Please check your connection and try again.';
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
                      'Send / Withdraw Funds',
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
              'Send money to saved beneficiaries, any Nigerian bank account, or transfer USDT on-chain.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            // Currency Mode Switcher Tabs (NGN vs USDT)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _withdrawalMode = 'NGN';
                        _amountController.clear();
                        _errorMessage = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                           color: _withdrawalMode == 'NGN' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _withdrawalMode == 'NGN'
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_rounded, size: 14, color: _withdrawalMode == 'NGN' ? AppColors.primary : AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              'Bank (NGN)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _withdrawalMode == 'NGN' ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _withdrawalMode = 'USDT';
                        _amountController.clear();
                        _errorMessage = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _withdrawalMode == 'USDT' ? const Color(0xFF07382B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _withdrawalMode == 'USDT'
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.currency_bitcoin_rounded, size: 14, color: _withdrawalMode == 'USDT' ? const Color(0xFF00E676) : AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              'USDT (TRC20)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _withdrawalMode == 'USDT' ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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

            // ── Past Recipients / Beneficiaries Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'PAST RECIPIENTS (${_savedBeneficiaries.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isLoadingBeneficiaries) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
                if (_savedBeneficiaries.isNotEmpty)
                  GestureDetector(
                    onTap: _openBeneficiarySearchSheet,
                    child: Text(
                      'Search All ➔',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            if (_isLoadingBeneficiaries && _savedBeneficiaries.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Syncing your past recipients & beneficiaries...',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ] else if (_savedBeneficiaries.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Anyone you transfer funds to will automatically be saved here for 1-tap re-use.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Search Past Recipients Input
              TextField(
                controller: _beneficiarySearchController,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search past recipient name, bank, or account...',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.primary),
                  suffixIcon: _beneficiarySearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14),
                          onPressed: () {
                            _beneficiarySearchController.clear();
                            _onSearchBeneficiaries('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                ),
                onChanged: _onSearchBeneficiaries,
              ),
              const SizedBox(height: 8),

              // Quick Beneficiary Chips / Avatars
              SizedBox(
                height: 72,
                child: _filteredBeneficiaries.isEmpty
                    ? Center(
                        child: Text(
                          'No past recipient found for "${_beneficiarySearchController.text}"',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filteredBeneficiaries.length,
                        itemBuilder: (context, idx) {
                          final b = _filteredBeneficiaries[idx];
                          final name = (b['accountName'] ?? 'Recipient').toString();
                          final bank = (b['bankName'] ?? 'Bank').toString();
                          final isSelected = _selectedBeneficiary != null &&
                              _selectedBeneficiary!['accountNumber'] == b['accountNumber'] &&
                              _selectedBeneficiary!['bankCode'] == b['bankCode'];

                          final initials = name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join('').toUpperCase();

                          return GestureDetector(
                            onTap: () => _selectBeneficiary(b),
                            child: Container(
                              width: 115,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.borderDark,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                                    child: Text(
                                      initials.isNotEmpty ? initials : 'R',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    bank,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8.5,
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              if (_selectedBeneficiary != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sending to: ${_selectedBeneficiary!['accountName']} • ${_selectedBeneficiary!['bankName']}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBeneficiary = null;
                            _accountController.clear();
                            _resolvedAccountName = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),

            // If USDT: Show Destination Selector (Bank Payout or Crypto Address)
            if (_withdrawalMode == 'USDT') ...[
              Text(
                'DESTINATION METHOD',
                style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text('Convert & Payout to Bank', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold)),
                      selected: _usdtDestinationType == 'BANK',
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      onSelected: (val) => setState(() => _usdtDestinationType = 'BANK'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text('Send to TRC20 Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold)),
                      selected: _usdtDestinationType == 'CRYPTO',
                      selectedColor: const Color(0xFF00E676).withValues(alpha: 0.2),
                      onSelected: (val) => setState(() => _usdtDestinationType = 'CRYPTO'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Amount Input Field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _withdrawalMode == 'USDT' ? 'ENTER USDT AMOUNT' : 'WITHDRAWAL AMOUNT (₦)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                Text(
                  _withdrawalMode == 'USDT'
                      ? 'Avail: \$${widget.user.usdtBalance.toStringAsFixed(2)} USDT'
                      : 'Avail: ₦${NumberFormat('#,###.00').format(widget.user.walletBalance)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              decoration: InputDecoration(
                prefixText: _withdrawalMode == 'USDT' ? '\$ ' : '₦ ',
                prefixStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                suffixText: _withdrawalMode == 'USDT' ? 'USDT' : 'NGN',
                suffixStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                hintText: _withdrawalMode == 'USDT' ? '50.00' : '50,000',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Live FX Conversion Banner for USDT
            if (_withdrawalMode == 'USDT') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF07382B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONVERTED NAIRA VALUE',
                          style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF00E676), letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '≈ ₦${NumberFormat('#,###.00').format(_computedNgnAmount)} NGN',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('1 USDT = ₦${_fxUsdtToNgn.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Payout Destination Inputs:
            // 1. If Crypto Address chosen
            if (_withdrawalMode == 'USDT' && _usdtDestinationType == 'CRYPTO') ...[
              Text('RECIPIENT TRON / TRC20 ADDRESS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _cryptoAddressController,
                style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'T...',
                  hintStyle: GoogleFonts.firaCode(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF00E676)),
                    tooltip: 'Scan Wallet QR Code',
                    onPressed: () async {
                      final scanned = await QRScannerScreen.startScan(
                        context,
                        mode: QRScannerMode.cryptoAddress,
                        title: 'Scan USDT Address',
                        instruction: 'Align recipient TRON (TRC20) QR code',
                      );
                      if (scanned != null && scanned.trim().isNotEmpty) {
                        setState(() {
                          _cryptoAddressController.text = scanned.trim();
                        });
                      }
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              // 2. Bank Destination Inputs (used for NGN mode OR USDT-converted mode)
              Text(
                'DESTINATION BANK (${_banks.length} AVAILABLE)',
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

              Text('ENTER 10-DIGIT ACCOUNT NUMBER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
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
              if (_accountResolutionError != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _accountResolutionError!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],

            // Narration / Remark Field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NARRATION / REMARK (OPTIONAL)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                Text(
                  'Appears on statement & receipt 📄',
                  style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _narrationController,
              maxLength: 60,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'e.g. Rent settlement for Flat 4B, Salary, Repairs...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                prefixIcon: const Icon(Icons.description_outlined, size: 18, color: AppColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _executeWithdrawal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _withdrawalMode == 'USDT' ? const Color(0xFF07382B) : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _withdrawalMode == 'USDT'
                            ? (_usdtDestinationType == 'CRYPTO' 
                                ? 'Authorize & Send ${_enteredAmount.toStringAsFixed(2)} USDT' 
                                : 'Convert & Payout ₦${NumberFormat('#,###.00').format(_computedNgnAmount)}')
                            : 'Authorize & Send ₦${NumberFormat('#,###.00').format(_computedNgnAmount)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
