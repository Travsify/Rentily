import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../models/property.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../utils/id_utils.dart';

class PartnerLandlordOnboardModal extends StatefulWidget {
  final UserProfile user;

  const PartnerLandlordOnboardModal({super.key, required this.user});

  static void show(BuildContext context, {required UserProfile user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartnerLandlordOnboardModal(user: user),
    );
  }

  @override
  State<PartnerLandlordOnboardModal> createState() => _PartnerLandlordOnboardModalState();
}

class _PartnerLandlordOnboardModalState extends State<PartnerLandlordOnboardModal> {
  final _landlordPhoneController = TextEditingController();
  final _landlordNameController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,###');
  bool _isLoadingLandlords = true;
  List<Map<String, dynamic>> _onboardedLandlords = [];

  @override
  void initState() {
    super.initState();
    _loadOnboardedLandlords();
  }

  Future<void> _loadOnboardedLandlords() async {
    // 1. Fetch live onboarded landlords from database
    final liveLandlords = await ApiService.fetchPartnerOnboardedLandlords(
      partnerId: widget.user.id,
      email: widget.user.email,
      firmName: widget.user.businessName,
    );

    if (liveLandlords.isNotEmpty) {
      if (mounted) {
        setState(() {
          _onboardedLandlords = liveLandlords;
          _isLoadingLandlords = false;
        });
      }
      return;
    }

    // 2. Fallback to properties grouping
    final allProps = await ApiService.fetchProperties();
    final partnerProps = allProps.where((p) =>
      (p.partnerId != null && p.partnerId == widget.user.id) ||
      (p.ownerId == widget.user.id) ||
      (p.ownerPhone.isNotEmpty && p.ownerPhone == widget.user.phoneNumber)
    ).toList();

    final Map<String, List<Property>> grouped = {};
    for (final p in partnerProps) {
      final key = p.ownerName.isNotEmpty && p.ownerName != 'Property Owner'
          ? p.ownerName
          : (p.ownerPhone.isNotEmpty ? p.ownerPhone : p.ownerId);
      grouped.putIfAbsent(key, () => []).add(p);
    }

    final List<Map<String, dynamic>> list = [];
    grouped.forEach((ownerName, props) {
      double totalCommission = 0.0;
      for (final p in props) {
        final rate = p.purpose == 'rent' ? 0.025 : 0.02;
        totalCommission += p.basePrice * rate;
      }
      list.add({
        'name': ownerName,
        'phone': props.first.ownerPhone,
        'unitCount': props.length,
        'properties': props,
        'lockedCommission': totalCommission,
      });
    });

    if (mounted) {
      setState(() {
        _onboardedLandlords = list;
        _isLoadingLandlords = false;
      });
    }
  }

  @override
  void dispose() {
    _landlordPhoneController.dispose();
    _landlordNameController.dispose();
    super.dispose();
  }

  void _shareViaWhatsApp() {
    final businessName = widget.user.businessName != null && widget.user.businessName!.trim().isNotEmpty
        ? widget.user.businessName!.trim()
        : (widget.user.fullName.trim().isNotEmpty ? widget.user.fullName.trim() : 'Accredited Partner Enterprise');
    final partnerId = IdUtils.formatOpsId(widget.user.id, isPartner: true);
    final inviteLink = 'https://myrentilly.com/invite/landlord?partner_id=$partnerId&firm=${Uri.encodeComponent(businessName)}';

    final message = 'Dear Property Owner,\n\n'
        'Kindly register and list your properties on Rentilly through our accredited firm link below:\n\n'
        '🔗 $inviteLink\n\n'
        'Why list on Rentilly with $businessName?\n'
        '• 100% verified & audited tenants\n'
        '• Nigerian Tenancy Law compliant digital agreements\n'
        '• Direct rent escrow payout to your bank account\n'
        '• Zero agency disputes — $businessName remains your official accredited managing partner.\n\n'
        'Accreditation ID: $partnerId';

    Share.share(message);
  }

  void _copyLink() {
    final businessName = widget.user.businessName != null && widget.user.businessName!.trim().isNotEmpty
        ? widget.user.businessName!.trim()
        : (widget.user.fullName.trim().isNotEmpty ? widget.user.fullName.trim() : 'Accredited Partner Enterprise');
    final partnerId = IdUtils.formatOpsId(widget.user.id, isPartner: true);
    final inviteLink = 'https://myrentilly.com/invite/landlord?partner_id=$partnerId&firm=${Uri.encodeComponent(businessName)}';

    Clipboard.setData(ClipboardData(text: inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Landlord onboarding link copied to clipboard! 🔗', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessName = widget.user.businessName != null && widget.user.businessName!.trim().isNotEmpty
        ? widget.user.businessName!.trim()
        : (widget.user.fullName.trim().isNotEmpty ? widget.user.fullName.trim() : 'Accredited Partner Enterprise');
    final partnerId = IdUtils.formatOpsId(widget.user.id, isPartner: true);
    final inviteLink = 'https://myrentilly.com/invite/landlord?partner_id=$partnerId';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Onboard My Landlord 🔗',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Auto-Link Properties & Lock Commissions',
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

          // Body Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Hero Card Explaining the Feature
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF4ADE80)),
                          const SizedBox(width: 6),
                          Text(
                            'GUARANTEED COMMISSION PROTECTION',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: const Color(0xFF4ADE80),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bring Your Landlords.\nNever Chase Commissions Again.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, height: 1.25),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'When your landlords register through your link, all their properties are permanently linked to $businessName. Rentilly escrow disburses your 2.5% rent / 2.0% sale commission automatically upon key handover.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Link Generator Box
                Text(
                  'YOUR UNIQUE ONBOARDING LINK',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          inviteLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                        onPressed: _copyLink,
                        tooltip: 'Copy Link',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareViaWhatsApp,
                        icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        label: Text('Share via WhatsApp', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyLink,
                        icon: const Icon(Icons.copy_all_rounded, size: 16, color: AppColors.primary),
                        label: Text('Copy Link', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Onboarded Landlord Portfolio Tracker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MY ONBOARDED LANDLORDS',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isLoadingLandlords
                            ? 'Scanning...'
                            : '${_onboardedLandlords.length} Onboarded Landlord${_onboardedLandlords.length == 1 ? '' : 's'}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoadingLandlords) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                ] else if (_onboardedLandlords.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 36, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No Landlords Onboarded Yet',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share your unique link with your landlord network. Once they register, they appear here and their listings are locked under your mandate.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ..._onboardedLandlords.map((client) {
                    final name = client['name']?.toString() ?? 'Verified Landlord';
                    final phone = client['phone']?.toString() ?? '';
                    final units = client['unitCount'] as int? ?? 0;
                    final comm = (client['lockedCommission'] as num?)?.toDouble() ?? 0.0;

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
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'L',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: Text(
                                        'MANDATE ACTIVE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone.isNotEmpty ? '$phone • $units Units Listed' : (units > 0 ? '$units Units Under Mandate' : 'Registered Landlord'),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                if (comm > 0)
                                  Text(
                                    'Locked Commission: ₦${_currencyFormat.format(comm)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  )
                                else
                                  Text(
                                    'Awaiting First Listing 🏠',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
