import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/crypto_data.dart';
import '../models/market_index.dart';

/// Yahoo Finance v8 chart API를 사용한 실시간 시장 지수 서비스
/// 심볼별 개별 병렬 요청 방식 — crumb/쿠키 불필요
class MarketDataService {
  /// 암호화폐 심볼 목록
  static const _cryptoSymbols = ['BTC-USD', 'ETH-USD', 'XRP-USD', 'SOL-USD'];
  static const _cryptoNameMap = {
    'BTC-USD': '비트코인',
    'ETH-USD': '이더리움',
    'XRP-USD': '리플',
    'SOL-USD': '솔라나',
  };

  /// 조회할 심볼 목록 (표시 순서)
  static const _symbols = [
    '^KS11', // KOSPI
    '^KQ11', // KOSDAQ
    '^IXIC', // NASDAQ Composite
    '^GSPC', // S&P 500
    '^DJI', // 다우 존스
    'KRW=X', // USD/KRW 환율
    'CL=F', // WTI 원유
  ];

  /// 심볼 → 한글 표시명 매핑
  static const _nameMap = {
    '^KS11': '코스피',
    '^KQ11': '코스닥',
    '^IXIC': '나스닥',
    '^GSPC': 'S&P 500',
    '^DJI': '다우존스',
    'KRW=X': '달러/원',
    'CL=F': '국제유가',
  };

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) '
        'Mobile/15E148',
    'Accept': 'application/json',
    'Accept-Language': 'ko-KR,ko;q=0.9',
  };

  final http.Client _client;

  MarketDataService({http.Client? client}) : _client = client ?? http.Client();

  /// 시장 지수 전체 조회 (병렬)
  Future<List<MarketIndex>> fetchMarketIndices() async {
    final results = await Future.wait(_symbols.map(_fetchSingle));

    // null(실패)은 폴백값으로 채움
    final now = DateTime.now();
    return List.generate(_symbols.length, (i) {
      return results[i] ??
          MarketIndex(
            symbol: _symbols[i],
            name: _nameMap[_symbols[i]] ?? _symbols[i],
            price: 0,
            change: 0,
            changeAmt: 0,
            currency: 'USD',
            updatedAt: now,
          );
    });
  }

  /// 심볼 하나씩 v8 chart API로 조회 (더 정확한 데이터 수집)
  Future<MarketIndex?> _fetchSingle(String symbol) async {
    final encoded = Uri.encodeComponent(symbol);
    // query1, query2, finance 순서로 시도하여 신뢰성 향상
    for (final host in ['query1', 'query2', 'finance']) {
      try {
        // 🔥 더 정확한 시장 데이터를 위한 파라미터 개선
        final uri = Uri.parse(
          'https://$host.finance.yahoo.com/v8/finance/chart/$encoded'
          '?interval=1d&range=1d&formatted=false&includePrePost=true' // premarket/afterhours 포함
          '&events=capitalGain%2Cdividends%2Csplits&corsDomain=finance.yahoo.com',
        );
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15)); // 타임아웃 증가

        if (response.statusCode == 200) {
          final result = _parseChart(response.body, symbol);
          if (result != null) return result;
        }

        // HTTP 오류코드 로깅 (개발 중 디버깅용)
        if (response.statusCode != 200) {
          debugPrint(
            'MarketData API Error: ${response.statusCode} for $symbol',
          );
        }
      } catch (e) {
        // 네트워크 오류 로깅
        debugPrint('MarketData Network Error for $symbol: $e');
        // 다음 호스트로 시도
        continue;
      }
    }
    return null;
  }

  MarketIndex? _parseChart(String body, String symbol) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final chart = json['chart'] as Map<String, dynamic>?;
      final resultList = chart?['result'] as List?;
      if (resultList == null || resultList.isEmpty) return null;

      final meta =
          (resultList[0] as Map<String, dynamic>)['meta']
              as Map<String, dynamic>?;
      if (meta == null) return null;

      // 🔥 더 정확한 가격 데이터 추출 (실시간 우선, 없으면 종가)
      final price =
          (meta['regularMarketPrice'] ??
                  meta['currentPrice'] ??
                  meta['previousClose'] as num?)
              ?.toDouble() ??
          0.0;

      final prevClose =
          (meta['chartPreviousClose'] ?? meta['previousClose'] as num?)
              ?.toDouble() ??
          0.0;

      final currency = meta['currency'] as String? ?? 'USD';

      // 🔥 변화량 계산 개선 (더 정확한 수식)
      final changeAmt = prevClose > 0 ? price - prevClose : 0.0;
      final changePct = prevClose > 0 ? (changeAmt / prevClose) * 100 : 0.0;

      // 🔥 데이터 유효성 검증 추가
      if (price <= 0 || prevClose <= 0) {
        debugPrint(
          'Invalid price data for $symbol: price=$price, prevClose=$prevClose',
        );
        return null;
      }

      return MarketIndex(
        symbol: symbol,
        name: _nameMap[symbol] ?? symbol,
        price: price,
        change: changePct,
        changeAmt: changeAmt,
        currency: currency,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Chart parsing error for $symbol: $e');
      return null;
    }
  }

  /// KRX 6자리 코드로 주식 가격 조회 (KOSPI → KOSDAQ 순서로 시도)
  /// [code] : KRX 6자리 종목코드 (예: "005930")
  /// [name] : 표시할 종목명 (예: "삼성전자")
  Future<MarketIndex?> fetchKrxStock(String code, String name) async {
    for (final suffix in ['.KS', '.KQ']) {
      final result = await _fetchSingle('$code$suffix');
      if (result != null) {
        return MarketIndex(
          symbol: result.symbol,
          name: name,
          price: result.price,
          change: result.change,
          changeAmt: result.changeAmt,
          currency: 'KRW',
          updatedAt: result.updatedAt,
        );
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // 암호화폐 히스토리 차트 데이터
  // ─────────────────────────────────────────────

  /// 기간에 따른 Yahoo Finance range/interval 매핑
  static ({String range, String interval}) _cryptoRangeInterval(String period) {
    return switch (period) {
      '24h' => (range: '1d', interval: '30m'),
      '7d' => (range: '5d', interval: '1d'),
      _ => (range: '1mo', interval: '1d'),
    };
  }

  /// BTC, ETH, XRP, SOL 가격 히스토리 병렬 조회
  Future<List<CryptoData>> fetchCryptoHistory(String period) async {
    final ri = _cryptoRangeInterval(period);
    final results = await Future.wait(
      _cryptoSymbols.map((s) => _fetchCryptoSingle(s, ri)),
    );
    return results.whereType<CryptoData>().toList();
  }

  Future<CryptoData?> _fetchCryptoSingle(
    String symbol,
    ({String range, String interval}) ri,
  ) async {
    final encoded = Uri.encodeComponent(symbol);
    for (final host in ['query1', 'query2', 'finance']) {
      try {
        final uri = Uri.parse(
          'https://$host.finance.yahoo.com/v8/finance/chart/$encoded'
          '?range=${ri.range}&interval=${ri.interval}&formatted=false',
        );
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = _parseCryptoHistory(response.body, symbol);
          if (data != null) return data;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  CryptoData? _parseCryptoHistory(String body, String symbol) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final result =
          ((json['chart']?['result']) as List<dynamic>?)?.firstOrNull;
      if (result == null) return null;

      final timestamps = result['timestamp'] as List<dynamic>?;
      final closes =
          ((result['indicators']?['quote'] as List<dynamic>?)
                  ?.firstOrNull)?['close']
              as List<dynamic>?;

      if (timestamps == null || closes == null || timestamps.isEmpty) {
        return null;
      }

      final points = <CryptoPricePoint>[];
      for (var i = 0; i < timestamps.length; i++) {
        final ts = timestamps[i] as int?;
        final price = closes[i] != null ? (closes[i] as num).toDouble() : null;
        if (ts != null && price != null && price > 0) {
          points.add(
            CryptoPricePoint(
              price: price,
              time: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
            ),
          );
        }
      }
      if (points.isEmpty) return null;

      final currentPrice = points.last.price;
      final firstPrice = points.first.price;
      final changePct = firstPrice > 0
          ? ((currentPrice - firstPrice) / firstPrice) * 100
          : 0.0;

      return CryptoData(
        symbol: symbol,
        name: _cryptoNameMap[symbol] ?? symbol,
        currentPrice: currentPrice,
        changePercent: changePct,
        points: points,
      );
    } catch (e) {
      debugPrint('CryptoHistory parse error [$symbol]: $e');
      return null;
    }
  }
}
