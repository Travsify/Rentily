import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../services/notification_service.dart';

class SmartSalarySplitterModal extends StatefulWidget {
  final List<Map<String, dynamic>> userVaults;
  final VoidCallback onConfigSaved;

  const SmartSalarySplitterModal({
    super.key,
    required this.userVaults,
    required this.onConfigSaved,
  });

  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> userVaults,
    required VoidCallback onConfigSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartSalarySplitterModal(
        userVaults: userVaults,
        onConfigSaved: onConfigSaved,
      ),
    );
  }

  @override
  State<SmartSalarySplitterModal> createState() => _SmartSalarySplitterModalState();
}

class _SmartSalarySplitterModalState extends State<SmartSalarySplitterModal> {
  bool _isEnabled = true;
  double _rentPercentage = 30.0;
  double _utilityPercentage = 10.0;
  String _targetVaultTitle = 'Annual Rent Stash';
  String _dateWindowMode = 'range'; // 'range' | 'all'
  int _startDay = 24;
  int _endDay = 31;

  final TextEditingController _testSalaryController = TextEditingController(text: '500,000');
  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  void _loadExistingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('rentilly_salary_splitter_config');
    if (data != null) {
      try {
        final map = json.decode(data);
        setState(() {
          _isEnabled = map['isEnabled'] ?? true;
          _rentPercentage = (map['rentPercentage'] as num?)?.toDouble() ?? 30.0;
          _utilityPercentage = (map['utilityPercentage'] as num?)?.toDouble() ?? 10.0;
          _targetVaultTitle = map['targetVaultTitle'] ?? 'Annual Rent Stash';
          _dateWindowMode = map['dateWindowMode'] ?? 'range';
          _startDay = (map['startDay'] as num?)?.toInt() ?? 24;
          _endDay = (map['endDay'] as num?)?.toInt() ?? 31;
        });
      } catch (_) {}
    } else if (widget.userVaults.isNotEmpty) {
      setState(() {
        _targetVaultTitle = widget.userVaults.first['title'] ?? 'Annual Rent Stash';
      });
    }
  }

  double get _liquidPercentage => (100.0 - _rentPercentage - _utilityPercentage).clamp(0.0, 100.0);

  void _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final config = {
      'isEnabled': _isEnabled,
      'rentPercentage': _rentPercentage,
      'utilityPercentage': _utilityPercentage,
      'liquidPercentage': _liquidPercentage,
      'targetVaultTitle': _targetVaultTitle,
      'dateWindowMode': _dateWindowMode,
      'startDay': _startDay,
      'endDay': _endDay,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString('rentilly_salary_splitter_config', json.encode(config));

    await NotificationService.addNotification(
      title: 'Smart Salary Splitter Updated ⚡',
      message: _isEnabled
          ? 'Automated rule active: ${_rentPercentage.toInt()}% swept to "$_targetVaultTitle" on deposits between Day $_startDay and Day $_endDay.'
          : 'Smart Salary Splitter has been deactivated.',
      category: 'vault',
      metadata: {
        'status': _isEnabled ? 'ACTIVE' : 'INACTIVE',
        'rent_percentage': '${_rentPercentage.toInt()}%',
        'target_vault': _targetVaultTitle,
        'window': 'Day $_startDay - Day $_endDay',
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onConfigSaved();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Smart Salary Splitter settings saved!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double salary = double.tryParse(_testSalaryController.text.replaceAll(',', '')) ?? 500000;
    final double rentAmt = (salary * (_rentPercentage / 100));
    final double utilAmt = (salary * (_utilityPercentage / 100));
    final double liquidAmt = (salary * (_liquidPercentage / 100));

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
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
                      child: const Icon(Icons.auto_fix_high_rounded, size: 20, color: AppColors.accentOrange),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Salary Splitter',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Automated Inward Deposit Allocation',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scrollable Settings Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Enable / Disable Toggle Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isEnabled ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isEnabled ? const Color(0xFFBBF7D0) : AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEnabled ? 'Smart Auto-Splitter Active ⚡' : 'Auto-Splitter Deactivated',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _isEnabled ? const Color(0xFF15803D) : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'When enabled, incoming bank transfers matching your date window are automatically allocated.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _isEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isEnabled = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. User-Defined Rent Percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1. RENT VAULT ALLOCATION', style: _labelStyle),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_rentPercentage.toInt()}% of Deposit',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Slider(
                  value: _rentPercentage,
                  min: 5.0,
                  max: 80.0,
                  divisions: 15,
                  activeColor: AppColors.primary,
                  inactiveColor: const Color(0xFFE2E8F0),
                  onChanged: _isEnabled
                      ? (v) {
                          setState(() {
                            _rentPercentage = v;
                            if (_rentPercentage + _utilityPercentage > 90) {
                              _utilityPercentage = 90 - _rentPercentage;
                            }
                          });
                        }
                      : null,
                ),
                // Quick Percentage Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [15.0, 25.0, 33.0, 50.0, 60.0].map((pct) {
                    final isSel = _rentPercentage == pct;
                    return GestureDetector(
                      onTap: _isEnabled ? () => setState(() => _rentPercentage = pct) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                        ),
                        child: Text(
                          '${pct.toInt()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // 3. User-Defined Date Range / Payday Window
                Text('2. PAYDAY / DATE WINDOW TRIGGER', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _dateWindowMode = 'range'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _dateWindowMode == 'range' ? AppColors.primary : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _dateWindowMode == 'range' ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Payday Window 📅',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _dateWindowMode == 'range' ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Day $_startDay - Day $_endDay',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  color: _dateWindowMode == 'range' ? Colors.white70 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _dateWindowMode = 'all'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _dateWindowMode == 'all' ? AppColors.primary : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _dateWindowMode == 'all' ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Every Deposit ⚡',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _dateWindowMode == 'all' ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'All Month Long',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  color: _dateWindowMode == 'all' ? Colors.white70 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_dateWindowMode == 'range') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Payday Date Range in Month:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start Day:', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<int>(
                                    value: _startDay,
                                    dropdownColor: Colors.white,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    decoration: _inputDeco(),
                                    items: List.generate(28, (i) => i + 1)
                                        .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                                        .toList(),
                                    onChanged: (v) => setState(() => _startDay = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('End Day:', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<int>(
                                    value: _endDay,
                                    dropdownColor: Colors.white,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    decoration: _inputDeco(),
                                    items: List.generate(31, (i) => i + 1)
                                        .where((d) => d >= _startDay)
                                        .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                                        .toList(),
                                    onChanged: (v) => setState(() => _endDay = v!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '💡 Any deposit received between Day $_startDay and Day $_endDay will automatically trigger this split.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // 4. Target Destination Vault Selector
                Text('3. TARGET DESTINATION LIVING VAULT', style: _labelStyle),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: widget.userVaults.any((v) => v['title'] == _targetVaultTitle)
                      ? _targetVaultTitle
                      : (widget.userVaults.isNotEmpty ? widget.userVaults.first['title'] : 'Annual Rent Stash'),
                  dropdownColor: Colors.white,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  decoration: _inputDeco(),
                  items: widget.userVaults.isNotEmpty
                      ? widget.userVaults.map((v) {
                          final title = v['title'] as String;
                          final y = v['yieldRate'] ?? v['yieldNote'] ?? '8.0% yield';
                          return DropdownMenuItem(value: title, child: Text('$title ($y)'));
                        }).toList()
                      : [const DropdownMenuItem(value: 'Annual Rent Stash', child: Text('Annual Rent Stash (8.0% yield)'))],
                  onChanged: (v) => setState(() => _targetVaultTitle = v!),
                ),
                const SizedBox(height: 18),

                // 5. Live Simulation / Breakdown Preview
                Text('4. LIVE ALLOCATION PREVIEW', style: _labelStyle),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Simulated Income:', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70)),
                          Text(
                            '₦${_currencyFormat.format(salary)} Deposit',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Visual Split Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: _rentPercentage.toInt(),
                              child: Container(height: 8, color: AppColors.primary),
                            ),
                            if (_utilityPercentage > 0)
                              Expanded(
                                flex: _utilityPercentage.toInt(),
                                child: Container(height: 8, color: const Color(0xFF0284C7)),
                              ),
                            Expanded(
                              flex: _liquidPercentage.toInt(),
                              child: Container(height: 8, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSplitRow('Rent Stash (${_rentPercentage.toInt()}%)', '₦${_currencyFormat.format(rentAmt)}', AppColors.primaryLight),
                      const SizedBox(height: 4),
                      _buildSplitRow('Liquid Wallet (${_liquidPercentage.toInt()}%)', '₦${_currencyFormat.format(liquidAmt)}', const Color(0xFF34D399)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Rule Button
                ElevatedButton(
                  onPressed: _saveConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Save & Activate Smart Splitter',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
          ],
        ),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  InputDecoration _inputDeco() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
    );
  }
}
