import 'package:intl/intl.dart';

/// 뉴스 모델
class News {
  final String id;
  final String title;
  final String description;
  final String content;
  final String source;
  final String imageUrl;
  final String newsUrl;
  final DateTime publishedAt;
  final DateTime createdAt;
  final List<String> keywords;
  final List<String> regions;
  final double sentimentScore; // -1.0 (부정) ~ 1.0 (긍정)
  final int importanceLevel; // 1 (낮음) ~ 5 (높음)
  final String category; // "중동", "미국", "에너지" 등
  final double stockRelevanceScore; // 0.0 (관련없음) ~ 1.0 (매우 관련)
  final bool isBookmarked;
  final String? memo;

  // 번역된 필드
  final String? translatedTitle;
  final String? translatedDescription;

  News({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.source,
    required this.imageUrl,
    required this.newsUrl,
    required this.publishedAt,
    required this.createdAt,
    required this.keywords,
    required this.regions,
    required this.sentimentScore,
    required this.importanceLevel,
    required this.category,
    this.stockRelevanceScore = 0.0,
    this.isBookmarked = false,
    this.memo,
    this.translatedTitle,
    this.translatedDescription,
  });

  /// JSON에서 News 객체 생성
  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      content: json['content'] as String? ?? '',
      source: json['source'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      newsUrl: json['newsUrl'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      keywords: List<String>.from(json['keywords'] as List? ?? []),
      regions: List<String>.from(json['regions'] as List? ?? []),
      sentimentScore: (json['sentimentScore'] as num?)?.toDouble() ?? 0.0,
      importanceLevel: json['importanceLevel'] as int? ?? 3,
      category: json['category'] as String? ?? '',
      stockRelevanceScore:
          (json['stockRelevanceScore'] as num?)?.toDouble() ?? 0.0,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      memo: json['memo'] as String?,
    );
  }

  /// News 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'source': source,
      'imageUrl': imageUrl,
      'newsUrl': newsUrl,
      'publishedAt': publishedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'keywords': keywords,
      'regions': regions,
      'sentimentScore': sentimentScore,
      'importanceLevel': importanceLevel,
      'category': category,
      'stockRelevanceScore': stockRelevanceScore,
      'isBookmarked': isBookmarked,
      'memo': memo,
    };
  }

  /// 복사본 생성
  News copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    String? source,
    String? imageUrl,
    String? newsUrl,
    DateTime? publishedAt,
    DateTime? createdAt,
    List<String>? keywords,
    List<String>? regions,
    double? sentimentScore,
    int? importanceLevel,
    String? category,
    double? stockRelevanceScore,
    bool? isBookmarked,
    String? memo,
    String? translatedTitle,
    String? translatedDescription,
  }) {
    return News(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      source: source ?? this.source,
      imageUrl: imageUrl ?? this.imageUrl,
      newsUrl: newsUrl ?? this.newsUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      keywords: keywords ?? this.keywords,
      regions: regions ?? this.regions,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      importanceLevel: importanceLevel ?? this.importanceLevel,
      category: category ?? this.category,
      stockRelevanceScore: stockRelevanceScore ?? this.stockRelevanceScore,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      memo: memo ?? this.memo,
      translatedTitle: translatedTitle ?? this.translatedTitle,
      translatedDescription:
          translatedDescription ?? this.translatedDescription,
    );
  }

  /// 발행 시간 포맷팅 (예: "2시간 전")
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MMM d').format(publishedAt);
    }
  }

  /// 감정 점수 텍스트 변환
  String getSentimentText() {
    if (sentimentScore > 0.3) return '긍정';
    if (sentimentScore < -0.3) return '부정';
    return '중립';
  }

  @override
  String toString() => 'News(id: $id, title: $title, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is News && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
