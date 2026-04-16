import 'package:flutter/material.dart';

/// 앱 컬러 팔레트 — ThemeExtension으로 다크/라이트 전환 지원
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceLight;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceLight,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  // ── 상태 색상 (테마 무관) ─────────────────────
  static const Color accent = Color(0xFF5B7BFF); // 로고 블루-인디고
  static const Color success = Color(0xFF22D172);
  static const Color error = Color(0xFFFF4D4D);
  static const Color warning = Color(0xFFFF8C42);
  static const Color info = Color(0xFF4D79FF);
  static const Color green = Color(0xFF22D172);
  static const Color red = Color(0xFFFF4D4D);
  static const Color orange = Color(0xFFFF8C42);

  // ── 다크 팔레트 ───────────────────────────────
  static const AppColors dark = AppColors(
    bg: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceLight: Color(0xFF1E1E1E),
    border: Color(0xFF2C2C2C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF808080),
  );

  // ── 라이트 팔레트 ─────────────────────────────
  static const AppColors light = AppColors(
    bg: Color(0xFFF2F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFECEFF1),
    border: Color(0xFFDDE1E6),
    textPrimary: Color(0xFF0D0D0D),
    textSecondary: Color(0xFF666C75),
  );

  // ── 컨텍스트에서 가져오기 ─────────────────────
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceLight,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

/// BuildContext 편의 extension
extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}
