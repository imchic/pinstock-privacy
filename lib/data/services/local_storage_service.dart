import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/index.dart';

/// 로컬 저장소 서비스
class LocalStorageService {
  static const String _newsKey = 'cached_news';
  static const String _keywordsKey = 'cached_keywords';
  static const String _trendsKey = 'cached_trends';
  static const String _alertsKey = 'cached_alerts';
  static const String _bookmarksKey = 'bookmarked_news';
  static const String _userPreferenceKey = 'user_preference';
  static const String _filterKey = 'news_filter';

  // FinanceNews 전용 캐시 키
  static const String _financeNewsKey = 'cached_finance_news';
  static const String _financeNewsTimestampKey = 'cached_finance_news_ts';

  // 북마크된 뉴스 객체 저장소 (ID 목록과 별개로 전체 JSON 저장)
  static const String _bookmarkedNewsObjectsKey = 'bookmarked_news_objects';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  /// SharedPreferences 인스턴스 생성
  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // ============ 뉴스 캐싱 ============

  /// 뉴스 저장
  Future<void> saveNews(List<News> newsList) async {
    final jsonList = newsList.map((news) => jsonEncode(news.toJson())).toList();
    await _prefs.setStringList(_newsKey, jsonList);
  }

  /// 캐시된 뉴스 조회
  List<News> getCachedNews() {
    final jsonList = _prefs.getStringList(_newsKey) ?? [];
    return jsonList.map((json) => News.fromJson(jsonDecode(json))).toList();
  }

  // ============ 키워드 캐싱 ============

  /// 키워드 저장
  Future<void> saveKeywords(List<Keyword> keywords) async {
    final jsonList = keywords.map((kw) => jsonEncode(kw.toJson())).toList();
    await _prefs.setStringList(_keywordsKey, jsonList);
  }

  /// 캐시된 키워드 조회
  List<Keyword> getCachedKeywords() {
    final jsonList = _prefs.getStringList(_keywordsKey) ?? [];
    return jsonList.map((json) => Keyword.fromJson(jsonDecode(json))).toList();
  }

  // ============ 트렌드 캐싱 ============

  /// 트렌드 저장
  Future<void> saveTrends(List<Trend> trends) async {
    final jsonList = trends.map((trend) => jsonEncode(trend.toJson())).toList();
    await _prefs.setStringList(_trendsKey, jsonList);
  }

  /// 캐시된 트렌드 조회
  List<Trend> getCachedTrends() {
    final jsonList = _prefs.getStringList(_trendsKey) ?? [];
    return jsonList.map((json) => Trend.fromJson(jsonDecode(json))).toList();
  }

  // ============ 알림 캐싱 ============

  /// 알림 저장
  Future<void> saveAlerts(List<Alert> alerts) async {
    final jsonList = alerts.map((alert) => jsonEncode(alert.toJson())).toList();
    await _prefs.setStringList(_alertsKey, jsonList);
  }

  /// 캐시된 알림 조회
  List<Alert> getCachedAlerts() {
    final jsonList = _prefs.getStringList(_alertsKey) ?? [];
    return jsonList.map((json) => Alert.fromJson(jsonDecode(json))).toList();
  }

  // ============ 북마크 관리 ============

  /// 뉴스 북마크 추가/제거 (ID 목록 + 전체 객체 동시 관리)
  Future<void> toggleBookmark(News news) async {
    final bookmarks = _getBookmarkedNewsIds();

    if (bookmarks.contains(news.id)) {
      bookmarks.remove(news.id);
      await _removeBookmarkedNewsObject(news.id);
    } else {
      bookmarks.add(news.id);
      await _saveBookmarkedNewsObject(news);
    }

    await _prefs.setStringList(_bookmarksKey, bookmarks);
  }

  /// 북마크된 뉴스 객체 전체 반환
  List<News> getBookmarkedNewsObjects() {
    final jsonList = _prefs.getStringList(_bookmarkedNewsObjectsKey) ?? [];
    final result = <News>[];
    for (final json in jsonList) {
      try {
        result.add(News.fromJson(jsonDecode(json)));
      } catch (_) {}
    }
    return result;
  }

