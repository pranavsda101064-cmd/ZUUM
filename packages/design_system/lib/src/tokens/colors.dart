import 'package:flutter/material.dart';

/// Zuum color tokens — "Obsidian Monochrome & Lime Volt" (v2).
///
/// Bold, tech-forward, minimalist: near-black CTAs, off-white canvas,
/// carbon-ink type, and a single volt-lime signal reserved for
/// live/rating/surge/PIN moments.
abstract final class ZColors {
  // brand / action
  static const primary = Color(0xFF111827); // Obsidian Black
  static const primaryPressed = Color(0xFF1F2937);
  static const onPrimary = Color(0xFFFFFFFF);
  static const dark = Color(0xFF090D16); // Carbon Ink
  static const accent = Color(0xFFF3F4F6); // Light Neutral (selected tint)
  static const background = Color(0xFFF9FAFB); // Off-White canvas
  static const highlight = Color(0xFF84CC16); // Volt Lime
  static const surface = Color(0xFFFFFFFF);

  // semantic
  static const error = Color(0xFFB91C1C);
  static const success = Color(0xFF15803D);
  static const warning = highlight;

  // text
  static const textPrimary = dark;
  static const textSecondary = Color(0xFF4B5563);
  static const textTertiary = Color(0xFF6B7280);
  static const onDark = Color(0xFFFFFFFF);
  static const onDarkSecondary = Color(0xFF9CA3AF);

  // structure
  static const divider = Color(0xFFE5E7EB);
  static const scrim = Color(0x66090D16);
  static const disabled = Color(0xFFD1D5DB);
  static const skeleton = Color(0xFFF3F4F6);

  // derived tints
  static const primaryTint = Color(0xFFF3F4F6);
  static const highlightTint = Color(0xFFF3FBE4);
  static const errorTint = Color(0xFFFEE9E7);
  static const successTint = Color(0xFFE8F5EC);

  /// Dark raised surface used inside dark cards/bars (wallet chips, sheets).
  static const darkRaised = Color(0xFF1F2937);

  /// Dark-scheme scaffolding (admin/partner reuse; light-only today).
  static const darkSurface = Color(0xFF111827);
  static const darkOutline = Color(0xFF374151);

  // elevation
  static const shadow = Color(0x14090D16);
  static const shadowSoft = Color(0x0A090D16);
  static const shadowStrong = Color(0x33090D16);
}
