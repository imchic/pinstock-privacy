import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/index.dart';
import '../../../providers/app_onboarding_provider.dart';
import '../../../utils/notification_permission_flow.dart';

class NotificationOnboardingScreen extends ConsumerStatefulWidget {
  const NotificationOnboardingScreen({super.key});

  @override
  ConsumerState<NotificationOnboardingScreen> createState() =>
      _NotificationOnboardingScreenState();
}

class _NotificationOnboardingScreenState
    extends ConsumerState<NotificationOnboardingScreen> {
  bool _submitting = false;

  Future<void> _completeOnboarding() async {
    await ref.read(completeNotificationOnboardingProvider.future);
  }

  Future<void> _handleEnableNotifications() async {
    if (_submitting) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await enableNotificationsFlow(
        context,
        ref,
        showIntroDialog: false,
        showSuccessToast: false,
      );
      await _completeOnboarding();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleSkip() async {
    if (_submitting) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await _completeOnboarding();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final extraCompact = constraints.maxHeight < 700;
            final compact = constraints.maxHeight < 760;
            final bodySize = extraCompact
                ? 12.0
                : compact
                ? 13.0
                : 14.0;
            final outerPadding = extraCompact
                ? 14.0
                : compact
                ? 18.0
                : 24.0;
            final blockGap = extraCompact
                ? 10.0
                : compact
                ? 16.0
                : 24.0;
            final cardGap = extraCompact
                ? 6.0
                : compact
                ? 8.0
                : 12.0;
            final buttonTopGap = extraCompact
                ? 10.0
                : compact
                ? 14.0
                : 18.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                outerPadding,
                extraCompact
                    ? 8
                    : compact
                    ? 12
                    : 20,
                outerPadding,
                extraCompact
                    ? 10
                    : compact
                    ? 14
                    : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: extraCompact ? 10 : 12,
                      vertical: extraCompact ? 5 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.accent.withAlpha(38)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: extraCompact ? 6 : 7,
                          height: extraCompact ? 6 : 7,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: extraCompact ? 6 : 8),
                        Text(
                          '알림 안내',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: extraCompact ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: extraCompact ? 10 : 20),
                  Text(
                    'PinStock은 속보, 급등락, 관심 키워드, 장 시작·마감 알림에만 권한을 사용합니다. 버튼을 누를 때만 권한 창이 열립니다.',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: bodySize,
                      height: extraCompact ? 1.3 : 1.4,
                    ),
                  ),
                  SizedBox(height: blockGap),
                  Expanded(
                    child: Column(
                      children: [
                        _FeatureCard(
                          icon: Icons.campaign_rounded,
                          title: '속보 알림',
                          description: '중요 뉴스를 빠르게 알려드려요.',
                          compact: compact,
                          extraCompact: extraCompact,
                        ),
                        SizedBox(height: cardGap),
                        _FeatureCard(
                          icon: Icons.show_chart_rounded,
                          title: '급등락 감시',
                          description: '기준을 넘는 변동을 바로 알려드려요.',
                          compact: compact,
                          extraCompact: extraCompact,
                        ),
                        SizedBox(height: cardGap),
                        _FeatureCard(
                          icon: Icons.sell_rounded,
                          title: '관심 키워드 추적',
                          description: '등록한 종목과 키워드를 알려드려요.',
                          compact: compact,
                          extraCompact: extraCompact,
                        ),
                        SizedBox(height: cardGap),
                        _FeatureCard(
                          icon: Icons.access_time_filled_rounded,
                          title: '장 시작/마감 알림',
                          description: '장 시작·마감 시간을 바로 알려드려요.',
                          compact: compact,
                          extraCompact: extraCompact,
                        ),
                        SizedBox(height: extraCompact ? 8 : 12),
                        if (!extraCompact) const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                            extraCompact
                                ? 10
                                : compact
                                ? 12
                                : 14,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(
                              extraCompact ? 14 : 16,
                            ),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: context.colors.textSecondary,
                                size: extraCompact
                                    ? 14
                                    : compact
                                    ? 16
                                    : 18,
                              ),
                              SizedBox(
                                width: extraCompact
                                    ? 6
                                    : compact
                                    ? 8
                                    : 10,
                              ),
                              Expanded(
                                child: Text(
                                  '지금 건너뛰고 나중에 설정에서 켤 수 있어요.',
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: extraCompact
                                        ? 10
                                        : compact
                                        ? 11
                                        : 12,
                                    height: extraCompact ? 1.25 : 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: buttonTopGap),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting
                          ? null
                          : _handleEnableNotifications,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: extraCompact
                              ? 12
                              : compact
                              ? 14
                              : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            extraCompact ? 14 : 16,
                          ),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '알림 설정하기',
                              style: TextStyle(
                                fontSize: extraCompact
                                    ? 13
                                    : compact
                                    ? 14
                                    : 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(
                    height: extraCompact
                        ? 2
                        : compact
                        ? 4
                        : 10,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _submitting ? null : _handleSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.textSecondary,
                        padding: EdgeInsets.symmetric(
                          vertical: extraCompact
                              ? 8
                              : compact
                              ? 10
                              : 14,
                        ),
                      ),
                      child: Text(
                        '나중에 둘러보기',
                        style: TextStyle(
                          fontSize: extraCompact
                              ? 12
                              : compact
                              ? 13
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool compact;
  final bool extraCompact;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.compact,
    required this.extraCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        extraCompact
            ? 10
            : compact
            ? 12
            : 16,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(
          extraCompact
              ? 14
              : compact
              ? 16
              : 18,
        ),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: extraCompact
                ? 32
                : compact
                ? 36
                : 42,
            height: extraCompact
                ? 32
                : compact
                ? 36
                : 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(18),
              borderRadius: BorderRadius.circular(
                extraCompact
                    ? 10
                    : compact
                    ? 12
                    : 14,
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.accent,
              size: extraCompact
                  ? 18
                  : compact
                  ? 20
                  : 22,
            ),
          ),
          SizedBox(
            width: extraCompact
                ? 8
                : compact
                ? 10
                : 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: extraCompact
                        ? 12
                        : compact
                        ? 13
                        : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  height: extraCompact
                      ? 1
                      : compact
                      ? 2
                      : 4,
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: extraCompact
                        ? 10
                        : compact
                        ? 11
                        : 12,
                    height: extraCompact ? 1.2 : 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
