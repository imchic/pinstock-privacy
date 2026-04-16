import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/index.dart';
import '../../../data/models/index.dart';
import '../../../providers/index.dart';
import '../../../utils/ad_service.dart';
import '../../feed/views/news_popup.dart';

class BookmarkScreen extends ConsumerStatefulWidget {
  const BookmarkScreen({super.key});

  @override
  ConsumerState<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends ConsumerState<BookmarkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      body: Column(
        children: [
          // 헤더
          Container(
            color: context.colors.surface,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '저장됨',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '북마크한 뉴스를 모아볼 수 있습니다',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: context.colors.textSecondary,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: '일반 뉴스'),
                    Tab(text: '금융 뉴스'),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          // 탭 컨텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_NewsBookmarkTab(), _FinanceBookmarkTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 일반 뉴스 북마크 탭
// ─────────────────────────────────────────────
class _NewsBookmarkTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNews = ref.watch(bookmarkedNewsProvider);

    return asyncNews.when(
      data: (newsList) {
        if (newsList.isEmpty) {
          return const _EmptyBookmark(
            message: '저장한 뉴스가 없습니다',
            subMessage: '뉴스 카드의 북마크 아이콘을 눌러 저장하세요',
          );
        }
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: context.colors.surface,
          onRefresh: () async => ref.invalidate(bookmarkedNewsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: newsList.length,
            itemBuilder: (context, index) =>
                _NewsBookmarkCard(news: newsList[index]),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2,
        ),
      ),
      error: (_, __) => const _EmptyBookmark(
        message: '불러오기 실패',
        subMessage: '잠시 후 다시 시도해주세요',
        isError: true,
      ),
    );
  }
}

class _NewsBookmarkCard extends ConsumerWidget {
  final News news;
  const _NewsBookmarkCard({required this.news});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentimentColor = _sentimentColor(context, news.sentimentScore);

    return GestureDetector(
      onTap: () => showNewsDetailSheet(context, news),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 소스 + 시간 + 북마크 해제
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    news.source,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  news.getTimeAgo(),
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final repository = await ref.read(
                      newsRepositoryProvider.future,
                    );
                    await repository.toggleBookmark(news);
                    ref.invalidate(bookmarkedNewsProvider);
                  },
                  child: const Icon(
                    Icons.bookmark,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 제목
            Text(
              news.title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
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
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            // 감정 배지 + 공유
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sentimentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _sentimentLabel(news.sentimentScore),
                    style: TextStyle(
                      color: sentimentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (news.newsUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () => SharePlus.instance.share(
                      ShareParams(text: '${news.title}\n\n${news.newsUrl}'),
                    ),
                    child: Icon(
                      Icons.share_outlined,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _sentimentColor(BuildContext context, double score) {
    if (score > 0.1) return AppColors.green;
    if (score < -0.1) return AppColors.red;
    return AppColors.of(context).textSecondary;
  }

  String _sentimentLabel(double score) {
    if (score > 0.5) return '강한 호재';
    if (score > 0.1) return '호재';
    if (score < -0.5) return '강한 악재';
    if (score < -0.1) return '악재';
    return '중립';
  }
}

// ─────────────────────────────────────────────
// 금융 뉴스 북마크 탭
// ─────────────────────────────────────────────
class _FinanceBookmarkTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNews = ref.watch(bookmarkedFinanceNewsProvider);

    return asyncNews.when(
      data: (newsList) {
        if (newsList.isEmpty) {
          return const _EmptyBookmark(
            message: '저장한 금융 뉴스가 없습니다',
            subMessage: '금융 탭에서 뉴스 카드를 길게 눌러 저장하세요',
          );
        }
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: context.colors.surface,
          onRefresh: () async => ref.invalidate(bookmarkedFinanceNewsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: newsList.length,
            itemBuilder: (context, index) =>
                _FinanceBookmarkCard(news: newsList[index]),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2,
        ),
      ),
      error: (_, __) => const _EmptyBookmark(
        message: '불러오기 실패',
        subMessage: '잠시 후 다시 시도해주세요',
        isError: true,
      ),
    );
  }
}

class _FinanceBookmarkCard extends ConsumerWidget {
  final FinanceNews news;
  const _FinanceBookmarkCard({required this.news});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentimentColor = news.sentimentScore > 0.1
        ? AppColors.green
        : news.sentimentScore < -0.1
        ? AppColors.red
        : AppColors.of(context).textSecondary;

    return GestureDetector(
      onTap: () {
        if (news.url != null && news.url!.isNotEmpty) {
          // ignore: deprecated_member_use_from_same_package
          openNewsWithAd(context, url: news.url!, title: news.title);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 소스 + 시간 + 북마크 해제
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    news.source,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final repository = await ref.read(
                      financeRepositoryProvider.future,
                    );
                    await repository.unbookmarkNews(news.id);
                    ref.invalidate(bookmarkedFinanceNewsProvider);
                  },
                  child: const Icon(
                    Icons.bookmark,
                    color: AppColors.accent,
                    size: 18,
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
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sentimentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _sentimentLabel(news.sentimentScore),
                    style: TextStyle(
                      color: sentimentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (news.url != null && news.url!.isNotEmpty)
                  GestureDetector(
                    onTap: () => SharePlus.instance.share(
                      ShareParams(text: '${news.title}\n\n${news.url!}'),
                    ),
                    child: Icon(
                      Icons.share_outlined,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _sentimentLabel(double score) {
    if (score > 0.5) return '강한 호재';
    if (score > 0.1) return '호재';
    if (score < -0.5) return '강한 악재';
    if (score < -0.1) return '악재';
    return '중립';
  }
}

// ─────────────────────────────────────────────
// 빈 상태 위젯
// ─────────────────────────────────────────────
class _EmptyBookmark extends StatelessWidget {
  final String message;
  final String subMessage;
  final bool isError;

  const _EmptyBookmark({
    required this.message,
    required this.subMessage,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.bookmark_border_rounded,
              size: 52,
              color: isError
                  ? AppColors.red.withValues(alpha: 0.5)
                  : context.colors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subMessage,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
