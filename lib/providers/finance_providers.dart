import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import '../data/services/ai_summary_service.dart';
import '../data/services/economic_calendar_service.dart';
import '../data/services/krx_stock_service.dart';
import '../data/services/market_data_service.dart';
import '../models/finance_news_filter.dart';
import 'news_providers.dart';
import 'repositories_provider.dart';

/// 금융 뉴스 관련 Riverpod Providers

// ─────────────────────────────────────────────
// 실시간 시장 지수 프로바이더
// ─────────────────────────────────────────────

/// MarketDataService 인스턴스 프로바이더
final marketDataServiceProvider = Provider<MarketDataService>((ref) {
  return MarketDataService();
});

/// AiSummaryService 인스턴스 프로바이더
final aiSummaryServiceProvider = Provider<AiSummaryService>((ref) {
  return AiSummaryService();
});

/// KrxStockService 인스턴스 프로바이더
final krxStockServiceProvider = Provider<KrxStockService>((ref) {
  return KrxStockService();
});

/// EconomicCalendarService 인스턴스 프로바이더
final economicCalendarServiceProvider = Provider<EconomicCalendarService>((
  ref,
) {
  return EconomicCalendarService();
});

/// 실시간 경제 캘린더 프로바이더
final economicCalendarProvider = FutureProvider<List<EconomicCalendarEvent>>((
  ref,
) async {
  ref.keepAlive();
  return ref.read(economicCalendarServiceProvider).fetchUpcomingEvents();
});

/// KRX 실제 상장 종목 목록 (코스피 + 코스닥)
/// 24시간 캐싱 — 앱 실행 시 1회 로드
final krxStocksProvider =
    FutureProvider<({List<String> kospi, List<String> kosdaq})>((ref) async {
      return ref.read(krxStockServiceProvider).fetchAllStocks();
    });

/// AI 시장 요약 — Naver 뉴스 기반 (정확도 우선)
final aiMarketSummaryProvider = FutureProvider.autoDispose<String>((ref) async {
  // 최신, 고중요도, 긍/부정 뉴스가 섞이도록 입력을 구성
  final allNews = await ref.watch(allFinanceNewsProvider.future);
  if (allNews.isEmpty) throw Exception('뉴스 데이터 없음');

  final sorted = [...allNews]
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  final selectedNews = <FinanceNews>[];
  final selectedIds = <String>{};

  void addChunk(Iterable<FinanceNews> items, int limit) {
    for (final item in items) {
      if (selectedIds.length >= 24) break;
      if (!selectedIds.add(item.id)) continue;
      selectedNews.add(item);
      if (selectedNews.length >= limit && selectedIds.length >= 24) break;
    }
  }

  addChunk(sorted.take(10), 10);
  addChunk(sorted.where((n) => n.importanceLevel >= 4).take(6), 6);
  addChunk(sorted.where((n) => n.sentimentScore >= 0.25).take(4), 4);
  addChunk(sorted.where((n) => n.sentimentScore <= -0.25).take(4), 4);
  addChunk(sorted.where((n) => n.description.trim().isNotEmpty).take(4), 4);

  // 시장 지수는 보조 데이터로만 사용 (없어도 동작)
  final indices = ref.read(marketIndicesProvider).valueOrNull ?? [];

  // KRX 실제 상장 종목 목록 (캐시 우선, 없으면 빈 리스트로 fallback)
  final krxStocks = await ref
      .read(krxStocksProvider.future)
      .catchError((_) => (kospi: <String>[], kosdaq: <String>[]));

  return ref
      .read(aiSummaryServiceProvider)
      .generateMarketSummary(
        indices: indices,
        newsItems: selectedNews,
        headlines: selectedNews.map((news) => news.title).toList(),
        kospiStocks: krxStocks.kospi,
        kosdaqStocks: krxStocks.kosdaq,
      );
});

/// 실시간 시장 지수 Stream — 최초 즉시 로드 후 60초마다 자동 갱신
final marketIndicesProvider = StreamProvider.autoDispose<List<MarketIndex>>((
  ref,
) async* {
  final service = ref.read(marketDataServiceProvider);

  // 즉시 첫 번째 데이터 반환
  yield await service.fetchMarketIndices();

  // 이후 60초 간격으로 갱신
  await for (final _ in Stream.periodic(const Duration(seconds: 60))) {
    yield await service.fetchMarketIndices();
  }
});

