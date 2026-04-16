/// 알림 모델
class Alert {
  final String id;
  final String keyword;
  final String region;
  final String title;
  final String message;
  final String? newsUrl; // 원본 기사 URL (속보/키워드 알림 전용)
  final int riskLevel; // 1 (낮음) ~ 5 (높음)
  final String
  alertType; // "keyword_surge", "sentiment_change", "breaking_news"
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final double changeRate; // 변동률
  final int currentMentionCount;
  final int previousMentionCount;

  Alert({
    required this.id,
    required this.keyword,
    required this.region,
    required this.title,
    required this.message,
    this.newsUrl,
    required this.riskLevel,
    required this.alertType,
    required this.createdAt,
    this.readAt,
    required this.isRead,
    required this.changeRate,
    required this.currentMentionCount,
    required this.previousMentionCount,
  });

  /// JSON에서 Alert 객체 생성
  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String? ?? '',
      keyword: json['keyword'] as String? ?? '',
      region: json['region'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      newsUrl: json['newsUrl'] as String?,
      riskLevel: json['riskLevel'] as int? ?? 3,
      alertType: json['alertType'] as String? ?? 'keyword_surge',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      isRead: json['isRead'] as bool? ?? false,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0.0,
      currentMentionCount: json['currentMentionCount'] as int? ?? 0,
      previousMentionCount: json['previousMentionCount'] as int? ?? 0,
    );
  }

  /// Alert 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyword': keyword,
      'region': region,
      'title': title,
      'message': message,
      'newsUrl': newsUrl,
      'riskLevel': riskLevel,
      'alertType': alertType,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isRead': isRead,
      'changeRate': changeRate,
      'currentMentionCount': currentMentionCount,
      'previousMentionCount': previousMentionCount,
    };
  }

  /// 복사본 생성
  Alert copyWith({
    String? id,
    String? keyword,
    String? region,
    String? title,
    String? message,
    String? newsUrl,
    int? riskLevel,
    String? alertType,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isRead,
    double? changeRate,
    int? currentMentionCount,
    int? previousMentionCount,
  }) {
    return Alert(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      region: region ?? this.region,
      title: title ?? this.title,
      message: message ?? this.message,
      newsUrl: newsUrl ?? this.newsUrl,
      riskLevel: riskLevel ?? this.riskLevel,
      alertType: alertType ?? this.alertType,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      changeRate: changeRate ?? this.changeRate,
      currentMentionCount: currentMentionCount ?? this.currentMentionCount,
      previousMentionCount: previousMentionCount ?? this.previousMentionCount,
    );
  }

  /// 위험도 텍스트 및 색상
  String getRiskText() {
    switch (riskLevel) {
      case 5:
        return '⛔ 긴급';
      case 4:
        return '🔴 높음';
      case 3:
        return '🟠 중간';
      case 2:
        return '🟡 낮음';
      default:
        return '🟢 매우낮음';
    }
  }

  /// 알림 타입 텍스트
  String getAlertTypeText() {
    switch (alertType) {
      case 'keyword_surge':
        return '키워드 급상승';
      case 'sentiment_change':
        return '감정 변화';
      case 'breaking_news':
        return '속보';
      default:
        return '일반 알림';
    }
  }

  @override
  String toString() =>
      'Alert(keyword: $keyword, region: $region, riskLevel: $riskLevel)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alert && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
