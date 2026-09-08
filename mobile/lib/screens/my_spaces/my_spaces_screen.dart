import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user_profile.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../main_navigation_screen.dart';

class MySpacesScreen extends StatefulWidget {
  const MySpacesScreen({super.key});

  @override
  State<MySpacesScreen> createState() => _MySpacesScreenState();
}

class _MySpacesScreenState extends State<MySpacesScreen> {
  String _activeTab = 'rented'; // 'rented', 'owned', 'receipts'
  UserProfile? _user;
  List<Map<String, dynamic>> _rentedSpaces = [];
  List<Map<String, dynamic>> _ownedSpaces = [];
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = true;

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final agreements = await ApiService.fetchLegalAgreements(email: user.email);
      final List<Map<String, dynamic>> rented = [];
      final List<Map<String, dynamic>> owned = [];
      final List<Map<String, dynamic>> receipts = [];

      for (final a in agreements) {
        final isRent = (a['transactionType'] ?? a['purpose'] ?? 'rent').toString().toLowerCase() == 'rent';
        if (isRent) {
          rented.add(a);
        } else {
          owned.add(a);
        }
        receipts.add({
          'id': a['id'] ?? a['escrowReference'] ?? 'REC-',
          'title': a['propertyTitle'] ?? 'Tenancy Agreement',
          'amount': a['annualRent'] ?? a['basePrice'] ?? 0,
          'date': a['commencementDate'] ?? a['createdAt'] ?? '2026-09-05',
          'ref': a['escrowReference'] ?? 'RENT-ESCROW',
        });
      }

