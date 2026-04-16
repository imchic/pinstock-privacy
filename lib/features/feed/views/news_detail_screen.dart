import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/index.dart';
import '../../../data/models/index.dart';
import '../../../providers/index.dart';
import '../../../widgets/news_feed_banner_ad.dart';

class NewsDetailScreen extends ConsumerWidget {
  final News news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref.watch(
      bookmarkedNewsProvider.selectAsync(
        (list) => list.any((n) => n.id == news.id),
      ),
    );

    final sentimentColor = _sentimentColor(context, news.sentimentScore);
    final sentimentLabel = _sentimentLabel(news.sentimentScore);

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          color: context.colors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          news.category.isEmpty ? '뉴스 상세' : news.category,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // 공유 버튼
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: context.colors.textSecondary,
              size: 22,
            ),
            onPressed: () {
              final shareText = news.newsUrl.isNotEmpty
                  ? '${news.title}\n\n${news.newsUrl}'
                  : news.title;
              SharePlus.instance.share(ShareParams(text: shareText));
            },
          ),
          FutureBuilder<bool>(
            future: isBookmarked,
            builder: (context, snapshot) {
              final bookmarked = snapshot.data ?? news.isBookmarked;
              return IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: bookmarked
                      ? AppColors.accent
                      : context.colors.textSecondary,
                  size: 22,
                ),
                onPressed: () async {
                  final wasBookmarked = bookmarked;
                  final repository = await ref.read(
                    newsRepositoryProvider.future,
                  );
                  await repository.toggleBookmark(news);
                  ref.invalidate(bookmarkedNewsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            wasBookmarked ? '저장이 해제되었습니다' : '저장되었습니다',
                          ),
                          duration: const Duration(milliseconds: 1500),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: wasBookmarked
                              ? context.colors.textSecondary
                              : AppColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 소스 + 시간
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
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
                const SizedBox(width: 8),
                Text(
                  news.getTimeAgo(),
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: sentimentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sentimentLabel,
                    style: TextStyle(
                      color: sentimentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 제목
            Text(
              news.title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // 설명
            if (news.description.isNotEmpty) ...[
              Text(
                news.description,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 구분선
            Divider(color: context.colors.border, height: 1),
            const SizedBox(height: 20),

            // 증시 영향 분석 섹션
            Text(
              '증시 영향 분석',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),

            // 증시 관련성
            _buildScoreRow(
              context,
              label: '증시 관련성',
              score: news.stockRelevanceScore,
              color: AppColors.accent,
            ),
            const SizedBox(height: 10),

            // 감정 점수 (0~1로 normalize해서 표시)
            _buildScoreRow(
              context,
              label: '감정 점수',
              score: (news.sentimentScore + 1) / 2, // -1~1 → 0~1
              color: sentimentColor,
              leadingLabel: '악재',
              trailingLabel: '호재',
            ),
            const SizedBox(height: 20),

            // 키워드 태그
            if (news.keywords.isNotEmpty) ...[
              Text(
                '관련 키워드',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: news.keywords
                    .map((kw) => _buildTag(context, kw))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // 지역 태그
            if (news.regions.isNotEmpty) ...[
              Text(
                '관련 지역',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: news.regions
                    .map(
                      (r) => _buildTag(
                        context,
                        AppConstants.regionToKorean(r),
                        color: AppColors.orange,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 28),
            ],

            // 광고 배너
            const NewsFeedBannerAd(),

            // 원문 공유 버튼
            if (news.newsUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final shareText = '${news.title}\n\n${news.newsUrl}';
                    SharePlus.instance.share(ShareParams(text: shareText));
                  },
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('원문 공유'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(
    BuildContext context, {
    required String label,
    required double score,
    required Color color,
    String leadingLabel = '낮음',
    String trailingLabel = '높음',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(score * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score.clamp(0.0, 1.0),
            backgroundColor: context.colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leadingLabel,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 9,
              ),
            ),
            Text(
              trailingLabel,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(BuildContext context, String label, {Color? color}) {
    final tagColor = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tagColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tagColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _sentimentColor(BuildContext context, double score) {
    if (score > 0.1) return AppColors.green;
    if (score < -0.1) return AppColors.red;
    return context.colors.textSecondary;
  }

  String _sentimentLabel(double score) {
    if (score > 0.5) return '강한 호재';
    if (score > 0.1) return '호재';
    if (score < -0.5) return '강한 악재';
    if (score < -0.1) return '악재';
    return '중립';
  }
}
