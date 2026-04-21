import '../data/models/index.dart';
import 'keyword_extractor_service.dart';
import 'trend_analyzer_service.dart';

/// 키워드 트렌드 계산 서비스
class KeywordTrendService {
  static const _trendWindow = Duration(hours: 6);

  /// 뉴스 리스트에서 키워드 트렌드 생성
  static List<Keyword> extractKeywordTrends(
    List<News> newsList, {
    int limit = 10,
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
            news.publishedAt,
          );
        } else {
          keywordStats[normalized] = _KeywordStat(
            name: normalized,
            importanceLevel: news.importanceLevel,
            sentimentScore: news.sentimentScore,
            hour: hour,
            dayKey: dayKey,
            publishedAt: news.publishedAt,
          );
        }
      }
    }

    // Keyword 모델로 변환
    final keywords = keywordStats.entries.map((entry) {
      final stat = entry.value;
      final previousCount = stat.previousWindowMentionCount(_trendWindow);
      final currentCount = stat.currentWindowMentionCount(_trendWindow);
      final changeRate = TrendAnalyzerService.calculateChangeRate(
        previousCount,
        currentCount,
      );

      return Keyword(
        id: entry.key,
        name: entry.key,
        mentionCount: stat.mentionCount,
        changeRate: changeRate,
        relatedRegions: stat.regions.toList(),
        category: stat.category,
        riskLevel: TrendAnalyzerService.calculateRiskLevel(
          stat.averageSentiment,
          changeRate,
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
  final List<DateTime> mentionTimes = [];

  _KeywordStat({
    required this.name,
    required int importanceLevel,
    required double sentimentScore,
    required String hour,
    required String dayKey,
    required DateTime publishedAt,
  }) {
    totalSentiment = sentimentScore;
    totalImportance = importanceLevel;
    hourlyMentions[hour] = 1;
    dailyMentions[dayKey] = 1;
    mentionTimes.add(publishedAt);
  }

  void _incrementMention(
    int importance,
    double sentiment,
    String hour,
    String dayKey,
    DateTime publishedAt,
  ) {
    mentionCount++;
    totalSentiment += sentiment;
    totalImportance += importance;
    hourlyMentions[hour] = (hourlyMentions[hour] ?? 0) + 1;
    dailyMentions[dayKey] = (dailyMentions[dayKey] ?? 0) + 1;
    mentionTimes.add(publishedAt);
  }

  int currentWindowMentionCount(Duration window) {
    final latestMentionAt = _latestMentionAt;
    final currentWindowStart = latestMentionAt.subtract(window);
    return mentionTimes
        .where((time) => !time.isBefore(currentWindowStart))
        .length;
  }

  int previousWindowMentionCount(Duration window) {
    final latestMentionAt = _latestMentionAt;
    final currentWindowStart = latestMentionAt.subtract(window);
    final previousWindowStart = currentWindowStart.subtract(window);
    return mentionTimes
        .where(
          (time) =>
              !time.isBefore(previousWindowStart) &&
              time.isBefore(currentWindowStart),
        )
        .length;
  }

  DateTime get _latestMentionAt {
    var latest = mentionTimes.first;
    for (final time in mentionTimes.skip(1)) {
      if (time.isAfter(latest)) {
        latest = time;
      }
    }
    return latest;
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
