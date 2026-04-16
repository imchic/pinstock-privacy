import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/constants.dart';
import '../models/index.dart';
import 'api_rate_limiter.dart';

/// API 서비스 (뉴스 데이터 수집)
class ApiService {
  static const String _baseUrl = 'https://newsapi.org/v2';
  static const String _apiKey = AppConstants.newsApiKey; // ✅ constants에서 키 가져오기

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// 뉴스 검색
  /// [query] - 검색어
  /// [sortBy] - "relevancy", "popularity", "publishedAt"
  /// [page] - 페이지 번호 (기본값: 1)
  /// [from] - 시작 날짜 (기본값: 일주일 전)
  /// [to] - 종료 날짜 (기본값: 오늘)
  /// [includeLanguage] - 언어 제한 (기본값: 한국어, 영어)
  Future<List<News>> searchNews({
    required String query,
    String sortBy = 'publishedAt',
    int page = 1,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
    String? language = 'ko',
  }) async {
    try {
      // 기본값: 당일 00:00부터 현재까지
      final now = DateTime.now();
      final fromDate = from ?? DateTime(now.year, now.month, now.day);
      final toDate = to ?? now;

      final queryParams = <String, String>{
        'q': query,
        'sortBy': sortBy,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'apiKey': _apiKey,
        'from': _formatDate(fromDate),
        'to': _formatDate(toDate),
        if (language != null) 'language': language,
      };

      final uri = Uri.parse(
        '$_baseUrl/everything',
      ).replace(queryParameters: queryParams);

      // Rate limit 확인 — await 전 동기적으로 처리하여 병렬 요청 시 경쟁 조건 방지
      final rateLimiter = ApiRateLimiter();
      if (!rateLimiter.canMakeRequest()) {
        debugPrint('⏳ [NewsAPI] Rate limit 초과 — 요청 건너뜀: $query');
        return [];
      }
      rateLimiter.recordRequest(); // await 전에 즉시 카운터 증가

      debugPrint('🔗 API 요청 URL: ${uri.toString()}');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final articles = (json['articles'] as List?)
            ?.cast<Map<String, dynamic>>();

        if (articles == null || articles.isEmpty) {
          debugPrint('⚠️ 기사 없음: $query');
          return [];
        }

        debugPrint('✅ ${articles.length}개 기사 파싱 중...');
        return articles.map((article) => _parseNews(article, query)).toList();
      } else {
        debugPrint('⚠️ API 응답 에러: ${response.statusCode}, Query: $query');
        debugPrint('Response: ${response.body}');
        if (response.statusCode == 429) rateLimiter.recordFailure();
        throw Exception('뉴스 검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ API 호출 오류: $e, Query: $query');
      throw Exception('API 호출 오류: $e');
    }
  }

