import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_hub/config/index.dart';

import '../../../data/models/index.dart';
import '../../../providers/index.dart';
import '../../../widgets/news_feed_banner_ad.dart';
import 'breaking_news_ticker.dart';
import 'news_popup.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedRegion = '전체';
  static const _defaultRegions = ['전체', '미국', '유럽', '아시아', '한국'];
  final markets = ['전체', '코스피', '코스닥', '나스닥', 'S&P500', '원자재'];
  DateTime? _lastRefreshedAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _lastRefreshedAt = DateTime.now();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 50,
            floating: true,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: context.colors.bg,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '뉴스 피드',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (_lastRefreshedAt != null)
                          Text(
                            '업데이트 ${_formatRefreshTime(_lastRefreshedAt!)}',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(45),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.accent,
                unselectedLabelColor: context.colors.textSecondary,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LiveIndicator(),
                        SizedBox(width: 5),
                        Text(
                          '속보',
                          style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(text: '전체'),
                  Tab(text: '코스피'),
                  Tab(text: '코스닥'),
                  Tab(text: '나스닥'),
                  Tab(text: 'S&P500'),
                  Tab(text: '원자재'),
                ],
              ),
            ),
          ),
          // 탭 콘텐츠
          SliverFillRemaining(
            child: Column(
              children: [
                // 실시간 속보 배너 (속보 탭에선 숨김)
                if (_tabController.index != 0) const BreakingNewsTicker(),
                // 지역 필터
                Builder(
                  builder: (ctx) {
                    const regionChips = _defaultRegions;
                    return SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        children: regionChips.map((region) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedRegion = region;
                                });
                                // selectedRegionProvider와 연동하여 filteredNewsProvider에 반영
                                ref
                                        .read(selectedRegionProvider.notifier)
                                        .state =
                                    region;
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedRegion == region
                                      ? AppColors.accent
                                      : context.colors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: selectedRegion != region
                                      ? Border.all(color: context.colors.border)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    region,
                                    style: TextStyle(
                                      color: selectedRegion == region
                                          ? Colors.white
                                          : context.colors.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBreakingNewsTab(),
                      ...markets.map((market) => _buildMarketNewsList(market)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketNewsList(String market) {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(marketNewsProvider(market));

        return newsAsync.when(
          data: (newsList) {
            if (newsList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      color: context.colors.textSecondary,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      market == '전체' ? '뉴스가 없습니다' : '$market 관련 뉴스가 없습니다',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: context.colors.surface,
              onRefresh: () async {
                ref.invalidate(stockMarketNewsProvider);
                if (mounted) setState(() => _lastRefreshedAt = DateTime.now());
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                // 5개마다 배너 광고 1개 삽입
                itemCount: newsList.length + (newsList.length ~/ 5),
                itemBuilder: (context, index) {
                  // 6개 단위({5뉴스 + 1광고}) 로직
                  final groupIndex = index ~/ 6;
                  final posInGroup = index % 6;
                  // 각 그룹의 6번째 아이템이 광고
                  if (posInGroup == 5) {
                    return const NewsFeedBannerAd();
                  }
                  final newsIndex = groupIndex * 5 + posInGroup;
                  if (newsIndex >= newsList.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildNewsCard(newsList[newsIndex]),
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
          ),
          error: (error, stack) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.red, size: 40),
                SizedBox(height: 12),
                Text(
                  '오류 발생',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsCard(News news) {
    final diff = DateTime.now().difference(news.publishedAt);
    final isNew = diff.inMinutes < 10;
    final sentimentColor = _getSentimentColor(news.sentimentScore);

    final String agoText;
    if (diff.inMinutes < 1) {
      agoText = '방금';
    } else if (diff.inMinutes < 60) {
      agoText = '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      agoText = '${diff.inHours}시간 전';
    } else {
      agoText = '${diff.inDays}일 전';
    }

    return GestureDetector(
      onTap: () => showNewsDetailSheet(context, news),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: sentimentColor, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isNew
                        ? sentimentColor.withValues(alpha: 0.12)
                        : context.colors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    agoText,
                    style: TextStyle(
                      color: isNew
                          ? sentimentColor
                          : context.colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  news.source,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sentimentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    _getSentimentLabel(news.sentimentScore),
                    style: TextStyle(
                      color: sentimentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              news.title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: -0.3,
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
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getSentimentLabel(double score) {
    if (score > 0.5) return '강한 호재';
    if (score > 0.1) return '호재';
    if (score < -0.5) return '강한 악재';
    if (score < -0.1) return '악재';
    return '중립';
  }

  Color _getSentimentColor(double score) {
    if (score > 0.1) return const Color(0xFF3B82F6);
    if (score < -0.1) return AppColors.red;
    return AppColors.accent;
  }

  String _formatRefreshTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── 속보 탭 ──────────────────────────────────────────────────────────────

  Widget _buildBreakingNewsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final newsAsync = ref.watch(breakingNewsProvider);
        return newsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.podcasts_rounded,
                      color: context.colors.textSecondary,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '현재 속보가 없습니다',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.red,
              backgroundColor: context.colors.surface,
              onRefresh: () async => ref.invalidate(breakingNewsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: items.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) return _buildBreakingHeader();
                  return _buildBreakingCard(items[i - 1]);
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.red,
              strokeWidth: 2,
            ),
          ),
          error: (_, __) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.red, size: 40),
                SizedBox(height: 12),
                Text(
                  '속보 로딩 실패',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakingHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.red.withValues(alpha: 0.13),
            AppColors.red.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const _LiveIndicator(),
          const SizedBox(width: 8),
          const Text(
            '실시간 속보',
            style: TextStyle(
              color: AppColors.red,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.red,
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

  Widget _buildBreakingCard(News news) {
    final diff = DateTime.now().difference(news.publishedAt);
    final isNew = diff.inMinutes < 10;
    final isRecent = diff.inMinutes < 60;

    final String agoText;
    if (diff.inMinutes < 1) {
      agoText = '방금';
    } else if (diff.inMinutes < 60) {
      agoText = '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      agoText = '${diff.inHours}시간 전';
    } else {
      agoText = '${diff.inDays}일 전';
    }

    final accentColor = isNew
        ? AppColors.red
        : isRecent
        ? AppColors.orange
        : context.colors.border;

    return GestureDetector(
      onTap: () => showNewsDetailSheet(context, news),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accentColor, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isNew
                        ? AppColors.red.withValues(alpha: 0.12)
                        : context.colors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    agoText,
                    style: TextStyle(
                      color: isNew
                          ? AppColors.red
                          : context.colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isNew) ...[
                  const SizedBox(width: 5),
                  Container(
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
                ],
                const Spacer(),
                Text(
                  news.source,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              news.title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: -0.3,
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
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 속보 탭 깜빡이는 빨간 점
class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
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
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
