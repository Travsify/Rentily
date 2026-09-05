import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'tier_upgrade_modal.dart';

class TierUpgradeBanner extends StatefulWidget {
  final UserProfile user;
  final int? currentTier;
  final VoidCallback? onUpgradeComplete;

  const TierUpgradeBanner({
    super.key,
    required this.user,
    this.currentTier,
    this.onUpgradeComplete,
  });

  @override
  State<TierUpgradeBanner> createState() => _TierUpgradeBannerState();
}

class _TierUpgradeBannerState extends State<TierUpgradeBanner> {
  int _tier = 1;

  @override
  void initState() {
    super.initState();
    _tier = widget.currentTier ?? widget.user.mapleradTier;
    if (_tier == 0 && (widget.user.isVerified || widget.user.bvnVerified)) {
      _tier = 1;
    }
    _checkServerTier();
  }

  @override
  void didUpdateWidget(covariant TierUpgradeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTier != null && widget.currentTier != _tier) {
      setState(() => _tier = widget.currentTier!);
    }
  }

  Future<void> _checkServerTier() async {
    try {
      final status = await ApiService.fetchTierStatus(widget.user.email);
      if (mounted) {
        final serverTier = (status['tier'] as num?)?.toInt() ?? 0;
        if (serverTier > 0 && serverTier != _tier) {
          setState(() => _tier = serverTier);
        }
      }
    } catch (_) {}
  }

  void _openUpgradeModal() {
    HapticFeedback.lightImpact();
    TierUpgradeModal.show(
      context,
      user: widget.user,
      currentTier: _tier,
      onSuccess: () {
        _checkServerTier();
        widget.onUpgradeComplete?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tier >= 3) {
      // Sleek verified badge for users who are already Tier 3
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tier 3 Verified Escrow • ₦5,000,000 Daily Limit Active',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF166534),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currentLimit = _tier == 2 ? '₦200,000' : '₦50,000';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openUpgradeModal,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 11, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 4),
                          Text(
                            'TIER $_tier ($currentLimit LIMIT)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: const Color(0xFFFBBF24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '⚡ UNLOCK ₦5,000,000',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Main headline
                Text(
                  'Upgrade Account to Tier 3',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Avoid transfer limits on rent and high-value payments. Tier 3 gives you ₦5M daily and unlimited monthly volume.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // CTA Action Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0D5C46),
                              Color(0xFF10B981),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'Upgrade to Tier 3 Now',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