  /// 지역별 뉴스 조회
  /// [region] - 지역 코드 ("MidEast", "USA", "Asia" 등)
  Future<List<News>> getNewsByRegion(
    String region, {
    int page = 1,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    final keywords = _getKeywordsByRegion(region);
    final query = keywords.join(' OR ');

    return searchNews(
      query: query,
      page: page,
      pageSize: pageSize,
      from: from,
      to: to,
    );
  }

  /// 카테고리별 뉴스 조회
  Future<List<News>> getNewsByCategory(
    String category, {
    int page = 1,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    return searchNews(
      query: category,
      page: page,
      pageSize: pageSize,
      from: from,
      to: to,
    );
  }

  /// 관심 키워드 뉴스 조회
  Future<List<News>> getNewsByKeywords(
    List<String> keywords, {
    int page = 1,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    if (keywords.isEmpty) return [];

    final query = keywords.join(' OR ');
    return searchNews(
      query: query,
      page: page,
      pageSize: pageSize,
      from: from,
      to: to,
    );
  }

  /// NewsAPI 기사를 News 모델로 변환
  News _parseNews(Map<String, dynamic> article, String searchQuery) {
    final now = DateTime.now();
    final keywords = _extractKeywords(article, searchQuery);
    final regions = _detectRegions(article);

    return News(
      id: article['url'] ?? '',
      title: article['title'] ?? '제목 없음',
      description: article['description'] ?? '',
      content: article['content'] ?? '',
      source: article['source']?['name'] ?? '알 수 없음',
      imageUrl: article['urlToImage'] ?? '',
      newsUrl: article['url'] ?? '',
      publishedAt:
          DateTime.tryParse(article['publishedAt'] as String? ?? '') ?? now,
      createdAt: now,
      keywords: keywords,
      regions: regions,
      sentimentScore: _calculateSentimentScore(article),
      importanceLevel: _calculateImportanceLevel(article),
      category: _categorizeNews(article),
      stockRelevanceScore: _calculateStockRelevanceScore(article),
    );
  }

  /// 뉴스에서 키워드 추출 (한국어 기사 기준)
  List<String> _extractKeywords(
    Map<String, dynamic> article,
    String searchQuery,
  ) {
    final keywords = <String>{};

    if (searchQuery.isNotEmpty) {
      keywords.add(searchQuery);
    }

    final content =
        ('${article['title'] ?? ''} ${article['description'] ?? ''}');

    // 한국어 기사에서 주요 키워드 패턴 검사
    final patterns = [
      '코스피',
      '코스닥',
      '나스닥',
      '다우존스',
      'S&P',
      '금리',
      '기준금리',
      '한국은행',
      '연준',
      '금리인상',
      '금리인하',
      '유가',
      '원유',
      'OPEC',
      '반도체',
      'AI',
      '인공지능',
      '삼성전자',
      'SK하이닉스',
      '현대차',
      '카카오',
      '네이버',
      '환율',
      '달러',
      '엔화',
      '위안화',
      '이스라엘',
      '우크라이나',
      '러시아',
      '중국',
      '미국',
      '인플레이션',
      '경기침체',
      '무역전쟁',
      '관세',
    ];

    for (final kw in patterns) {
      if (content.contains(kw)) {
        keywords.add(kw);
      }
    }

    return keywords.toList();
  }

  /// 지역 감지 (한국어 기사 기준)
  List<String> _detectRegions(Map<String, dynamic> article) {
    final regions = <String>{};
    final content =
        ('${article['title'] ?? ''} ${article['description'] ?? ''}');

    final regionPatterns = {
      'MidEast': ['중동', '이란', '사우디', '이스라엘', '이라크', '팔레스타인', '하마스'],
      'USA': ['미국', '미 연준', '연준', '워싱턴', '뉴욕', '월가', '월스트리트'],
      'Asia': ['중국', '일본', '한국', '인도', '대만', '아시아', '홍콩'],
      'Europe': ['유럽', '러시아', '우크라이나', 'EU', '독일', '영국', '프랑스'],
    };

    regionPatterns.forEach((region, patterns) {
      if (patterns.any((pattern) => content.contains(pattern))) {
        regions.add(region);
      }
    });

    return regions.toList();
  }

  /// 감정 점수 계산 (한국어 기사 기준)
  double _calculateSentimentScore(Map<String, dynamic> article) {
    final content =
        ('${article['title'] ?? ''} ${article['description'] ?? ''}');

    int positive = 0, negative = 0;

    const positiveWords = [
      '상승',
      '급등',
      '호조',
      '반등',
      '돌파',
      '신고가',
      '성장',
      '흑자',
      '수익',
      '기대',
      '회복',
      '개선',
      '강세',
      '랠리',
      '호재',
      '증가',
      '확대',
      '호실적',
      '낙관',
    ];
    const negativeWords = [
      '하락',
      '급락',
      '폭락',
      '위기',
      '적자',
      '손실',
      '충격',
      '불안',
      '공포',
      '우려',
      '악화',
      '약세',
      '침체',
      '위협',
      '악재',
      '감소',
      '축소',
      '부진',
      '비관',
      '전쟁',
      '갈등',
    ];

    for (final word in positiveWords) {
      if (content.contains(word)) positive++;
    }
    for (final word in negativeWords) {
      if (content.contains(word)) negative++;
    }

    if (positive + negative == 0) return 0.0;
    return (positive - negative) / (positive + negative);
  }

  /// 중요도 레벨 계산 (증시 관련성 반영)
  int _calculateImportanceLevel(Map<String, dynamic> article) {
    final source = (article['source']?['name'] ?? '').toString();
    final stockScore = _calculateStockRelevanceScore(article);

    // 신뢰도 높은 한국 뉴스 소스 + 증시 고관련 → 5
    final trustedSources = [
      '연합뉴스',
      '한국경제',
      '매일경제',
      '조선비즈',
      '이데일리',
      '머니투데이',
      '헤럴드경제',
      '파이낸셜뉴스',
      '서울경제',
      'KBS',
      'MBC',
      'SBS',
      'The Guardian',
      'Reuters',
      'Bloomberg',
      'BBC News',
      'Financial Times',
      'Wall Street Journal',
      'CNBC',
      'Associated Press',
    ];
    final isTrusted = trustedSources.any((s) => source.contains(s));

    if (isTrusted && stockScore >= 0.4) return 5;
    if (isTrusted || stockScore >= 0.5) return 4;
    if (stockScore >= 0.3) return 3;
    if (stockScore >= 0.15) return 2;
    return 1;
  }

  /// 증시 영향 관련성 점수 계산 (0.0 ~ 1.0) — 한국어 기사 기준
  /// 제목+설명에서 증시 관련 키워드 가중치 합산 후 정규화
  double _calculateStockRelevanceScore(Map<String, dynamic> article) {
    final content =
        ('${article['title'] ?? ''} ${article['description'] ?? ''}');

    int score = 0;

    // 핵심 증시 키워드 (가중치 3)
    const highWeight = [
      '코스피', '코스닥', '주가', '주식시장', '증시',
      '상한가', '하한가', '급등주', '급락주', '시가총액',
      '나스닥', '다우존스', 'S&P', '닛케이', '항셍',
      'IPO', '상장', '공모주', '배당', '자사주',
      '금리인상', '금리인하', '기준금리 결정', '연준 결정',
      '실적발표', '분기실적', 'EPS', '어닝쇼크', '어닝서프라이즈',
      // 영어 키워드
      'stock market', 'nasdaq', 'dow jones', 's&p 500', 'nikkei',
      'ipo listing', 'earnings report', 'earnings surprise',
      'rate hike',
      'rate cut',
      'fed decision',
      'interest rate decision', // 트럼프 관련 (증시 영향 최고 수준)
      'trump tariffs', 'trump trade', 'trump tax', '트럼프 관세', '트럼프 무역',
    ];

    // 주요 경제·금융 키워드 (가중치 2)
    const midWeight = [
      '기준금리', '한국은행', '연준', '중앙은행', '통화정책',
      '인플레이션', '소비자물가', 'CPI', 'GDP', '경기침체',
      '무역전쟁', '관세', '제재', '환율', '달러', '엔화', '위안화',
      '유가', '원유', '금값', '국채', '채권금리',
      '삼성전자', 'SK하이닉스', '현대차', '카카오', '네이버',
      'TSMC', '엔비디아', '애플', '마이크로소프트',
      '매출', '영업이익', '순이익', '적자전환', '흑자전환',
      'ETF', '펀드', '포트폴리오', '자산', '헤지펀드',
      '신용등급', '부도', '인수합병', 'M&A',
      '트럼프', 'Trump', '모라토리엄', '경야지',
      '이스라엘', '하마스', '가자', '중동', '이란', '헤즈볼라', 'OPEC',
      '유가급등', '지정학', '표적타격', '휴전', '확전',
      // 영어 키워드
      'federal reserve', 'inflation', 'recession', 'gdp growth',
      'trade war', 'tariffs', 'sanctions', 'exchange rate',
      'oil price', 'gold price', 'treasury yield', 'bond yield',
      'nvidia', 'apple', 'microsoft', 'amazon', 'tesla',
      'revenue', 'net income', 'profit', 'loss',
      'etf', 'hedge fund', 'credit rating', 'merger', 'acquisition',
      'trump', 'moratorium', 'executive order', 'white house',
      'israel', 'hamas', 'gaza', 'middle east', 'iran', 'hezbollah',
      'ceasefire', 'airstrike', 'opec', 'crude oil', 'geopolitical',
    ];

    // 일반 경제 키워드 (가중치 1)
    const lowWeight = [
      '경제', '금융', '시장', '은행', '무역', '투자',
      '고용', '실업률', '소비', '수출', '수입', '경상수지',
      '공급망', '반도체', '부동산', '주택시장',
      // 영어 키워드
      'economy', 'financial', 'market', 'bank', 'trade', 'investment',
      'employment', 'unemployment', 'consumption', 'exports', 'imports',
      'supply chain', 'semiconductor', 'real estate',
    ];

    for (final k in highWeight) {
      if (content.contains(k)) score += 3;
    }
    for (final k in midWeight) {
      if (content.contains(k)) score += 2;
    }
    for (final k in lowWeight) {
      if (content.contains(k)) score += 1;
    }

    // 최대 기준점 24로 정규화
    return (score / 24.0).clamp(0.0, 1.0);
  }

  /// 뉴스 카테고리 분류 (한국어 기사 기준)
  String _categorizeNews(Map<String, dynamic> article) {
    final content =
        ('${article['title'] ?? ''} ${article['description'] ?? ''}');

    if (content.contains('코스피') ||
        content.contains('코스닥') ||
        content.contains('주가') ||
        content.contains('주식') ||
        content.contains('증시') ||
        content.contains('나스닥') ||
        content.contains('실적발표') ||
        content.contains('IPO') ||
        content.contains('배당') ||
        content.contains('상장')) {
      return '증시';
    }
    if (content.contains('금리') ||
        content.contains('한국은행') ||
        content.contains('연준') ||
        content.contains('인플레이션') ||
        content.contains('GDP') ||
        content.contains('경기침체') ||
        content.contains('무역') ||
        content.contains('경제') ||
        content.contains('시장')) {
      return '경제';
    }
    if (content.contains('유가') ||
        content.contains('원유') ||
        content.contains('OPEC') ||
        content.contains('가스')) {
      return '에너지';
    }
    if (content.contains('전쟁') ||
        content.contains('군사') ||
        content.contains('국방')) {
      return '군사';
    }
    if (content.contains('정치') || content.contains('정부')) {
      return '정치';
    }

    return '기타';
  }

  /// 지역별 키워드 반환 (한국어 검색어)
  List<String> _getKeywordsByRegion(String region) {
    final keywords = {
      'MidEast': ['중동 유가', '이란 제재', '사우디 OPEC', '이스라엘 전쟁'],
      'USA': ['미국 금리 연준', '미국 증시 나스닥', '미국 경제 관세'],
      'Asia': ['코스피 코스닥', '일본 닛케이', '중국 경제 위안화', '대만 반도체'],
      'Europe': ['유럽 ECB 금리', '러시아 우크라이나', 'EU 경제'],
    };

    return keywords[region] ?? [];
  }

  /// 날짜를 ISO 8601 형식으로 포맷팅
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T')[0]; // YYYY-MM-DD
  }
}
