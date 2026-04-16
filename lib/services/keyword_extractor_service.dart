import '../data/models/index.dart';

/// 키워드 추출 서비스
class KeywordExtractorService {
  /// 텍스트에서 기본 키워드 추출
  static List<String> extractBasicKeywords(String text, {int minLength = 2}) {
    if (text.isEmpty) return [];

    // 간단한 토큰화 (실제로는 SpaCy, Kkma 등의 자연어 처리 라이브러리 사용)
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9가-힣\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= minLength)
        .where((word) => !_stopwords.contains(word))
        .toList();

    // 단어 횟수 계산
    final wordCount = <String, int>{};
    for (final word in words) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }

    // 횟수순 정렬
    final sortedWords = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedWords.map((e) => e.key).toList();
  }

  /// 모든 뉴스에서 핫 키워드 추출
  static List<String> extractHotKeywords(
    List<News> newsArticles, {
    int limit = 10,
  }) {
    final keywordFreq = <String, int>{};

    for (final news in newsArticles) {
      for (final keyword in news.keywords) {
        keywordFreq[keyword] = (keywordFreq[keyword] ?? 0) + 1;
      }
    }

    final sortedKeywords = keywordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedKeywords.take(limit).map((e) => e.key).toList();
  }

  /// 지역별 주요 키워드 추출
  static List<String> extractKeywordsByRegion(
    List<News> newsArticles,
    String region, {
    int limit = 5,
  }) {
    final regionNews = newsArticles
        .where((n) => n.regions.contains(region))
        .toList();

    return extractHotKeywords(regionNews, limit: limit);
  }

  /// 급상승 키워드 감지
  static List<Keyword> detectSurgingKeywords(
    List<Keyword> keywords, {
    double threshold = 50.0,
  }) {
    return keywords.where((k) => k.changeRate > threshold).toList()
      ..sort((a, b) => b.changeRate.compareTo(a.changeRate));
  }

  /// 관련 키워드 추천
  static List<String> recommendRelatedKeywords(
    String keyword,
    List<News> newsArticles, {
    int limit = 5,
  }) {
    // 주어진 키워드를 포함한 뉴스 찾기
    final relatedNews = newsArticles
        .where(
          (news) =>
              news.keywords.contains(keyword) ||
              news.title.toLowerCase().contains(keyword.toLowerCase()) ||
              news.description.toLowerCase().contains(keyword.toLowerCase()),
        )
        .toList();

    if (relatedNews.isEmpty) return [];

    // 자주 함께 나타나는 키워드 찾기
    final relatedKeywordFreq = <String, int>{};

    for (final news in relatedNews) {
      for (final kw in news.keywords) {
        if (kw != keyword) {
          relatedKeywordFreq[kw] = (relatedKeywordFreq[kw] ?? 0) + 1;
        }
      }
    }

    final sortedKeywords = relatedKeywordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedKeywords.take(limit).map((e) => e.key).toList();
  }

  /// 키워드 정규화 (동의어 통합)
  static String normalizeKeyword(String keyword) {
    // 동의어 매핑
    final synonyms = {
      'oil': ['석유', '유류', 'petroleum'],
      'middle east': ['중동', 'mideast'],
      'us': ['usa', 'america', '미국'],
      'korea': ['south korea', '한국', 'sk'],
      'semiconductor': ['chip', '반도체', 'semiconductor'],
    };

    final normalizedKeyword = keyword.toLowerCase().trim();

    for (final entry in synonyms.entries) {
      if (entry.value.contains(normalizedKeyword)) {
        return entry.key;
      }
      if (normalizedKeyword == entry.key) {
        return entry.key;
      }
    }

    return normalizedKeyword;
  }

  /// 정지어 (불용어) 리스트
  static final _stopwords = {
    // 한국어 정지어
    '그',
    '것',
    '것은',
    '수',
    '될',
    '것이다',
    '또는',
    '혹은',
    '그리고',
    '및',
    '등',
    // 영어 정지어
    'the',
    'is',
    'are',
    'am',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'should',
    'could',
    'may',
    'might',
    'can',
    'and',
    'or',
    'for',
    'with',
    'on',
    'at',
    'in',
    'to',
    'of',
    'a',
    'an',
  };
}
