/// 주식 종목 정보 모델
class StockTicker {
  final String symbol; // KOSPI, AAPL 등
  final String name; // 코스피, 애플
  final String market; // "KOSPI", "NASDAQ", "NYSE" 등
  final String? companyName; // Apple Inc.
  final String? sector; // 기술, 금융
  final String? industry; // 반도체, 소매

  const StockTicker({
    required this.symbol,
    required this.name,
    required this.market,
    this.companyName,
    this.sector,
    this.industry,
  });

  factory StockTicker.fromJson(Map<String, dynamic> json) {
    return StockTicker(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      market: json['market'] as String? ?? '',
      companyName: json['companyName'] as String?,
      sector: json['sector'] as String?,
      industry: json['industry'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'market': market,
      'companyName': companyName,
      'sector': sector,
      'industry': industry,
    };
  }
}
