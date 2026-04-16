import '../data/models/index.dart';
import 'keyword_extractor_service.dart';
import 'trend_analyzer_service.dart';

/// 키워드 트렌드 계산 서비스
class KeywordTrendService {
  /// 뉴스 리스트에서 키워드 트렌드 생성
  static List<Keyword> extractKeywordTrends(
    List<News> newsList, {
    int limit = 10,
    Map<String, int>? previousMentionCounts,
  }) {
    if (newsList.isEmpty) return [];

    final keywordStats = <String, _KeywordStat>{};

    // 뉴스에서 키워드 추출 및 통계 계산
    for (final news in newsList) {
      final hour = news.publishedAt.hour.toString().padLeft(2, '0');
      final dayKey = news.publishedAt.toIso8601String().split('T')[0];

      for (final keyword in news.keywords) {
        final normalized = KeywordExtractorService.normalizeKeyword(keyword);

        if (keywordStats.containsKey(normalized)) {
          keywordStats[normalized]!._incrementMention(
            news.importanceLevel,
            news.sentimentScore,
            hour,
            dayKey,
          );
        } else {
          keywordStats[normalized] = _KeywordStat(
            name: normalized,
            importanceLevel: news.importanceLevel,
            sentimentScore: news.sentimentScore,
            hour: hour,
            dayKey: dayKey,
          );
        }
      }
    }

    // Keyword 모델로 변환
    final keywords = keywordStats.entries.map((entry) {
      final stat = entry.value;
      final previousCount =
          previousMentionCounts?[entry.key] ?? stat.mentionCount;

      return Keyword(
        id: entry.key,
        name: entry.key,
        mentionCount: stat.mentionCount,
        changeRate: TrendAnalyzerService.calculateChangeRate(
          previousCount,
          stat.mentionCount,
        ),
        relatedRegions: stat.regions.toList(),
        category: stat.category,
        riskLevel: TrendAnalyzerService.calculateRiskLevel(
          stat.averageSentiment,
          TrendAnalyzerService.calculateChangeRate(
            previousCount,
            stat.mentionCount,
          ),
          stat.averageImportance,
        ),
        lastUpdatedAt: DateTime.now(),
        hourlyMentions: stat.hourlyMentions,
        dailyMentions: stat.dailyMentions,
      );
    }).toList();

    // 변동률 기준으로 정렬 및 상위 N개 반환
    keywords.sort((a, b) => b.changeRate.compareTo(a.changeRate));
    return keywords.take(limit).toList();
  }

  /// 지역별 상위 키워드 추출
  static List<Keyword> extractKeywordsByRegion(
    List<News> newsList,
    String region, {
    int limit = 5,
  }) {
    final regionNews = newsList
        .where((n) => n.regions.contains(region))
        .toList();

    return extractKeywordTrends(regionNews, limit: limit);
  }

  /// 관련 키워드 네트워크 생성
  static List<KeywordConnection> findRelatedKeywords(
    List<News> newsList,
    String targetKeyword, {
    int limit = 5,
  }) {
    final connections = <String, KeywordConnection>{};
    final targetKeywordNormalized = KeywordExtractorService.normalizeKeyword(
      targetKeyword,
    );

    // 타겟 키워드를 포함한 뉴스에서 함께 나타나는 키워드 찾기
    for (final news in newsList) {
      final normalizedKeywords = news.keywords
          .map((k) => KeywordExtractorService.normalizeKeyword(k))
          .toList();

      if (normalizedKeywords.contains(targetKeywordNormalized)) {
        for (final keyword in normalizedKeywords) {
          if (keyword != targetKeywordNormalized) {
            if (connections.containsKey(keyword)) {
              connections[keyword]!.strength++;
            } else {
              connections[keyword] = KeywordConnection(
                keyword: keyword,
                strength: 1,
              );
            }
          }
        }
      }
    }

    // 강도 순서로 정렬
    final sorted = connections.values.toList()
      ..sort((a, b) => b.strength.compareTo(a.strength));

    return sorted.take(limit).toList();
  }

  /// 급상승 키워드 감지
  static List<Keyword> detectSurging(
    List<Keyword> keywords, {
    double threshold = 50.0,
  }) {
    return keywords.where((k) => k.changeRate > threshold).toList();
  }

  /// 급하락 키워드 감지
  static List<Keyword> detectFalling(
    List<Keyword> keywords, {
    double threshold = -30.0,
  }) {
    return keywords.where((k) => k.changeRate < threshold).toList();
  }
}

/// 내부 클래스: 키워드 통계
class _KeywordStat {
  final String name;
  int mentionCount = 1;
  double totalSentiment = 0;
  int totalImportance = 0;
  final Set<String> regions = {};
  String category = '기타';
  final Map<String, int> hourlyMentions = {};
  final Map<String, int> dailyMentions = {};

  _KeywordStat({
    required this.name,
    required int importanceLevel,
    required double sentimentScore,
    required String hour,
    required String dayKey,
  }) {
    totalSentiment = sentimentScore;
    totalImportance = importanceLevel;
    // 시간 및 일일 데이터 초기화
    hourlyMentions[hour] = 1;
    dailyMentions[dayKey] = 1;
  }

  void _incrementMention(
    int importance,
    double sentiment,
    String hour,
    String dayKey,
  ) {
    mentionCount++;
    totalSentiment += sentiment;
    totalImportance += importance;
    hourlyMentions[hour] = (hourlyMentions[hour] ?? 0) + 1;
    dailyMentions[dayKey] = (dailyMentions[dayKey] ?? 0) + 1;
  }

  double get averageSentiment => totalSentiment / mentionCount;
  int get averageImportance => (totalImportance / mentionCount).ceil();
}

/// 내부 클래스: 키워드 연결
class KeywordConnection {
  final String keyword;
  int strength;

  KeywordConnection({required this.keyword, required this.strength});
}
