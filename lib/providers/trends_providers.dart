import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import 'news_providers.dart';
import 'repositories_provider.dart';

/// 트렌드 관련 상태 프로바이더들

/// 기간 선택
final selectedPeriodProvider = StateProvider<String>((ref) => '24h');

/// 트렌드 리스트
final trendsProvider = FutureProvider<List<Trend>>((ref) async {
  final repository = await ref.watch(trendRepositoryProvider.future);
  final region = ref.watch(selectedRegionProvider);
  final period = ref.watch(selectedPeriodProvider);

  return repository.getTrends(region: region, period: period);
});

/// 상위 트렌딩 키워드 (뉴스에서 실시간 계산)
final topTrendingKeywordsProvider = FutureProvider<List<Keyword>>((ref) async {
  final repository = await ref.watch(trendRepositoryProvider.future);
  final newsList = await ref.watch(newsListProvider.future);
  final region = ref.watch(selectedRegionProvider);

  try {
    // 지역이 '전체'가 아닌 경우 지역별 키워드 계산
    if (region != '전체') {
      return await repository.getTopKeywordsByRegion(
        newsList: newsList,
        region: region,
        limit: 10,
      );
    }

    // 전체 뉴스에서 키워드 트렌드 계산
    return await repository.getTopTrendingKeywords(newsList: newsList);
  } catch (e) {
    // 실패 시 캐시된 키워드 반환 (폴백)
    return repository.getCachedKeywords();
  }
});

/// 급상승 키워드
final surgingKeywordsProvider = FutureProvider<List<Keyword>>((ref) async {
  final repository = await ref.watch(trendRepositoryProvider.future);
  final newsList = await ref.watch(newsListProvider.future);

  try {
    return await repository.detectSurgingKeywords(newsList: newsList);
  } catch (e) {
    return [];
  }
});

/// 관련 키워드
final relatedKeywordsProvider = FutureProvider.family<List<String>, String>((
  ref,
  keyword,
) async {
  final repository = await ref.watch(trendRepositoryProvider.future);
  final newsList = await ref.watch(newsListProvider.future);

  try {
    return await repository.getRelatedKeywords(
      newsList: newsList,
      keyword: keyword,
    );
  } catch (e) {
    return [];
  }
});

/// 키워드별 트렌드
final keywordTrendsProvider = FutureProvider.family<List<Trend>, String>((
  ref,
  keyword,
) async {
  final repository = await ref.watch(trendRepositoryProvider.future);
  return repository.getTrendsByKeyword(keyword);
});
