import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/constants.dart';
import '../models/market_index.dart';

/// Google Gemini를 사용한 AI 한줄 시장 요약 서비스
class AiSummaryService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';

  static const List<_NasdaqCandidate> _nasdaqCandidates = [
    _NasdaqCandidate(
      name: '엔비디아',
      ticker: 'NVDA',
      sector: 'AI반도체',
      aliases: ['nvidia'],
      keywords: ['ai', '인공지능', 'gpu', '데이터센터', '반도체', 'hbm'],
      reason: 'AI 서버 투자 확대 수혜',
    ),
    _NasdaqCandidate(
      name: 'AMD',
      ticker: 'AMD',
      sector: 'AI반도체',
      aliases: ['advanced micro devices'],
      keywords: ['ai', 'gpu', '서버', 'cpu', '반도체', '데이터센터'],
      reason: 'AI GPU와 서버 CPU 확장 기대',
    ),
    _NasdaqCandidate(
      name: '브로드컴',
      ticker: 'AVGO',
      sector: 'AI반도체',
      aliases: ['broadcom'],
      keywords: ['ai', '반도체', '네트워크', '데이터센터', '맞춤형칩'],
      reason: '맞춤형 AI 칩 수요 확대 수혜',
    ),
    _NasdaqCandidate(
      name: 'ARM',
      ticker: 'ARM',
      sector: '반도체설계',
      aliases: ['arm holdings'],
      keywords: ['반도체', '설계', 'ai', '모바일칩', 'ip'],
      reason: '반도체 설계 IP 수요 확대 기대',
    ),
    _NasdaqCandidate(
      name: '마이크론',
      ticker: 'MU',
      sector: '메모리',
      aliases: ['micron', 'micron technology'],
      keywords: ['hbm', '메모리', 'd램', 'dram', '낸드', 'ai'],
      reason: 'HBM 중심 메모리 업황 개선 수혜',
    ),
    _NasdaqCandidate(
      name: 'ASML',
      ticker: 'ASML',
      sector: '반도체장비',
      aliases: ['asml holding', 'asml holdings'],
      keywords: ['euv', '반도체장비', '파운드리', '첨단공정', '반도체'],
      reason: '첨단공정 투자 재개 수혜 기대',
    ),
    _NasdaqCandidate(
      name: '마이크로소프트',
      ticker: 'MSFT',
      sector: '클라우드소프트웨어',
      aliases: ['microsoft'],
      keywords: ['클라우드', 'azure', 'ai', 'copilot', '소프트웨어', '기업IT'],
      reason: 'Azure와 Copilot 동반 성장 기대',
    ),
    _NasdaqCandidate(
      name: '알파벳',
      ticker: 'GOOGL',
      sector: '광고플랫폼',
      aliases: ['alphabet', 'google'],
      keywords: ['검색', '광고', '유튜브', '클라우드', 'ai', '디지털광고'],
      reason: '검색·광고 회복과 AI 서비스 확장',
    ),
    _NasdaqCandidate(
      name: '아마존',
      ticker: 'AMZN',
      sector: '클라우드소비',
      aliases: ['amazon'],
      keywords: ['aws', '클라우드', '전자상거래', '소비', '물류', '광고'],
      reason: 'AWS와 소비 회복 동시 수혜 기대',
    ),
    _NasdaqCandidate(
      name: '메타',
      ticker: 'META',
      sector: '광고플랫폼',
      aliases: ['meta', 'meta platforms', 'facebook'],
      keywords: ['광고', 'sns', '소셜', '릴스', 'ai', '디지털광고'],
      reason: '광고 효율 개선과 AI 추천 강화',
    ),
    _NasdaqCandidate(
      name: '애플',
      ticker: 'AAPL',
      sector: '소비전자',
      aliases: ['apple'],
      keywords: ['아이폰', '스마트폰', '디바이스', '소비', '서비스', '웨어러블'],
      reason: '기기 교체 수요와 서비스 매출 방어',
    ),
    _NasdaqCandidate(
      name: '테슬라',
      ticker: 'TSLA',
      sector: '전기차',
      aliases: ['tesla'],
      keywords: ['전기차', 'ev', '배터리', '자율주행', '로보택시', '에너지저장'],
      reason: '자율주행·에너지 사업 모멘텀 반영',
    ),
    _NasdaqCandidate(
      name: '팔란티어',
      ticker: 'PLTR',
      sector: '데이터소프트웨어',
      aliases: ['palantir', 'palantir technologies'],
      keywords: ['국방', '정부', '데이터', 'ai', '방산', '공공'],
      reason: '정부·국방 AI 수요 확대 수혜',
    ),
    _NasdaqCandidate(
      name: '팔로알토',
      ticker: 'PANW',
      sector: '사이버보안',
      aliases: ['palo alto', 'palo alto networks'],
      keywords: ['보안', '사이버', '해킹', '랜섬웨어', '클라우드보안'],
      reason: '사이버보안 지출 확대 수혜 기대',
    ),
    _NasdaqCandidate(
      name: '크라우드스트라이크',
      ticker: 'CRWD',
      sector: '사이버보안',
      aliases: ['crowdstrike', 'crowdstrike holdings'],
      keywords: ['보안', '사이버', 'endpoint', '해킹', '랜섬웨어'],
      reason: '클라우드 보안 수요 확대로 수혜',
    ),
    _NasdaqCandidate(
      name: '어도비',
      ticker: 'ADBE',
      sector: '소프트웨어',
      aliases: ['adobe'],
      keywords: ['콘텐츠', '디자인', '크리에이터', '생성형ai', '소프트웨어'],
      reason: '생성형 AI 기반 소프트웨어 수혜',
    ),
    _NasdaqCandidate(
      name: '넷플릭스',
      ticker: 'NFLX',
      sector: '미디어플랫폼',
      aliases: ['netflix'],
      keywords: ['스트리밍', '광고요금제', '콘텐츠', '구독'],
      reason: '광고 요금제와 가입자 성장 기대',
    ),
    _NasdaqCandidate(
      name: '인튜이티브서지컬',
      ticker: 'ISRG',
      sector: '의료기기',
      aliases: ['intuitive surgical'],
      keywords: ['의료기기', '수술로봇', '헬스케어', '병원'],
      reason: '수술로봇 확산에 따른 성장 기대',
    ),
    _NasdaqCandidate(
      name: '버텍스',
      ticker: 'VRTX',
      sector: '바이오',
      aliases: ['vertex', 'vertex pharmaceuticals'],
      keywords: ['신약', '바이오', '제약', '임상', '희귀질환'],
      reason: '신약 파이프라인 가치 재평가 가능',
    ),
  ];

  static const List<String> _defaultNasdaqFallbackTickers = [
    'MSFT',
    'AVGO',
    'AMZN',
    'META',
  ];

  /// 시장 지수 데이터 + 뉴스 헤드라인 → 한 줄 한국어 요약 반환
  Future<String> generateMarketSummary({
    required List<MarketIndex> indices,
    List<String> headlines = const [],
    List<String> kospiStocks = const [], // KRX 코스피 실제 상장 종목
    List<String> kosdaqStocks = const [], // KRX 코스닥 실제 상장 종목
  }) async {
    const key = AppConstants.geminiApiKey;
    if (key.isEmpty) throw Exception('Gemini API 키가 설정되지 않았습니다');

    // 뉴스 헤드라인이 핵심 데이터, 지수는 보조
    final newsText = headlines.isNotEmpty
        ? headlines.map((h) => '• $h').join('\n')
        : '뉴스 없음';
    final indexText = indices.isNotEmpty
        ? '시장 지수: ${indices.map((i) => '${i.name} ${i.formattedChange}').join(', ')}'
        : '';

    // KRX 실제 종목 리스트 — 있으면 프롬프트에 포함, 없으면 추천 금지
    final kospiListText = kospiStocks.isNotEmpty
        ? '코스피 상장 종목 목록(이 중에서만 추천):\n${kospiStocks.join(', ')}\n'
        : '코스피 종목 목록 없음 → 코스피 항목은 반드시 "코스피: 없음" 으로만 출력할 것\n';
    final kosdaqListText = kosdaqStocks.isNotEmpty
        ? '코스닥 상장 종목 목록(이 중에서만 추천):\n${kosdaqStocks.join(', ')}\n'
        : '코스닥 종목 목록 없음 → 코스닥 항목은 반드시 "코스닥: 없음" 으로만 출력할 것\n';
    final nasdaqListText =
        '나스닥 우선 추천 후보군(가능하면 이 안에서 선택, 티커만 쓰지 말고 종목명+티커로 출력):\n'
        '${_nasdaqCandidates.map((c) => '${c.name} ${c.ticker}(${c.sector})').join(', ')}\n';

    final prompt =
        '역할:\n'
        '당신은 한국 및 글로벌 금융시장을 분석하는 탑티어 헤지펀드 애널리스트다.\n'
        '뉴스 기반으로 단기 트레이딩 관점에서 실제 수익 기회를 찾는 것이 목표다.\n\n'
        '분석 기준:\n'
        '- 뉴스 → 수혜/피해 산업 도출\n'
        '- 산업 → 실제 수혜 가능 종목 연결\n'
        '- 반드시 "왜 오를지" 근거 중심\n\n'
        '--- 출력 형식 (반드시 그대로 따를 것) ---\n'
        '하이라이트: 핵심 포인트 한 줄\n'
        '하이라이트: 핵심 포인트 한 줄\n'
        '하이라이트: 핵심 포인트 한 줄\n'
        '분석제목: 첫 번째 분석 소제목\n'
        '분석내용: 소제목에 대한 상세 분석 1~2줄\n'
        '분석제목: 두 번째 분석 소제목\n'
        '분석내용: 소제목에 대한 상세 분석 1~2줄\n'
        '강세섹터: 섹터A, 섹터B, 섹터C\n'
        '약세섹터: 섹터D, 섹터E\n'
        '코스피: 종목명(핵심 이유), 종목명(핵심 이유)\n'
        '코스닥: 종목명(핵심 이유), 종목명(핵심 이유)\n'
        '나스닥: 종목명 티커(핵심 이유), 종목명 티커(핵심 이유)\n'
        '코인: 티커(핵심 이유), 티커(핵심 이유)\n'
        '---\n\n'
        '규칙:\n'
        '[하이라이트]\n'
        '- 정확히 3줄\n'
        '- 각 줄: 이 뉴스에서 가장 중요한 핵심 사실 1개\n'
        '- 핵심 키워드는 **굵게** 표시\n'
        '- 20~40자 이내\n\n'
        '[분석]\n'
        '- 분석제목+분석내용 세트 정확히 2개\n'
        '- 소제목: 10자 이내, 관점/테마 중심\n'
        '- 내용: 뉴스 → 시장 영향 흐름 서술\n\n'
        '[섹터]\n'
        '- 뉴스에서 직접 연결되는 섹터만 선택\n'
        '- 강세/약세 각각 2~4개\n\n'
        '[추천 종목]\n'
        '- 각 시장별 3~5개\n'
        '- 종목명(핵심 이유) 형식, 이유는 15~30자\n'
        '- 뉴스 → 산업 → 종목 흐름이 명확해야 함\n\n'
        '[나스닥 제한]\n'
        '- 나스닥은 티커만 쓰지 말고 반드시 종목명과 티커를 함께 표기\n'
        '- 가능하면 서로 다른 2개 이상 세부 테마로 분산 추천\n'
        '- 엔비디아 1종목만 반복 추천하는 식의 쏠림 금지\n'
        '- AI/반도체 이슈면 AMD, AVGO, ARM, MU, MSFT 등 연관 수혜주도 함께 검토\n\n'
        '[KRX 제한]\n'
        '- 코스피/코스닥 종목은 반드시 제공된 리스트 내에서만 선택\n'
        '- 코스피 리스트에 있는 종목은 절대 코스닥 항목에 포함하지 말 것\n'
        '- 코스닥 리스트에 있는 종목은 절대 코스피 항목에 포함하지 말 것\n'
        '- 리스트에 없는 종목은 추천하지 말 것\n\n'
        '[금지사항]\n'
        '- 뉴스와 무관한 추천 금지\n'
        '- 형식 변경 금지\n\n'
        '뉴스:\n$newsText\n'
        '${indexText.isNotEmpty ? '$indexText\n' : ''}'
        '$kospiListText'
        '$kosdaqListText'
        '$nasdaqListText'
        '출력:';

    final resp = await http.post(
      Uri.parse('$_endpoint?key=$key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': 500, // 분석 3줄 + 섹터 2줄 + 추천 종목 4줄(이유 포함)
          'temperature': 0.4, // 더 일관된 응답을 위해 온도 감소
          'topP': 0.8, // 출력 다양성 제한
        },
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Gemini API 오류 ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final rawText =
        data['candidates'][0]['content']['parts'][0]['text'] as String;

    // AI 응답 포맷 정리 + KRX 목록 기반 시장 교차 검증
    return _formatAndValidate(
      rawText.trim(),
      kospiStocks,
      kosdaqStocks,
      headlines,
    );
  }

  /// AI 응답 텍스트를 포맷팅 + KRX 목록으로 코스피/코스닥 교차 검증
  /// 코스피 리스트 종목이 코스닥에, 코스닥 리스트 종목이 코스피에 잘못 배치된 경우 제거
  String _formatAndValidate(
    String text,
    List<String> kospiStocks,
    List<String> kosdaqStocks,
    List<String> headlines,
  ) {
    final cleanText = text
        .replaceAll(RegExp(r'\n+'), '\n')
        .replaceAll(RegExp(r'^\s+|\s+$', multiLine: true), '')
        .trim();

    final lines = cleanText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final highlightPattern = RegExp(r'^하이라이트\s*:');
    final analysisTitlePattern = RegExp(r'^분석제목\s*:');
    final analysisContentPattern = RegExp(r'^분석내용\s*:');

    final highlights = <String>[];
    final analysisTitles = <String>[];
    final analysisContents = <String>[];
    String? bullSector, bearSector;
    final Map<String, String> pickMap = {};

    for (final l in lines) {
      final t = l.trim();
      if (highlightPattern.hasMatch(t)) {
        highlights.add(t.replaceFirst(highlightPattern, '').trim());
      } else if (analysisTitlePattern.hasMatch(t)) {
        analysisTitles.add(t.replaceFirst(analysisTitlePattern, '').trim());
      } else if (analysisContentPattern.hasMatch(t)) {
        analysisContents.add(t.replaceFirst(analysisContentPattern, '').trim());
      } else {
        final sM = RegExp(r'^(강세섹터|약세섹터)\s*:\s*(.+)').firstMatch(t);
        if (sM != null) {
          if (sM.group(1) == '강세섹터') {
            bullSector = sM.group(2)!.trim();
          } else {
            bearSector = sM.group(2)!.trim();
          }
          continue;
        }
        final pM = RegExp(r'^(코스피|코스닥|나스닥|코인)\s*:\s*(.+)').firstMatch(t);
        if (pM != null) pickMap[pM.group(1)!] = pM.group(2)!.trim();
      }
    }

    // fallback
    while (highlights.length < 3) {
      highlights.add('-');
    }
    while (analysisTitles.length < 2) {
      analysisTitles.add('-');
    }
    while (analysisContents.length < 2) {
      analysisContents.add('-');
    }

    final result = StringBuffer();
    for (final h in highlights.take(3)) {
      result.writeln('하이라이트: $h');
    }
    for (var i = 0; i < 2; i++) {
      result.writeln('분석제목: ${analysisTitles[i]}');
      result.writeln('분석내용: ${analysisContents[i]}');
    }
    result.writeln('강세섹터: ${bullSector ?? '-'}');
    result.writeln('약세섹터: ${bearSector ?? '-'}');
    // KRX 목록이 있으면 잘못 배치된 종목 교차 제거
    final validated = _rebalancePicks(
      pickMap,
      kospiStocks,
      kosdaqStocks,
      headlines,
    );

    result.writeln('코스피: ${validated['코스피'] ?? '-'}');
    result.writeln('코스닥: ${validated['코스닥'] ?? '-'}');
    result.writeln('나스닥: ${validated['나스닥'] ?? '-'}');
    result.write('코인: ${pickMap['코인'] ?? '-'}');

    return result.toString();
  }

  /// KRX 상장 목록 기반으로 코스피/코스닥 추천 종목 교차 오배치 제거
  /// - 코스닥 상장 종목이 코스피 추천에 등장 → 코스피에서 제거
  /// - 코스피 상장 종목이 코스닥 추천에 등장 → 코스닥에서 제거
  Map<String, String> _rebalancePicks(
    Map<String, String> pickMap,
    List<String> kospiStocks,
    List<String> kosdaqStocks,
    List<String> headlines,
  ) {
    final kospiSet = kospiStocks.toSet();
    final kosdaqSet = kosdaqStocks.toSet();
    // 이름(이유) 형식에서 종목명만 추출
    final itemPattern = RegExp(r'^(.+?)\(');

    String filterOut(String items, Set<String> excludeSet) {
      if (items == '-' || items.isEmpty) return items;
      final rawItems = items.split(RegExp(r',\s*(?=[^)]*(?:\(|$))'));
      final kept = rawItems.where((t) {
        final name = (itemPattern.firstMatch(t.trim())?.group(1) ?? t).trim();
        return !excludeSet.contains(name);
      }).toList();
      return kept.isEmpty ? '-' : kept.join(', ');
    }

    final normalizedNasdaq = _normalizeNasdaqPicks(pickMap['나스닥'] ?? '-');
    final nasdaqItems = normalizedNasdaq == '-' || normalizedNasdaq.isEmpty
        ? <_ParsedPick>[]
        : _parsePickItems(normalizedNasdaq);
    final nasdaqTickers = nasdaqItems
        .map((item) => item.ticker)
        .whereType<String>()
        .toSet();
    final needsNasdaqSupplement =
        nasdaqItems.length < 3 ||
        nasdaqTickers.length < 3 ||
        (nasdaqTickers.length == 1 && nasdaqTickers.contains('NVDA'));

    var finalNasdaq = normalizedNasdaq;
    if (needsNasdaqSupplement) {
      final supplements = _buildNasdaqFallback(
        headlines,
        excludedTickers: nasdaqTickers,
      );
      final merged = [...nasdaqItems, ...supplements];
      final unique = <String, _ParsedPick>{};
      for (final item in merged) {
        final key = item.ticker ?? item.name;
        unique.putIfAbsent(key, () => item);
      }
      finalNasdaq = unique.values
          .take(4)
          .map((item) => item.display)
          .join(', ');
      if (finalNasdaq.isEmpty) {
        finalNasdaq = '-';
      }
    }

    return {
      ...pickMap,
      '코스피': kospiStocks.isEmpty
          ? (pickMap['코스피'] ?? '-')
          : filterOut(pickMap['코스피'] ?? '-', kosdaqSet),
      '코스닥': kosdaqStocks.isEmpty
          ? (pickMap['코스닥'] ?? '-')
          : filterOut(pickMap['코스닥'] ?? '-', kospiSet),
      '나스닥': finalNasdaq,
    };
  }

  String _normalizeNasdaqPicks(String items) {
    if (items == '-' || items.trim().isEmpty) return '-';

    final parsed = _parsePickItems(items);
    if (parsed.isEmpty) return '-';

    final unique = <String, _ParsedPick>{};
    for (final item in parsed) {
      final key = item.ticker ?? item.name;
      unique.putIfAbsent(key, () => item);
    }
    return unique.values.map((item) => item.display).join(', ');
  }

  List<_ParsedPick> _parsePickItems(String items) {
    final itemPattern = RegExp(r'^(.+?)\((.+?)\)$');
    final rawItems = items.split(RegExp(r',\s*(?=[^)]*(?:\(|$))'));

    return rawItems
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty && raw != '-')
        .map((raw) {
          final match = itemPattern.firstMatch(raw);
          final label = match?.group(1)?.trim() ?? raw;
          final reason = match?.group(2)?.trim() ?? '';
          final candidate = _findNasdaqCandidate(label);
          final displayName = candidate != null
              ? '${candidate.name} ${candidate.ticker}'
              : label;
          final displayReason = reason.isNotEmpty
              ? reason
              : candidate?.reason ?? '뉴스 흐름상 상대 강도 우위';
          return _ParsedPick(
            name: candidate?.name ?? label,
            ticker: candidate?.ticker,
            display: '$displayName($displayReason)',
          );
        })
        .toList();
  }

  List<_ParsedPick> _buildNasdaqFallback(
    List<String> headlines, {
    Set<String> excludedTickers = const {},
  }) {
    final text = headlines.join(' ').toLowerCase();
    final scored =
        _nasdaqCandidates
            .where((candidate) => !excludedTickers.contains(candidate.ticker))
            .map((candidate) {
              var score = 0;
              for (final keyword in candidate.keywords) {
                if (text.contains(keyword.toLowerCase())) {
                  score += 3;
                }
              }
              if (candidate.sector == 'AI반도체' &&
                  (text.contains('엔비디아') ||
                      text.contains('nvidia') ||
                      text.contains('반도체'))) {
                score += 2;
              }
              if (candidate.sector == '광고플랫폼' &&
                  (text.contains('광고') || text.contains('소비'))) {
                score += 1;
              }
              if (candidate.sector == '클라우드소프트웨어' &&
                  (text.contains('클라우드') || text.contains('기업'))) {
                score += 1;
              }
              return (candidate: candidate, score: score);
            })
            .where((entry) => entry.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final selected = <_NasdaqCandidate>[];
    final usedSectors = <String>{};

    void addCandidate(_NasdaqCandidate candidate) {
      if (selected.any((item) => item.ticker == candidate.ticker)) return;
      selected.add(candidate);
      usedSectors.add(candidate.sector);
    }

    for (final entry in scored) {
      if (selected.length >= 4) break;
      if (selected.length < 3 && usedSectors.contains(entry.candidate.sector)) {
        continue;
      }
      addCandidate(entry.candidate);
    }

    if (selected.length < 3) {
      for (final ticker in _defaultNasdaqFallbackTickers) {
        final candidate = _nasdaqCandidates.firstWhere(
          (item) => item.ticker == ticker,
        );
        if (excludedTickers.contains(candidate.ticker)) continue;
        if (selected.length < 3 && usedSectors.contains(candidate.sector)) {
          continue;
        }
        addCandidate(candidate);
        if (selected.length >= 4) break;
      }
    }

    if (selected.length < 3) {
      for (final candidate in _nasdaqCandidates) {
        if (excludedTickers.contains(candidate.ticker)) continue;
        addCandidate(candidate);
        if (selected.length >= 4) break;
      }
    }

    return selected
        .take(4)
        .map(
          (candidate) => _ParsedPick(
            name: candidate.name,
            ticker: candidate.ticker,
            display:
                '${candidate.name} ${candidate.ticker}(${candidate.reason})',
          ),
        )
        .toList();
  }

  _NasdaqCandidate? _findNasdaqCandidate(String label) {
    final normalized = label.trim().toLowerCase();
    final tickerMatch = RegExp(r'\b[A-Z]{2,5}\b').firstMatch(label);
    final ticker = tickerMatch?.group(0)?.toUpperCase();

    for (final candidate in _nasdaqCandidates) {
      if (ticker != null && candidate.ticker == ticker) {
        return candidate;
      }
      if (normalized == candidate.name.toLowerCase() ||
          normalized == candidate.ticker.toLowerCase() ||
          candidate.aliases.any(
            (alias) => normalized == alias || normalized.contains(alias),
          ) ||
          normalized.contains(candidate.name.toLowerCase()) ||
          normalized.contains(candidate.ticker.toLowerCase())) {
        return candidate;
      }
    }
    return null;
  }
}

class _ParsedPick {
  const _ParsedPick({required this.name, required this.display, this.ticker});

  final String name;
  final String display;
  final String? ticker;
}

class _NasdaqCandidate {
  const _NasdaqCandidate({
    required this.name,
    required this.ticker,
    required this.sector,
    this.aliases = const [],
    required this.keywords,
    required this.reason,
  });

  final String name;
  final String ticker;
  final String sector;
  final List<String> aliases;
  final List<String> keywords;
  final String reason;
}
