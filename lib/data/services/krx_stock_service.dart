import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_hub/config/constants.dart';

class KrxStockService {
  // KRX Open API (http, GET, AUTH_KEY 헤더, basDd query param)
  static const _apiUrl = 'https://data-dbg.krx.co.kr/svc/apis/sto';

  final Dio _dio;
  KrxStockService({Dio? dio}) : _dio = dio ?? Dio();

  // fallback
  static const List<String> _kospiList = [];
  static const List<String> _kosdaqList = [];

  Future<({List<String> kospi, List<String> kosdaq})> fetchAllStocks() async {
    final cached = await _loadCache();
    if (cached != null) return cached;

    if (AppConstants.krxOpenApiKey.isNotEmpty) {
      try {
        final results = await Future.wait([
          _fetchApi('stk_isu_base_info'), // KOSPI 종목기본정보
          _fetchApi('ksq_isu_base_info'), // KOSDAQ 종목기본정보
        ]);

        final result = (kospi: results[0], kosdaq: results[1]);

        if (result.kospi.isNotEmpty || result.kosdaq.isNotEmpty) {
          await _saveCache(result.kospi, result.kosdaq);
          return result;
        }
      } catch (e) {
        debugPrint('⚠️ KRX API 호출 오류: $e');
      }
    }

    // API 실패 시 만료된 캐시라도 사용 (비상장 종목 추천 방지)
    final stale = await _loadStaleCache();
    return stale ?? (kospi: _kospiList, kosdaq: _kosdaqList);
  }

  Future<List<String>> _fetchApi(String path) async {
    final result = await _fetchApiWithCodes(path);
    return result.keys.toList();
  }

  Future<Map<String, String>> _fetchApiWithCodes(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_apiUrl/$path',
        queryParameters: {'basDd': '20260329'},
        options: Options(
          headers: {'AUTH_KEY': AppConstants.krxOpenApiKey},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      final items = data?['OutBlock_1'] ?? data?['output'] ?? data?['data'];

      if (items == null || items is! List) {
        debugPrint('KRX 응답 구조 이상 ($path): ${data?.keys}');
        return {};
      }

      final map = <String, String>{};
      for (final e in items) {
        final m = e as Map<String, dynamic>;
        final name = (m['ISU_ABBRV'] ?? '').toString().trim();
        final code = (m['ISU_SRT_CD'] ?? '').toString().trim();
        if (name.isNotEmpty && code.isNotEmpty) map[name] = code;
      }
      return map;
    } on DioException catch (e) {
      debugPrint('KRX API 실패 ($path): ${e.response?.statusCode}');
      debugPrint('${e.response?.data}');
      return {};
    }
  }

  // 캐시
  static const _cacheKeyKospi = 'krx_kospi_stocks';
  static const _cacheKeyKosdaq = 'krx_kosdaq_stocks';
  static const _cacheTsKey = 'krx_stocks_timestamp';

  Future<({List<String> kospi, List<String> kosdaq})?> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTsKey);

    if (ts == null || DateTime.now().millisecondsSinceEpoch - ts > 604800000) {
      return null;
    }

    final k = prefs.getStringList(_cacheKeyKospi);
    final q = prefs.getStringList(_cacheKeyKosdaq);

    return (k != null && q != null) ? (kospi: k, kosdaq: q) : null;
  }

  Future<({List<String> kospi, List<String> kosdaq})?> _loadStaleCache() async {
    final prefs = await SharedPreferences.getInstance();
    final k = prefs.getStringList(_cacheKeyKospi);
    final q = prefs.getStringList(_cacheKeyKosdaq);
    if (k != null && k.isNotEmpty && q != null && q.isNotEmpty) {
      return (kospi: k, kosdaq: q);
    }
    return null;
  }

  Future<void> _saveCache(List<String> kospi, List<String> kosdaq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cacheKeyKospi, kospi);
    await prefs.setStringList(_cacheKeyKosdaq, kosdaq);
    await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }
}
