import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../screens/inspections/inspections_screen.dart';

class PartnerLeadPipelineModal extends StatefulWidget {
  final UserProfile user;

  const PartnerLeadPipelineModal({super.key, required this.user});

  static void show(BuildContext context, {required UserProfile user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartnerLeadPipelineModal(user: user),
    );
  }

  @override
  State<PartnerLeadPipelineModal> createState() => _PartnerLeadPipelineModalState();
}

class _PartnerLeadPipelineModalState extends State<PartnerLeadPipelineModal> {
  final NumberFormat _currencyFormat = NumberFormat('#,###');
  bool _isLoading = true;
  String _selectedStage = 'all'; // 'all', 'inspection', 'escrow', 'closed'
  List<Map<String, dynamic>> _pipelineItems = [];

  @override
  void initState() {
    super.initState();
    _loadPipelineData();
  }

  Future<void> _loadPipelineData() async {
    setState(() => _isLoading = true);

    try {
      final inspections = await ApiService.fetchInspections(
        userId: widget.user.id,
      );

      final allProps = await ApiService.fetchProperties();
      final partnerProps = allProps.where((p) =>
        (p.partnerId != null && p.partnerId == widget.user.id) ||
        (p.ownerId == widget.user.id) ||
        (p.ownerPhone.isNotEmpty && p.ownerPhone == widget.user.phoneNumber)
      ).toList();

      final List<Map<String, dynamic>> items = [];

      for (final insp in inspections) {
        final propId = insp.propertyId;
        final matchingProp = partnerProps.where((p) => p.id == propId).firstOrNull;

        final isClosed = insp.status == 'completed' || insp.status == 'verified';
        final isEscrow = insp.status == 'escrow_initiated' || insp.status == 'approved';
        final stage = isClosed ? 'closed' : (isEscrow ? 'escrow' : 'inspection');

        final price = matchingProp?.basePrice ?? 0.0;
        final isRent = matchingProp?.purpose == 'rent';
        final commission = price > 0 ? (price * (isRent ? 0.025 : 0.02)) : 0.0;

        items.add({
          'id': insp.id.isNotEmpty ? insp.id : 'lead_${DateTime.now().millisecondsSinceEpoch}',
          'prospectName': insp.prospectName.isNotEmpty ? insp.prospectName : 'Prospective Client',
          'prospectPhone': insp.prospectPhone,
          'prospectEmail': '',
          'propertyTitle': insp.propertyTitle.isNotEmpty ? insp.propertyTitle : (matchingProp?.title ?? 'Mandate Listing'),
          'propertyAddress': insp.propertyAddress.isNotEmpty ? insp.propertyAddress : (matchingProp?.address ?? ''),
          'scheduledDate': insp.scheduledDate,
          'scheduledTime': insp.scheduledTimeSlot,
          'gatePass': insp.inspectionPassCode,
          'status': insp.status.isNotEmpty ? insp.status : 'pending',
          'stage': stage,
          'projectedCommission': commission,
        });
      }

      if (items.isEmpty && partnerProps.isNotEmpty) {
        for (final p in partnerProps) {
          final isRent = p.purpose == 'rent';
          final commission = p.basePrice * (isRent ? 0.025 : 0.02);
          items.add({
            'id': 'mandate_${p.id}',
            'prospectName': 'Open for Inquiries',
            'prospectPhone': '',
            'prospectEmail': '',
            'propertyTitle': p.title,
            'propertyAddress': '${p.neighborhood}, ${p.state}',
            'scheduledDate': 'Active Listing',
            'scheduledTime': 'Available for Booking',
            'gatePass': 'ON-DEMAND',
            'status': p.status,
            'stage': 'inspection',
            'projectedCommission': commission,
          });
        }
      }

      if (mounted) {
        setState(() {
          _pipelineItems = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedStage == 'all') return _pipelineItems;
    return _pipelineItems.where((i) => i['stage'] == _selectedStage).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
                        color: const Color(0xFF064E3B).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF064E3B)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deal Pipeline & Leads 🎯',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Walkthroughs, Offers & Escrow Closings',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Deals (${_pipelineItems.length})'),
                  _buildFilterChip('inspection', '1. Walkthroughs'),
                  _buildFilterChip('escrow', '2. In Escrow 🔒'),
                  _buildFilterChip('closed', '3. Closed / Settled 🎉'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_outlined, size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            Text('No active deals in this stage', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('When prospects book walkthroughs or fund escrows, they appear here.', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final deal = _filteredItems[index];
                          final stage = deal['stage'] as String;
                          final comm = (deal['projectedCommission'] as num?)?.toDouble() ?? 0.0;

                          Color stageColor;
                          String stageLabel;
                          if (stage == 'closed') {
                            stageColor = const Color(0xFF16A34A);
                            stageLabel = 'COMMISSION DISBURSED';
                          } else if (stage == 'escrow') {
                            stageColor = const Color(0xFF0284C7);
                            stageLabel = 'HELD IN ESCROW';
                          } else {
                            stageColor = const Color(0xFFD97706);
                            stageLabel = 'WALKTHROUGH STAGE';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderDark),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: stageColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        stageLabel,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w900, color: stageColor),
                                      ),
                                    ),
                                    if (comm > 0)
                                      Text(
                                        'Yield: ₦${_currencyFormat.format(comm)}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  deal['propertyTitle'],
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  deal['propertyAddress'],
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('PROSPECTIVE CLIENT', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                          const SizedBox(height: 1),
                                          Text(
                                            deal['prospectName'],
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                      if (deal['gatePass'].toString().isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('GATE PASS CODE', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                            const SizedBox(height: 1),
                                            Text(
                                              deal['gatePass'],
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF064E3B)),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InspectionsScreen()));
                                      },
                                      icon: const Icon(Icons.qr_code_rounded, size: 14, color: AppColors.primary),
                                      label: Text('Open Inspection Desk', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String stage, String label) {
    final isSelected = _selectedStage == stage;
    return GestureDetector(
      onTap: () => setState(() => _selectedStage = stage),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF064E3B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF064E3B) : AppColors.borderDark),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
