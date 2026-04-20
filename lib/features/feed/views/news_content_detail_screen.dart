import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/index.dart';
import '../../../data/models/index.dart';
import '../../../data/services/article_content_crawler.dart';
import '../../../utils/text_sanitizer.dart';
import 'news_web_view_screen.dart';

class NewsContentDetailScreen extends StatefulWidget {
  final News news;
  final String? fallbackContent;

  const NewsContentDetailScreen({
    super.key,
    required this.news,
    this.fallbackContent,
  });

  @override
  State<NewsContentDetailScreen> createState() =>
      _NewsContentDetailScreenState();
}

class _NewsContentDetailScreenState extends State<NewsContentDetailScreen> {
  late final ArticleContentCrawler _crawler;
  late Future<ArticleContent> _contentFuture;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _readingProgress = ValueNotifier(0.0);
  double _textScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _crawler = ArticleContentCrawler();
    _contentFuture = _crawler.crawlArticle(widget.news.newsUrl);
    _scrollController.addListener(_updateReadingProgress);
  }

  void _updateReadingProgress() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    _readingProgress.value = (_scrollController.offset / max).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateReadingProgress);
    _scrollController.dispose();
    _readingProgress.dispose();
    super.dispose();
  }

  String get _finalFallback => sanitizeHtmlText(
    widget.fallbackContent ??
        (widget.news.description.isNotEmpty
            ? widget.news.description
            : '내용을 불러올 수 없습니다.'),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ArticleContent>(
      future: _contentFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final data = snapshot.data;
        final success = data?.success ?? false;

        // 본문 데이터 결정
        String displayTitle = widget.news.title;
        String displayContent = _finalFallback;
        List<String> displayImages = [];
        bool isFallbackMode = true;

        if (!isLoading && !hasError && success && data != null) {
          if (data.content.isNotEmpty) {
            displayTitle = sanitizeHtmlText(
              data.title.isEmpty ? widget.news.title : data.title,
            );
            displayContent = sanitizeHtmlText(data.content);
            displayImages = data.imageUrls;
            isFallbackMode = false;
          }
        }

        return Scaffold(
          backgroundColor: context.colors.bg,
          appBar: AppBar(
            backgroundColor: context.colors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.colors.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              '뉴스 본문',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: ValueListenableBuilder<double>(
                valueListenable: _readingProgress,
                builder: (context, progress, _) => LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                  minHeight: 2,
                ),
              ),
            ),
          ),

          /// 🔥 핵심: Stack으로 강제 하단 고정
          body: Stack(
            children: [
              Positioned.fill(
                child: isLoading
                    ? _buildLoadingState()
                    : _buildMainBody(
                        displayTitle,
                        displayContent,
                        displayImages,
                        isFallbackMode,
                      ),
              ),

              /// 🔥 바텀 고정
              if (!isLoading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomBar(context),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainBody(
    String title,
    String content,
    List<String> images,
    bool isFallback,
  ) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뉴스 출처 및 상태 뱃지
          Row(
            children: [
              _buildBadge(
                widget.news.source.isNotEmpty ? widget.news.source : '뉴스',
                AppColors.accent,
              ),
              if (isFallback) ...[
                const SizedBox(width: 8),
                _buildBadge('기사 요약', Colors.orange),
              ],
              const Spacer(),
              Text(
                widget.news.getTimeAgo(),
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 제목
          Text(
            title,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 22 * _textScaleFactor,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // 이미지 (있는 경우)
          if (images.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                images.first,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // 본문 내용
          SelectableText(
            content,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16 * _textScaleFactor,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 40),
          // 관련 키워드
          if (widget.news.keywords.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: context.colors.border, height: 1),
            const SizedBox(height: 20),
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
              children: widget.news.keywords
                  .map((kw) => _buildTag(kw))
                  .toList(),
            ),
          ],
          // 관련 지역
          if (widget.news.regions.isNotEmpty) ...[
            const SizedBox(height: 20),
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
              children: widget.news.regions
                  .map(
                    (r) => _buildTag(
                      AppConstants.regionToKorean(r),
                      color: AppColors.orange,
                    ),
                  )
                  .toList(),
            ),
          ],
          // 원문 링크 버튼
          if (widget.news.newsUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildLinkButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String label, {Color? color}) {
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

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLinkButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsWebViewScreen(
              url: widget.news.newsUrl,
              title: widget.news.title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.open_in_browser_rounded, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '원문 링크 열기',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            top: BorderSide(color: context.colors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              '가',
              style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
            ),
            Expanded(
              child: Slider(
                value: _textScaleFactor,
                min: 0.8,
                max: 1.5,
                divisions: 7,
                activeColor: AppColors.accent,
                onChanged: (v) => setState(() => _textScaleFactor = v),
              ),
            ),
            Text(
              '가',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: '${widget.news.title}\n${widget.news.newsUrl}',
                ),
              ),
              icon: Icon(
                Icons.share_outlined,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
