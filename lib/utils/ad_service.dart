import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/index.dart';
import '../data/models/index.dart';
import '../features/feed/views/news_content_detail_screen.dart';
import 'ad_helper.dart';

/// 전체 보기 호출 횟수 카운터 (앱 세션 기준)
int _openCount = 0;
int _aiSummaryRefreshSuccessCount = 0;
bool _isAppOpenAdShowing = false;
bool _isAppOpenAdFlowRunning = false;
bool _didShowInitialAppOpenAd = false;
DateTime? _lastAppOpenAdShownAt;
DateTime? _lastAiSummaryRefreshAdShownAt;
final DateTime _sessionStartedAt = DateTime.now();

/// 매 [_adInterval]번째 호출마다 인터스티셜 광고를 표시한 뒤 WebView로 이동.
/// 광고 로드 실패 또는 타임아웃(1.5초) 시에는 광고 없이 바로 이동합니다.
const int _adInterval = 4;
const int _aiSummaryRefreshAdInterval = 5;
const Duration _appOpenAdCooldown = Duration(minutes: 4);
const Duration _aiSummaryRefreshAdCooldown = Duration(minutes: 5);
const Duration _aiSummaryRefreshAdInitialGrace = Duration(minutes: 2);

bool _canShowAiSummaryRefreshAd() {
  if (_isAppOpenAdShowing || _isAppOpenAdFlowRunning) {
    return false;
  }

  if (DateTime.now().difference(_sessionStartedAt) <
      _aiSummaryRefreshAdInitialGrace) {
    return false;
  }

  final lastShownAt = _lastAiSummaryRefreshAdShownAt;
  if (lastShownAt == null) {
    return true;
  }

  return DateTime.now().difference(lastShownAt) >= _aiSummaryRefreshAdCooldown;
}

Future<void> maybeShowAiSummaryRefreshAd(BuildContext context) async {
  if (!context.mounted || !_canShowAiSummaryRefreshAd()) {
    return;
  }

  _aiSummaryRefreshSuccessCount++;
  final shouldShow =
      _aiSummaryRefreshSuccessCount % _aiSummaryRefreshAdInterval == 0;
  if (!shouldShow) {
    return;
  }

  InterstitialAd? ad;
  bool didRollBack = false;
  bool didStartShowing = false;
  final completer = Completer<void>();

  void completeIfNeeded() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void rollbackCounter() {
    if (didRollBack) {
      return;
    }
    didRollBack = true;
    if (_aiSummaryRefreshSuccessCount > 0) {
      _aiSummaryRefreshSuccessCount--;
    }
  }

  try {
    await InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (loaded) {
          ad = loaded;
          didStartShowing = true;
          _lastAiSummaryRefreshAdShownAt = DateTime.now();
          loaded.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              completeIfNeeded();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              rollbackCounter();
              ad.dispose();
              completeIfNeeded();
            },
          );
          loaded.show();
        },
        onAdFailedToLoad: (_) {
          rollbackCounter();
          completeIfNeeded();
        },
      ),
    ).timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () {
        rollbackCounter();
        ad?.dispose();
        completeIfNeeded();
      },
    );

    if (didStartShowing) {
      await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          rollbackCounter();
          ad?.dispose();
          completeIfNeeded();
        },
      );
    }
  } catch (_) {
    rollbackCounter();
    await ad?.dispose();
  }
}

/// 뉴스 객체 + News 본문 화면으로 이동 (권장)
/// 매 [_adInterval]번째 호출마다 인터스티셜 광고를 표시한 뒤 뉴스 본문으로 이동.
Future<void> openNewsWithAdV2(
  BuildContext context, {
  required News news,
}) async {
  _openCount++;
  final showAd = _openCount % _adInterval == 0;

  void navigateDirect() {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsContentDetailScreen(news: news)),
      );
    }
  }

  if (!showAd) {
    navigateDirect();
    return;
  }

  // 4번째마다 광고 표시
  InterstitialAd? ad;
  bool navigated = false;

  void navigateToNews() {
    if (navigated) return;
    navigated = true;
    ad?.dispose();
    navigateDirect();
  }

  void onAdUnavailable() {
    // 광고를 로드하지 못한 경우 카운터를 되돌려 다음 번에 다시 시도
    _openCount--;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('광고를 불러올 수 없어요. 잠시 후 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  try {
    // 광고 로드 (최대 1.5초 대기)
    await InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (loaded) {
          ad = loaded;
          ad!.fullScreenContentCallback = FullScreenContentCallback(
            // 광고를 다 본 뒤 닫으면 뉴스로 이동
            onAdDismissedFullScreenContent: (_) => navigateToNews(),
            // 표시 자체 실패 시에도 이동 허용 (사용자 귀책 아님)
            onAdFailedToShowFullScreenContent: (_, __) => navigateToNews(),
          );
          ad!.show();
        },
        // 로드 실패 → 뉴스 차단
        onAdFailedToLoad: (_) => onAdUnavailable(),
      ),
    ).timeout(
      const Duration(milliseconds: 1500),
      // 타임아웃 → 뉴스 차단
      onTimeout: () => onAdUnavailable(),
    );
  } catch (_) {
    onAdUnavailable();
  }
}

