import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';

class VaultsScreen extends StatefulWidget {
  const VaultsScreen({super.key});

  @override
  State<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends State<VaultsScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  List<Map<String, dynamic>> _userVaults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  void _loadVaults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('rentilly_user_vaults');
    if (saved != null) {
      try {
        final List<dynamic> list = json.decode(saved);
        setState(() {
          _userVaults = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }

    // Per specifications: Blank living vault until user adds one themselves!
    setState(() {
      _userVaults = [];
      _isLoading = false;
    });
  }

  void _saveVaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rentilly_user_vaults', json.encode(_userVaults));
  }

  void _showCreateVaultDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController targetController = TextEditingController();
    String selectedCategory = 'Annual Rent Stash';

    final categories = [
      {
        'name': 'Annual Rent Stash',
        'desc': 'Save towards yearly rent renewal',
        'yield': '7.0% p.a.',
        'yieldNote': '5.0% - 8.0% APY',
      },
      {
        'name': 'Living Utility & Target Stash',
        'desc': 'Power tokens, water, data, & maintenance',
        'yield': '5.0% p.a.',
        'yieldNote': 'Max 5.0% APY',
      },
      {
        'name': 'Caution Deposit & Service Fund',
        'desc': 'Interest-free escrow damage deposit',
        'yield': '0.0%',
        'yieldNote': 'Interest-Free Escrow Protection',
      },
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
            final currentCategoryMeta = categories.firstWhere((c) => c['name'] == selectedCategory);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
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
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.savings_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Create Living Vault 🎯',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set aside disciplined funds for rent, utility bills, or caution deposits.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  Text('SELECT VAULT CATEGORY', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 8),

                  // Category Selector Chips
                  Column(
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat['name'];
                      return GestureDetector(
                        onTap: () => setModalState(() {
                          selectedCategory = cat['name']!;
                          if (titleController.text.isEmpty || categories.any((c) => c['name'] == titleController.text)) {
                            titleController.text = cat['name']!;
                          }
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark, width: isSelected ? 1.5 : 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat['name']!, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text(cat['desc']!, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cat['yield'] == '0.0%' ? const Color(0xFFF1F5F9) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cat['yieldNote']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: cat['yield'] == '0.0%' ? AppColors.textSecondary : const Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  Text('VAULT NAME / TITLE', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Annual Rent Renewal 2027',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text('TARGET GOAL AMOUNT (₦)', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixText: '₦ ',
                      prefixStyle: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold),
                      hintText: '1,500,000',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final t = titleController.text.trim().isNotEmpty ? titleController.text.trim() : selectedCategory;
                        final amt = double.tryParse(targetController.text.replaceAll(',', '').trim()) ?? 0;
                        if (amt > 0) {
                          setState(() {
                            _userVaults.add({
                              'title': t,
                              'category': selectedCategory,
                              'target': amt,
                              'saved': 0.0,
                              'yieldRate': currentCategoryMeta['yield']!,
                              'yieldNote': currentCategoryMeta['yieldNote']!,
                            });
                          });
                          _saveVaults();
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Living Vault "$t" created successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: AppColors.primary,
                            ),
                          );
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
                      child: Text('Create Living Vault', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
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
                            '5.0% - 8.0% ANNUAL YIELD',
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
                      'Disciplined living reserves. Caution deposit protection is strictly interest-free (0%); annual rent stashes earn 5% to 8% yield.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Smart Salary Splitter Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_fix_high_rounded, size: 20, color: AppColors.accentOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Salary Splitter',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Automatically allocates a percentage of every wallet top-up into your annual rent renewal vault.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    final yieldStr = v['yieldRate'] ?? (v['yieldNote'] ?? '5.0% p.a.');

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
                                  color: yieldStr == '0.0%' ? const Color(0xFFF1F5F9) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  yieldStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: yieldStr == '0.0%' ? AppColors.textSecondary : const Color(0xFF059669),
                                  ),
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
                              Text(
                                '₦${_currencyFormat.format(saved)} saved',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              Text(
                                'Target: ₦${_currencyFormat.format(target)}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
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
