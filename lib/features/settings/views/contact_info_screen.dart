import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/index.dart';
import '../../../services/app_update_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/support_link_opener.dart';

class ContactInfoScreen extends StatelessWidget {
  const ContactInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: context.colors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '앱 정보 및 문의',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _OverviewCard(),
          const SizedBox(height: 14),
          FutureBuilder<AppUpdateStatus>(
            future: AppUpdateService.checkStatus(),
            builder: (context, snapshot) {
              final status = snapshot.data;
              final currentVersion = status?.currentVersion ?? '확인 중...';
              final previousVersion = status?.previousVersion;

              return FutureBuilder<StoreUpdateStatus>(
                future: AppUpdateService.checkStoreUpdateStatus(),
                builder: (context, storeSnapshot) {
                  return _InfoCard(
                    title: '앱 정보',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _InfoRow(
                          label: '서비스명',
                          value: AppConstants.appName,
                        ),
                        const SizedBox(height: 10),
                        const _InfoRow(
                          label: '운영 주체',
                          value: AppConstants.supportTeamName,
                        ),
                        const SizedBox(height: 10),
                        _VersionInfoBlock(
                          currentVersion: currentVersion,
                          previousVersion: previousVersion,
                          storeStatus: storeSnapshot.data,
                        ),
                        const SizedBox(height: 10),
                        const _InfoRow(
                          label: '문의 가능 시간',
                          value: AppConstants.supportResponseHours,
                        ),
                        if (status != null &&
                            status.releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Text(
                            '최근 변경 사항',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final note in status.releaseNotes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _BulletLine(note),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: '연락처',
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.email_outlined,
                  label: '이메일',
                  value: AppConstants.supportEmail,
                  actionLabel: '복사',
                  onTap: () => _copyValue(
                    context,
                    AppConstants.supportEmail,
                    '이메일이 복사되었습니다',
                  ),
                ),
                if (AppConstants.supportPhone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ActionRow(
                    icon: Icons.call_outlined,
                    label: '전화',
                    value: AppConstants.supportPhone,
                    actionLabel: '복사',
                    onTap: () => _copyValue(
                      context,
                      AppConstants.supportPhone,
                      '전화번호가 복사되었습니다',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: '정책 및 안내 링크',
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.public_rounded,
                  label: '공식 안내 페이지',
                  actionLabel: '열기',
                  showValue: false,
                  onTap: () => _openPage(
                    context,
                    title: '공식 안내',
                    url: AppConstants.supportWebsiteUrl,
                  ),
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  icon: Icons.contact_page_outlined,
                  label: '문의 페이지',
                  actionLabel: '열기',
                  showValue: false,
                  onTap: () => _openPage(
                    context,
                    title: '문의 페이지',
                    url: AppConstants.supportContactPageUrl,
                  ),
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  icon: Icons.privacy_tip_outlined,
                  label: '개인정보처리방침',
                  actionLabel: '열기',
                  showValue: false,
                  onTap: () => _openPage(
                    context,
                    title: '개인정보처리방침',
                    url: AppConstants.privacyPolicyUrl,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            title: '뉴스 및 데이터 출처 안내',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletLine('네이버 검색 API를 통해 국내 뉴스 기사를 수집합니다.'),
                _BulletLine('NewsAPI를 통해 글로벌 금융 뉴스를 보조적으로 수집합니다.'),
                _BulletLine('Yahoo Finance와 KRX Open API를 통해 시장 데이터를 조회합니다.'),
                _BulletLine('각 기사 화면에서 언론사명과 발행 시각을 함께 표시합니다.'),
                _BulletLine('앱은 정적 콘텐츠가 아니라 최신 뉴스와 시장 데이터를 주기적으로 갱신합니다.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: '투자 유의사항',
            child: Text(
              '본 서비스에서 제공하는 정보는 단순 참고용이며, 특정 투자 판단을 유도하거나 종목 매수·매도를 권유하기 위한 목적이 아닙니다. 투자에 대한 최종 판단과 책임은 이용자 본인에게 있습니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: '안내',
            child: Text(
              'Google Play 뉴스 및 잡지 정책 대응을 위해 이 화면에서 운영 주체와 최신 연락처 정보를 제공합니다. 스토어 등록정보의 웹사이트 및 뉴스 선언 URL도 동일한 연락처 페이지로 유지하세요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyValue(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showAppToast(context, message);
  }

  Future<void> _openPage(
    BuildContext context, {
    required String title,
    required String url,
  }) async {
    await openSupportLink(context, title: title, url: url);
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '앱 운영 정보와 문의 채널을 한 곳에 모았습니다.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '버전, 업데이트 상태, 연락처, 정책 링크, 데이터 출처를 이 화면에서 바로 확인할 수 있어요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: context.colors.textSecondary,
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

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String actionLabel;
  final bool showValue;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.value,
    required this.actionLabel,
    this.showValue = true,
    required this.onTap,
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
          Icon(icon, size: 18, color: context.colors.textSecondary),
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
                if (showValue && value != null) ...[
                  const SizedBox(height: 2),
                  SelectableText(
                    value!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _VersionInfoBlock extends StatelessWidget {
  final String currentVersion;
  final String? previousVersion;
  final StoreUpdateStatus? storeStatus;

  const _VersionInfoBlock({
    required this.currentVersion,
    required this.previousVersion,
    required this.storeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch ((
      storeStatus?.isUpdateAvailable,
      storeStatus?.isSupported,
    )) {
      (true, _) => '업데이트 가능',
      (_, true) => '최신 버전',
      _ => '확인 불가',
    };
    final statusColor = switch ((
      storeStatus?.isUpdateAvailable,
      storeStatus?.isSupported,
    )) {
      (true, _) => AppColors.orange,
      (_, true) => AppColors.green,
      _ => context.colors.textSecondary,
    };
    final actionLabel = storeStatus?.isUpdateAvailable == true
        ? (storeStatus!.immediateUpdateAllowed ? '업데이트' : '스토어 열기')
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.system_update_rounded,
            size: 18,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 버전',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentVersion,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (previousVersion != null &&
                    previousVersion != currentVersion) ...[
                  const SizedBox(height: 4),
                  Text(
                    '최근 업데이트 $previousVersion -> $currentVersion',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: () async {
                final launched = await AppUpdateService.launchUpdate();
                if (!context.mounted || launched) return;
                showAppToast(
                  context,
                  '업데이트 화면을 열지 못했습니다.',
                  color: AppColors.red,
                  icon: Icons.error_rounded,
                );
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