/// 레거시: URL + 제목으로 이동 (하위호환성용)
@Deprecated('Use openNewsWithAdV2 instead')
Future<void> openNewsWithAd(
  BuildContext context, {
  required String url,
  required String title,
}) async {
  _openCount++;
  final showAd = _openCount % _adInterval == 0;

  void navigateDirect() {
    if (context.mounted) {
      // URL로 곧바로 뉴스 본문 화면 (News 객체 없이)
      // 대신 임시 News 객체 생성
      final tempNews = News(
        id: url,
        title: title,
        description: '',
        content: '',
        source: '',
        imageUrl: '',
        newsUrl: url,
        publishedAt: DateTime.now(),
        createdAt: DateTime.now(),
        keywords: [],
        regions: [],
        sentimentScore: 0.0,
        importanceLevel: 3,
        category: '',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsContentDetailScreen(news: tempNews),
        ),
      );
    }
  }

  if (!showAd) {
    navigateDirect();
    return;
  }

  // 4번째마다 광고 표시
  InterstitialAd? ad;
  bool navigated = false;

  void navigateToWebView() {
    if (navigated) return;
    navigated = true;
    ad?.dispose();
    navigateDirect();
  }

  void onAdUnavailable() {
    // 광고를 로드하지 못한 경우 카운터를 되돌려 다음 번에 다시 시도
    _openCount--;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('광고를 불러올 수 없어요. 잠시 후 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  try {
    // 광고 로드 (최대 1.5초 대기)
    await InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (loaded) {
          ad = loaded;
          ad!.fullScreenContentCallback = FullScreenContentCallback(
            // 광고를 다 본 뒤 닫으면 뉴스로 이동
            onAdDismissedFullScreenContent: (_) => navigateToWebView(),
            // 표시 자체 실패 시에도 이동 허용 (사용자 귀책 아님)
            onAdFailedToShowFullScreenContent: (_, __) => navigateToWebView(),
          );
          ad!.show();
        },
        // 로드 실패 → 뉴스 차단
        onAdFailedToLoad: (_) => onAdUnavailable(),
      ),
    ).timeout(
      const Duration(milliseconds: 1500),
      // 타임아웃 → 뉴스 차단
      onTimeout: () => onAdUnavailable(),
    );
  } catch (_) {
    onAdUnavailable();
  }
}

/// 앱 최초 진입 시 앱 오픈 광고 표시.
/// 광고가 로드되면 닫힐 때까지 대기하고, 로드 실패 또는 타임아웃 시에는 그냥 진행합니다.
Future<void> _showRawAppOpenAd() async {
  if (_isAppOpenAdShowing) {
    return;
  }

  final completer = Completer<void>();
  AppOpenAd? appOpenAd;

  _isAppOpenAdShowing = true;

  void completeIfNeeded() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  try {
    await AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          appOpenAd = ad;
          _lastAppOpenAdShownAt = DateTime.now();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              ad.dispose();
              completeIfNeeded();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              ad.dispose();
              completeIfNeeded();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (_) => completeIfNeeded(),
      ),
    ).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        appOpenAd?.dispose();
        completeIfNeeded();
      },
    );

    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        appOpenAd?.dispose();
        completeIfNeeded();
      },
    );
  } catch (_) {
    await appOpenAd?.dispose();
    completeIfNeeded();
  } finally {
    _isAppOpenAdShowing = false;
  }
}

Future<void> showInitialAppOpenAdIfNeeded(BuildContext context) async {
  if (_didShowInitialAppOpenAd) {
    return;
  }

  _didShowInitialAppOpenAd = true;
  await showAppOpenAd(context);
}

Future<void> showAppOpenAd(BuildContext context) async {
  if (_isAppOpenAdShowing || _isAppOpenAdFlowRunning || !context.mounted) {
    return;
  }

  _isAppOpenAdFlowRunning = true;
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => const _AppOpenAdBackdropScreen(),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

  unawaited(navigator.push(route));

  try {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await _showRawAppOpenAd();
  } finally {
    if (route.isActive) {
      navigator.removeRoute(route);
    }
    _isAppOpenAdFlowRunning = false;
  }
}

bool canShowAppOpenAdOnResume() {
  if (_isAppOpenAdShowing) {
    return false;
  }

  final lastShownAt = _lastAppOpenAdShownAt;
  if (lastShownAt == null) {
    return true;
  }

  return DateTime.now().difference(lastShownAt) >= _appOpenAdCooldown;
}

class _AppOpenAdBackdropScreen extends StatelessWidget {
  const _AppOpenAdBackdropScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accent.withValues(alpha: 0.18),
              colors.bg,
              colors.bg,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth * 0.8).clamp(
                280.0,
                360.0,
              );
              final cardHeight = (constraints.maxHeight * 0.26).clamp(
                180.0,
                240.0,
              );

              return Stack(
                children: [
                  Positioned(
                    top: 28,
                    left: 24,
                    right: 24,
                    child: _BackdropHeader(colors: colors),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: AppColors.accent.withValues(alpha: 0.1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(9),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.asset(
                                    'assets/image/pinstock_logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'PinStock',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '실시간 시장 속보와 핵심 종목 흐름을 이어서 확인합니다.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BackdropHeader extends StatelessWidget {
  const _BackdropHeader({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colors.surface.withValues(alpha: 0.92),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/image/pinstock_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PinStock - 내 손안의 투자 아카이브',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '광고 후 바로 앱으로 이어집니다',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
