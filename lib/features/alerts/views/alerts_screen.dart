import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/index.dart';
import '../../../data/models/index.dart' show Alert, News;
import '../../../providers/index.dart';
import '../../../utils/ad_service.dart';
import '../../settings/views/settings_screen.dart';

/// 알림 화면
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 알림을 날짜별로 그룹화
  Map<String, List<Alert>> _groupAlertsByDate(List<Alert> alerts) {
    final Map<String, List<Alert>> grouped = {};

    for (final alert in alerts) {
      final dateKey = _getDateKey(alert.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(alert);
    }

    return grouped;
  }

  /// 날짜 키 생성 (정렬용)
  String _getDateKey(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final alertDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (alertDate == today) return '0_오늘';
    if (alertDate == yesterday) return '1_어제';

    final daysAgo = today.difference(alertDate).inDays;
    if (daysAgo < 7) return '2_$daysAgo일 전';

    final weekAgo = (daysAgo / 7).floor();
    if (weekAgo < 4) return '3_$weekAgo주 전';

    return '4_${dateTime.month}월 ${dateTime.day}일';
  }

  /// 섹션 제목 정렬 및 포맷팅
  String _getDateSectionTitle(String dateKey) {
    if (dateKey.startsWith('0_')) return '오늘';
    if (dateKey.startsWith('1_')) return '어제';
    return dateKey.substring(2);
  }

  /// 알림 탭 처리: 읽음 처리 후 상세 바텀시트 표시
  void _onAlertTap(BuildContext context, WidgetRef ref, Alert alert) {
    ref.read(markAlertAsReadProvider(alert.id).future).ignore();
    showAlertDetailSheet(context, alert);
  }

  /// 탭별 읽지 않은 알림 카운트
  Future<Map<String, int>> _buildUnreadCounts(WidgetRef ref) async {
    final all = await ref.watch(unreadAlertCountProvider.future);
    final breaking = await ref.watch(breakingNewsAlertsProvider.future);
    final war = await ref.watch(warAlertsProvider.future);
    final surge = await ref.watch(surgeAlertsProvider.future);
    final falling = await ref.watch(fallingAlertsProvider.future);
    final kospi = await ref.watch(kospiAlertsProvider.future);
    final kosdaq = await ref.watch(kosdaqAlertsProvider.future);
    final nasdaq = await ref.watch(nasdaqAlertsProvider.future);
    final coin = await ref.watch(coinAlertsProvider.future);
    final economy = await ref.watch(economyTabAlertsProvider.future);
    final keyword = await ref.watch(keywordMatchAlertsProvider.future);
    return {
      'all': all,
      'breaking': breaking.where((a) => !a.isRead).length,
      'war': war.where((a) => !a.isRead).length,
      'surge': surge.where((a) => !a.isRead).length,
      'falling': falling.where((a) => !a.isRead).length,
      'kospi': kospi.where((a) => !a.isRead).length,
      'kosdaq': kosdaq.where((a) => !a.isRead).length,
      'nasdaq': nasdaq.where((a) => !a.isRead).length,
      'coin': coin.where((a) => !a.isRead).length,
      'economy': economy.where((a) => !a.isRead).length,
      'keyword': keyword.where((a) => !a.isRead).length,
    };
  }

  /// Pill 스타일 탭 빌드
  Widget _buildAlertPillTab(
    int index,
    String label,
    Color color,
    int unreadCount,
  ) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : context.colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : context.colors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 날짜별 그룹화된 알림 리스트
  Widget _buildGroupedAlertsList(List<Alert> alerts) {
    return Consumer(
      builder: (context, ref, _) {
        final grouped = _groupAlertsByDate(alerts);
        final sortedKeys = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: sortedKeys.length * 2, // 섹션 + 아이템들
          itemBuilder: (context, index) {
            final groupIndex = index ~/ 2;
            final isSection = index % 2 == 0;

            if (isSection) {
              final dateKey = sortedKeys[groupIndex];
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Text(
                  _getDateSectionTitle(dateKey),
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            } else {
              final dateKey = sortedKeys[groupIndex];
              final groupAlerts = grouped[dateKey] ?? [];
              return Column(
                children: List.generate(groupAlerts.length, (alertIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AlertItem(
                      alert: groupAlerts[alertIndex],
                      onTap: () =>
                          _onAlertTap(context, ref, groupAlerts[alertIndex]),
                      onRead: () async {
                        await ref.read(
                          markAlertAsReadProvider(
                            groupAlerts[alertIndex].id,
                          ).future,
                        );
                      },
                      onDelete: () async {
                        await ref.read(
                          deleteAlertProvider(
                            groupAlerts[alertIndex].id,
                          ).future,
                        );
                      },
                    ),
                  );
                }),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCountAsync = ref.watch(unreadAlertCountProvider);

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Column(
        children: [
          // 다크 헤더
          Container(
            color: context.colors.bg,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '알림',
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 6),
                            unreadCountAsync.when(
                              data: (count) {
                                if (count == 0) return const SizedBox.shrink();
                                return Text(
                                  '$count개의 새 알림',
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (error, stack) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // 안읽음 토글
                            _HeaderChip(
                              label: unreadOnly ? '전체' : '안읽음',
                              icon: unreadOnly
                                  ? Icons.list_rounded
                                  : Icons.mark_email_unread_outlined,
                              active: unreadOnly,
                              onTap: () =>
                                  setState(() => unreadOnly = !unreadOnly),
                            ),
                            const SizedBox(width: 6),
                            _HeaderChip(
                              label: '알림 설정',
                              icon: Icons.tune_rounded,
                              active: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            // 액션 메뉴
                            _HeaderMoreMenu(
                              onDeleteRead: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: context.colors.surface,
                                    title: Text(
                                      '읽은 알림 삭제',
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    content: Text(
                                      '읽은 알림을 모두 삭제합니다.\n이 작업은 되돌릴 수 없습니다.',
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(
                                          '취소',
                                          style: TextStyle(
                                            color: context.colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          '삭제',
                                          style: TextStyle(
                                            color: AppColors.red,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await ref.read(
                                    deleteReadAlertsProvider.future,
                                  );
                                }
                              },
                              onDeleteAll: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: context.colors.surface,
                                    title: Text(
                                      '알림 전체 삭제',
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    content: Text(
                                      '모든 알림을 삭제합니다.\n이 작업은 되돌릴 수 없습니다.',
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(
                                          '취소',
                                          style: TextStyle(
                                            color: context.colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          '삭제',
                                          style: TextStyle(
                                            color: AppColors.red,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await ref.read(
                                    deleteAllAlertsProvider.future,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 탭 바 with 배지 (pill 스타일)
                  Consumer(
                    builder: (context, ref, _) {
                      return FutureBuilder<Map<String, int>>(
                        future: _buildUnreadCounts(ref),
                        builder: (context, snapshot) {
                          final counts = snapshot.data ?? {};
                          return AnimatedBuilder(
                            animation: _tabController,
                            builder: (context, _) {
                              return Container(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildAlertPillTab(
                                        0,
                                        '전체',
                                        AppColors.accent,
                                        counts['all'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        1,
                                        '속보',
                                        AppColors.red,
                                        counts['breaking'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        2,
                                        '키워드',
                                        AppColors.accent,
                                        counts['keyword'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        3,
                                        '급등',
                                        AppColors.green,
                                        counts['surge'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        4,
                                        '폭락',
                                        AppColors.red,
                                        counts['falling'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        5,
                                        '전쟁',
                                        AppColors.orange,
                                        counts['war'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        6,
                                        '코스피',
                                        AppColors.accent,
                                        counts['kospi'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        7,
                                        '코스닥',
                                        AppColors.accent,
                                        counts['kosdaq'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        8,
                                        '나스닥',
                                        AppColors.orange,
                                        counts['nasdaq'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        9,
                                        '코인',
                                        const Color(0xFFF7931A),
                                        counts['coin'] ?? 0,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildAlertPillTab(
                                        10,
                                        '경제',
                                        AppColors.accent,
                                        counts['economy'] ?? 0,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  Divider(height: 1, color: context.colors.border),
                  // 모두 읽음 버튼
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: unreadCountAsync.when(
                      data: (count) {
                        if (count == 0) return const SizedBox.shrink();
                        return SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                await ref.read(
                                  markAllAlertsAsReadProvider.future,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '모두 읽음 처리',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 탭 뷰
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFilteredTab(alertsProvider, '전체'),
                _buildFilteredTab(breakingNewsAlertsProvider, '속보'),
                _KeywordTab(unreadOnly: unreadOnly),
                _buildFilteredTab(surgeAlertsProvider, '급등'),
                _buildFilteredTab(fallingAlertsProvider, '폭락'),
                _buildFilteredTab(warAlertsProvider, '전쟁'),
                _buildFilteredTab(kospiAlertsProvider, '코스피'),
                _buildFilteredTab(kosdaqAlertsProvider, '코스닥'),
                _buildFilteredTab(nasdaqAlertsProvider, '나스닥'),
                _buildFilteredTab(coinAlertsProvider, '코인'),
                _buildFilteredTab(economyTabAlertsProvider, '경제'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 탭용 공통 위젯 — provider와 탭 이름만 넘기면 됨
  Widget _buildFilteredTab(
    ProviderListenable<AsyncValue<List<Alert>>> provider,
    String label,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final alertsAsync = ref.watch(provider);
        return alertsAsync.when(
          data: (alerts) {
            final filtered = unreadOnly
                ? alerts.where((a) => !a.isRead).toList()
                : alerts;
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Icon(
                        Icons.notifications_none_outlined,
                        size: 28,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      unreadOnly ? '읽지 않은 알림이 없어요' : '$label 알림이 없어요',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '새로운 소식을 놓치지 마세요',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }
            return _buildGroupedAlertsList(filtered);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.red),
                const SizedBox(height: 12),
                Text(
                  '오류: $error',
                  style: const TextStyle(color: AppColors.red, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// 키워드 탭 — 키워드 칩 선택 → 해당 키워드 알림만 표시
// ─────────────────────────────────────────────────────
class _KeywordTab extends ConsumerStatefulWidget {
  final bool unreadOnly;
  const _KeywordTab({required this.unreadOnly});

  @override
  ConsumerState<_KeywordTab> createState() => _KeywordTabState();
}

class _KeywordTabState extends ConsumerState<_KeywordTab> {
  String? _selectedKeyword;

  @override
  Widget build(BuildContext context) {
    final keywords = ref.watch(favoriteKeywordsControllerProvider);
    final alertsAsync = ref.watch(keywordMatchAlertsProvider);

    // 등록된 키워드 없음
    if (keywords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(
                Icons.search_outlined,
                size: 28,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '등록된 키워드가 없어요',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '설정 화면에서 키워드를 추가해보세요',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('설정으로 이동'),
            ),
          ],
        ),
      );
    }

    // 선택된 키워드가 목록에서 삭제된 경우 초기화
    if (_selectedKeyword != null && !keywords.contains(_selectedKeyword)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedKeyword = null);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 키워드 칩 가로 스크롤
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              // '전체' 칩
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedKeyword = null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedKeyword == null
                          ? AppColors.accent
                          : context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedKeyword == null
                            ? AppColors.accent
                            : context.colors.border,
                        width: _selectedKeyword == null ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      '전체',
                      style: TextStyle(
                        color: _selectedKeyword == null
                            ? Colors.white
                            : context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: _selectedKeyword == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              // 개별 키워드 칩
              ...keywords.map((kw) {
                final isSelected = _selectedKeyword == kw;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedKeyword = kw),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : context.colors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        kw,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Divider(height: 1, color: context.colors.border),
        // 알림 리스트
        Expanded(
          child: alertsAsync.when(
            data: (allAlerts) {
              final filtered = allAlerts.where((a) {
                if (widget.unreadOnly && a.isRead) return false;
                if (_selectedKeyword != null) {
                  return a.keyword == _selectedKeyword;
                }
                return true;
              }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Icon(
                          Icons.notifications_none_outlined,
                          size: 28,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.unreadOnly
                            ? '읽지 않은 키워드 알림이 없어요'
                            : _selectedKeyword != null
                            ? "'$_selectedKeyword' 알림이 없어요"
                            : '키워드 알림이 없어요',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '키워드 알림이 발생하면 여기에 표시돼요',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Consumer(
                builder: (context, ref, _) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final alert = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AlertItem(
                          alert: alert,
                          onTap: () {
                            ref
                                .read(markAlertAsReadProvider(alert.id).future)
                                .ignore();
                            showAlertDetailSheet(context, alert);
                          },
                          onRead: () => ref
                              .read(markAlertAsReadProvider(alert.id).future)
                              .ignore(),
                          onDelete: () => ref
                              .read(deleteAlertProvider(alert.id).future)
                              .ignore(),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '오류: $e',
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 알림 아이템
class _AlertItem extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onTap;
  final VoidCallback? onRead;
  final VoidCallback? onDelete;

  const _AlertItem({
    required this.alert,
    this.onTap,
    this.onRead,
    this.onDelete,
  });

  Color _getAlertColor(BuildContext context) {
    if (alert.alertType == 'finance_surge') return AppColors.green;
    if (alert.alertType == 'finance_fall') return AppColors.red;
    if (alert.alertType == 'finance_economic') return AppColors.accent;
    if (alert.alertType == 'breaking_news') return AppColors.red;
    if (alert.alertType == 'keyword_match') return AppColors.accent;
    return context.colors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final alertColor = _getAlertColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: alert.isRead
                ? context.colors.surface
                : alertColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: alert.isRead
                  ? context.colors.border
                  : alertColor.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: alertColor.withAlpha(alert.isRead ? 8 : 20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 좌측 타입 컬러 바
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [alertColor, alertColor.withValues(alpha: 0.4)],
                      ),
                    ),
                  ),
                  // 본문
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목과 액션
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 상태 배지
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: alertColor.withAlpha(120),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        _getAlertTypeLabel(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    // 제목
                                    Text(
                                      alert.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: context.colors.textPrimary,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // 읽음 상태 인디케이터
                              if (!alert.isRead)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 2,
                                  ),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: alertColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: alertColor.withAlpha(100),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 메시지
                          Text(
                            alert.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // 하단: 정보 + 액션
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 메타 정보
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.keyword,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: alertColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '${alert.region} • ${_formatTime(alert.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '뉴스 보기 →',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: alertColor.withAlpha(200),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // 액션 버튼
                              Row(
                                children: [
                                  if (!alert.isRead)
                                    GestureDetector(
                                      onTap: onRead,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: alertColor.withAlpha(140),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (!alert.isRead) const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: onDelete,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.red.withAlpha(140),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getAlertTypeLabel() {
    if (alert.alertType == 'finance_surge') return '급등';
    if (alert.alertType == 'finance_fall') return '폭락';
    if (alert.alertType == 'finance_economic') return '경제';
    if (alert.alertType == 'breaking_news') return '속보';
    if (alert.alertType == 'keyword_match') return '키워드';
    return '알림';
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '방금';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${dateTime.month}월 ${dateTime.day}일';
    }
  }
}

// ─────────────────────────────────────────────────────
/// 헤더 오른쪽 — 안읽음 토글 칩
class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _HeaderChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.6)
                : context.colors.border,
            width: active ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? AppColors.accent : context.colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.accent : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 알림 상세 바텀시트
// ─────────────────────────────────────────────

void showAlertDetailSheet(BuildContext context, Alert alert) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AlertDetailSheet(alert: alert),
  );
}

class _AlertDetailSheet extends StatelessWidget {
  final Alert alert;
  const _AlertDetailSheet({required this.alert});

  Color _alertColor(BuildContext context) {
    if (alert.alertType == 'finance_surge') return AppColors.green;
    if (alert.alertType == 'finance_fall') return AppColors.red;
    if (alert.alertType == 'finance_economic') return AppColors.accent;
    if (alert.alertType == 'breaking_news') return AppColors.red;
    if (alert.alertType == 'keyword_match') return AppColors.accent;
    return AppColors.accent;
  }

  String _sentimentLabel() {
    if (alert.alertType == 'finance_surge' || alert.changeRate > 0.5) {
      return '호재';
    }
    if (alert.alertType == 'finance_fall' || alert.changeRate < -0.5) {
      return '악재';
    }
    if (alert.alertType == 'breaking_news') return '속보';
    return '중립';
  }

  String _typeLabel() {
    if (alert.alertType == 'finance_surge') return '급등';
    if (alert.alertType == 'finance_fall') return '폭락';
    if (alert.alertType == 'finance_economic') return '경제';
    if (alert.alertType == 'breaking_news') return '속보';
    if (alert.alertType == 'keyword_match') return '키워드';
    return '알림';
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}월 ${dt.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final alertColor = _alertColor(context);
    final sentimentLabel = _sentimentLabel();
    final typeLabel = _typeLabel();
    final timeAgo = _formatTime(alert.createdAt);

    // 감정 점수 (changeRate를 0~1 로 정규화, 최대 ±5)
    final sentimentScore = ((alert.changeRate / 5).clamp(-1.0, 1.0) + 1) / 2;
    // 위험도를 0~1로
    final riskScore = (alert.riskLevel / 5).clamp(0.0, 1.0);

    final url = (alert.newsUrl != null && alert.newsUrl!.isNotEmpty)
        ? alert.newsUrl!
        : 'https://search.naver.com/search.naver?where=news&query=${Uri.encodeComponent(alert.keyword)}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.93,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 출처(타입) + 시간 + 감정 배지
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: alertColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: alertColor.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            color: alertColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alert.region,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: alertColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sentimentLabel,
                          style: TextStyle(
                            color: alertColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 제목
                  Text(
                    alert.title,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 메시지 (요약)
                  if (alert.message.isNotEmpty) ...[
                    Text(
                      alert.message,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Divider(color: context.colors.border, height: 1),
                  const SizedBox(height: 20),

                  // 증시 영향 분석
                  Text(
                    '증시 영향 분석',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildScoreRow(
                    context,
                    label: '위험도',
                    score: riskScore,
                    color: alert.riskLevel >= 4
                        ? AppColors.red
                        : alert.riskLevel >= 3
                        ? AppColors.orange
                        : AppColors.green,
                  ),
                  const SizedBox(height: 10),

                  _buildScoreRow(
                    context,
                    label: '감정 점수',
                    score: sentimentScore,
                    color: alertColor,
                    leadingLabel: '악재',
                    trailingLabel: '호재',
                  ),

                  if (alert.changeRate != 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '변동률',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${alert.changeRate > 0 ? '+' : ''}${alert.changeRate.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: alert.changeRate > 0
                                ? AppColors.green
                                : AppColors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 관련 키워드
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
                    children: [
                      _buildTag(context, alert.keyword, color: alertColor),
                      _buildTag(context, alert.region, color: AppColors.orange),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 액션 버튼
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final news = News(
                              id: alert.id,
                              title: alert.title,
                              description: alert.message,
                              content: alert.message,
                              source: alert.keyword,
                              imageUrl: '',
                              newsUrl: url,
                              publishedAt: alert.createdAt,
                              createdAt: alert.createdAt,
                              keywords: [alert.keyword],
                              regions: [alert.region],
                              sentimentScore: 0.0,
                              importanceLevel: alert.riskLevel,
                              category: alert.keyword,
                            );
                            openNewsWithAdV2(context, news: news);
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('전체 보기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          SharePlus.instance.share(
                            ShareParams(text: '${alert.title}\n\n$url'),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Icon(
                            Icons.share_outlined,
                            color: context.colors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(
    BuildContext context, {
    required String label,
    required double score,
    required Color color,
    String leadingLabel = '낮음',
    String trailingLabel = '높음',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(score * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: context.colors.surfaceLight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: score.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leadingLabel,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 9,
              ),
            ),
            Text(
              trailingLabel,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(
    BuildContext context,
    String label, {
    Color color = AppColors.accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 헤더 오른쪽 — 더보기(⋯) 메뉴 버튼
class _HeaderMoreMenu extends StatelessWidget {
  final VoidCallback onDeleteRead;
  final VoidCallback onDeleteAll;

  const _HeaderMoreMenu({
    required this.onDeleteRead,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final button = context.findRenderObject() as RenderBox;
        final offset = button.localToGlobal(Offset.zero, ancestor: overlay);

        showMenu<String>(
          context: context,
          color: context.colors.surface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.colors.border, width: 0.8),
          ),
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + button.size.height + 4,
            overlay.size.width - offset.dx - button.size.width,
            0,
          ),
          items: [
            PopupMenuItem(
              value: 'read',
              child: Row(
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 16,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '읽은 알림 삭제',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'all',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_sweep_outlined,
                    size: 16,
                    color: AppColors.red,
                  ),
                  SizedBox(width: 10),
                  Text(
                    '전체 삭제',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).then((value) {
          if (value == 'read') onDeleteRead();
          if (value == 'all') onDeleteAll();
        });
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
