import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../bills/bills_screen.dart';

class LandlordWalletScreen extends StatefulWidget {
  const LandlordWalletScreen({super.key});

  @override
  State<LandlordWalletScreen> createState() => _LandlordWalletScreenState();
}

class _LandlordWalletScreenState extends State<LandlordWalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  bool _isLoading = true;
  String _selectedLedgerFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadUser();
    AuthService.currentUserNotifier.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) {
      setState(() {
        _user = AuthService.currentUserNotifier.value;
      });
    }
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

  void _downloadStatement() async {
    final name = _user?.fullName ?? 'Property Owner';
    final balance = _user?.walletBalance ?? 2000.0;
    final acc = _user?.accountNumber ?? '9254090338';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RENTILLY ESCROW & SETTLEMENT NETWORK', style: pw.TextStyle(color: PdfColor.fromHex('064E3B'), fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text('OFFICIAL LANDLORD ACCOUNT STATEMENT', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://rentilly.ng/statement/$acc',
                    width: 44,
                    height: 44,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F0FDF4'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('86EFAC')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ACCOUNT HOLDER: $name', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('VIRTUAL SETTLEMENT ACCOUNT: $acc (Providus Bank)', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('NET OPERATING BALANCE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.Text('NGN ${_currencyFormat.format(balance)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('064E3B'))),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('TRANSACTION & DISBURSEMENT LEDGER', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('064E3B')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('DATE', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('DESCRIPTION', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TYPE', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('AMOUNT (NGN)', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('STATUS', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('01 Sep 2026', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Wallet Direct Funding (Bank Transfer to $acc)', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Inflow', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('+2,000.00', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('16A34A')))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('COMPLETED', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green700))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('28 Aug 2026', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rental Escrow Clearance (3-Bed Lekki Phase 1)', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Settlement', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('+3,500,000.00', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('16A34A')))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('RELEASED', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green700))),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Rentilly_Statement_$acc.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isVerified = _user?.isVerified ?? true;
    final name = _user?.fullName ?? 'Property Owner';
    final operationalBalance = _user?.walletBalance ?? 2000.0;
    final escrowBalance = 0.00;
    final accountNumber = _user?.accountNumber ?? '9254090338';
    final bankName = _user?.bankName ?? 'Providus Bank';

    // Transactions list
    final List<Map<String, dynamic>> allTransactions = [
      {
        'title': 'Wallet Funding (Bank Transfer to $accountNumber)',
        'subtitle': 'Direct deposit via Providus Bank Virtual Account',
        'date': 'Today, 03:45 AM',
        'amount': 2000.0,
        'type': 'inflow',
        'status': 'Completed',
        'icon': Icons.arrow_downward_rounded,
        'color': const Color(0xFF16A34A),
      },
      {
        'title': 'Rental Escrow Clearance (3-Bed Lekki Phase 1)',
        'subtitle': 'Tenant Move-in & Key Handover Confirmed',
        'date': '28 Aug 2026',
        'amount': 3500000.0,
        'type': 'escrow',
        'status': 'Released',
        'icon': Icons.real_estate_agent_rounded,
        'color': const Color(0xFF16A34A),
      },
      {
        'title': 'Prepaid Unit Utility (IKEDC Token #450291)',
        'subtitle': 'Vacant Unit 3B Prepaid Electricity Recharge',
        'date': '25 Aug 2026',
        'amount': -5000.0,
        'type': 'outflow',
        'status': 'Successful',
        'icon': Icons.electric_bolt_rounded,
        'color': AppColors.accentOrange,
      },
    ];

    final filteredTransactions = _selectedLedgerFilter == 'All'
        ? allTransactions
        : _selectedLedgerFilter == 'Inflows'
            ? allTransactions.where((t) => (t['amount'] as double) > 0).toList()
            : _selectedLedgerFilter == 'Outflows'
                ? allTransactions.where((t) => (t['amount'] as double) < 0).toList()
                : allTransactions.where((t) => t['type'] == 'escrow').toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Settlement & Escrow Vault',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: AppColors.primary),
            onPressed: _downloadStatement,
            tooltip: 'Download Statement',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _loadUser(),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Dual Balance Card (Styled 100% in Rentilly Brand Green with Emerald & Gold Accents)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF042F2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.35), width: 1.2),
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
                            const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF4ADE80)),
                            const SizedBox(width: 6),
                            Text(
                              'LANDLORD OPERATING VAULT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: const Color(0xFF4ADE80),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4ADE80)),
                          ),
                          child: Text(
                            'VERIFIED VAULT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4ADE80),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operational Funded Balance
                    Text('AVAILABLE OPERATING FUNDS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text('₦${_currencyFormat.format(operationalBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 14),

                    // Divider
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),

                    // Escrow Balance (Rent & Sales Proceeds)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACTIVE SETTLEMENT FUNDS IN ESCROW', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text('₦${_currencyFormat.format(escrowBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RELEASES ON KEY CONFIRMATION',
                            style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Virtual Bank Account Section (Rentilly Brand Green Accent)
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
                              'DEDICATED SETTLEMENT BANK ACCOUNT',
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
                            'AUTOMATED SETTLEMENT',
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
                            Text('$bankName • $name / Rentilly', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
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
              const SizedBox(height: 20),

              // Unit Utilities & Maintenance Pod
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'UNIT UTILITIES & MAINTENANCE',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                  ),
                  Text(
                    'INSTANT DISPATCH',
                    style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    _buildUtilityButton(
                      Icons.electric_bolt_rounded,
                      'Electricity',
                      'Prepaid DisCo',
                      AppColors.accentOrange,
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'electricity')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.phone_android_rounded,
                      'Airtime',
                      'Quick Top-Up',
                      AppColors.primary,
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'airtime')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.wifi_rounded,
                      'Data Bundle',
                      '4K Video Tours',
                      const Color(0xFFF59E0B),
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'data')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.tv_rounded,
                      'Cable TV',
                      'DSTV/GOTV',
                      const Color(0xFF7C3AED),
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'cable')));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recent Disbursements & Transaction History Ledger
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT DISBURSEMENTS & LEDGER',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: _downloadStatement,
                    icon: const Icon(Icons.download_rounded, size: 13, color: AppColors.primary),
                    label: Text('Export PDF', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Inflows'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Outflows'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Escrow'),
                ],
              ),
              const SizedBox(height: 10),

              ...filteredTransactions.map((tx) {
                final isPositive = (tx['amount'] as double) > 0;
                final formatted = isPositive ? '+₦${_currencyFormat.format(tx['amount'])}' : '-₦${_currencyFormat.format((tx['amount'] as double).abs())}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (tx['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(tx['icon'] as IconData, size: 18, color: tx['color'] as Color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(tx['subtitle'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(tx['date'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatted, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: isPositive ? const Color(0xFF16A34A) : Colors.red)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tx['status'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedLedgerFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedLedgerFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityButton(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
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
