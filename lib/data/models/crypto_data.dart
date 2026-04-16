/// 암호화폐 가격 데이터 포인트
class CryptoPricePoint {
  final double price;
  final DateTime time;

  const CryptoPricePoint({required this.price, required this.time});
}

/// 암호화폐 차트 데이터 모델
class CryptoData {
  final String symbol;
  final String name;
  final double currentPrice;
  final double changePercent;
  final List<CryptoPricePoint> points;

  const CryptoData({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.changePercent,
    required this.points,
  });

  bool get isUp => changePercent >= 0;

  String get formattedChange =>
      '${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

  String get formattedPrice {
    if (currentPrice >= 1000) {
      final intPart = currentPrice.toInt();
      final s = intPart.toString();
      final buf = StringBuffer('\$');
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    } else if (currentPrice >= 1) {
      return '\$${currentPrice.toStringAsFixed(2)}';
    } else {
      return '\$${currentPrice.toStringAsFixed(4)}';
    }
  }
}