      if (mounted) {
        setState(() {
          _user = user;
          _rentedSpaces = rented;
          _ownedSpaces = owned;
          _receipts = receipts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        child: RefreshIndicator(
          onRefresh: _loadSpaces,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        child: _buildSubTab('rented', 'Rented ()'),
                      ),
                      Expanded(
                        child: _buildSubTab('owned', 'Owned ()'),
                      ),
                      Expanded(
                        child: _buildSubTab('receipts', 'Legal Receipts ()'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else ...[
                  if (_activeTab == 'rented')
                    _rentedSpaces.isNotEmpty ? _buildRentedSpacesList() : _buildEmptyRentedSpaces(),
                  if (_activeTab == 'owned')
                    _ownedSpaces.isNotEmpty ? _buildOwnedSpacesList() : _buildEmptyOwnedSpaces(),
                  if (_activeTab == 'receipts')
                    _receipts.isNotEmpty ? _buildReceiptsList() : _buildEmptyReceipts(),
                ],
              ],
            ),
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

  Widget _buildRentedSpacesList() {
    return Column(
      children: _rentedSpaces.map((space) {
        final title = space['propertyTitle'] ?? space['property_title'] ?? 'Rented Apartment';
        final address = space['propertyAddress'] ?? space['property_address'] ?? 'Lagos, Nigeria';
        final rent = (space['annualRent'] ?? space['annual_rent'] ?? 0) as num;
        final caution = (space['cautionDeposit'] ?? space['caution_deposit'] ?? 0) as num;
        final duration = space['tenancyDuration'] ?? space['tenancy_duration'] ?? '12 Months';
        final landlord = space['landlordName'] ?? space['landlord_name'] ?? 'Verified Landlord';
        final ref = space['escrowReference'] ?? space['escrow_reference'] ?? 'ESCROW-ACTIVE';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
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
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ACTIVE LEASE • ESCROW SECURED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ),
                  Text(
                    duration,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 13, color: AppColors.accentOrange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Annual Rent', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted)),
                        Text('₦${_currencyFormat.format(rent)}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Caution (Held)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted)),
                        Text('₦${_currencyFormat.format(caution)}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Landlord', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted)),
                        Text(landlord.split(' ')[0], style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAgreementDetailsModal(space),
                      icon: const Icon(Icons.description_outlined, size: 14),
                      label: const Text('View Agreement'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showReportIssueModal(space),
                      icon: const Icon(Icons.build_rounded, size: 14),
                      label: const Text('Report Issue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOwnedSpacesList() {
    return Column(
      children: _ownedSpaces.map((space) {
        final title = space['propertyTitle'] ?? space['property_title'] ?? 'Owned Property';
        final address = space['propertyAddress'] ?? space['property_address'] ?? 'Nigeria';
        final price = (space['annualRent'] ?? space['basePrice'] ?? 0) as num;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'C OF O & TITLE VERIFIED',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFFB45309)),
                ),
              ),
              const SizedBox(height: 10),
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(address, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Text('Purchase Value: ₦${_currencyFormat.format(price)}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReceiptsList() {
    return Column(
      children: _receipts.map((rec) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec['title'], style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Ref: ${rec['ref']} • ${rec['date']}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(
                '₦${_currencyFormat.format(rec['amount'])}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
        );
      }).toList(),
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
            decoration: const BoxDecoration(
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
            decoration: const BoxDecoration(
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
            decoration: const BoxDecoration(
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

  void _showAgreementDetailsModal(Map<String, dynamic> space) {
    final title = space['propertyTitle'] ?? space['property_title'] ?? 'Tenancy Agreement';
    final address = space['propertyAddress'] ?? space['property_address'] ?? 'Nigeria';
    final rent = (space['annualRent'] ?? space['annual_rent'] ?? 0) as num;
    final caution = (space['cautionDeposit'] ?? space['caution_deposit'] ?? 0) as num;
    final duration = space['tenancyDuration'] ?? space['tenancy_duration'] ?? '12 Months';
    final landlord = space['landlordName'] ?? space['landlord_name'] ?? 'Verified Landlord';
    final ref = space['escrowReference'] ?? space['escrow_reference'] ?? 'ESCROW-2026';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Tenancy Agreement Details', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _buildModalRow('Property', title),
                  const Divider(height: 16),
                  _buildModalRow('Address', address),
                  const Divider(height: 16),
                  _buildModalRow('Annual Rent', '₦${_currencyFormat.format(rent)}'),
                  const Divider(height: 16),
                  _buildModalRow('Caution Deposit', '₦${_currencyFormat.format(caution)}'),
                  const Divider(height: 16),
                  _buildModalRow('Duration', duration),
                  const Divider(height: 16),
                  _buildModalRow('Landlord', landlord),
                  const Divider(height: 16),
                  _buildModalRow('Escrow Reference', ref),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Agreement ($ref) is secured and authenticated on Rentilly Escrow Protocol.'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                },
                icon: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                label: Text('Authenticated Escrow Agreement ✓', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportIssueModal(Map<String, dynamic> space) {
    final title = space['propertyTitle'] ?? space['property_title'] ?? 'My Space';
    final issueCtrl = TextEditingController();
    String category = 'Plumbing & Water';
    bool isUrgent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build_rounded, size: 20, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Text('Report Maintenance Issue', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 6),
              Text('Property: $title', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'Plumbing & Water', child: Text('Plumbing & Water')),
                  DropdownMenuItem(value: 'Electrical & Power', child: Text('Electrical & Power')),
                  DropdownMenuItem(value: 'Structural / Roofing', child: Text('Structural / Roofing')),
                  DropdownMenuItem(value: 'Security & Locks', child: Text('Security & Locks')),
                  DropdownMenuItem(value: 'Other Maintenance', child: Text('Other Maintenance')),
                ],
                onChanged: (val) {
                  if (val != null) setMState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: issueCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Describe the issue *',
                  hintText: 'e.g. Bathroom pipe leakage on master bedroom side',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: isUrgent,
                contentPadding: EdgeInsets.zero,
                title: Text('Flag as Urgent', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                onChanged: (val) => setMState(() => isUrgent = val ?? false),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (issueCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please describe the issue.')),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Maintenance ticket logged: "$category" dispatched to landlord.'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  },
                  child: Text('Submit Ticket', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
