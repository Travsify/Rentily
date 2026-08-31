import 'package:flutter/material.dart';

class AppColors {
  // --- THE 3 HARMONIOUS SIGNATURE BRAND COLORS ---
  // 1. Deep Emerald Teal: Trust, Institutional Security, Grounded Luxury
  static const Color primary = Color(0xFF0D5C46);
  static const Color primaryDark = Color(0xFF07382B);

  // 2. Electric Mint: Freshness, Growth, Active Financial Life, Vibrant Accents
  static const Color primaryLight = Color(0xFF10B981);
  static const Color mint = Color(0xFF10B981);

  // 3. Radiant Sunset Amber: Warmth, Keys, High-Value Highlights, Real Estate
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentGoldDark = Color(0xFFD97706);

  // --- CLEAN, BRIGHT PORCELAIN SURFACES (NEVER WHITE TEXT ON WHITE) ---
  static const Color backgroundDark = Color(0xFFF9FAFB); // Pristine Soft Off-White Canvas
  static const Color surfaceDark = Color(0xFFFFFFFF); // Crisp Pure White Card
  static const Color cardDark = Color(0xFFFFFFFF);
  static const Color borderDark = Color(0xFFE5E7EB); // Delicate Clean Border

  // --- HIGH-CONTRAST READABLE TYPOGRAPHY (SHARP INK BLACK) ---
  static const Color textPrimary = Color(0xFF111827); // Deep Ink Black (Always 100% visible on light)
  static const Color textSecondary = Color(0xFF4B5563); // Crisp Slate Gray
  static const Color textMuted = Color(0xFF9CA3AF); // Subtle Gray

  // Utility Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0D5C46);
}