  Future<void> _saveBookmarkedNewsObject(News news) async {
    final existing = _prefs.getStringList(_bookmarkedNewsObjectsKey) ?? [];
    // 중복 방지
    final filtered = existing.where((j) {
      try {
        return jsonDecode(j)['id'] != news.id;
      } catch (_) {
        return true;
      }
    }).toList();
    // isBookmarked를 true로 보장하여 저장
    filtered.add(jsonEncode(news.copyWith(isBookmarked: true).toJson()));
    await _prefs.setStringList(_bookmarkedNewsObjectsKey, filtered);
  }

  Future<void> _removeBookmarkedNewsObject(String newsId) async {
    final existing = _prefs.getStringList(_bookmarkedNewsObjectsKey) ?? [];
    final filtered = existing.where((j) {
      try {
        return jsonDecode(j)['id'] != newsId;
      } catch (_) {
        return true;
      }
    }).toList();
    await _prefs.setStringList(_bookmarkedNewsObjectsKey, filtered);
  }

  /// 북마크 상태 확인
  bool isBookmarked(String newsId) {
    return _getBookmarkedNewsIds().contains(newsId);
  }

  /// 북마크된 뉴스 ID 리스트
  List<String> _getBookmarkedNewsIds() {
    return _prefs.getStringList(_bookmarksKey) ?? [];
  }

  // ============ 사용자 설정 ============

  /// 사용자 설정 저장
  Future<void> saveUserPreference(UserPreference preference) async {
    await _prefs.setString(_userPreferenceKey, jsonEncode(preference.toJson()));
  }

  /// 사용자 설정 조회
  UserPreference? getUserPreference() {
    final json = _prefs.getString(_userPreferenceKey);
    if (json == null) return null;
    return UserPreference.fromJson(jsonDecode(json));
  }

  // ============ 필터 저장 ============

  /// 필터 저장
  Future<void> saveFilter(NewsFilter filter) async {
    await _prefs.setString(_filterKey, jsonEncode(filter.toJson()));
  }

  /// 필터 조회
  NewsFilter? getFilter() {
    final json = _prefs.getString(_filterKey);
    if (json == null) return null;
    return NewsFilter.fromJson(jsonDecode(json));
  }

  // ============ 캐시 관리 ============

  /// 모든 캐시 초기화
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  /// 뉴스 캐시만 초기화
  Future<void> clearNews() async {
    await _prefs.remove(_newsKey);
  }

  /// 마지막 업데이트 시간 저장
  Future<void> setLastUpdateTime(String key, DateTime time) async {
    await _prefs.setString(key, time.toIso8601String());
  }

  /// 마지막 업데이트 시간 조회
  DateTime? getLastUpdateTime(String key) {
    final timeStr = _prefs.getString(key);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // ============ FinanceNews 캐싱 ============

  /// FinanceNews 목록 저장
  Future<void> saveFinanceNews(List<FinanceNews> news) async {
    final jsonList = news.map((n) => jsonEncode(n.toJson())).toList();
    await _prefs.setStringList(_financeNewsKey, jsonList);
    await _prefs.setString(
      _financeNewsTimestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// 캐시된 FinanceNews 조회
  List<FinanceNews> getCachedFinanceNews() {
    final jsonList = _prefs.getStringList(_financeNewsKey) ?? [];
    if (jsonList.isEmpty) return [];
    try {
      return jsonList.map((j) => FinanceNews.fromJson(jsonDecode(j))).toList();
    } catch (_) {
      return [];
    }
  }

  /// FinanceNews 캐시가 유효한지 여부 (기본 4시간 TTL)
  bool isFinanceNewsCacheValid({Duration ttl = const Duration(hours: 4)}) {
    final tsStr = _prefs.getString(_financeNewsTimestampKey);
    if (tsStr == null) return false;
    final ts = DateTime.tryParse(tsStr);
    if (ts == null) return false;
    return DateTime.now().difference(ts) < ttl;
  }
}
