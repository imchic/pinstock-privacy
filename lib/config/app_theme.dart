import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// 앱 테마 설정
class AppTheme {
  // 주요 색상 — 로고 그라디언트 기반
  static const Color primaryColor = Color(0xFF3D9DF5); // 로고 스카이블루
  static const Color secondaryColor = Color(0xFF8A3FEB); // 로고 바이올렛
  static const Color accentColor = Color(0xFFBF44F0); // 로고 핑크-퍼플

  // 상태 색상
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color infoColor = Color(0xFF2196F3);

  // 위험도별 색상
  static const Color riskLevel5 = Color(0xFF8B0000); // 어두운 빨강 (극도)
  static const Color riskLevel4 = Color(0xFFFF0000); // 빨강 (높음)
  static const Color riskLevel3 = Color(0xFFFFA500); // 주황 (중간)
  static const Color riskLevel2 = Color(0xFFFFFF00); // 노랑 (낮음)
  static const Color riskLevel1 = Color(0xFF00CC00); // 녹색 (매우낮음)

  // 감정 색상
  static const Color sentimentPositive = Color(0xFF4CAF50);
  static const Color sentimentNegative = Color(0xFFF44336);
  static const Color sentimentNeutral = Color(0xFF9E9E9E);

  // 배경 색상
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFAFAFA);

  // 텍스트 색상
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // 다크 모드 색상
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);

  // 라이트 테마
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      // 텍스트 테마 설정 - 폰트 크기를 크게 설정
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 2,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
      ),
      chipTheme: ChipThemeData.fromDefaults(
        primaryColor: primaryColor,
        secondaryColor: primaryColor,
        labelStyle: const TextStyle(
          color: Colors.black,
          fontSize: 16, // 칩 텍스트 크기도 증가
        ),
      ),
      // 카드 스타일 설정
      cardTheme: const CardThemeData(elevation: 4, margin: EdgeInsets.all(8)),
      // 리스트 타일 스타일 설정
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(fontSize: 14),
      ),
      extensions: const [AppColors.light],
    );
  }

  // 다크 테마
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      // 다크 모드용 텍스트 테마 설정 - 동일한 폰트 크기
      textTheme: const TextTheme()
          .apply(displayColor: darkTextPrimary, bodyColor: darkTextPrimary)
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: darkTextPrimary,
            ),
            displayMedium: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: darkTextPrimary,
            ),
            displaySmall: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkTextPrimary,
            ),
            headlineLarge: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: darkTextPrimary,
            ),
            headlineMedium: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: darkTextPrimary,
            ),
            headlineSmall: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkTextPrimary,
            ),
            titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: darkTextPrimary,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: darkTextPrimary,
            ),
            titleSmall: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: darkTextPrimary,
            ),
            bodyLarge: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: darkTextPrimary,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: darkTextPrimary,
            ),
            bodySmall: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: darkTextSecondary,
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: darkTextPrimary,
            ),
            labelMedium: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: darkTextSecondary,
            ),
            labelSmall: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: darkTextSecondary,
            ),
          ),
      appBarTheme: const AppBarTheme(
        elevation: 2,
        backgroundColor: darkSurfaceColor,
        foregroundColor: darkTextPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
      ),
      // 다크 모드 카드 스타일
      cardTheme: const CardThemeData(
        elevation: 4,
        margin: EdgeInsets.all(8),
        color: darkSurfaceColor,
      ),
      // 다크 모드 리스트 타일 스타일
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkTextPrimary,
        ),
        subtitleTextStyle: TextStyle(fontSize: 14, color: darkTextSecondary),
      ),
      extensions: const [AppColors.dark],
    );
  }

  // 색상 코드 반환 (위험도 기반)
  static Color getRiskLevelColor(int level) {
    switch (level) {
      case 5:
        return riskLevel5;
      case 4:
        return riskLevel4;
      case 3:
        return riskLevel3;
      case 2:
        return riskLevel2;
      default:
        return riskLevel1;
    }
  }

  // 감정 색상 반환
  static Color getSentimentColor(double score) {
    if (score > 0.3) return sentimentPositive;
    if (score < -0.3) return sentimentNegative;
    return sentimentNeutral;
  }
}
