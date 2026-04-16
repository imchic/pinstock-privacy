import '../../services/index.dart' as app_services;
import '../models/index.dart';
import '../services/index.dart';

/// 트렌드 Repository
class TrendRepository {
  final LocalStorageService localService;

  TrendRepository({required this.localService});

  /// 트렌드 조회
  Future<List<Trend>> getTrends({String? region, String period = '24h'}) async {
    var trends = localService.getCachedTrends();

    if (region != null) {
      trends = trends.where((t) => t.region == region).toList();
    }

    if (period.isNotEmpty) {
      trends = trends.where((t) => t.period == period).toList();
    }

    return trends;
  }

  /// 키워드별 트렌드 조회
  Future<List<Trend>> getTrendsByKeyword(String keyword) async {
    final trends = localService.getCachedTrends();
    return trends.where((t) => t.keyword == keyword).toList();
  }

  /// 뉴스에서 상위 트렌딩 키워드 계산
  Future<List<Keyword>> getTopTrendingKeywords({
    required List<News> newsList,
    int limit = 10,
    String period = '24h',
  }) async {
    // KeywordTrendService를 사용하여 뉴스에서 키워드 트렌드 계산
    final keywords = app_services.KeywordTrendService.extractKeywordTrends(
      newsList,
      limit: limit,
      previousMentionCounts: _getPreviousMentionCounts(),
    );

    // 캐시에 저장
    await localService.saveKeywords(keywords);

    return keywords;
  }

  /// 지역별 상위 키워드 계산
  Future<List<Keyword>> getTopKeywordsByRegion({
    required List<News> newsList,
    required String region,
    int limit = 5,
  }) async {
    final keywords = app_services.KeywordTrendService.extractKeywordsByRegion(
      newsList,
      region,
      limit: limit,
    );

    return keywords;
  }

  /// 급상승 키워드 감지
  Future<List<Keyword>> detectSurgingKeywords({
    required List<News> newsList,
    double threshold = 50.0,
    int limit = 10,
  }) async {
    final keywords = app_services.KeywordTrendService.extractKeywordTrends(
      newsList,
      limit: limit * 2, // 필터 전에 더 많이 가져오기
    );

    final surging = app_services.KeywordTrendService.detectSurging(
      keywords,
      threshold: threshold,
    );

    return surging.take(limit).toList();
  }

  /// 관련 키워드 찾기
  Future<List<String>> getRelatedKeywords({
    required List<News> newsList,
    required String keyword,
    int limit = 5,
  }) async {
    final connections = app_services.KeywordTrendService.findRelatedKeywords(
      newsList,
      keyword,
      limit: limit,
    );

    return connections.map((c) => c.keyword).toList();
  }

  /// 이전 언급 횟수 조회 (변동률 계산용)
  Map<String, int>? _getPreviousMentionCounts() {
    try {
      final cachedKeywords = localService.getCachedKeywords();
      return {for (final kw in cachedKeywords) kw.name: kw.mentionCount};
    } catch (e) {
      return null;
    }
  }

  /// 트렌드 저장
  Future<void> saveTrends(List<Trend> trends) async {
    await localService.saveTrends(trends);
  }

  /// 캐시된 트렌드 조회
  List<Trend> getCachedTrends() {
    return localService.getCachedTrends();
  }

  /// 캐시된 키워드 조회 (폴백용)
  List<Keyword> getCachedKeywords() {
    return localService.getCachedKeywords();
  }
}
