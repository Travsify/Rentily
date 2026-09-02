import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const AppAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 44.0,
    this.border,
    this.borderRadius,
    this.shape = BoxShape.circle,
  });

  String _getInitials(String rawName) {
    final clean = rawName.trim();
    if (clean.isEmpty) return 'RT';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean.toUpperCase();
  }

  ImageProvider? _resolveImageProvider(String url) {
    try {
      if (url.startsWith('data:image')) {
        final commaIndex = url.indexOf(',');
        if (commaIndex != -1) {
          final base64Data = url.substring(commaIndex + 1);
          final bytes = base64Decode(base64Data);
          return MemoryImage(bytes);
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        return NetworkImage(url);
      } else {
        final file = File(url);
        if (file.existsSync()) {
          return FileImage(file);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final ImageProvider? imageProvider = hasUrl ? _resolveImageProvider(avatarUrl!.trim()) : null;

    final effectiveBorderRadius = shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(12));

    if (imageProvider != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: effectiveBorderRadius,
          border: border ?? Border.all(color: AppColors.primary, width: 1.5),
          color: const Color(0xFFF1F5F9),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback: Initials with Premium Gradient
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: effectiveBorderRadius,
        border: border ?? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.0),
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
