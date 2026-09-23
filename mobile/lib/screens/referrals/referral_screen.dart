import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';

class ReferralScreen extends StatefulWidget {
  final UserProfile? user;

  const ReferralScreen({super.key, this.user});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  UserProfile? _currentUser;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'referralCode': 'RENTILLY',
    'shareLink': 'https://myrentilly.com',
    'totalReferrals': 0,
    'successfulReferrals': 0,
    'pendingReferrals': 0,
    'totalEarned': 0,
    'recentReferrals': []
  };
  Map<String, dynamic> _config = {
    'enabled': true,
    'instantEarning': true,
    'signupBonusAmount': 1000,
    'referrerBonusAmount': 500,
  };

  final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // 1. Resolve user profile
    UserProfile? user = widget.user ?? await AuthService.getCurrentUser();
    _currentUser = user;

    if (user != null) {
      final identifier = user.id.isNotEmpty ? user.id : user.email;
      final results = await Future.wait([
        AuthService.getReferralStats(identifier),
        AuthService.getReferralConfig()
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0];
          _config = results[1];
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String get _referralCode {
    if (_stats['referralCode'] != null && _stats['referralCode'].toString().isNotEmpty) {
      return _stats['referralCode'].toString();
    }
    return _currentUser?.displayReferralCode ?? 'RENTILLY';
  }

  void _copyReferralCode() {
    final code = _referralCode;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Referral code $code copied to clipboard! 📋',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareReferral() {
    final code = _referralCode;
    final signupBonus = _config['signupBonusAmount'] ?? 1000;
    final shareMsg =
        'Join me on Rentilly — Nigeria\'s zero-agent real estate & verified escrow platform!\n\n'
        'Use my referral code *$code* when signing up to get an instant *₦${NumberFormat('#,###').format(signupBonus)} welcome reward* credited to your wallet upon verification.\n\n'
        'Download Rentilly: https://myrentilly.com';

    Share.share(shareMsg, subject: 'Get ₦${NumberFormat('#,###').format(signupBonus)} Welcome Bonus on Rentilly');
  }

  @override
  Widget build(BuildContext context) {
    final signupBonus = _config['signupBonusAmount'] ?? 1000;
    final referrerBonus = _config['referrerBonusAmount'] ?? 500;
    final totalEarned = (_stats['totalEarned'] as num?)?.toDouble() ?? 0.0;
    final totalReferrals = (_stats['totalReferrals'] as num?)?.toInt() ?? 0;
    final successfulReferrals = (_stats['successfulReferrals'] as num?)?.toInt() ?? 0;
    final pendingReferrals = (_stats['pendingReferrals'] as num?)?.toInt() ?? 0;
    final recentReferrals = (_stats['recentReferrals'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Refer & Earn',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Promo Banner Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Earn ₦${NumberFormat('#,###').format(referrerBonus)} For Every Friend',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Friends get ₦${NumberFormat('#,###').format(signupBonus)} instant welcome bonus credited to their wallet upon KYC verification.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Referral Code Display & Actions
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0F1D),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'YOUR EXCLUSIVE CODE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _referralCode,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _copyReferralCode,
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                                  tooltip: 'Copy Code',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Share Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _shareReferral,
                              icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                              label: Text(
                                'Share Referral Code',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Earnings & Invites Overview Card
                    Text(
                      'YOUR REFERRAL METRICS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Total Earned',
                            value: currencyFormatter.format(totalEarned),
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Total Invites',
                            value: '$totalReferrals',
                            icon: Icons.people_alt_rounded,
                            iconColor: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Verified',
                            value: '$successfulReferrals',
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Pending KYC',
                            value: '$pendingReferrals',
                            icon: Icons.hourglass_top_rounded,
                            iconColor: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // How it works 3-step guide
                    Text(
                      'HOW IT WORKS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Column(
                        children: [
                          _buildStepRow(
                            step: '1',
                            title: 'Share your code',
                            desc: 'Send your exclusive referral code to friends, family, and associates.',
                          ),
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildStepRow(
                            step: '2',
                            title: 'They Sign Up & Verify',
                            desc: 'Your friend registers on Rentilly and completes instant NIN/BVN KYC.',
                          ),
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildStepRow(
                            step: '3',
                            title: 'Instant Cash Credited',
                            desc: 'They get ₦${NumberFormat('#,###').format(signupBonus)} instant welcome bonus, and you get ₦${NumberFormat('#,###').format(referrerBonus)} credited right into your wallet!',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recent Referrals List
                    Text(
                      'RECENT REFERRALS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (recentReferrals.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.group_outlined, size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'No referrals yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Share your referral code to start earning cash rewards today!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentReferrals.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = recentReferrals[index];
                            final name = item['name'] ?? 'Invited User';
                            final isVerified = item['status'] == 'paid' || item['status'] == 'completed';
                            final amount = item['amount'] ?? 500;
                            final dateStr = item['date'] != null
                                ? DateFormat('MMM d, yyyy').format(DateTime.tryParse(item['date']) ?? DateTime.now())
                                : 'Recent';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                child: Icon(
                                  isVerified ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                                  color: isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '$dateStr • ${isVerified ? "KYC Verified" : "Pending Verification"}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: Text(
                                '+₦${NumberFormat('#,###').format(amount)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isVerified ? const Color(0xFF16A34A) : AppColors.textMuted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
