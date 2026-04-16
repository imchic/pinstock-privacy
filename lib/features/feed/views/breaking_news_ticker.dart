import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/index.dart';
import '../../../providers/index.dart';
import 'news_popup.dart';

/// 실시간 속보 헤드라인 티커
/// 상위 8개 속보를 4초마다 아래→위 슬라이드 애니메이션으로 순환 표시
class BreakingNewsTicker extends ConsumerStatefulWidget {
  const BreakingNewsTicker({super.key});

  @override
  ConsumerState<BreakingNewsTicker> createState() => _BreakingNewsTickerState();
}

class _BreakingNewsTickerState extends ConsumerState<BreakingNewsTicker>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;

  late final AnimationController _animController;
  late final Animation<Offset> _slideIn;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideIn = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _fadeIn = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _animController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _index++);
        _animController.forward();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(breakingNewsProvider);

    return newsAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        final current = items[_index % items.length];
        final total = items.length;

        return GestureDetector(
          onTap: () => showNewsDetailSheet(context, current),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(bottom: BorderSide(color: context.colors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // 깜빡이는 빨간 점
                _BlinkingDot(),
                const SizedBox(width: 6),

                // 속보 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    '속보',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 슬라이드-업 타이틀
                Expanded(
                  child: ClipRect(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideIn,
                        child: Text(
                          current.title,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 진행 도트 인디케이터
                _DotIndicator(current: _index % total, total: total),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 깜빡이는 빨간 점 (속보 표시)
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
        decoration: const BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// 소형 도트 인디케이터 (현재 위치 표시)
class _DotIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _DotIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total > 5 ? 5 : total, (i) {
        // 5개 초과 시 슬라이딩 윈도우로 표시
        final visibleIndex = total > 5 ? (current ~/ 5) * 5 + i : i;
        final isActive = total > 5 ? visibleIndex == current : i == current;
        return Container(
          width: isActive ? 12 : 4,
          height: 4,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: isActive ? AppColors.red : context.colors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
