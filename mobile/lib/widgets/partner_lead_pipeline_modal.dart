import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/direct_message_service.dart';
import '../screens/inspections/inspections_screen.dart';
import '../screens/messages/direct_chat_detail_screen.dart';
import 'partner_legal_modal.dart';

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
      final List<Map<String, dynamic>> items = [];

      // 1. Fetch live inspections from database
      final inspections = await ApiService.fetchInspections(
        userId: widget.user.id,
      );

      final allProps = await ApiService.fetchProperties();
      final partnerProps = allProps.where((p) =>
        (p.partnerId != null && p.partnerId == widget.user.id) ||
        (p.ownerId == widget.user.id) ||
        (p.ownerPhone.isNotEmpty && p.ownerPhone == widget.user.phoneNumber)
      ).toList();

      for (final insp in inspections) {
        final propId = insp.propertyId;
        final matchingProp = partnerProps.where((p) => p.id == propId).firstOrNull;

        final isClosed = insp.status == 'completed' || insp.status == 'verified' || insp.status == 'settled';
        final isEscrow = insp.status == 'escrow_initiated' || insp.status == 'in_escrow' || insp.status == 'approved' || insp.status == 'funded';
        final stage = isClosed ? 'closed' : (isEscrow ? 'escrow' : 'inspection');

        final price = matchingProp?.basePrice ?? 0.0;
        final isRent = matchingProp?.purpose == 'rent';
        final commission = price > 0 ? (price * (isRent ? 0.025 : 0.02)) : 0.0;

        items.add({
          'id': insp.id,
          'type': 'inspection',
          'prospectName': insp.prospectName.isNotEmpty ? insp.prospectName : 'Prospective Client',
          'prospectPhone': insp.prospectPhone,
          'prospectEmail': insp.prospectEmail ?? '',
          'propertyTitle': insp.propertyTitle.isNotEmpty ? insp.propertyTitle : (matchingProp?.title ?? 'Partner Mandate Listing'),
          'propertyAddress': insp.propertyAddress.isNotEmpty ? insp.propertyAddress : (matchingProp?.address ?? ''),
          'scheduledDate': insp.scheduledDate,
          'scheduledTime': insp.scheduledTimeSlot,
          'gatePass': insp.inspectionPassCode,
          'status': insp.status.isNotEmpty ? insp.status : 'pending',
          'stage': stage,
          'projectedCommission': commission,
          'rawData': insp,
        });
      }

      // 2. Fetch live tenant direct inquiry leads from Supabase
      try {
        final directConvos = await DirectMessageService.getOwnerConversations(widget.user.id);
        for (final convo in directConvos) {
          final propId = convo['property_id']?.toString() ?? '';
          final matchingProp = partnerProps.where((p) => p.id == propId).firstOrNull;
          final price = matchingProp?.basePrice ?? 0.0;
          final isRent = matchingProp?.purpose == 'rent';
          final commission = price > 0 ? (price * (isRent ? 0.025 : 0.02)) : 0.0;

          // Check if this inquiry already has a scheduled inspection in the list
          final hasInspection = items.any((i) => i['propertyTitle'] == convo['property_title'] && (i['prospectName'] == convo['tenant_name'] || i['prospectEmail'] == convo['tenant_email']));

          if (!hasInspection) {
            items.add({
              'id': convo['id']?.toString() ?? 'convo_${DateTime.now().millisecondsSinceEpoch}',
              'type': 'inquiry',
              'prospectName': convo['tenant_name']?.toString() ?? 'Prospective Client',
              'prospectPhone': '',
              'prospectEmail': convo['tenant_email']?.toString() ?? '',
              'propertyTitle': convo['property_title']?.toString() ?? (matchingProp?.title ?? 'Property Inquiry'),
              'propertyAddress': convo['property_address']?.toString() ?? (matchingProp?.address ?? ''),
              'scheduledDate': 'Direct Inquiry',
              'scheduledTime': convo['last_message']?.toString() ?? 'Chat active',
              'gatePass': '',
              'status': convo['status']?.toString() ?? 'active',
              'stage': 'inspection',
              'projectedCommission': commission,
              'convo': convo,
            });
          }
        }
      } catch (_) {}

      // 3. Fetch live Escrow transactions for closed & in-escrow deals
      try {
        final commData = await ApiService.fetchPartnerCommissions(widget.user.id, widget.user.email);
        final txns = (commData['transactions'] as List<dynamic>?) ?? [];
        for (final tx in txns) {
          if (tx is Map<String, dynamic>) {
            final isSettled = tx['status'] == 'completed' || tx['status'] == 'settled';
            final stage = isSettled ? 'closed' : 'escrow';
            final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;

            final alreadyInList = items.any((i) => i['id'] == tx['id'] || i['id'] == tx['reference']);
            if (!alreadyInList && amt > 0) {
              items.add({
                'id': tx['id']?.toString() ?? tx['reference']?.toString() ?? 'esc_${DateTime.now().millisecondsSinceEpoch}',
                'type': 'escrow_deal',
                'prospectName': tx['tenantName']?.toString() ?? tx['narration']?.toString() ?? 'Escrow Client',
                'prospectPhone': '',
                'prospectEmail': tx['tenantEmail']?.toString() ?? '',
                'propertyTitle': tx['propertyTitle']?.toString() ?? 'Escrow Settlement',
                'propertyAddress': tx['propertyAddress']?.toString() ?? 'Secured Escrow Vault',
                'scheduledDate': tx['createdAt']?.toString() ?? 'Escrow Funded',
                'scheduledTime': isSettled ? 'Disbursed to Vault' : 'Locked in Escrow',
                'gatePass': tx['reference']?.toString() ?? '',
                'status': tx['status']?.toString() ?? 'in_escrow',
                'stage': stage,
                'projectedCommission': amt,
                'rawData': tx,
              });
            }
          }
        }
      } catch (_) {}

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

          // Horizontal Stage Filter Tabs
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
                  _buildFilterChip('inspection', '1. Walkthroughs & Leads (${_pipelineItems.where((i) => i['stage'] == 'inspection').length})'),
                  _buildFilterChip('escrow', '2. In Escrow 🔒 (${_pipelineItems.where((i) => i['stage'] == 'escrow').length})'),
                  _buildFilterChip('closed', '3. Closed & Settled 🎉 (${_pipelineItems.where((i) => i['stage'] == 'closed').length})'),
                ],
              ),
            ),
          ),

          // Main List / Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredItems.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final deal = _filteredItems[index];
                          final stage = deal['stage'] as String;
                          final comm = (deal['projectedCommission'] as num?)?.toDouble() ?? 0.0;
                          final isChat = deal['type'] == 'inquiry';

                          Color stageColor;
                          String stageLabel;
                          if (stage == 'closed') {
                            stageColor = const Color(0xFF16A34A);
                            stageLabel = 'COMMISSION DISBURSED';
                          } else if (stage == 'escrow') {
                            stageColor = const Color(0xFF0284C7);
                            stageLabel = 'HELD IN ESCROW';
                          } else {
                            stageColor = isChat ? const Color(0xFF0D9488) : const Color(0xFFD97706);
                            stageLabel = isChat ? 'DIRECT INQUIRY LEAD' : 'WALKTHROUGH STAGE';
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
                                        stage == 'closed'
                                            ? 'Earned: ₦${_currencyFormat.format(comm)}'
                                            : 'Est. Yield: ₦${_currencyFormat.format(comm)}',
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
                                if (deal['propertyAddress'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    deal['propertyAddress'],
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('PROSPECTIVE CLIENT', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                            const SizedBox(height: 1),
                                            Text(
                                              deal['prospectName'],
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (deal['prospectPhone'].toString().isNotEmpty)
                                              Text(
                                                deal['prospectPhone'],
                                                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (deal['gatePass'].toString().isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('GATE PASS CODE', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                            const SizedBox(height: 1),
                                            Text(
                                              deal['gatePass'],
                                              style: GoogleFonts.sourceCodePro(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF064E3B)),
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
                                    if (isChat && deal['convo'] != null)
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(MaterialPageRoute(
                                            builder: (_) => DirectChatDetailScreen(
                                              conversation: deal['convo'],
                                              currentUser: widget.user,
                                            ),
                                          ));
                                        },
                                        icon: const Icon(Icons.chat_rounded, size: 14, color: AppColors.primary),
                                        label: Text('Open Chat', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      )
                                    else
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

  Widget _buildEmptyState() {
    String title = 'No Active Deals in this Stage';
    String desc = 'When prospects book walkthroughs or fund escrows, they appear here in real-time.';
    if (_selectedStage == 'inspection') {
      title = 'No Walkthroughs Scheduled';
      desc = 'When tenants or buyers request an inspection on your listings, their 6-digit gate passes and contact details appear here.';
    } else if (_selectedStage == 'escrow') {
      title = 'No Funds in Escrow';
      desc = 'When a client pays rent or a property purchase deposit into the Escrow Vault, your protected commission is tracked here.';
    } else if (_selectedStage == 'closed') {
      title = 'No Settled Deals Yet';
      desc = 'When an inspection is verified and the digital lease is signed, your commission is disbursed to your Commissions Vault.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hub_outlined, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                PartnerLegalModal.generateMandateAgreementPdf(context);
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
              label: Text(
                'Generate Mandate Agreement (PDF)',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF064E3B),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
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
