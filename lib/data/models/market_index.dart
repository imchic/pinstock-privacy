/// 실시간 시장 지수 데이터 모델
class MarketIndex {
  final String symbol; // "^KS11", "^IXIC" 등
  final String name; // "KOSPI", "NASDAQ" 등
  final double price; // 현재가
  final double change; // % 변화율
  final double changeAmt; // 절대 변화량
  final String currency; // "KRW", "USD" 등
  final DateTime updatedAt;

  const MarketIndex({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changeAmt,
    required this.currency,
    required this.updatedAt,
  });

  bool get isUp => change >= 0;

  /// 천 단위 콤마 포맷 (통화·규모에 따라 소수점 자리 조정)
  String get formattedPrice {
    if (price == 0) return '-';

    // KRW: 소수점 없이 정수, 그 외: 소수 2자리
    final isKrw = currency == 'KRW';
    final decimals = isKrw ? 0 : 2;
    final parts = price.toStringAsFixed(decimals).split('.');
    final intStr = parts[0];

    final buf = StringBuffer();
    for (var i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) buf.write(',');
      buf.write(intStr[i]);
    }
    if (parts.length > 1) return '$buf.${parts[1]}';
    return buf.toString();
  }

  /// 변화율 포맷 (부호 포함)
  String get formattedChange {
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}%';
  }

  /// 절대 변화량 포맷 (부호 포함)
  String get formattedChangeAmt {
    final sign = changeAmt >= 0 ? '+' : '';
    // KRW: 소수점 없이 정수
    if (currency == 'KRW') return '$sign${changeAmt.toStringAsFixed(0)}';
    if (changeAmt.abs() < 100) {
      return '$sign${changeAmt.toStringAsFixed(2)}';
    }
    return '$sign${changeAmt.toStringAsFixed(0)}';
  }

  MarketIndex copyWith({
    String? symbol,
    String? name,
    double? price,
    double? change,
    double? changeAmt,
    String? currency,
    DateTime? updatedAt,
  }) {
    return MarketIndex(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      price: price ?? this.price,
      change: change ?? this.change,
      changeAmt: changeAmt ?? this.changeAmt,
      currency: currency ?? this.currency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
