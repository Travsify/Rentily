import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class TierUpgradeBanner extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
