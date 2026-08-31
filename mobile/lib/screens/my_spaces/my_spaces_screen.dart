import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

class MySpacesScreen extends StatefulWidget {
  const MySpacesScreen({super.key});

  @override
  State<MySpacesScreen> createState() => _MySpacesScreenState();
}

class _MySpacesScreenState extends State<MySpacesScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  String _activeTab = 'rented'; // 'rented', 'owned', 'receipts'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'My Spaces & Real Estate',
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
              // Segmented Sub-tab Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSubTab('rented', 'Rented Spaces (1)'),
                    ),
                    Expanded(
                      child: _buildSubTab('owned', 'Owned Real Estate (0)'),
                    ),
                    Expanded(
                      child: _buildSubTab('receipts', 'Legal Receipts'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_activeTab == 'rented') _buildRentedSpacesTab(),
              if (_activeTab == 'owned') _buildOwnedSpacesTab(),
              if (_activeTab == 'receipts') _buildReceiptsTab(),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRentedSpacesTab() {
    return Column(
      children: [
        // Active Leased Home Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ACTIVE LEASE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  Text(
                    '184 Days to Renewal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                '4-Bedroom Semi-Detached Duplex + BQ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primaryLight),
                  const SizedBox(width: 4),
                  Text(
                    'Plot 18, Block B, Off Admiralty Way, Lekki Phase 1, Lagos',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Landlord & Tenancy Details Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildRow('Direct Landlord', 'Chief Adebayo Falana'),
                    _buildRow('Annual Rent', '₦6,500,000 /yr'),
                    _buildRow('Caution Deposit Held', '₦500,000 (Safe in Escrow)'),
                    _buildRow('Governing Law', 'Lagos State Tenancy Law 2011'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Actions: Download Agreement & Pay Early
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.description_outlined, size: 13, color: AppColors.primaryLight),
                      label: Text(
                        'Tenancy PDF',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13),
                      label: Text(
                        'Chat Landlord',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOwnedSpacesTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.home_work_outlined, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text(
              'No Outright Properties Owned Yet',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'When you buy land or houses directly on Rentilly, your audited C of O title deeds and deed of assignment will be vaulted here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RENT RECEIPT #RENT-2026-091',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
              ),
              const Icon(Icons.verified, size: 16, color: AppColors.primaryLight),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tenant: Femi Adesanya • Landlord: Chief Adebayo Falana',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
          ),
          Text(
            'Amount Paid: ₦8,250,000.00 (Rent + Caution + 10% Legal Fee)',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Tamper-proof digital seal valid for visa applications, bank compliance, and Nigerian corporate filings.',
            style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_rounded, size: 13, color: AppColors.primaryLight),
              label: Text(
                'Download Visa-Grade PDF Receipt',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
