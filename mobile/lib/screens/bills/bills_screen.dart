import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  String _selectedCategory = 'electricity'; // 'electricity', 'airtime', 'data', 'cable'

  // Disco State
  String _selectedDisco = 'EKEDC (Eko Electricity)';
  final TextEditingController _meterController = TextEditingController(text: '04218930491');
  final TextEditingController _amountController = TextEditingController(text: '15000');
  bool _isPurchasing = false;
  String? _purchasedToken;

  final List<String> _discos = [
    'EKEDC (Eko Electricity - Lagos)',
    'IKEDC (Ikeja Electric - Lagos)',
    'AEDC (Abuja Electricity)',
    'IBEDC (Ibadan Electricity)',
    'PHED (Port Harcourt Electricity)',
    'EEDC (Enugu Electricity)',
    'KAEDCO (Kaduna Electric)',
    'KEDCO (Kano Electricity)',
    'BEDC (Benin Electricity)',
  ];

  void _buyToken() async {
    setState(() => _isPurchasing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      _isPurchasing = false;
      _purchasedToken = '4920 1839 2049 1049 3920';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Utility & Bill Payments',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Switcher Chips
              Row(
                children: [
                  _buildCategoryChip('electricity', 'Electricity', Icons.electric_meter_rounded),
                  const SizedBox(width: 8),
                  _buildCategoryChip('data', 'Data', Icons.wifi_rounded),
                  const SizedBox(width: 8),
                  _buildCategoryChip('airtime', 'Airtime', Icons.phone_android_rounded),
                  const SizedBox(width: 8),
                  _buildCategoryChip('cable', 'Cable TV', Icons.tv_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // Disco Autopilot Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentGold.withValues(alpha: 0.15),
                      AppColors.surfaceDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 20, color: AppColors.accentGold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disco Autopilot Protection Active',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Token is delivered directly to your SMS, WhatsApp, and email within 3 seconds of purchase.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Purchase Form
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT ELECTRICITY DISTRIBUTION COMPANY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedDisco,
                      dropdownColor: AppColors.surfaceDark,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.borderDark.withValues(alpha: 0.5)),
                        ),
                      ),
                      items: _discos.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDisco = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'PREPAID METER NUMBER',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _meterController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundDark,
                        prefixIcon: const Icon(Icons.electric_meter_rounded, size: 16, color: AppColors.primaryLight),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.borderDark.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'AMOUNT (₦)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundDark,
                        prefixText: '₦ ',
                        prefixStyle: GoogleFonts.plusJakartaSans(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.borderDark.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buy Token Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPurchasing ? null : _buyToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _isPurchasing ? 'Recharging Meter...' : 'Generate 20-Digit Disco Token',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Purchased Token Display Box
              if (_purchasedToken != null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F382A).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 6),
                          Text(
                            'TOKEN GENERATED SUCCESSFULLY',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryLight,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _purchasedToken!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _purchasedToken!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('20-Digit Token Copied to Clipboard!', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                              backgroundColor: AppColors.primaryLight,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 13, color: AppColors.primaryLight),
                        label: Text(
                          'Copy Token for Prepaid Meter',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, IconData icon) {
    final isSelected = _selectedCategory == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : AppColors.borderDark.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
