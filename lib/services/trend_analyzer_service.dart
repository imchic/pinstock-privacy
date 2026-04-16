import '../data/models/index.dart';

/// 트렌드 분석 서비스
class TrendAnalyzerService {
  /// 키워드 언급량 변화 계산
  /// [previousCount] - 이전 기간 언급량
  /// [currentCount] - 현재 기간 언급량
  static double calculateChangeRate(int previousCount, int currentCount) {
    if (previousCount == 0) {
      return currentCount > 0 ? 100.0 : 0.0;
    }
    return ((currentCount - previousCount) / previousCount) * 100;
  }

  /// 급상승 키워드 감지
  /// [changeRate] - 변동률 (%)
  /// [threshold] - 급상승 임계값 (기본: 50%)
  static bool isSurging(double changeRate, {double threshold = 50.0}) {
    return changeRate > threshold;
  }

  /// 급하락 키워드 감지
  /// [changeRate] - 변동률 (%)
  /// [threshold] - 급하락 임계값 (기본: -30%)
  static bool isFalling(double changeRate, {double threshold = -30.0}) {
    return changeRate < threshold;
  }

  /// 감정 점수 평균 계산
  static double calculateAverageSentiment(List<double> sentiments) {
    if (sentiments.isEmpty) return 0.0;
    final sum = sentiments.fold<double>(0.0, (a, b) => a + b);
    return sum / sentiments.length;
  }

  /// 위험도 레벨 계산
  /// [sentimentScore] - 감정 점수 (-1 ~ 1)
  /// [changeRate] - 변동률 (%)
  /// [importanceLevel] - 기본 중요도 (1 ~ 5)
  static int calculateRiskLevel(
    double sentimentScore,
    double changeRate,
    int importanceLevel,
  ) {
    int riskScore = 0;

    // 감정 점수에 따른 위험도
    if (sentimentScore < -0.5) {
      riskScore += 4;
    } else if (sentimentScore < 0) {
      riskScore += 2;
    }

    // 변동률에 따른 위험도
    if (changeRate > 100) {
      riskScore += 5;
    } else if (changeRate > 50) {
      riskScore += 4;
    } else if (changeRate > 20) {
      riskScore += 2;
    }

    // 기본 중요도
    riskScore += importanceLevel;

    // 1~5 범위로 정규화
    final int level = (riskScore / 3).ceil();
    return level.clamp(1, 5);
  }

  /// 트렌드 분석 요약 생성
  static String generateTrendSummary(
    String keyword,
    int mentionCount,
    double changeRate,
    double sentimentScore,
  ) {
    final sentiment = sentimentScore > 0.3
        ? '긍정적'
        : sentimentScore < -0.3
        ? '부정적'
        : '중립적';

    if (changeRate > 50) {
      return '$keyword는 지난 24시간에 ${changeRate.toStringAsFixed(1)}% 급상승했으며, 언급이 $mentionCount회 있었습니다. ($sentiment 감정)';
    } else if (changeRate < -30) {
      return '$keyword는 지난 24시간에 ${changeRate.toStringAsFixed(1)}% 하락했지만, 여전히 주목할 만한 주제입니다.';
    } else {
      return '$keyword는 현재 $mentionCount회 언급되었으며, $sentiment 반응을 보이고 있습니다.';
    }
  }

  /// 시계열 데이터 분석
  /// [data] - 시간대별 언급량 데이터
  static Map<String, dynamic> analyzeTimeSeries(List<int> data) {
    if (data.isEmpty) {
      return {'average': 0.0, 'peak': 0, 'peakIndex': -1, 'trend': 'stable'};
    }

    final average = data.fold<int>(0, (a, b) => a + b) / data.length;
    final peak = data.reduce((a, b) => a > b ? a : b);
    final peakIndex = data.indexOf(peak);

    // 추세 판단
    String trend = 'stable';
    if (data.length > 1) {
      final lastHalf = data.sublist((data.length / 2).ceil());
      final firstHalf = data.sublist(0, (data.length / 2).floor());

      final lastAvg = lastHalf.fold<int>(0, (a, b) => a + b) / lastHalf.length;
      final firstAvg =
          firstHalf.fold<int>(0, (a, b) => a + b) / firstHalf.length;

      if (lastAvg > firstAvg * 1.2) {
        trend = 'rising';
      } else if (lastAvg < firstAvg * 0.8) {
        trend = 'falling';
      }
    }

    return {
      'average': average,
      'peak': peak,
      'peakIndex': peakIndex,
      'trend': trend,
    };
  }

  /// 지역별 영향도 계산
  static int calculateRegionalImpact(String region, List<News> newsArticles) {
    final regionNews = newsArticles
        .where((news) => news.regions.contains(region))
        .toList();

    if (regionNews.isEmpty) return 0;

    // 중요도와 감정 점수 기반으로 영향도 계산
    int impact = 0;
    for (final news in regionNews) {
      impact += news.importanceLevel;
      if (news.sentimentScore < -0.3) {
        impact += 3; // 부정적 뉴스는 더 큰 영향
      }
    }

    return (impact / regionNews.length).ceil();
  }

  /// 관련 키워드 연결 강도 계산
  static double calculateKeywordCorrelation(
    String keyword1,
    String keyword2,
    List<News> newsArticles,
  ) {
    int cooccurrence = 0;
    int keyword1Count = 0;
    int keyword2Count = 0;

    for (final news in newsArticles) {
      final hasKeyword1 = news.keywords.contains(keyword1);
      final hasKeyword2 = news.keywords.contains(keyword2);

      if (hasKeyword1) keyword1Count++;
      if (hasKeyword2) keyword2Count++;
      if (hasKeyword1 && hasKeyword2) cooccurrence++;
    }

    if (keyword1Count == 0 || keyword2Count == 0) return 0.0;

    return cooccurrence / (keyword1Count + keyword2Count - cooccurrence);
  }
}
