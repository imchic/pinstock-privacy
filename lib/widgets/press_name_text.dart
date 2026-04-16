import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/news.dart';
import '../providers/repositories_provider.dart';

/// 언론사명을 표시하는 위젯.
/// [PressCacheService]를 watch하여 크롤링 완료 시 자동으로 업데이트됩니다.
class PressNameText extends ConsumerWidget {
  final News news;
  final TextStyle? style;
  final TextOverflow? overflow;

  /// source가 비어있을 때 표시할 대체 문자열 (기본값: '')
  final String fallback;

  const PressNameText({
    super.key,
    required this.news,
    this.style,
    this.overflow,
    this.fallback = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressCache = ref.watch(pressCacheServiceProvider);
    final name = pressCache.resolveSource(news);
    final display = name.isNotEmpty
        ? name
        : (fallback.isNotEmpty ? fallback : name);
    return Text(display, style: style, overflow: overflow);
  }
}
