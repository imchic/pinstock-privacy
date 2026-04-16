import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/index.dart';
import '../data/services/index.dart';

/// 공유 프로바이더들

/// SharedPreferences 프로바이더
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// LocalStorageService 프로바이더
final localStorageServiceProvider = FutureProvider<LocalStorageService>((
  ref,
) async {
  return await LocalStorageService.create();
});

/// NaverNewsService 프로바이더
final pressCacheServiceProvider = ChangeNotifierProvider<PressCacheService>((
  ref,
) {
  return PressCacheService();
});

/// NaverNewsService 프로바이더
final naverNewsServiceProvider = Provider<NaverNewsService>((ref) {
  // 언론사 캐시 notifyListeners가 뉴스 fetch provider 체인을 다시 실행하지 않도록
  // 서비스 생성 시에는 동일 인스턴스만 읽고 구독하지 않는다.
  final pressCache = ref.read(pressCacheServiceProvider);
  return NaverNewsService(pressCache: pressCache);
});

/// NewsRepository 프로바이더
final newsRepositoryProvider = FutureProvider<NewsRepository>((ref) async {
  final naverService = ref.watch(naverNewsServiceProvider);
  final localStorage = await ref.watch(localStorageServiceProvider.future);
  return NewsRepository(naverService: naverService, localService: localStorage);
});

/// TrendRepository 프로바이더
final trendRepositoryProvider = FutureProvider<TrendRepository>((ref) async {
  final localStorage = await ref.watch(localStorageServiceProvider.future);
  return TrendRepository(localService: localStorage);
});

/// AlertRepository 프로바이더
final alertRepositoryProvider = FutureProvider<AlertRepository>((ref) async {
  final localStorage = await ref.watch(localStorageServiceProvider.future);
  return AlertRepository(localService: localStorage);
});

/// UserPreferenceRepository 프로바이더
final userPreferenceRepositoryProvider =
    FutureProvider<UserPreferenceRepository>((ref) async {
      final localStorage = await ref.watch(localStorageServiceProvider.future);
      return UserPreferenceRepository(localService: localStorage);
    });

/// FinanceRepository 프로바이더
final financeRepositoryProvider = FutureProvider<FinanceRepository>((
  ref,
) async {
  final apiService = FinanceApiService();
  final localStorage = await ref.watch(localStorageServiceProvider.future);
  return FinanceRepository(apiService: apiService, localService: localStorage);
});