/// 전쟁·지정학 충돌 뉴스 — stockMarketNewsProvider에서 직접 필터링 (News 타입 유지)
final warNewsProvider = FutureProvider<List<News>>((ref) async {
  ref.keepAlive();
  final all = await ref.watch(stockMarketNewsProvider.future);
  return all
      .where(
        (n) => _containsAnyStr(n.title + n.description, [
          '전쟁',
          '전투',
          '공습',
          '미사일',
          '이스라엘',
          '하마스',
          '가자',
          '이란',
          '헤즈볼라',
          '중동',
          '우크라이나',
          '러시아',
          '분쟁',
          '확전',
          'war',
          'conflict',
          'Gaza',
          'Hamas',
          'Iran',
          'Israel',
          'Ukraine',
          'Russia',
          'ceasefire',
        ]),
      )
      .toList();
});

/// 코스피 뉴스 — stockMarketNewsProvider에서 직접 필터링 (News 타입 유지)
final kospiNewsProvider = FutureProvider<List<News>>((ref) async {
  ref.keepAlive();
  final all = await ref.watch(stockMarketNewsProvider.future);
  return all
      .where(
        (n) => _containsAnyStr(n.title + n.description, [
          '코스피',
          'KOSPI',
          '유가증권',
          '코스피지수',
          '한국증시',
        ]),
      )
      .toList();
});

/// 코스닥 뉴스 — stockMarketNewsProvider에서 직접 필터링
final kosdaqNewsProvider = FutureProvider<List<News>>((ref) async {
  ref.keepAlive();
  final all = await ref.watch(stockMarketNewsProvider.future);
  return all
      .where(
        (n) => _containsAnyStr(n.title + n.description, [
          '코스닥',
          'KOSDAQ',
          '코스닥지수',
          '중소형주',
        ]),
      )
      .toList();
});

/// 나스닥 뉴스 — stockMarketNewsProvider에서 직접 필터링
final nasdaqNewsProvider = FutureProvider<List<News>>((ref) async {
  ref.keepAlive();
  final all = await ref.watch(stockMarketNewsProvider.future);
  return all
      .where(
        (n) => _containsAnyStr(n.title + n.description, [
          '나스닥',
          'NASDAQ',
          '미국주식',
          '기술주',
        ]),
      )
      .toList();
});

/// 코인 뉴스 — stockMarketNewsProvider에서 직접 필터링
final coinNewsProvider = FutureProvider<List<News>>((ref) async {
  ref.keepAlive();
  final all = await ref.watch(stockMarketNewsProvider.future);
  return all
      .where(
        (n) => _containsAnyStr(n.title + n.description, [
          '비트코인',
          '이더리움',
          '암호화폐',
          '코인',
          '가상화폐',
          'BTC',
          'ETH',
          'XRP',
          '리플',
          '솔라나',
        ]),
      )
      .toList();
});

/// 경제 뉴스 — stockMarketNewsProvider에서 직접 필터링
final economicNewsProvider = FutureProvider<List<News>>((ref) async {
  ref.keepAlive();
  final all = await ref.watch(stockMarketNewsProvider.future);
  return all
      .where(
        (n) => _containsAnyStr(n.title + n.description, [
          '금리',
          'FED',
          '인플레이션',
          '경제',
          '재정',
        ]),
      )
      .toList();
});

bool _containsAnyStr(String text, List<String> keywords) {
  final lower = text.toLowerCase();
  return keywords.any((kw) => lower.contains(kw.toLowerCase()));
}

/// 통합 금융 뉴스 (Naver + NewsAPI) — 중복 API 호출 방지
final allFinanceNewsProvider = FutureProvider<List<FinanceNews>>((ref) async {
  ref.keepAlive();

  try {
    // 1. 먼저 Naver 뉴스 확인 (stockMarketNewsProvider에서 가져옴)
    final naverNews = await ref.watch(stockMarketNewsProvider.future);
    debugPrint('📊 [통합뉴스] Naver 뉴스: ${naverNews.length}개');

    // 2. Naver 뉴스를 FinanceNews 형태로 변환
    final naverFinanceNews = naverNews
        .map(
          (news) => FinanceNews(
            id: news.id,
            title: news.title,
            description: news.description,
            source: news.source,
            publishedAt: news.publishedAt,
            createdAt: news.createdAt,
            imageUrl: news.imageUrl.isNotEmpty ? news.imageUrl : null,
            url: news.newsUrl.isNotEmpty ? news.newsUrl : null,
            keywords: news.keywords,
            tickers: [], // Naver 뉴스는 티커 정보 없음
            sectors: [], // 섹터 정보도 없음
            sentimentScore: news.sentimentScore,
            importanceLevel: news.importanceLevel,
            category: news.category,
            isBookmarked: news.isBookmarked,
          ),
        )
        .toList();

    // 3. Naver 뉴스가 충분하면 (100개 이상) NewsAPI 생략
    if (naverFinanceNews.length >= 100) {
      debugPrint(
        '✅ [통합뉴스] Naver 뉴스 충분 → NewsAPI 생략 (${naverFinanceNews.length}개)',
      );
      return naverFinanceNews;
    }

    // 4. 부족하면 NewsAPI 추가 호출
    debugPrint('📡 [통합뉴스] Naver 부족 → NewsAPI 추가 호출');
    final repository = await ref.watch(financeRepositoryProvider.future);
    final newsApiNews = await repository.getFinanceNews();

    // 5. 두 소스 병합 (중복 제거)
    final seen = <String>{};
    final combined = <FinanceNews>[];

    for (final news in [...naverFinanceNews, ...newsApiNews]) {
      if (seen.add(news.url ?? news.id)) {
        combined.add(news);
      }
    }

    debugPrint(
      '✅ [통합뉴스] 병합 완료: Naver ${naverFinanceNews.length} + NewsAPI ${newsApiNews.length} = 총 ${combined.length}개',
    );
    return combined;
  } catch (e) {
    debugPrint('❌ [통합뉴스] 오류: $e');
    // 실패 시 기존 방식 fallback
    final repository = await ref.watch(financeRepositoryProvider.future);
    return repository.getFinanceNews();
  }
});

