import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/ad_helper.dart';

/// 뉴스 리스트 사이에 삽입하는 배너 광고 위젯
class NewsFeedBannerAd extends StatefulWidget {
  const NewsFeedBannerAd({super.key});

  @override
  State<NewsFeedBannerAd> createState() => _NewsFeedBannerAdState();
}

class _NewsFeedBannerAdState extends State<NewsFeedBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) _loadAd();
  }

  Future<void> _loadAd() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final adSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width,
    );
    if (adSize == null || !mounted) return;

    final ad = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('배너 광고 로드 실패: $error');
          if (mounted) setState(() => _hasFailed = true);
        },
      ),
    );
    await ad.load();
    if (mounted) setState(() => _bannerAd = ad);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 디버그 모드: 실패 시 오류 메시지 표시
    if (_hasFailed) {
      if (kDebugMode) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 50,
          color: Colors.red.withValues(alpha: 0.15),
          alignment: Alignment.center,
          child: const Text(
            '[광고] 로드 실패 — 로그 확인',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      // 디버그 모드: 로딩 중 placeholder 표시
      if (kDebugMode) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 50,
          color: Colors.grey.withValues(alpha: 0.1),
          alignment: Alignment.center,
          child: const Text(
            '[광고] 로딩 중...',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
