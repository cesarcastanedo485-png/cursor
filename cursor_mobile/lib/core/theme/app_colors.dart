import 'package:flutter/material.dart';

/// Semantic color palette for Cursor Mobile (Material 3).
abstract class AppColors {
  // Dark theme (default)
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceVariant = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF7C3AED);
  static const Color darkPrimaryContainer = Color(0xFF5B21B6);
  static const Color darkOnSurface = Color(0xFFE4E4E7);
  static const Color darkOnSurfaceVariant = Color(0xFFA1A1AA);
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkOutline = Color(0xFF3F3F46);

  // Light theme
  static const Color lightSurface = Color(0xFFFAFAFA);
  static const Color lightSurfaceVariant = Color(0xFFF4F4F5);
  static const Color lightPrimary = Color(0xFF6D28D9);
  static const Color lightPrimaryContainer = Color(0xFFEDE9FE);
  static const Color lightOnSurface = Color(0xFF18181B);
  static const Color lightOnSurfaceVariant = Color(0xFF71717A);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightOutline = Color(0xFFE4E4E7);

  // Status badge colors (shared)
  static const Color statusRunning = Color(0xFF22C55E);
  static const Color statusFinished = Color(0xFF3B82F6);
  static const Color statusFailed = Color(0xFFEF4444);
}