/// 섹터별 뉴스 커스텀 프로바이더
final financeNewsBySectorProvider =
    FutureProvider.family<List<FinanceNews>, String>((ref, sector) async {
      final repository = await ref.watch(financeRepositoryProvider.future);
      return repository.getSectorNews(sector);
    });

/// 특정 종목 뉴스
final financeNewsByTickerProvider =
    FutureProvider.family<List<FinanceNews>, String>((ref, ticker) async {
      final repository = await ref.watch(financeRepositoryProvider.future);
      return repository.getStockNews(ticker);
    });

/// 긍정적인 금융 뉴스 (강세) — allFinanceNewsProvider 로드 후 필터링
final positiveFinanceNewsProvider = FutureProvider<List<FinanceNews>>((
  ref,
) async {
  final all = await ref.watch(allFinanceNewsProvider.future);
  final filtered = all.where((n) => n.sentimentScore >= 0.3).toList();
  filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return filtered;
});

/// 부정적인 금융 뉴스 (약세) — allFinanceNewsProvider 로드 후 필터링
final negativeFinanceNewsProvider = FutureProvider<List<FinanceNews>>((
  ref,
) async {
  final all = await ref.watch(allFinanceNewsProvider.future);
  final filtered = all.where((n) => n.sentimentScore <= -0.3).toList();
  filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return filtered;
});

/// 북마크된 금융 뉴스
final bookmarkedFinanceNewsProvider = FutureProvider<List<FinanceNews>>((
  ref,
) async {
  final repository = await ref.watch(financeRepositoryProvider.future);
  return repository.getBookmarkedNews();
});

/// 금융 뉴스 필터 상태
final financeNewsFilterProvider = StateProvider<FinanceNewsFilter>((ref) {
  return FinanceNewsFilter();
});

/// 금융 뉴스 정렬 상태
final financeNewsSortProvider = StateProvider<String>((ref) => 'publishedAt');

/// 금융 뉴스 중요도 필터
final financeNewsImportanceProvider = StateProvider<int>((ref) => 1);

/// 금융 뉴스 감정 필터
final financeNewsSentimentProvider = StateProvider<({double min, double max})>(
  (ref) => (min: -1.0, max: 1.0),
);

/// 필터 적용된 금융 뉴스
final filteredFinanceNewsProvider = FutureProvider<List<FinanceNews>>((
  ref,
) async {
  final allNews = await ref.watch(allFinanceNewsProvider.future);
  final filter = ref.watch(financeNewsFilterProvider);
  final importanceLevel = ref.watch(financeNewsImportanceProvider);
  final sentiment = ref.watch(financeNewsSentimentProvider);

  var filtered = allNews;

  // 섹터 필터
  if (filter.sectors.isNotEmpty) {
    filtered = filtered
        .where((n) => n.sectors.any((s) => filter.sectors.contains(s)))
        .toList();
  }

  // 카테고리 필터
  if (filter.categories.isNotEmpty) {
    filtered = filtered
        .where((n) => filter.categories.contains(n.category))
        .toList();
  }

  // 중요도 필터
  filtered = filtered
      .where((n) => n.importanceLevel >= importanceLevel)
      .toList();

  // 감정 필터
  filtered = filtered
      .where(
        (n) =>
            n.sentimentScore >= sentiment.min &&
            n.sentimentScore <= sentiment.max,
      )
      .toList();

  return filtered;
});

// ─────────────────────────────────────────────
// 암호화폐 차트 프로바이더
// ─────────────────────────────────────────────

/// BTC, ETH, XRP, SOL 가격 히스토리 — 기간별 자동 캐시 폐기
final cryptoChartProvider = FutureProvider.autoDispose
    .family<List<CryptoData>, String>((ref, period) async {
      final service = ref.read(marketDataServiceProvider);
      return service.fetchCryptoHistory(period);
    });
