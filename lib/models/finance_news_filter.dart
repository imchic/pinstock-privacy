/// 금융 뉴스 필터 모델
class FinanceNewsFilter {
  final List<String> sectors; // "기술", "금융" 등
  final List<String> categories; // "market", "economic", "earnings" 등
  final List<String> tickers; // "KOSPI", "AAPL" 등
  final bool onlyBookmarked;
  final String searchQuery;

  FinanceNewsFilter({
    this.sectors = const [],
    this.categories = const [],
    this.tickers = const [],
    this.onlyBookmarked = false,
    this.searchQuery = '',
  });

  /// 복사본 생성
  FinanceNewsFilter copyWith({
    List<String>? sectors,
    List<String>? categories,
    List<String>? tickers,
    bool? onlyBookmarked,
    String? searchQuery,
  }) {
    return FinanceNewsFilter(
      sectors: sectors ?? this.sectors,
      categories: categories ?? this.categories,
      tickers: tickers ?? this.tickers,
      onlyBookmarked: onlyBookmarked ?? this.onlyBookmarked,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
