import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Accent
  static const Color primary = Color(0xFF6366F1); // Modern Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color secondary = Color(0xFFF43F5E); // Campus Rose / Like
  static const Color secondaryLight = Color(0xFFFB7185);

  static const Color accent = Color(0xFF10B981); // Emerald / Match / Online
  static const Color warning = Color(0xFFF59E0B); // Amber / Gold Crown

  // Light Theme Neutrals
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Dark Theme Neutrals
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);

  // Status & Actions
  static const Color likeGreen = Color(0xFF10B981);
  static const Color skipRed = Color(0xFFEF4444);
  static const Color superStar = Color(0xFF38BDF8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heartGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
