/// 키워드 모델
class Keyword {
  final String id;
  final String name;
  final int mentionCount; // 언급 횟수
  final double changeRate; // 변동률 (%)
  final List<String> relatedRegions; // 관련 지역
  final String category; // "에너지", "정치", "군사" 등
  final int riskLevel; // 1 (낮음) ~ 5 (높음)
  final DateTime lastUpdatedAt;
  final Map<String, int> hourlyMentions; // { "00": 10, "01": 12, ... }
  final Map<String, int> dailyMentions; // { "2025-03-21": 100, ... }

  Keyword({
    required this.id,
    required this.name,
    required this.mentionCount,
    required this.changeRate,
    required this.relatedRegions,
    required this.category,
    required this.riskLevel,
    required this.lastUpdatedAt,
    this.hourlyMentions = const {},
    this.dailyMentions = const {},
  });

  /// JSON에서 Keyword 객체 생성
  factory Keyword.fromJson(Map<String, dynamic> json) {
    return Keyword(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mentionCount: json['mentionCount'] as int? ?? 0,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0.0,
      relatedRegions: List<String>.from(json['relatedRegions'] as List? ?? []),
      category: json['category'] as String? ?? '',
      riskLevel: json['riskLevel'] as int? ?? 3,
      lastUpdatedAt:
          DateTime.tryParse(json['lastUpdatedAt'] as String? ?? '') ??
          DateTime.now(),
      hourlyMentions: Map<String, int>.from(
        (json['hourlyMentions'] as Map?)?.cast<String, int>() ?? {},
      ),
      dailyMentions: Map<String, int>.from(
        (json['dailyMentions'] as Map?)?.cast<String, int>() ?? {},
      ),
    );
  }

  /// Keyword 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mentionCount': mentionCount,
      'changeRate': changeRate,
      'relatedRegions': relatedRegions,
      'category': category,
      'riskLevel': riskLevel,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'hourlyMentions': hourlyMentions,
      'dailyMentions': dailyMentions,
    };
  }

  /// 복사본 생성
  Keyword copyWith({
    String? id,
    String? name,
    int? mentionCount,
    double? changeRate,
    List<String>? relatedRegions,
    String? category,
    int? riskLevel,
    DateTime? lastUpdatedAt,
    Map<String, int>? hourlyMentions,
    Map<String, int>? dailyMentions,
  }) {
    return Keyword(
      id: id ?? this.id,
      name: name ?? this.name,
      mentionCount: mentionCount ?? this.mentionCount,
      changeRate: changeRate ?? this.changeRate,
      relatedRegions: relatedRegions ?? this.relatedRegions,
      category: category ?? this.category,
      riskLevel: riskLevel ?? this.riskLevel,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      hourlyMentions: hourlyMentions ?? this.hourlyMentions,
      dailyMentions: dailyMentions ?? this.dailyMentions,
    );
  }

  /// 위험도 텍스트 변환
  String getRiskText() {
    switch (riskLevel) {
      case 5:
        return '매우 높음 🔴';
      case 4:
        return '높음 🟠';
      case 3:
        return '중간 🟡';
      case 2:
        return '낮음 🟢';
      default:
        return '매우 낮음 🟢';
    }
  }

  /// 변동률 텍스트 변환 (증가/감소)
  String getChangeText() {
    if (changeRate > 0) {
      return '↑ +${changeRate.toStringAsFixed(1)}%';
    } else if (changeRate < 0) {
      return '↓ ${changeRate.toStringAsFixed(1)}%';
    }
    return '→ 0%';
  }

  @override
  String toString() =>
      'Keyword(name: $name, mentionCount: $mentionCount, changeRate: $changeRate%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Keyword && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
