import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinstock/features/trends/views/trends_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/index.dart';
import '../../../data/models/index.dart';
import '../../../features/alerts/views/alerts_screen.dart';
import '../../../features/bookmark/views/bookmark_screen.dart';
import '../../../features/feed/views/news_popup.dart';
import '../../../features/finance/views/finance_screen.dart';
import '../../../features/settings/views/settings_screen.dart';
import '../../../providers/index.dart';
import '../../../services/app_onboarding_service.dart';
import '../../../services/app_update_service.dart';
import '../../../services/notification_service.dart';
import '../../../utils/ad_service.dart';

/// 배너 방주 제어 상수
const _kBannerCooldownMinutes = 5; // 최소 간격
const _kDailyBannerLimit = 5; // 하루 최대 배너 횟수
const _kBannerCountKey = 'banner_count_v1';

/// 저긴급 타입은 배너 표시 안 함 (알림 탭에서만 조용히 확인)
const _silentAlertTypes = {'keyword_match', 'finance_economic'};
const _financeTabIndex = 0;
const _economicTabIndex = 1;
const _trendsTabIndex = 2;
const _alertsTabIndex = 3;
const _bookmarkTabIndex = 4;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedTabIndex = 0;

  /// 마지막으로 배너를 표시한 시각
  DateTime? _lastBannerTime;

  /// 당일 배너 표시 횟수
  int _todayBannerCount = 0;
  String _todayBannerDateStr = '';

  StreamSubscription<String>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodayBannerCount();
    _showInitialAppOpenAd();
    _deepLinkSub = NotificationService.deepLinkStream.listen(_handleDeepLink);
    // 속보·키워드 감시 시작 — 새 Alert 발생 시 인앱 배너 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(appUpdateStatusProvider, (_, next) {
        next.whenData((status) {
          if (status.hasJustUpdated) {
            _showAppUpdateBanner(status);
          }
        });
      });
      ref.listenManual(storeUpdateStatusProvider, (_, next) {
        next.whenData((status) {
          if (status.isUpdateAvailable) {
            _showStoreUpdateBanner(status);
          }
        });
      });
      ref.listenManual(breakingNewsWatcherProvider, (_, next) {
        next.whenData((alert) => _showAlertBanner(alert));
      });
      // 급등/폭락 지수 감시 시작
      ref.listenManual(marketSurgeWatcherProvider, (_, next) {
        next.whenData((alert) => _showAlertBanner(alert));
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    if (!canShowAppOpenAdOnResume()) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(showAppOpenAd(context));
    });
  }

  void _showInitialAppOpenAd() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final onboardingSeen =
          await AppOnboardingService.isNotificationOnboardingSeen();
      if (!mounted || !onboardingSeen) {
        return;
      }

      unawaited(showInitialAppOpenAdIfNeeded(context));
    });
  }

  /// 로컨 푸시 탭 페이로드 처리
  void _handleDeepLink(String payload) {
    if (!mounted) return;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final alert = Alert.fromJson(json);
      showAlertDetailSheet(context, alert);
    } catch (_) {
      // 구형 payload(URL 문자열) 또는 'alerts' 처리
      if (payload.startsWith('http://') || payload.startsWith('https://')) {
        showUrlNewsSheet(context, title: '뉴스', url: payload);
      } else {
        setState(() => _selectedTabIndex = _alertsTabIndex);
      }
    }
  }

  /// 오늘 배너 횟수를 SharedPreferences에서 로드
  Future<void> _loadTodayBannerCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateStr(DateTime.now());
    final raw = prefs.getString(_kBannerCountKey) ?? '';
    if (raw.startsWith(today)) {
      _todayBannerCount = int.tryParse(raw.split(':').last) ?? 0;
    } else {
      _todayBannerCount = 0;
    }
    _todayBannerDateStr = today;
  }

  Future<void> _incrementBannerCount() async {
    _todayBannerCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kBannerCountKey,
      '$_todayBannerDateStr:$_todayBannerCount',
    );
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void _showAppUpdateBanner(AppUpdateStatus status) {
    if (!mounted) return;

    final previousVersion = status.previousVersion;
    if (previousVersion == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 5),
        content: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.system_update_alt,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '앱 업데이트 완료',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$previousVersion -> ${status.currentVersion}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status.releaseSummary != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        status.releaseSummary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStoreUpdateBanner(StoreUpdateStatus status) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 6),
        content: GestureDetector(
          onTap: () async {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            final launched = await AppUpdateService.launchUpdate();
            if (!mounted || launched) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('업데이트 화면을 열지 못했습니다.')));
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '새 버전 사용 가능',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '터치해서 최신 버전으로 업데이트하세요.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  status.immediateUpdateAllowed ? '업데이트' : '스토어',
                  style: const TextStyle(
                    color: Color(0xFF7DD3FC),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertBanner(Alert alert) {
    if (!mounted) return;

    // ① 저긴급 타입은 배너 없이 뱃지만 업데이트
    if (_silentAlertTypes.contains(alert.alertType)) return;

    // ② 하루 최대 횟수 초과
    final today = _dateStr(DateTime.now());
    if (_todayBannerDateStr != today) {
      // 날짜가 바뀐 경우 리셋
      _todayBannerCount = 0;
      _todayBannerDateStr = today;
    }
    if (_todayBannerCount >= _kDailyBannerLimit) return;

    // ③ 5분 쿨다운 체크
    final now = DateTime.now();
    if (_lastBannerTime != null &&
        now.difference(_lastBannerTime!).inMinutes < _kBannerCooldownMinutes) {
      return;
    }

    _lastBannerTime = now;
    _incrementBannerCount();

    final isSurge = alert.alertType == 'finance_surge';
    final isFall = alert.alertType == 'finance_fall';
    final isBreaking = alert.alertType == 'breaking_news';
    final hasUrl = alert.newsUrl != null && alert.newsUrl!.isNotEmpty;

    final String label;
    final Color bannerColor;
    final IconData bannerIcon;
    if (isSurge) {
      label = '급등';
      bannerColor = AppColors.green.withValues(alpha: 0.95);
      bannerIcon = Icons.trending_up;
    } else if (isFall) {
      label = '급락';
      bannerColor = AppColors.red.withValues(alpha: 0.95);
      bannerIcon = Icons.trending_down;
    } else if (isBreaking) {
      label = '속보';
      bannerColor = AppColors.red.withValues(alpha: 0.95);
      bannerIcon = Icons.campaign;
    } else {
      label = '키워드';
      bannerColor = AppColors.accent.withValues(alpha: 0.95);
      bannerIcon = Icons.notifications_active;
    }

    final headline = alert.title;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 6),
        content: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (hasUrl) {
              showUrlNewsSheet(context, title: headline, url: alert.newsUrl);
            } else {
              setState(() => _selectedTabIndex = _alertsTabIndex);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bannerColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(bannerIcon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadAlertCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, unreadCount),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(child: _buildBottomNav()),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.colors.border, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 로고 + 워드마크
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/image/pinstock_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Pin',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const TextSpan(
                      text: 'Stock',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // 설정 버튼
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: context.colors.textSecondary,
                size: 20,
              ),
            ),
          ),
          // 알림 벨 버튼
          GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = _alertsTabIndex),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _selectedTabIndex == _alertsTabIndex
                    ? AppColors.orange.withValues(alpha: 0.12)
                    : context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    _selectedTabIndex == _alertsTabIndex
                        ? Icons.notifications
                        : Icons.notifications_outlined,
                    color: _selectedTabIndex == _alertsTabIndex
                        ? AppColors.orange
                        : context.colors.textSecondary,
                    size: 20,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 5,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    const tabs = [
      (Icons.trending_up, '금융', AppColors.green),
      (Icons.account_balance_rounded, '경제', Color(0xFF6366F1)),
      (Icons.bar_chart_rounded, '통계', Color(0xFF9B59B6)),
      (Icons.notifications_outlined, '알림', AppColors.orange),
      (Icons.bookmark_border_rounded, '저장', AppColors.accent),
    ];

    // 읽지 않은 알림 카운트 (배지용)
    final unreadCount = ref.watch(unreadAlertCountProvider).valueOrNull ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          top: BorderSide(color: context.colors.border, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        10,
        10,
        MediaQuery.of(context).padding.bottom > 0 ? 10 : 16,
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final (icon, label, color) = tabs[i];
          final isSelected = _selectedTabIndex == i;
          final showBadge = i == _alertsTabIndex && unreadCount > 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedTabIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: isSelected
                        ? Border.all(color: color.withValues(alpha: 0.35))
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isSelected
                                ? color
                                : context.colors.textSecondary,
                          ),
                          if (showBadge)
                            Positioned(
                              top: -4,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(
                                  minWidth: 14,
                                  minHeight: 14,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? color
                              : context.colors.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTabIndex) {
      case _financeTabIndex:
        return const FinanceScreen();
      case _economicTabIndex:
        return const FinanceScreen(showEconomicOnly: true);
      case _trendsTabIndex:
        return const TrendsScreen();
      case _alertsTabIndex:
        return const AlertsScreen();
      case _bookmarkTabIndex:
        return const BookmarkScreen();
      default:
        return const FinanceScreen();
    }
  }
}

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  String _getMarketStatus(List<News> newsList) {
    if (newsList.isEmpty) return '데이터 부족';
    final double avgSentiment =
        newsList.fold(0.0, (sum, news) => sum + news.sentimentScore) /
        newsList.length;
    if (avgSentiment > 0.3) return '강세장';
    if (avgSentiment < -0.3) return '약세장';
    return '관망';
  }

  Color _getMarketStatusColor(String status) {
    if (status == '강세장') return AppColors.green;
    if (status == '약세장') return AppColors.red;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsListProvider);
    final trendsAsync = ref.watch(topTrendingKeywordsProvider);
    final unreadCountAsync = ref.watch(unreadAlertCountProvider);

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: context.colors.surface,
      onRefresh: () async {
        ref.invalidate(newsListProvider);
        ref.invalidate(topTrendingKeywordsProvider);
      },
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // 시장 상황 - 큰 카드
              newsAsync.when(
                data: (newsList) {
                  final marketStatus = newsList.isNotEmpty
                      ? _getMarketStatus(newsList)
                      : '관망';
                  final statusColor = _getMarketStatusColor(marketStatus);

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘의 시장',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  marketStatus == '강세장'
                                      ? Icons.trending_up
                                      : marketStatus == '약세장'
                                      ? Icons.trending_down
                                      : Icons.remove,
                                  color: statusColor,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        marketStatus,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        newsList.isEmpty
                                            ? ''
                                            : '${(newsList.fold<double>(0, (sum, news) => sum + news.sentimentScore) / newsList.length * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: context.colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // TOP 뉴스
                      if (newsList.isNotEmpty) ...[
                        Text(
                          'TOP 1 뉴스',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTopNewsCard(context, newsList[0]),
                        const SizedBox(height: 16),
                      ],
                      // 뉴스 리스트
                      if (newsList.length > 1) ...[
                        Text(
                          '뉴스',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...newsList.skip(1).take(4).map((news) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildNewsItem(context, news),
                          );
                        }),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (error, stack) => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.red,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '뉴스 로드 실패',
                          style: TextStyle(
                            color: AppColors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 키워드
              trendsAsync.when(
                data: (keywords) {
                  if (keywords.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '주목할 키워드',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: keywords.take(5).map((keyword) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: context.colors.border,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      keyword.name,
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${keyword.changeRate > 0 ? '+' : ''}${keyword.changeRate.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: keyword.changeRate > 0
                                            ? AppColors.green
                                            : AppColors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
              // 알림
              unreadCountAsync.when(
                data: (count) {
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(80),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '읽지 않은 알림 $count개',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNewsCard(BuildContext context, News news) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getSentimentColor(news.sentimentScore).withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  news.source,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSentimentColor(news.sentimentScore),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getSentimentLabel(news.sentimentScore),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildNewsItem(BuildContext context, News news) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: _getSentimentColor(news.sentimentScore),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        news.source,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getSentimentLabel(news.sentimentScore),
                      style: TextStyle(
                        color: _getSentimentColor(news.sentimentScore),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  news.title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
    if (score > 0.1) return AppColors.green;
    if (score < -0.1) return AppColors.red;
    return AppColors.accent;
  }
}
