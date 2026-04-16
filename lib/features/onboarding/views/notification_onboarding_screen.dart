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
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 44,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(22),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.accent,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '알림 설정 전에\n먼저 안내드릴게요',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Stock Hub는 속보, 급등락, 관심 키워드 소식을 보낼 때만 알림 권한을 사용합니다. 아래 버튼을 눌렀을 때만 시스템 권한 창이 열립니다.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _FeatureCard(
                      icon: Icons.campaign_rounded,
                      title: '속보 알림',
                      description: '시장 영향도가 큰 뉴스를 빠르게 알려드려요.',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureCard(
                      icon: Icons.show_chart_rounded,
                      title: '급등락 감시',
                      description: '설정한 기준을 넘는 변동이 생기면 즉시 알려드려요.',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureCard(
                      icon: Icons.sell_rounded,
                      title: '관심 키워드 추적',
                      description: '내가 등록한 종목과 키워드가 뉴스에 나오면 알려드려요.',
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: context.colors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '지금 건너뛰어도 괜찮습니다. 나중에 설정 화면에서 다시 켤 수 있어요.',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting
                            ? null
                            : _handleEnableNotifications,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                            : const Text(
                                '알림 설정하기',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _submitting ? null : _handleSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          '나중에 둘러보기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
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
