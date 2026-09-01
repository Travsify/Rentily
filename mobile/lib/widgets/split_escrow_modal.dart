import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/roommate_post.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';

class SplitEscrowModal extends StatefulWidget {
  final RoommatePost post;
  final UserProfile user;

  const SplitEscrowModal({super.key, required this.post, required this.user});

  static void show(BuildContext context, {required RoommatePost post, required UserProfile user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SplitEscrowModal(post: post, user: user),
    );
  }

  @override
  State<SplitEscrowModal> createState() => _SplitEscrowModalState();
}

class _SplitEscrowModalState extends State<SplitEscrowModal> {
  bool _isLocking = false;
  final NumberFormat _currencyFormat = NumberFormat('#,###.00');

  void _confirmSplitEscrow() async {
    setState(() => _isLocking = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    await NotificationService.addNotification(
      title: 'Joint Split-Escrow Initiated 👥🔒',
      message: 'Your 50% split deposit of ₦${_currencyFormat.format(widget.post.budgetShare)} was locked into joint living escrow with ${widget.post.userName} for ${widget.post.bedroomType}.',
      category: 'transaction',
      metadata: {
        'post_id': widget.post.id,
        'partner': widget.post.userName,
        'share': '₦${_currencyFormat.format(widget.post.budgetShare)}',
        'property': widget.post.bedroomType,
        'escrow_status': 'AWAITING_PARTNER_MATCH',
      },
    );

    if (!mounted) return;
    setState(() => _isLocking = false);
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text('Split-Escrow Locked!', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your 50% rent deposit has been securely escrowed. Rentilly has notified ${widget.post.userName} to match their half.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Protected by 0% Caution Living Escrow Protocol. Funds are only disbursed when both parties sign.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myShare = widget.post.budgetShare;
    final totalRent = widget.post.totalRent;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
                      child: const Icon(Icons.handshake_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Split-the-Scroll Escrow Contract',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Dual-Party Living Escrow Agreement',
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

          // Content Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Property & Location Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
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
                              color: AppColors.accentOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '50 / 50 LEASE SPLIT',
                              style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accentOrange),
                            ),
                          ),
                          Text(
                            'Total Rent: ₦${_currencyFormat.format(totalRent)}/yr',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.post.bedroomType,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.post.location,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2 Co-Tenants Breakdown
                Text('CO-TENANT SHARES BREAKDOWN', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Roommate A (Host)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(widget.post.userName, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '₦${_currencyFormat.format(myShare)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Roommate B (You)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Me', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '₦${_currencyFormat.format(myShare)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Escrow Safety Guarantees
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildGuaranteeRow(Icons.check_circle_outline_rounded, 'Funds remain protected in living escrow until both parties sign.'),
                      const SizedBox(height: 6),
                      _buildGuaranteeRow(Icons.check_circle_outline_rounded, '0% illegal caution fee & 0% hidden middleman markups.'),
                      const SizedBox(height: 6),
                      _buildGuaranteeRow(Icons.check_circle_outline_rounded, 'Legally recognized joint tenancy contract generated automatically.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Confirm Escrow Lock Button
                ElevatedButton(
                  onPressed: _isLocking ? null : _confirmSplitEscrow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLocking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.accentOrange),
                            const SizedBox(width: 8),
                            Text(
                              'Fund 50% Share (₦${NumberFormat('#,###').format(myShare)})',
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

  Widget _buildGuaranteeRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );
}
