/// 금융 뉴스 모델 (주식 관련)
class FinanceNews {
  final String id;
  final String title;
  final String description;
  final String source;
  final DateTime publishedAt;
  final DateTime createdAt;
  final String? imageUrl;
  final String? url;
  final List<String> keywords; // ["코스피", "삼성"]
  final List<String> tickers; // ["KOSPI", "SSNLF"]
  final List<String> sectors; // ["기술", "금융"]
  final double sentimentScore; // -1.0 ~ 1.0 (음수: 부정, 양수: 긍정)
  final int importanceLevel; // 1 ~ 5
  final String category; // "earnings", "market", "regulation", "general"
  final bool isBookmarked;

  FinanceNews({
    required this.id,
    required this.title,
    required this.description,
    required this.source,
    required this.publishedAt,
    required this.createdAt,
    this.imageUrl,
    this.url,
    this.keywords = const [],
    this.tickers = const [],
    this.sectors = const [],
    this.sentimentScore = 0.0,
    this.importanceLevel = 3,
    this.category = 'general',
    this.isBookmarked = false,
  });

  /// JSON에서 FinanceNews 객체 생성
  factory FinanceNews.fromJson(Map<String, dynamic> json) {
    return FinanceNews(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      source: json['source'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      imageUrl: json['imageUrl'] as String?,
      url: json['url'] as String?,
      keywords: List<String>.from(json['keywords'] as List? ?? []),
      tickers: List<String>.from(json['tickers'] as List? ?? []),
      sectors: List<String>.from(json['sectors'] as List? ?? []),
      sentimentScore: (json['sentimentScore'] as num?)?.toDouble() ?? 0.0,
      importanceLevel: json['importanceLevel'] as int? ?? 3,
      category: json['category'] as String? ?? 'general',
      isBookmarked: json['isBookmarked'] as bool? ?? false,
    );
  }

  /// FinanceNews 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'source': source,
      'publishedAt': publishedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'imageUrl': imageUrl,
      'url': url,
      'keywords': keywords,
      'tickers': tickers,
      'sectors': sectors,
      'sentimentScore': sentimentScore,
      'importanceLevel': importanceLevel,
      'category': category,
      'isBookmarked': isBookmarked,
    };
  }

  /// 복사본 생성 (특정 필드만 수정)
  FinanceNews copyWith({
    String? id,
    String? title,
    String? description,
    String? source,
    DateTime? publishedAt,
    DateTime? createdAt,
    String? imageUrl,
    String? url,
    List<String>? keywords,
    List<String>? tickers,
    List<String>? sectors,
    double? sentimentScore,
    int? importanceLevel,
    String? category,
    bool? isBookmarked,
  }) {
    return FinanceNews(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      keywords: keywords ?? this.keywords,
      tickers: tickers ?? this.tickers,
      sectors: sectors ?? this.sectors,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      importanceLevel: importanceLevel ?? this.importanceLevel,
      category: category ?? this.category,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
