import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stock_hub/config/constants.dart';
import 'package:stock_hub/config/theme/colors.dart';

import '../../../data/models/finance_news.dart';
import '../../../data/models/index.dart' show News;
import '../../../data/models/market_index.dart';
import '../../../providers/index.dart';
import '../../../utils/app_toast.dart';
import '../../feed/views/news_popup.dart';
import '../../feed/views/news_web_view_screen.dart';

/// 금융 뉴스 화면
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _newsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    // 5분마다 뉴스 자동 갱신 (stockMarketNewsProvider를 무효화하면
    // allFinanceNewsProvider → 각 탭 프로바이더까지 연쇄 갱신됨)
    _newsRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      ref.invalidate(stockMarketNewsProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newsRefreshTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message, {Color? color}) {
    showAppToast(context, message, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildMarketIndicesRow()),
          SliverToBoxAdapter(child: _buildAiSummaryCard()),
          SliverToBoxAdapter(child: _buildTabBar()),
          SliverToBoxAdapter(
            child: Divider(height: 1, color: context.colors.border),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildStockNewsTab(),
            const _FinanceKeywordTab(),
            _buildWarNewsTab(),
            _buildKospiTab(),
            _buildKosdaqTab(),
            _buildNasdaqTab(),
            _buildCoinTab(),
            _buildEconomicTab(),
          ],
        ),
      ),
    );
  }

  // ── 헤더 ──────────────────────────────────────
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 증시 분석',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '실시간 시장 분석',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Consumer(
              builder: (context, ref, _) {
                final indicesAsync = ref.watch(marketIndicesProvider);
                final updatedAt =
                    indicesAsync.valueOrNull?.firstOrNull?.updatedAt;
                final timeStr = updatedAt != null
                    ? '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}:${updatedAt.second.toString().padLeft(2, '0')}'
                    : null;
                final statusColor = indicesAsync.isLoading
                    ? AppColors.orange
                    : indicesAsync.hasError
                    ? AppColors.red
                    : AppColors.green;

                return GestureDetector(
                  onTap: () {
                    ref.invalidate(marketIndicesProvider);
                    _showToast('시장 지수 새로고침 중…');
                  },
                  child: Container(
                    width: 100,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceLight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              indicesAsync.isLoading
                                  ? '갱신 중'
                                  : indicesAsync.hasError
                                  ? '오류'
                                  : '업데이트',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: indicesAsync.isLoading
                              ? Row(
                                  key: const ValueKey('loading'),
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '불러오는 중',
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  timeStr ?? '--:--:--',
                                  key: ValueKey(timeStr ?? 'empty'),
                                  style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── AI 한줄 요약 카드 ──────────────────────────
  Widget _buildAiSummaryCard() {
    return Consumer(
      builder: (context, ref, _) {
        final summaryAsync = ref.watch(aiMarketSummaryProvider);
        return GestureDetector(
          onTap: summaryAsync.hasValue
              ? () => _showAiRelatedNewsSheet(context, ref, summaryAsync.value!)
              : null,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (summaryAsync.hasValue)
                      Text(
                        '관련 뉴스 보기',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    const Spacer(),
                    if (summaryAsync.hasValue)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: context.colors.textSecondary,
                      ),
                    const SizedBox(width: 4),
                    if (summaryAsync.isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.accent,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => ref.invalidate(aiMarketSummaryProvider),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: context.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: summaryAsync.when(
                    data: (text) => SingleChildScrollView(
                      primary: false,
                      child: _buildHighlightedSummary(text),
                    ),
                    loading: () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        3,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Shimmer.fromColors(
                            baseColor: context.colors.surfaceLight,
                            highlightColor: context.colors.border,
                            child: Container(
                              height: 12,
                              width: i == 2 ? 160 : double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (e, _) => GestureDetector(
                      onTap: () => ref.invalidate(aiMarketSummaryProvider),
                      child: Text(
                        AppConstants.geminiApiKey.isEmpty
                            ? 'Gemini API 키를 설정하면 AI 요약이 활성화됩니다'
                            : 'AI 요약 실패 — 탭하여 재시도',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// AI 요약 텍스트에서 핵심 키워드를 추출해 관련 뉴스를 모아 바텀시트로 표시
  void _showAiRelatedNewsSheet(
    BuildContext context,
    WidgetRef ref,
    String summaryText,
  ) {
    // 요약 텍스트에서 단어 단위 키워드 추출 (2글자 이상 한글/영문)
    final keywords = RegExp(r'[가-힣a-zA-Z]{2,}')
        .allMatches(summaryText)
        .map((m) => m.group(0)!)
        .where((w) => !_aiStopWords.contains(w))
        .toSet()
        .toList();

    final allNewsAsync = ref.read(allFinanceNewsProvider);
    final allNews = allNewsAsync.valueOrNull ?? [];

    // 키워드가 제목 또는 설명에 포함된 뉴스 필터링 (relevance score 순 정렬)
    final scored = <(int, FinanceNews)>[];
    for (final news in allNews) {
      final corpus = '${news.title} ${news.description}'.toLowerCase();
      final score = keywords
          .where((kw) => corpus.contains(kw.toLowerCase()))
          .length;
      if (score > 0) scored.add((score, news));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final related = scored.take(30).map((e) => e.$2).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiRelatedNewsSheet(newsList: related),
    );
  }

  static const _aiStopWords = {
    '분석',
    '요약',
    '하이라이트',
    '분석제목',
    '분석내용',
    '강세섹터',
    '약세섹터',
    '코스피',
    '코스닥',
    '나스닥',
    '코인',
    '주목',
    '섹터',
    '종목',
    '추천',
    '시장',
    '뉴스',
    '오늘',
    '현재',
    '전일',
    '전망',
    '상승',
    '하락',
    '기술',
    '금융',
    '에너지',
    '소비재',
    '산업재',
    'AI',
    'the',
    'and',
    'or',
    'of',
    'in',
    'is',
    'to',
  };

  // ── AI 요약 하이라이트 렌더러 ─────────────────────
  Widget _buildHighlightedSummary(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    final highlightPattern = RegExp(r'^하이라이트\s*:');
    final analysisTitlePattern = RegExp(r'^분석제목\s*:');
    final analysisContentPattern = RegExp(r'^분석내용\s*:');
    final sectorPattern = RegExp(r'^(강세섹터|약세섹터)\s*:');
    final pickPattern = RegExp(r'^(코스피|코스닥|나스닥|코인)\s*:');

    final highlights = <String>[];
    final analysisTitles = <String>[];
    final analysisContents = <String>[];
    final sectorLines = <String>[];
    final pickLines = <String>[];

    for (final l in lines) {
      final t = l.trim();
      if (highlightPattern.hasMatch(t)) {
        highlights.add(t.replaceFirst(highlightPattern, '').trim());
      } else if (analysisTitlePattern.hasMatch(t)) {
        analysisTitles.add(t.replaceFirst(analysisTitlePattern, '').trim());
      } else if (analysisContentPattern.hasMatch(t)) {
        analysisContents.add(t.replaceFirst(analysisContentPattern, '').trim());
      } else if (sectorPattern.hasMatch(t)) {
        sectorLines.add(t);
      } else if (pickPattern.hasMatch(t)) {
        pickLines.add(t);
      }
    }

    /// **굵게** 마크다운을 파싱해 TextSpan 반환
    List<TextSpan> parseBold(String line, {TextStyle? base}) {
      final baseStyle =
          base ??
          TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.55,
          );
      final spans = <TextSpan>[];
      final boldRegex = RegExp(r'\*\*(.+?)\*\*');
      int cursor = 0;
      for (final m in boldRegex.allMatches(line)) {
        if (m.start > cursor) {
          spans.add(
            TextSpan(text: line.substring(cursor, m.start), style: baseStyle),
          );
        }
        spans.add(
          TextSpan(
            text: m.group(1),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
        );
        cursor = m.end;
      }
      if (cursor < line.length) {
        spans.add(TextSpan(text: line.substring(cursor), style: baseStyle));
      }
      return spans.isEmpty ? [TextSpan(text: line, style: baseStyle)] : spans;
    }

    // ── 섹터 칩 줄 ──
    Widget buildSectorRow(String line) {
      final m = sectorPattern.firstMatch(line.trim());
      final label = m?.group(1) ?? '';
      final isBull = label == '강세섹터';
      final color = isBull ? AppColors.green : AppColors.red;
      final icon = isBull ? '▲' : '▼';
      final rest = line.trim().replaceFirst(sectorPattern, '').trim();
      final sectors = rest
          .split(RegExp(r'[,，、]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                icon,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 3,
                children: sectors
                    .map(
                      (sector) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          sector,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    // ── 추천 종목 줄 ──
    const pickColors = {
      '코스피': AppColors.accent,
      '코스닥': AppColors.accent,
      '나스닥': AppColors.orange,
      '코인': Color(0xFFF7931A),
    };

    Widget buildPickRow(String line, bool isLast) {
      final m = pickPattern.firstMatch(line.trim());
      final label = m?.group(1) ?? '';
      final color = pickColors[label] ?? AppColors.accent;
      final rest = line.trim().replaceFirst(pickPattern, '').trim();
      final isNasdaq = label == '나스닥';

      final itemPattern = RegExp(r'^(.+?)\((.+?)\)$');
      final trailingTickerPattern = RegExp(r'^(.*?)\s+([A-Z]{2,5})$');
      final rawItems = rest.split(RegExp(r',\s*(?=[^)]*(?:\(|$))'));
      final items = rawItems
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .map((t) {
            final im = itemPattern.firstMatch(t);
            final rawName = im != null ? im.group(1)!.trim() : t;
            final tickerMatch = trailingTickerPattern.firstMatch(rawName);
            final displayName = isNasdaq && tickerMatch != null
                ? tickerMatch.group(1)!.trim()
                : rawName;
            final linkKeyword = isNasdaq && tickerMatch != null
                ? tickerMatch.group(2)!.trim()
                : rawName;
            final reason = im != null ? im.group(2)!.trim() : '';
            return (
              name: displayName,
              linkKeyword: linkKeyword,
              reason: reason,
            );
          })
          .toList();

      return Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: items
                      .map(
                        (item) => GestureDetector(
                          onTap: () {
                            final url =
                                'https://m.stock.naver.com/searchItem?keyword=${Uri.encodeComponent(item.linkKeyword)}';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewsWebViewScreen(
                                  url: url,
                                  title: '${item.name} 주가',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: color.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (item.reason.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    item.reason,
                                    style: TextStyle(
                                      color: color.withValues(alpha: 0.70),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 하이라이트 섹션 ──
        if (highlights.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 11, color: AppColors.accent),
              SizedBox(width: 3),
              Text(
                '하이라이트',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surfaceLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: highlights
                  .map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: parseBold(h)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── 분석 섹션 ──
        if (analysisTitles.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 11,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: 3),
              Text(
                '분석',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(analysisTitles.length, (i) {
            final title = analysisTitles[i];
            final content = i < analysisContents.length
                ? analysisContents[i]
                : '';
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < analysisTitles.length - 1 ? 8 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    RichText(text: TextSpan(children: parseBold(content))),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
        ],

        // ── 섹터 ──
        if (sectorLines.isNotEmpty) ...[
          Divider(height: 10, thickness: 0.5, color: context.colors.border),
          const SizedBox(height: 1),
          const Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 10, color: AppColors.accent),
              SizedBox(width: 4),
              Text(
                '주목 섹터',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ...sectorLines.map(buildSectorRow),
        ],

        // ── 추천 종목 ──
        if (pickLines.isNotEmpty) ...[
          Divider(height: 10, thickness: 0.5, color: context.colors.border),
          const SizedBox(height: 1),
          const Row(
            children: [
              Icon(Icons.star_rounded, size: 10, color: AppColors.accent),
              SizedBox(width: 4),
              Text(
                '추천 종목',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(
            pickLines.length,
            (i) => buildPickRow(pickLines[i], i == pickLines.length - 1),
          ),
        ],
      ],
    );
  }

  // ── 마켓 인덱스 가로 스크롤 ────────────────────
  Widget _buildMarketIndicesRow() {
    return Consumer(
      builder: (context, ref, _) {
        final indicesAsync = ref.watch(marketIndicesProvider);
        final isLoading = indicesAsync.isLoading;
        final indices =
            indicesAsync.valueOrNull ??
            (indicesAsync.hasError ? _fallbackIndices : []);
        return _MarketTickerBar(indices: indices, isLoading: isLoading);
      },
    );
  }

  // ── 탭 바 ──────────────────────────────────────
  Widget _buildTabBar() {
    const tabDefs = [
      (0, '속보', AppColors.green),
      (1, '키워드', AppColors.info),
      (2, '전쟁', AppColors.red),
      (3, '코스피', Color(0xFF3B82F6)),
      (4, '코스닥', Color(0xFF14B8A6)),
      (5, '나스닥', Color(0xFFF59E0B)),
      (6, '코인', Color(0xFFF7931A)),
      (7, '경제', Color(0xFF6366F1)),
    ];

    return Container(
      color: context.colors.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabDefs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _buildPillTab(tabDefs[i].$1, tabDefs[i].$2, tabDefs[i].$3),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPillTab(int index, String label, Color color) {
    final isSelected = _tabController.index == index;
    final isBreaking = label == '속보';
    final foregroundColor = isSelected
        ? Colors.white
        : Color.alphaBlend(
            color.withValues(alpha: 0.82),
            context.colors.textPrimary,
          );

    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.12),
                      color,
                    ),
                    color,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : context.colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.95)
                : color.withValues(alpha: 0.22),
            width: isSelected ? 1.1 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBreaking) ...[
              _FinanceLiveIndicator(isSelected: isSelected),
              const SizedBox(width: 5),
            ] else ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.92)
                      : color.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 속보 탭 (importanceLevel 4+, 신뢰 언론 or 증시 고관련) ─────
  Widget _buildStockNewsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(breakingNewsProvider);
        return RefreshIndicator(
          color: AppColors.green,
          backgroundColor: context.colors.surface,
          onRefresh: () async {
            ref.invalidate(breakingNewsProvider);
            ref.invalidate(stockMarketNewsProvider);
            _showToast('속보 뉴스 새로고침 중…');
          },
          child: newsAsync.when(
            data: (news) {
              if (news.isEmpty) {
                return _buildEmptyState('중요 속보가 없습니다', Icons.article_outlined);
              }
              return ListView.builder(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: news.length + 1,
                itemBuilder: (ctx, index) {
                  if (index == 0) return _buildBreakingHeader();
                  final item = news[index - 1];
                  final publishedAt = item.publishedAt as DateTime?;
                  final isNew =
                      publishedAt != null &&
                      DateTime.now().difference(publishedAt).inMinutes < 10;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Stack(
                      children: [
                        _FinanceNewsCard(item: item),
                        if (isNew)
                          Positioned(
                            top: 10,
                            right: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.green,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => _buildEmptyState('오류: $e', Icons.error_outline),
          ),
        );
      },
    );
  }

  Widget _buildBreakingHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.green.withValues(alpha: 0.13),
            AppColors.green.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const _FinanceLiveIndicator(isSelected: true),
          const SizedBox(width: 8),
          const Text(
            '실시간 속보',
            style: TextStyle(
              color: AppColors.green,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 전쟁·지정학 탭 ────────────────────────────
  Widget _buildWarNewsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(warNewsProvider);
        return RefreshIndicator(
          color: AppColors.red,
          backgroundColor: context.colors.surface,
          onRefresh: () async {
            ref.invalidate(warNewsProvider);
            _showToast('전쟁·지정학 뉴스 새로고침 중…');
          },
          child: newsAsync.when(
            data: (news) {
              if (news.isEmpty) {
                return _buildEmptyState(
                  '전쟁·지정학 뉴스가 없습니다',
                  Icons.public_outlined,
                );
              }
              final sorted = [...news]
                ..sort((a, b) => (b.publishedAt).compareTo(a.publishedAt));
              return ListView.separated(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _FinanceNewsCard(item: sorted[index]),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.red,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => _buildEmptyState('오류: $e', Icons.error_outline),
          ),
        );
      },
    );
  }

  // ── 코스닥 탭 ─────────────────────────────────
  Widget _buildKosdaqTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(kosdaqNewsProvider);
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: context.colors.surface,
          onRefresh: () async {
            ref.invalidate(kosdaqNewsProvider);
            _showToast('코스닥 뉴스 새로고침 중…');
          },
          child: newsAsync.when(
            data: (news) {
              if (news.isEmpty) {
                return _buildEmptyState('코스닥 뉴스가 없습니다', Icons.show_chart);
              }
              final sorted = [...news]
                ..sort((a, b) => (b.publishedAt).compareTo(a.publishedAt));
              return ListView.separated(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _FinanceNewsCard(item: sorted[index]),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => _buildEmptyState('오류: $e', Icons.error_outline),
          ),
        );
      },
    );
  }

  // ── 코스피 탭 ─────────────────────────────────
  Widget _buildKospiTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(kospiNewsProvider);
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: context.colors.surface,
          onRefresh: () async {
            ref.invalidate(kospiNewsProvider);
            _showToast('코스피 뉴스 새로고침 중…');
          },
          child: newsAsync.when(
            data: (news) {
              if (news.isEmpty) {
                return _buildEmptyState('코스피 뉴스가 없습니다', Icons.show_chart);
              }
              final sorted = [...news]
                ..sort((a, b) => (b.publishedAt).compareTo(a.publishedAt));
              return ListView.separated(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _FinanceNewsCard(item: sorted[index]),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => _buildEmptyState('오류: $e', Icons.error_outline),
          ),
        );
      },
    );
  }

  // ── 나스닥 탭 ─────────────────────────────────
  Widget _buildNasdaqTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(nasdaqNewsProvider);
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: context.colors.surface,
          onRefresh: () async {
            ref.invalidate(nasdaqNewsProvider);
            _showToast('나스닥 뉴스 새로고침 중…');
          },
          child: newsAsync.when(
            data: (news) {
              if (news.isEmpty) {
                return _buildEmptyState('나스닥 뉴스가 없습니다', Icons.show_chart);
              }
              final sorted = [...news]
                ..sort((a, b) => (b.publishedAt).compareTo(a.publishedAt));
              return ListView.separated(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _FinanceNewsCard(item: sorted[index]),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => _buildEmptyState('오류: $e', Icons.error_outline),
          ),
        );
      },
    );
  }

  // ── 코인 탭 ───────────────────────────────────
  Widget _buildCoinTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(coinNewsProvider);
        return RefreshIndicator(
          color: const Color(0xFFF7931A),
          backgroundColor: context.colors.surface,
          onRefresh: () async {
            ref.invalidate(coinNewsProvider);
            _showToast('코인 뉴스 새로고침 중…');
          },
          child: newsAsync.when(
            data: (news) {
              if (news.isEmpty) {
                return _buildEmptyState('코인 뉴스가 없습니다', Icons.currency_bitcoin);
              }
              final sorted = [...news]
                ..sort((a, b) => (b.publishedAt).compareTo(a.publishedAt));
              return ListView.separated(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _FinanceNewsCard(item: sorted[index]),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF7931A),
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => _buildEmptyState('오류: $e', Icons.error_outline),
          ),
        );
      },
    );
  }

  // ── 경제 탭 ───────────────────────────────────
  Widget _buildEconomicTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(economicNewsProvider);
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: context.colors.surface,
          onRefresh: () async {
            ref.invalidate(economicNewsProvider);
            _showToast('경제 뉴스 새로고침 중…');
          },
          child: newsAsync.when(
            data: (news) {
              if (news.isEmpty) {
                return _buildEmptyState('경제 뉴스가 없습니다', Icons.business_outlined);
              }
              final sorted = [...news]
                ..sort((a, b) => (b.publishedAt).compareTo(a.publishedAt));
              return ListView.separated(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _FinanceNewsCard(item: sorted[index]),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => _buildEmptyState('오류: $e', Icons.error_outline),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: context.colors.border),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 폴백 더미 데이터 (API 오류 시 표시)
// ─────────────────────────────────────────────
final _fallbackIndices = [
  MarketIndex(
    symbol: '^KS11',
    name: '코스피',
    price: 0,
    change: 0,
    changeAmt: 0,
    currency: 'KRW',
    updatedAt: DateTime(2000),
  ),
  MarketIndex(
    symbol: '^KQ11',
    name: '코스닥',
    price: 0,
    change: 0,
    changeAmt: 0,
    currency: 'KRW',
    updatedAt: DateTime(2000),
  ),
  MarketIndex(
    symbol: '^IXIC',
    name: '나스닥',
    price: 0,
    change: 0,
    changeAmt: 0,
    currency: 'USD',
    updatedAt: DateTime(2000),
  ),
  MarketIndex(
    symbol: '^GSPC',
    name: 'S&P 500',
    price: 0,
    change: 0,
    changeAmt: 0,
    currency: 'USD',
    updatedAt: DateTime(2000),
  ),
  MarketIndex(
    symbol: 'KRW=X',
    name: '달러/원',
    price: 0,
    change: 0,
    changeAmt: 0,
    currency: 'KRW',
    updatedAt: DateTime(2000),
  ),
  MarketIndex(
    symbol: 'CL=F',
    name: '국제유가',
    price: 0,
    change: 0,
    changeAmt: 0,
    currency: 'USD',
    updatedAt: DateTime(2000),
  ),
];

// ─────────────────────────────────────────────
// 마켓 티커 바 (자동 무한 스크롤)
// ─────────────────────────────────────────────
class _MarketTickerBar extends StatefulWidget {
  final List<MarketIndex> indices;
  final bool isLoading;
  const _MarketTickerBar({required this.indices, this.isLoading = false});
  @override
  State<_MarketTickerBar> createState() => _MarketTickerBarState();
}

class _MarketTickerBarState extends State<_MarketTickerBar>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  final _measureKey = GlobalKey();
  double _measuredWidth = 0;

  // 스크롤 속도 (px/s)
  static const double _speed = 52.0;

  @override
  void initState() {
    super.initState();
    // 주스 임시 컨트롤러 — 첫 프레임 후 컨트롤러 재생성
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    WidgetsBinding.instance.addPostFrameCallback(_measureAndStart);
  }

  void _measureAndStart(_) {
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;
    if (w <= 0 || w == _measuredWidth) return;
    _measuredWidth = w;
    _ctrl.dispose();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (w / _speed * 1000).round()),
    )..repeat();
    if (mounted) setState(() {});
  }

  double get _totalWidth => _measuredWidth;

  @override
  void didUpdateWidget(_MarketTickerBar old) {
    super.didUpdateWidget(old);
    if (old.indices != widget.indices) {
      WidgetsBinding.instance.addPostFrameCallback(_measureAndStart);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = context.colors.border;

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E0E0E) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          // LIVE 배지
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 10),
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          //     decoration: BoxDecoration(
          //       color: AppColors.red,
          //       borderRadius: BorderRadius.circular(3),
          //     ),
          //     child: const Text(
          //       'LIVE',
          //       style: TextStyle(
          //         color: Colors.white,
          //         fontSize: 8,
          //         fontWeight: FontWeight.w900,
          //         letterSpacing: 0.8,
          //       ),
          //     ),
          //   ),
          // ),
          // Container(width: 0.5, height: 16, color: borderColor),
          // 티커 스크롤 영역
          Expanded(
            child: ClipRect(
              child: widget.isLoading || widget.indices.isEmpty
                  ? _buildLoadingRow(context)
                  : AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, child) {
                        final offset = _ctrl.value * _totalWidth;
                        return OverflowBox(
                          maxWidth: double.infinity,
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(-offset, 0),
                            child: child,
                          ),
                        );
                      },
                      // 원본(측정용) + 복사본을 이어 붙여 원형 루프 구현
                      child: Row(
                        key: _measureKey,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final idx in [
                            ...widget.indices,
                            ...widget.indices,
                          ])
                            _TickerItem(index: idx),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              width: 80,
              height: 12,
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 개별 티커 아이템 (한 줄 컴팩트) ──────────────
class _TickerItem extends StatelessWidget {
  final MarketIndex index;
  const _TickerItem({required this.index});

  @override
  Widget build(BuildContext context) {
    final isError = index.price == 0 && index.updatedAt.year == 2000;
    final isUp = index.isUp;
    final changeColor = isUp ? AppColors.green : AppColors.red;
    final borderColor = context.colors.border;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        // 방향 인디케이터 바
        if (!isError)
          //   Container(
          //     width: 2,
          //     height: 12,
          //     margin: const EdgeInsets.only(right: 4),
          //   decoration: BoxDecoration(
          //     color: changeColor,
          //     borderRadius: BorderRadius.circular(1),
          //   ),
          // ),
          // 이름
          Text(
            index.name,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        const SizedBox(width: 5),
        // 현재가
        Text(
          isError ? '-' : index.formattedPrice,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (!isError) ...[
          const SizedBox(width: 3),
          Text(
            index.formattedChange,
            style: TextStyle(
              color: changeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(width: 8),
        // 구분선
        Container(width: 0.5, height: 14, color: borderColor),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 통계: 강세/약세 게이지 카드
// ─────────────────────────────────────────────
class _StatsGaugeCard extends StatelessWidget {
  final int bullCount;
  final int bearCount;
  final int bullPct;
  final int bearPct;
  final int total;

  const _StatsGaugeCard({
    required this.bullCount,
    required this.bearCount,
    required this.bullPct,
    required this.bearPct,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '시장 통계',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '총 $total건',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 게이지 바
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Flexible(
                  flex: bullCount == 0 && bearCount == 0 ? 1 : bullPct,
                  child: Container(height: 12, color: AppColors.green),
                ),
                Flexible(
                  flex: bullCount == 0 && bearCount == 0
                      ? 1
                      : bearPct.clamp(1, 100),
                  child: Container(height: 12, color: AppColors.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GaugeLegend(
                label: '매수(강세)',
                count: bullCount,
                pct: bullPct,
                color: AppColors.green,
                align: CrossAxisAlignment.start,
              ),
              _GaugeLegend(
                label: '매도(약세)',
                count: bearCount,
                pct: bearPct,
                color: AppColors.red,
                align: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeLegend extends StatelessWidget {
  final String label;
  final int count;
  final int pct;
  final Color color;
  final CrossAxisAlignment align;

  const _GaugeLegend({
    required this.label,
    required this.count,
    required this.pct,
    required this.color,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          children: [
            if (align == CrossAxisAlignment.start) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (align == CrossAxisAlignment.end) ...[
              const SizedBox(width: 5),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '$count건',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '$pct%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 통계: 수치 요약 카드
// ─────────────────────────────────────────────
class _StatValueCard extends StatelessWidget {
  final String label;
  final String value;
  final int pct;
  final Color color;
  final IconData icon;

  const _StatValueCard({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '전체의 $pct%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 통계: 인덱스별 통계 모델
// ─────────────────────────────────────────────
class _IndexStat {
  final String name;
  final int bull;
  final int bear;
  final double marketChange;
  const _IndexStat(this.name, this.bull, this.bear, this.marketChange);
}

// ─────────────────────────────────────────────
// 통계: 인덱스별 강세/약세 Row
// ─────────────────────────────────────────────
class _IndexStatRow extends StatelessWidget {
  final _IndexStat stat;
  const _IndexStatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final total = stat.bull + stat.bear;
    final bullPct = total == 0 ? 50 : ((stat.bull / total) * 100).round();
    final bearPct = 100 - bullPct;
    final isUp = stat.marketChange >= 0;
    final changeColor = isUp ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                stat.name,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: changeColor,
                size: 16,
              ),
              Text(
                '${isUp ? '+' : ''}${stat.marketChange.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: changeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Flexible(
                  flex: bullPct == 0 ? 1 : bullPct,
                  child: Container(height: 6, color: AppColors.green),
                ),
                Flexible(
                  flex: bearPct == 0 ? 1 : bearPct,
                  child: Container(height: 6, color: AppColors.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '강세 $bullPct%',
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '약세 $bearPct%',
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '총 $total건',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 통계: 섹션 헤더
// ─────────────────────────────────────────────
class _StatsSectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _StatsSectionHeader({
    required this.label,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 뉴스 카드
// ─────────────────────────────────────────────
class _FinanceNewsCard extends StatelessWidget {
  final dynamic item;

  const _FinanceNewsCard({required this.item});

  // 더 길고 정확한 키가 먼저 와야 부분일치 방지
  static const _sourceMap = {
    // ▶ 한국 주요 일간지
    'chosunilbo': '조선일보',
    'sportschosun': '스포츠조선',
    'tvchosun': 'TV조선',
    'chosun': '조선일보',
    'joongang': '중앙일보',
    'joins': '중앙일보',
    'donga': '동아일보',
    'sportsdonga': '스포츠동아',
    'hankookilbo': '한국일보',
    'hankooki': '한국일보',
    'hani': '한겨례',
    'khan': '경향신문',
    'munhwa': '문화일보',
    'segye': '세계일보',
    'm-in': '매일일보',
    'kmib': '국민일보',
    'seoul': '서울신문',
    'naeil': '내일신문',
    'imaeil': '매일신문',
    'busan': '부산일보',
    // ▶ 한국 경제지
    'hankyung': '한국경제',
    'mk': '매일경제',
    'maeil': '매일경제',
    'mt': '머니투데이',
    'moneytoday': '머니투데이',
    'money today': '머니투데이',
    'sedaily': '서울경제',
    'seoul economic': '서울경제',
    'edaily': '이데일리',
    'asiae': '아시아경제',
    'heraldcorp': '헤럴드경제',
    'herald': '헤럴드경제',
    'fnnews': '파이낸셜뉴스',
    'ajunews': '아주경제',
    'businesspost': '비즈니스포스트',
    'thebell': '더벨',
    'inews24': '아이뉴스24',
    'newspim': '뉴스핌',
    'dealsites': '딜사이트',
    'dealsitetv': '딜사이트TV',
    'newsway': '뉴스웨이',
    'econonews': '이코노뉴스',
    'topstarnews': '톱스타뉴스',
    'ebn': 'EBN',
    'etoday': '이투데이',
    'junggil': '중기이코노미',
    'newsfc': '금융소비자뉴스',
    'viva100': '브릿지경제',
    'gukjnews': '국제뉴스',
    'mstoday': 'MS투데이',
    'bntnews': 'BNT뉴스',
    'newstomato': '뉴스토마토',
    'm-i': '매일일보',
    'mhns': '더쎈뉴스',
    'g-enews': '글로벌이코노믹',
    'theguru': '더구루',
    'mediapen': '미디어펜',
    'gokorea': '공감신문',
    // ▶ 한국 IT·전문지
    'etnews': '전자신문',
    'dt': '디지털타임스',
    'zdnet': 'ZDNet코리아',
    'bloter': '블로터',
    'itchosun': 'IT조선',
    // ▶ 한국 방송·통신
    'yonhapnewstv': '연합뉴스TV',
    'yonhapnews': '연합뉴스',
    'yonhap news agency': '연합뉴스',
    'yonhap news': '연합뉴스',
    'yonhap': '연합뉴스',
    'yna': '연합뉴스',
    'news1': '뉴스1',
    'newsis': '뉴시스',
    'kbs': 'KBS',
    'mbc': 'MBC',
    'sbs': 'SBS',
    'jtbc': 'JTBC',
    'ichannela': '채널A',
    'mbn': 'MBN',
    'ytn': 'YTN',
    'ohmynews': '오마이뉴스',
    'pressian': '프레시안',
    'dailian': '데일리안',
    'nocutnews': '노컷뉴스',
    'mediatoday': '미디어오늘',
    'sisain': '시사인',
    'sportseoul': '스포츠서울',
    'isplus': '일간스포츠',
    'startuptoday': '스타트업투데이',
    'einfomax': '연합인포맥스',
    'korea herald': '코리아헤럴드',
    'korea times': '코리아타임스',
    'korea joongang': '중앙일보',
    'hankyoreh': '한겨례',
    // ▶ 해외 주요 언론
    'reuters': '로이터',
    'bloomberg': '블룸버그',
    'cnbc': 'CNBC',
    'wsj': 'WSJ',
    'wall street journal': 'WSJ',
    'financial times': 'FT',
    'ft': 'FT',
    'associated press': 'AP통신',
    'ap news': 'AP통신',
    'nikkei': '닛케이',
    'marketwatch': '마켓워치',
    'seeking alpha': '시킹알파',
    'barrons': '배런스',
    'forbes': '포브스',
    'business insider': '비즈인사이더',
    'the economist': '이코노미스트',
    'bbc': 'BBC',
    'nytimes': 'NYT',
    'huffpost': '허프포스트',
    'investopedia': '인베스토피디아',
    'coinreaders': '코인리더스',
    'asiatime': '아시아타임즈',
    'tokenpost': '토큰포스트',
  };

  static const _faviconDomainMap = {
    // 일간지
    'chosunilbo': 'chosun.com',
    'sportschosun': 'sportschosun.com',
    'tvchosun': 'tvchosun.com',
    'chosun': 'chosun.com',
    'joongang': 'joongang.co.kr',
    'joins': 'joins.com',
    'donga': 'donga.com',
    'sportsdonga': 'donga.com',
    'hankookilbo': 'hankookilbo.com',
    'hankooki': 'hankooki.com',
    'hani': 'hani.co.kr',
    'khan': 'khan.co.kr',
    'munhwa': 'munhwa.com',
    'segye': 'segye.com',
    'kukinews': 'kukinews.com',
    'seoul': 'seoul.co.kr',
    'naeil': 'naeil.com',
    'imaeil': 'imaeil.com',
    'busan': 'busan.com',
    // 경제지
    'hankyung': 'hankyung.com',
    'mk': 'mk.co.kr',
    'maeil': 'maeil.com',
    'mt': 'mt.co.kr',
    'moneytoday': 'mt.co.kr',
    'money today': 'mt.co.kr',
    'sedaily': 'sedaily.com',
    'edaily': 'edaily.co.kr',
    'asiae': 'asiae.co.kr',
    'heraldcorp': 'heraldcorp.com',
    'fnnews': 'fnnews.com',
    'ajunews': 'ajunews.com',
    'businesspost': 'businesspost.co.kr',
    'thebell': 'thebell.co.kr',
    'newspim': 'newspim.com',
    // IT·전문
    'etnews': 'etnews.com',
    'dt': 'dt.co.kr',
    'zdnet': 'zdnet.co.kr',
    'bloter': 'bloter.net',
    'itchosun': 'it.chosun.com',
    // 방송·통신
    'yonhapnewstv': 'yonhapnewstv.co.kr',
    'yonhapnews': 'yna.co.kr',
    'yonhap': 'yna.co.kr',
    'yna': 'yna.co.kr',
    'news1': 'news1.kr',
    'newsis': 'newsis.com',
    'kbs': 'kbs.co.kr',
    'mbc': 'mbc.co.kr',
    'sbs': 'sbs.co.kr',
    'jtbc': 'jtbc.co.kr',
    'ichannela': 'ichannela.com',
    'mbn': 'mbn.co.kr',
    'ytn': 'ytn.co.kr',
    'ohmynews': 'ohmynews.com',
    'pressian': 'pressian.com',
    'dailian': 'dailian.co.kr',
    'nocutnews': 'nocutnews.co.kr',
    'mediatoday': 'mediatoday.co.kr',
    'sisain': 'sisain.co.kr',
    'sportseoul': 'sportseoul.com',
    'inews24': 'inews24.com',
    'startuptoday': 'startuptoday.co.kr',
    'einfomax': 'einfomax.com',
    'korea herald': 'koreaherald.com',
    'korea times': 'koreatimes.co.kr',
    'korea joongang': 'koreajoongangdaily.joins.com',
    'hankyoreh': 'english.hani.co.kr',
    // 해외
    'reuters': 'reuters.com',
    'bloomberg': 'bloomberg.com',
    'cnbc': 'cnbc.com',
    'wsj': 'wsj.com',
    'wall street journal': 'wsj.com',
    'financial times': 'ft.com',
    'ft': 'ft.com',
    'associated press': 'apnews.com',
    'ap news': 'apnews.com',
    'seeking alpha': 'seekingalpha.com',
    'business insider': 'businessinsider.com',
    'the economist': 'economist.com',
    'nikkei': 'nikkei.com',
    'marketwatch': 'marketwatch.com',
    'forbes': 'forbes.com',
    'bbc': 'bbc.com',
    'nytimes': 'nytimes.com',
    'huffpost': 'huffpost.com',
  };

  // ▶ 해외 언론사 키 집합
  static const _overseasKeys = {
    'reuters',
    'bloomberg',
    'cnbc',
    'wsj',
    'wall street journal',
    'financial times',
    'ft',
    'associated press',
    'ap news',
    'nikkei',
    'marketwatch',
    'seeking alpha',
    'barrons',
    'forbes',
    'business insider',
    'the economist',
    'bbc',
    'nytimes',
    'huffpost',
    'investopedia',
    'coinreaders',
  };

  static bool _isOverseas(String rawSource) {
    final key = rawSource.toLowerCase().trim();
    return _overseasKeys.any((k) => key.contains(k));
  }

  static String _localizeSource(String raw) {
    final key = raw.toLowerCase().trim();
    for (final entry in _sourceMap.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return raw;
  }

  static String? _getFaviconUrl(String rawSource, {String? url}) {
    // 1순위: 기사 URL에서 도메인 직접 추출 (가장 정확)
    if (url != null && url.isNotEmpty) {
      try {
        final host = Uri.parse(url).host.replaceFirst('www.', '');
        if (host.isNotEmpty) {
          return 'https://www.google.com/s2/favicons?domain=$host&sz=64';
        }
      } catch (_) {}
    }
    // 2순위: 소스명 → 도메인 맵 조회
    final key = rawSource.toLowerCase().trim();
    for (final entry in _faviconDomainMap.entries) {
      if (key.contains(entry.key)) {
        return 'https://www.google.com/s2/favicons?domain=${entry.value}&sz=64';
      }
    }
    // 3순위: 소스명 자체가 도메인 형태인 경우
    if (key.contains('.')) {
      return 'https://www.google.com/s2/favicons?domain=$key&sz=64';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = (item.title as String?) ?? '';
    final description = (item.description as String?) ?? '';
    final rawSource = item.source as String? ?? '뉴스';
    final source = _localizeSource(rawSource);
    final overseas = _isOverseas(rawSource);
    final publishedAt = item.publishedAt as DateTime?;
    final sentiment = item.sentimentScore as double? ?? 0.0;
    // url 필드 (FinanceNews: url, News: newsUrl)
    final String? url = () {
      try {
        return item.url as String?;
      } catch (_) {}
      try {
        return item.newsUrl as String?;
      } catch (_) {}
      return null;
    }();
    final faviconUrl = _getFaviconUrl(rawSource, url: url);
    // tickers/keywords 표시 (있는 경우)
    final List<String> tickers = () {
      try {
        return List<String>.from(item.tickers as List? ?? []);
      } catch (_) {
        return <String>[];
      }
    }();

    final sentimentColor = sentiment > 0.3
        ? const Color(0xFF3B82F6)
        : sentiment < -0.3
        ? AppColors.red
        : context.colors.textSecondary;
    final sentimentLabel = sentiment > 0.5
        ? '강한 호재'
        : sentiment > 0.1
        ? '호재'
        : sentiment < -0.5
        ? '강한 악재'
        : sentiment < -0.1
        ? '악재'
        : '중립';
    final sentimentIcon = sentiment > 0.1
        ? Icons.trending_up
        : sentiment < -0.1
        ? Icons.trending_down
        : Icons.remove;

    String timeAgo = '';
    if (publishedAt != null) {
      final diff = DateTime.now().difference(publishedAt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}분 전';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}시간 전';
      }
    } else {
      timeAgo = '시간 정보 없음';
    }

    return GestureDetector(
      onTap: () {
        if (item is News) {
          showNewsDetailSheet(context, item as News);
        } else if (url != null && url.isNotEmpty) {
          showUrlNewsSheet(context, title: title, url: url);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 좌측 감정 컬러 바
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: sentimentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              // 본문
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단 메타
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (faviconUrl != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: Image.network(
                                      faviconUrl,
                                      width: 12,
                                      height: 12,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  source,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          // 국내/해외 딱지
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: overseas
                                  ? AppColors.orange.withValues(alpha: 0.15)
                                  : AppColors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: overseas
                                    ? AppColors.orange.withValues(alpha: 0.45)
                                    : AppColors.green.withValues(alpha: 0.40),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              overseas ? '해외' : '국내',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: overseas
                                    ? AppColors.orange
                                    : AppColors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          // 호재/악재 딱지
                          if (sentimentLabel != '중립')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: sentimentColor.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: sentimentColor.withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    sentimentIcon,
                                    size: 9,
                                    color: sentimentColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    sentimentLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: sentimentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 6),
                          if (tickers.isNotEmpty) ...[
                            ...tickers
                                .take(2)
                                .map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        t,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                          const Spacer(),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 9,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      // 제목
                      Text(
                        title,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 키워드 탭 — 관심 키워드 필터링 뉴스
// ─────────────────────────────────────────────
class _FinanceKeywordTab extends ConsumerStatefulWidget {
  const _FinanceKeywordTab();

  @override
  ConsumerState<_FinanceKeywordTab> createState() => _FinanceKeywordTabState();
}

class _FinanceKeywordTabState extends ConsumerState<_FinanceKeywordTab> {
  String? _selectedKeyword;

  final bool _stocksLoading = false;
  final List<MarketIndex> _keywordStocks = [];

  @override
  Widget build(BuildContext context) {
    final keywords = ref.watch(favoriteKeywordsControllerProvider);
    final newsAsync = ref.watch(stockMarketNewsProvider);

    if (keywords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(
                Icons.search_outlined,
                size: 28,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '등록된 키워드가 없어요',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '설정 탭에서 키워드를 추가해보세요',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedKeyword != null && !keywords.contains(_selectedKeyword)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedKeyword = null);
      });
    }

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // 키워드 칩 가로 스크롤
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                // '전체' 칩
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedKeyword = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedKeyword == null
                            ? AppColors.accent
                            : context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedKeyword == null
                              ? AppColors.accent
                              : context.colors.border,
                          width: _selectedKeyword == null ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        '전체',
                        style: TextStyle(
                          color: _selectedKeyword == null
                              ? Colors.white
                              : context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: _selectedKeyword == null
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                // 개별 키워드 칩
                ...keywords.map((kw) {
                  final isSelected = _selectedKeyword == kw;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedKeyword = kw),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent
                              : context.colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : context.colors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          kw,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : context.colors.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Divider(height: 1, color: context.colors.border),
        ),
        // ─── 관련 종목 주가 섹션 ───
        if (_stocksLoading || _keywordStocks.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildStockSection(context)),
          SliverToBoxAdapter(
            child: Divider(height: 1, color: context.colors.border),
          ),
        ],
        // 뉴스 리스트
        ...newsAsync.when(
          data: (allNews) {
            final filtered = allNews.where((n) {
              final text = '${n.title} ${n.description}'.toLowerCase();
              if (_selectedKeyword != null) {
                return text.contains(_selectedKeyword!.toLowerCase());
              }
              return keywords.any((kw) => text.contains(kw.toLowerCase()));
            }).toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

            if (filtered.isEmpty) {
              return [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Icon(
                            Icons.article_outlined,
                            size: 28,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedKeyword != null
                              ? "'$_selectedKeyword' 관련 뉴스가 없어요"
                              : '키워드 관련 뉴스가 없어요',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '잠시 후 뉴스가 업데이트될 수 있어요',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            }

            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _FinanceNewsCard(item: filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ];
          },
          loading: () => [
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
          error: (e, _) => [
            SliverFillRemaining(
              child: Center(
                child: Text(
                  '오류: $e',
                  style: const TextStyle(color: AppColors.red, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '관련 종목 주가',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          if (_stocksLoading)
            SizedBox(
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: 3,
                itemBuilder: (_, __) => _StockBannerSkeleton(),
              ),
            )
          else
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: _keywordStocks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) =>
                    _StockBannerTile(stock: _keywordStocks[i]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 주가 배너 종목 타일
// ─────────────────────────────────────────────
class _StockBannerTile extends StatelessWidget {
  final MarketIndex stock;
  const _StockBannerTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    final isUp = stock.isUp;
    final changeColor = isUp ? AppColors.green : AppColors.red;

    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: changeColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: changeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 종목명
          Text(
            stock.name,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // 현재가
          Text(
            stock.formattedPrice,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          // 변화율
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: changeColor,
                size: 14,
              ),
              Text(
                stock.formattedChange,
                style: TextStyle(
                  color: changeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 주가 배너 스켈레톤
// ─────────────────────────────────────────────
class _StockBannerSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Shimmer.fromColors(
        baseColor: context.colors.surfaceLight,
        highlightColor: context.colors.border,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 70,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 55,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 속보 탭 깜빡이는 LIVE 인디케이터
// ─────────────────────────────────────────────
class _FinanceLiveIndicator extends StatefulWidget {
  final bool isSelected;
  const _FinanceLiveIndicator({required this.isSelected});

  @override
  State<_FinanceLiveIndicator> createState() => _FinanceLiveIndicatorState();
}

class _FinanceLiveIndicatorState extends State<_FinanceLiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 통계 독립 화면 (하단 네비에서 사용)
// ─────────────────────────────────────────────
class FinanceStatsScreen extends ConsumerWidget {
  const FinanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positiveAsync = ref.watch(positiveFinanceNewsProvider);
    final negativeAsync = ref.watch(negativeFinanceNewsProvider);

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '시장 통계',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '강세/약세 뉴스 분석',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          Expanded(
            child: positiveAsync.when(
              data: (positiveNews) => negativeAsync.when(
                data: (negativeNews) {
                  final total = positiveNews.length + negativeNews.length;
                  final bullRatio = total == 0
                      ? 0.5
                      : positiveNews.length / total;
                  final bullPct = total == 0 ? 50 : (bullRatio * 100).round();
                  final bearPct = 100 - bullPct;

                  final indicesStats = [
                    _IndexStat(
                      'KOSPI',
                      positiveNews
                          .where(
                            (n) =>
                                (n.title).contains('코스피') ||
                                (n.description).contains('코스피'),
                          )
                          .length,
                      negativeNews
                          .where(
                            (n) =>
                                (n.title).contains('코스피') ||
                                (n.description).contains('코스피'),
                          )
                          .length,
                      0.47,
                    ),
                    _IndexStat(
                      'KOSDAQ',
                      positiveNews
                          .where((n) => (n.title).contains('코스닥'))
                          .length,
                      negativeNews
                          .where((n) => (n.title).contains('코스닥'))
                          .length,
                      -0.32,
                    ),
                    _IndexStat(
                      'NASDAQ',
                      positiveNews
                          .where(
                            (n) =>
                                (n.title).contains('나스닥') ||
                                (n.title).contains('Nasdaq'),
                          )
                          .length,
                      negativeNews
                          .where(
                            (n) =>
                                (n.title).contains('나스닥') ||
                                (n.title).contains('Nasdaq'),
                          )
                          .length,
                      1.12,
                    ),
                    _IndexStat(
                      'S&P500',
                      positiveNews
                          .where(
                            (n) =>
                                (n.title).contains('S&P') ||
                                (n.title).contains('SP500'),
                          )
                          .length,
                      negativeNews
                          .where(
                            (n) =>
                                (n.title).contains('S&P') ||
                                (n.title).contains('SP500'),
                          )
                          .length,
                      0.78,
                    ),
                  ];

                  return RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: context.colors.surface,
                    onRefresh: () async {
                      ref.invalidate(allFinanceNewsProvider);
                      await Future.wait([
                        ref.read(positiveFinanceNewsProvider.future),
                        ref.read(negativeFinanceNewsProvider.future),
                      ]);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _StatsGaugeCard(
                          bullCount: positiveNews.length,
                          bearCount: negativeNews.length,
                          bullPct: bullPct,
                          bearPct: bearPct,
                          total: total,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatValueCard(
                                label: '강세 뉴스',
                                value: '${positiveNews.length}건',
                                pct: bullPct,
                                color: AppColors.green,
                                icon: Icons.trending_up,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatValueCard(
                                label: '약세 뉴스',
                                value: '${negativeNews.length}건',
                                pct: bearPct,
                                color: AppColors.red,
                                icon: Icons.trending_down,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _StatsSectionHeader(label: '인덱스별 강세/약세'),
                        const SizedBox(height: 10),
                        ...indicesStats.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _IndexStatRow(stat: s),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _StatsSectionHeader(
                          label: '강세 뉴스 TOP 3',
                          color: AppColors.green,
                        ),
                        const SizedBox(height: 10),
                        if (positiveNews.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '강세 뉴스가 없습니다',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          ...positiveNews
                              .take(3)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _FinanceNewsCard(item: item),
                                ),
                              ),
                        const SizedBox(height: 16),
                        const _StatsSectionHeader(
                          label: '약세 뉴스 TOP 3',
                          color: AppColors.red,
                        ),
                        const SizedBox(height: 10),
                        if (negativeNews.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '약세 뉴스가 없습니다',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          ...negativeNews
                              .take(3)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _FinanceNewsCard(item: item),
                                ),
                              ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '오류: $e',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  '오류: $e',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AI 관련 뉴스 바텀시트
// ─────────────────────────────────────────────
class _AiRelatedNewsSheet extends StatelessWidget {
  final List<FinanceNews> newsList;

  const _AiRelatedNewsSheet({required this.newsList});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI 요약 관련 뉴스',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${newsList.length}건',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              // 뉴스 리스트
              Expanded(
                child: newsList.isEmpty
                    ? Center(
                        child: Text(
                          '관련 뉴스가 없습니다',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          0,
                          8,
                          0,
                          MediaQuery.of(context).padding.bottom + 16,
                        ),
                        itemCount: newsList.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: context.colors.border),
                        itemBuilder: (context, i) {
                          final news = newsList[i];
                          final urlStr = news.url ?? '';
                          final host = urlStr.isNotEmpty
                              ? () {
                                  try {
                                    return Uri.parse(
                                      urlStr,
                                    ).host.replaceFirst('www.', '');
                                  } catch (_) {
                                    return '';
                                  }
                                }()
                              : '';
                          final sentiment = news.sentimentScore;
                          final sentimentColor = sentiment > 0.1
                              ? AppColors.green
                              : sentiment < -0.1
                              ? AppColors.red
                              : context.colors.textSecondary;

                          return InkWell(
                            onTap: urlStr.isNotEmpty
                                ? () => showUrlNewsSheet(
                                    context,
                                    title: news.title,
                                    url: urlStr,
                                  )
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 소스 + 시간 + 감정
                                  Row(
                                    children: [
                                      if (host.isNotEmpty) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          child: Image.network(
                                            'https://www.google.com/s2/favicons?domain=$host&sz=64',
                                            width: 12,
                                            height: 12,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        news.source,
                                        style: TextStyle(
                                          color: context.colors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _timeAgo(news.publishedAt),
                                        style: TextStyle(
                                          color: context.colors.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: sentimentColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          _sentimentLabel(sentiment),
                                          style: TextStyle(
                                            color: sentimentColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    news.title,
                                    style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (news.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      news.description,
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  static String _sentimentLabel(double score) {
    if (score > 0.5) return '강한 호재';
    if (score > 0.1) return '호재';
    if (score < -0.5) return '강한 악재';
    if (score < -0.1) return '악재';
    return '중립';
  }
}
