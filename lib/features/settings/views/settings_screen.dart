import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/index.dart';
import '../../../providers/index.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/notification_permission_flow.dart';
import '../../../utils/support_link_opener.dart';
import 'contact_info_screen.dart';

/// 설정 화면
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '설정',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '개인 맞춤 설정',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          const Expanded(child: _SettingsContent()),
        ],
      ),
    );
  }
}

/// 설정 콘텐츠
class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: const [
        _SettingsSection(title: '관심 키워드', child: _KeywordSettings()),
        _SettingsSection(title: '알림 설정', child: _NotificationSettings()),
        _SettingsSection(title: '테마', child: _AppearanceSettings()),
        _SettingsSection(title: '앱 정보 및 문의', child: _SupportSettings()),
      ],
    );
  }
}

/// 설정 섹션
class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 키워드 설정
class _KeywordSettings extends ConsumerStatefulWidget {
  const _KeywordSettings();

  @override
  ConsumerState<_KeywordSettings> createState() => _KeywordSettingsState();
}

class _KeywordSettingsState extends ConsumerState<_KeywordSettings> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    // FocusManager가 비동기로 알림을 보내므로, 다음 프레임에서 dispose하여
    // EditableTextState._handleFocusChanged가 먼저 완전히 정리되도록 함
    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _controller.clear();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '키워드 추가',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: '쉼표로 여러 키워드 추가 가능 (삼성, 하이닉스, ...)',
            hintStyle: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 10,
            ),
            filled: true,
            fillColor: context.colors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(ctx).pop(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(
              '취소',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final input = _controller.text.trim();
              if (input.isNotEmpty) {
                Navigator.of(ctx).pop(input);
              }
            },
            child: const Text(
              '추가',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      // 쉼표로 구분된 여러 키워드를 각각 등록
      final keywords = result
          .split(',')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList();

      for (final keyword in keywords) {
        await ref
            .read(favoriteKeywordsControllerProvider.notifier)
            .addKeyword(keyword);
      }
    }
  }

  Future<void> _removeKeyword(String keyword) async {
    try {
      await ref
          .read(favoriteKeywordsControllerProvider.notifier)
          .removeKeyword(keyword);
      if (!mounted) return;
      showAppToast(context, '관심 키워드 "$keyword" 삭제됨');
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        '키워드 삭제에 실패했습니다.',
        color: AppColors.red,
        icon: Icons.error_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keywords = ref.watch(favoriteKeywordsControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (keywords.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((keyword) {
                return Container(
                  key: ValueKey(keyword),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accent.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Text(
                          keyword,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _removeKeyword(keyword),
                        child: SizedBox(
                          width: 44,
                          height: 40,
                          child: Center(
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _showAddDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border),
              ),
              child: const Center(
                child: Text(
                  '+ 키워드 추가',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림 설정
class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(userPreferenceProvider).valueOrNull;
    final notificationsEnabled = pref?.notificationsEnabled ?? false;
    final alertLevel = pref?.alertLevel ?? 'medium';

    const levelDefs = [
      ('low', '낮음', '급등·폭락 등 긴급 알림만'),
      ('medium', '중간', '주요 시장 이벤트 포함'),
      ('high', '높음', '모든 뉴스·키워드 알림'),
    ];

    return Column(
      children: [
        // 알림 활성화
        InkWell(
          onTap: () async {
            final nextValue = !notificationsEnabled;

            if (nextValue) {
              await enableNotificationsFlow(context, ref);
              return;
            }

            await disableNotificationsFlow(context, ref);
          },
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '알림 활성화',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ),
                _Toggle(
                  value: notificationsEnabled,
                  activeColor: AppColors.accent,
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          color: context.colors.border,
          indent: 16,
          endIndent: 16,
        ),
        // 알림 민감도 레이블
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Text(
                '알림 민감도',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              if (!notificationsEnabled) ...[
                const SizedBox(width: 6),
                Text(
                  '(알림 꺼짐)',
                  style: TextStyle(fontSize: 10, color: context.colors.border),
                ),
              ],
            ],
          ),
        ),
        // 알림 레벨 선택
        ...levelDefs.asMap().entries.map((entry) {
          final index = entry.key;
          final (level, label, desc) = entry.value;
          final isSelected = alertLevel == level;
          final isLast = index == levelDefs.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: notificationsEnabled
                    ? () async {
                        await ref.read(setAlertLevelProvider(level).future);
                      }
                    : null,
                borderRadius: BorderRadius.vertical(
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: !notificationsEnabled
                                    ? context.colors.border
                                    : isSelected
                                    ? AppColors.accent
                                    : context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: !notificationsEnabled
                                    ? context.colors.border
                                    : context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected && notificationsEnabled)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: context.colors.border,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ],
    );
  }
}

/// 테마 설정
class _AppearanceSettings extends ConsumerWidget {
  const _AppearanceSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode =
        ref.watch(userPreferenceProvider).valueOrNull?.darkMode ?? false;

    return InkWell(
      onTap: () async {
        await ref.read(toggleDarkModeProvider(!darkMode).future);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '다크 모드',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
            _Toggle(value: darkMode, activeColor: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _SupportSettings extends StatelessWidget {
  const _SupportSettings();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactInfoScreen()),
            );
          },
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '문의하기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '운영 정보, 연락처, 뉴스 출처 안내',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          color: context.colors.border,
          indent: 16,
          endIndent: 16,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              _ContactSummaryRow(
                icon: Icons.email_outlined,
                label: '이메일',
                value: AppConstants.supportEmail,
                onCopy: () => _copySupportValue(
                  context,
                  AppConstants.supportEmail,
                  '이메일이 복사되었습니다',
                ),
              ),
              if (AppConstants.supportPhone.isNotEmpty) ...[
                const SizedBox(height: 10),
                _ContactSummaryRow(
                  icon: Icons.call_outlined,
                  label: '전화',
                  value: AppConstants.supportPhone,
                  onCopy: () => _copySupportValue(
                    context,
                    AppConstants.supportPhone,
                    '전화번호가 복사되었습니다',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _ContactLinkRow(
                icon: Icons.public_rounded,
                label: '공식 안내 페이지',
                onTap: () => _openSupportPage(
                  context,
                  title: '공식 안내',
                  url: AppConstants.supportWebsiteUrl,
                ),
              ),
              const SizedBox(height: 10),
              _ContactLinkRow(
                icon: Icons.privacy_tip_outlined,
                label: '개인정보처리방침',
                onTap: () => _openSupportPage(
                  context,
                  title: '개인정보처리방침',
                  url: AppConstants.privacyPolicyUrl,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copySupportValue(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showAppToast(context, message);
  }

  Future<void> _openSupportPage(
    BuildContext context, {
    required String title,
    required String url,
  }) async {
    await openSupportLink(context, title: title, url: url);
  }
}

class _ContactSummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _ContactSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onCopy, child: const Text('복사')),
        ],
      ),
    );
  }
}

class _ContactLinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 커스텀 토글
class _Toggle extends StatelessWidget {
  final bool value;
  final Color activeColor;

  const _Toggle({required this.value, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: value ? activeColor : context.colors.border,
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            left: value ? 20 : 2,
            top: 2,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
