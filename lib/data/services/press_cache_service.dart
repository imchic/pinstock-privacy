import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news.dart';

/// 언론사 도메인 → 한글명 자동 크롤링 + 로컬 영구 캐싱 서비스
///
/// 동작 방식:
///  1. 앱 시작 시 SharedPreferences에서 기존 캐시 로드 (비동기, 내부 처리)
///  2. [resolveSync]로 메모리 캐시 즉시 조회
///  3. 캐시 미스 시 [prefetch]로 백그라운드 크롤링 + 저장
///  4. 다음 뉴스 갱신부터 한글명이 표시됨
class PressCacheService extends ChangeNotifier {
  static const _prefKey = 'press_domain_cache_v1';

  /// 메모리 캐시 (host → 한글 언론사명)
  final Map<String, String> _cache = {};

  /// 현재 크롤링 중인 host 집합 (중복 요청 방지)
  final Set<String> _fetching = {};

  /// SharedPreferences 로드 완료 Future
  late final Future<void> _preloadFuture;

  PressCacheService() {
    _preloadFuture = _loadFromPrefs();
  }

  // ── 초기화 ──────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final map = (jsonDecode(raw) as Map<String, dynamic>)
            .cast<String, String>();
        _cache.addAll(map);
        debugPrint('📰 PressCacheService: ${_cache.length}개 언론사 캐시 로드');
      }
    } catch (e) {
      debugPrint('⚠️ PressCacheService 로드 실패: $e');
    }
  }

  // ── 공개 API ────────────────────────────────────

  /// 메모리 캐시에서 즉시 조회 (없으면 null)
  String? resolveSync(String host) => _cache[host];

  /// [news.newsUrl]에서 host를 추출해 캐시 조회, 없으면 [News.source] 반환
  String resolveSource(News news) {
    try {
      final host = Uri.parse(news.newsUrl).host.replaceFirst('www.', '');
      return _cache[host] ?? news.source;
    } catch (_) {
      return news.source;
    }
  }

  /// 캐시에 없는 도메인을 백그라운드에서 크롤링 후 저장
  /// 결과는 다음 [resolveSync] 호출 때 반영됩니다.
  void prefetch(String host) {
    if (_cache.containsKey(host) || _fetching.contains(host)) return;
    _fetching.add(host);

    // 프리로드 완료 후 실행
    _preloadFuture.then((_) async {
      if (_cache.containsKey(host)) {
        _fetching.remove(host);
        return;
      }
      try {
        final name = await _crawlName(host);
        if (name != null && name.isNotEmpty) {
          final abbr = _abbreviate(name);
          _cache[host] = abbr;
          await _persist();
          notifyListeners();
          debugPrint('📰 언론사명 저장: $host → $abbr');
        }
      } catch (e) {
        debugPrint('⚠️ prefetch 실패 ($host): $e');
      } finally {
        _fetching.remove(host);
      }
    });
  }

  // ── 크롤링 ──────────────────────────────────────

  Future<String?> _crawlName(String host) async {
    final candidates = [
      Uri.https('www.$host', '/'),
      Uri.https(host, '/'),
      Uri.http('www.$host', '/'),
    ];

    for (final url in candidates) {
      try {
        final resp = await http
            .get(
              url,
              headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; StockHubBot/1.0)',
                'Accept-Language': 'ko-KR,ko;q=0.9',
              },
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode != 200) continue;

        final body = _decodeBody(resp);

        // 1순위: <meta property="og:site_name">
        final ogSite = _metaContent(
          body,
          r'''<meta[^>]+property=["']og:site_name["'][^>]+content=["']([^"']+)["']''',
        );
        if (ogSite != null && !_isGarbled(ogSite)) return ogSite;

        // og 속성 순서가 반대인 경우
        final ogSiteRev = _metaContent(
          body,
          r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:site_name["']''',
        );
        if (ogSiteRev != null && !_isGarbled(ogSiteRev)) return ogSiteRev;

        // 2순위: <meta name="application-name">
        final appName = _metaContent(
          body,
          r'''<meta[^>]+name=["']application-name["'][^>]+content=["']([^"']+)["']''',
        );
        if (appName != null && !_isGarbled(appName)) return appName;

        // 3순위: <title>과 <meta name="description"> 비교 파싱
        final titleRaw = RegExp(
          r'<title[^>]*>([^<]+)</title>',
          caseSensitive: false,
        ).firstMatch(body)?.group(1);

        final descriptionRaw =
            _metaContent(
              body,
              r'''<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']''',
            ) ??
            _metaContent(
              body,
              r'''<meta[^>]+content=["']([^"']+)["'][^>]+name=["']description["']''',
            );

        // title에서 후보 추출
        final titleCandidates = <String>[];
        if (titleRaw != null && titleRaw.trim().isNotEmpty) {
          final segments = titleRaw
              .split(RegExp(r'[|\-–—▶：:]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          // 마지막 세그먼트가 더 짧으면 사이트명일 가능성이 높음
          if (segments.length > 1 &&
              segments.last.length < 20 &&
              !_isGarbled(segments.last)) {
            titleCandidates.add(segments.last);
          }
          if (segments.isNotEmpty && !_isGarbled(segments.first)) {
            titleCandidates.add(segments.first);
          }
        }

        // description에서 후보 추출 (보통 더 짧은 언론사명이 들어옴)
        String? bestCandidate;
        if (descriptionRaw != null &&
            descriptionRaw.isNotEmpty &&
            !_isGarbled(descriptionRaw)) {
          bestCandidate = descriptionRaw;
        }

        // title 후보 중 선택
        if (bestCandidate == null) {
          for (final c in titleCandidates) {
            if (c.isNotEmpty) {
              bestCandidate = c;
              break;
            }
          }
        }

        return bestCandidate;
      } on TimeoutException {
        return null;
      } on SocketException {
        continue;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Latin Extended 범위(0x80–0x2FFF)에 한글이 아닌 문자 포함 → EUC-KR 깨짐으로 판단
  bool _isGarbled(String s) => s.runes.any((r) => r >= 0x80 && r < 0x3000);

  String? _metaContent(String body, String pattern) {
    final m = RegExp(pattern, caseSensitive: false).firstMatch(body);
    final value = m?.group(1)?.trim();
    return (value != null && value.isNotEmpty) ? value : null;
  }

  /// 언론사명 함축 정제
  /// - HTML 엔티티 제거, 불필요 접미어 제거, 16자 초과 시 단어 단위 절사
  String _abbreviate(String raw) {
    var s = raw
        // 앞뒤 구분자 제거: "::: 뉴스토마토 :::" → "뉴스토마토"
        .replaceAll(RegExp(r'^[\s:\-–—|▶]+'), '')
        .replaceAll(RegExp(r'[\s:\-–—|▶]+$'), '')
        // HTML 엔티티 기본 디코딩
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&nbsp;', ' ')
        // 괄호·슬로건 제거: "매일경제 - 세계를 보는..." → 매일경제
        .replaceAll(RegExp(r'\s*[-–—|:]\s*.+$'), '')
        // 괄호 내용 제거: "YTN (와이티엔)" → YTN
        .replaceAll(RegExp(r'\s*[(\[（［].+?[)\]）］]'), '')
        .trim();

    // 불필요 접미어 제거 (순서 중요: 긴 것 먼저)
    const suffixes = [
      ' 공식 홈페이지',
      ' 홈페이지',
      ' 온라인',
      ' 인터넷',
      ' 닷컴',
      '닷컴',
      '.com',
      '뉴미디어',
      ' 미디어',
    ];
    for (final suffix in suffixes) {
      if (s.endsWith(suffix)) {
        s = s.substring(0, s.length - suffix.length).trim();
      }
    }

    // 10자 초과 시 단어 단위로 절사
    if (s.length > 10) {
      final words = s.split(' ');
      final buf = StringBuffer();
      for (final w in words) {
        if ((buf.length + w.length) > 10) break;
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(w);
      }
      s = buf.isNotEmpty ? buf.toString() : s.substring(0, 10);
    }

    return s.trim();
  }

  String _decodeBody(http.Response resp) {
    final ct = resp.headers['content-type'] ?? '';
    // EUC-KR 페이지는 Dart에서 네이티브 디코딩 불가 → 빈 문자열 반환해 크롤링 스킵
    if (ct.contains('euc-kr') || ct.contains('ks_c_5601')) {
      return '';
    }
    // UTF-8 외 charset 명시 없는 경우 meta charset 확인용으로 latin1 시도
    try {
      final body = utf8.decode(resp.bodyBytes);
      return body;
    } catch (_) {
      // UTF-8 디코딩 실패 → 인코딩 불명, 스킵
      return '';
    }
  }

  // ── 캐시 저장 ────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_cache));
    } catch (e) {
      debugPrint('⚠️ PressCacheService 저장 실패: $e');
    }
  }
}
