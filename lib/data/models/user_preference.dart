import 'package:flutter/foundation.dart';

/// 사용자 설정 모델
class UserPreference {
  final String userId;
  final List<String> favoriteKeywords; // 관심 키워드
  final String alertLevel; // "high", "medium", "low"
  final bool notificationsEnabled;
  final bool darkMode;
  final String language; // "ko", "en"
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  UserPreference({
    required this.userId,
    this.favoriteKeywords = const [],
    this.alertLevel = 'medium',
    this.notificationsEnabled = false,
    this.darkMode = false,
    this.language = 'ko',
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  /// JSON에서 UserPreference 객체 생성
  factory UserPreference.fromJson(Map<String, dynamic> json) {
    return UserPreference(
      userId: json['userId'] as String? ?? '',
      favoriteKeywords: List<String>.from(
        json['favoriteKeywords'] as List? ?? [],
      ),
      alertLevel: json['alertLevel'] as String? ?? 'medium',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      darkMode: json['darkMode'] as bool? ?? false,
      language: json['language'] as String? ?? 'ko',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastUpdatedAt:
          DateTime.tryParse(json['lastUpdatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// UserPreference 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'favoriteKeywords': favoriteKeywords,
      'alertLevel': alertLevel,
      'notificationsEnabled': notificationsEnabled,
      'darkMode': darkMode,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  /// 복사본 생성
  UserPreference copyWith({
    String? userId,
    List<String>? favoriteKeywords,
    String? alertLevel,
    bool? notificationsEnabled,
    bool? darkMode,
    String? language,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return UserPreference(
      userId: userId ?? this.userId,
      favoriteKeywords: favoriteKeywords ?? this.favoriteKeywords,
      alertLevel: alertLevel ?? this.alertLevel,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  String toString() => 'UserPreference(userId: $userId, language: $language)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreference &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          listEquals(favoriteKeywords, other.favoriteKeywords) &&
          alertLevel == other.alertLevel &&
          notificationsEnabled == other.notificationsEnabled &&
          darkMode == other.darkMode &&
          language == other.language &&
          createdAt == other.createdAt &&
          lastUpdatedAt == other.lastUpdatedAt;

  @override
  int get hashCode => Object.hash(
    userId,
    Object.hashAll(favoriteKeywords),
    alertLevel,
    notificationsEnabled,
    darkMode,
    language,
    createdAt,
    lastUpdatedAt,
  );
}
