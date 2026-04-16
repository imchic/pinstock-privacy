/// 트렌드 모델
class Trend {
  final String id;
  final String keyword;
  final String region; // 국가/지역 코드 (e.g., "MidEast", "USA", "Asia")
  final DateTime timestamp;
  final int mentionCount;
  final double changeRate; // 변동률 (%)
  final double sentimentAverage; // 평균 감정 점수
  final int totalArticles; // 해당 시간/일의 관련 기사 수
  final List<String> topSources; // 상위 소스들
  final String period; // "1h", "24h", "7d"

  Trend({
    required this.id,
    required this.keyword,
    required this.region,
    required this.timestamp,
    required this.mentionCount,
    required this.changeRate,
    required this.sentimentAverage,
    required this.totalArticles,
    required this.topSources,
    required this.period,
  });

  /// JSON에서 Trend 객체 생성
  factory Trend.fromJson(Map<String, dynamic> json) {
    return Trend(
      id: json['id'] as String? ?? '',
      keyword: json['keyword'] as String? ?? '',
      region: json['region'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      mentionCount: json['mentionCount'] as int? ?? 0,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0.0,
      sentimentAverage: (json['sentimentAverage'] as num?)?.toDouble() ?? 0.0,
      totalArticles: json['totalArticles'] as int? ?? 0,
      topSources: List<String>.from(json['topSources'] as List? ?? []),
      period: json['period'] as String? ?? '1h',
    );
  }

  /// Trend 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyword': keyword,
      'region': region,
      'timestamp': timestamp.toIso8601String(),
      'mentionCount': mentionCount,
      'changeRate': changeRate,
      'sentimentAverage': sentimentAverage,
      'totalArticles': totalArticles,
      'topSources': topSources,
      'period': period,
    };
  }

  /// 복사본 생성
  Trend copyWith({
    String? id,
    String? keyword,
    String? region,
    DateTime? timestamp,
    int? mentionCount,
    double? changeRate,
    double? sentimentAverage,
    int? totalArticles,
    List<String>? topSources,
    String? period,
  }) {
    return Trend(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      region: region ?? this.region,
      timestamp: timestamp ?? this.timestamp,
      mentionCount: mentionCount ?? this.mentionCount,
      changeRate: changeRate ?? this.changeRate,
      sentimentAverage: sentimentAverage ?? this.sentimentAverage,
      totalArticles: totalArticles ?? this.totalArticles,
      topSources: topSources ?? this.topSources,
      period: period ?? this.period,
    );
  }

  /// 급상승 여부 확인 (변동률 > 50%)
  bool isSurging() => changeRate > 50;

  /// 급하락 여부 확인 (변동률 < -30%)
  bool isFalling() => changeRate < -30;

  @override
  String toString() =>
      'Trend(keyword: $keyword, region: $region, mentionCount: $mentionCount, changeRate: $changeRate%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trend && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
