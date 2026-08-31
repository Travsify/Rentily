import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../main_navigation_screen.dart';

class MySpacesScreen extends StatefulWidget {
  const MySpacesScreen({super.key});

  @override
  State<MySpacesScreen> createState() => _MySpacesScreenState();
}

class _MySpacesScreenState extends State<MySpacesScreen> {
  String _activeTab = 'rented'; // 'rented', 'owned', 'receipts'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'My Spaces & Real Estate',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: const RentillyBottomBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSubTab('rented', 'Rented (0)'),
                    ),
                    Expanded(
                      child: _buildSubTab('owned', 'Owned (0)'),
                    ),
                    Expanded(
                      child: _buildSubTab('receipts', 'Legal Receipts'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_activeTab == 'rented') _buildEmptyRentedSpaces(),
              if (_activeTab == 'owned') _buildEmptyOwnedSpaces(),
              if (_activeTab == 'receipts') _buildEmptyReceipts(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTab(String id, String label) {
    final isSelected = _activeTab == id;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRentedSpaces() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_work_outlined, size: 36, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'No Active Rented Spaces Yet',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'When you lease an apartment directly from verified landlords on Rentilly, your renewal countdown and Lagos tenancy agreements will be vaulted here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 1)),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Explore Verified Rentals',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOwnedSpaces() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
            child: const Icon(Icons.vpn_key_outlined, size: 36, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'No Owned Properties Yet',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Properties and land purchased outright on Rentilly will store their verified C of O deeds and legal title documents here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReceipts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
            child: const Icon(Icons.verified_outlined, size: 36, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'No Legal Receipts Yet',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Official tax- and visa-compliant rent receipts will be generated automatically upon your first lease payment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
