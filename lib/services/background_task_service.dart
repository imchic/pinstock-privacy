import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config/constants.dart';

/// WorkManager 백그라운드 태스크 이름 / ID
const String kBgTaskName = 'stockhub_news_check';
const String kBgTaskId = 'stockhub_periodic_news';
const String _kUserPreferenceKey = 'user_preference';

Future<void> syncBackgroundAlertTask({required bool enabled}) async {
  if (!Platform.isAndroid) {
    return;
  }

  try {
    await Workmanager().initialize(callbackDispatcher);
  } catch (error) {
    debugPrint('WorkManager initialize skipped: $error');
  }

  if (!enabled) {
    await Workmanager().cancelByUniqueName(kBgTaskId);
    return;
  }

  await Workmanager().registerPeriodicTask(
    kBgTaskId,
    kBgTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

/// WorkManager callback — 별도 Dart isolate에서 실행됩니다.
/// Riverpod / Provider 사용 불가, http 및 shared_preferences 직접 사용.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kBgTaskName) {
      await _checkForBreakingNews();
    }
    return true;
  });
}

// ─── 내부 구현 ─────────────────────────────────────────────────────────────

/// 네이버 뉴스 API에서 최신 기사를 가져와 새 기사 발견 시 푸시 알림을 표시하고
/// SharedPreferences 알림 리스트에도 저장합니다.
Future<void> _checkForBreakingNews() async {
  const queries = ['주식 속보', '코스피 급등 급락', '증시 이슈'];
  final prefs = await SharedPreferences.getInstance();
  final rawUserPreference = prefs.getString(_kUserPreferenceKey);
  if (rawUserPreference == null) {
    return;
  }

  try {
    final userPreference =
        jsonDecode(rawUserPreference) as Map<String, dynamic>;
    final notificationsEnabled =
        userPreference['notificationsEnabled'] as bool? ?? false;
    if (!notificationsEnabled) {
      return;
    }
  } catch (_) {
    // 저장값이 깨진 경우에는 기존 동작대로 계속 진행
  }

  final seenIds = Set<String>.from(
    prefs.getStringList('bg_seen_article_ids') ?? [],
  );
  final isFirstBaselinePending = seenIds.isEmpty;

  // 새로 발견된 기사들의 Alert JSON 목록
  final newAlertJsonList = <String>[];
  int alertIndex = 0;
  final newSeenIds = <String>{...seenIds};

  for (final query in queries) {
    final uri = Uri.parse(
      '${AppConstants.naverSearchBaseUrl}/news.json'
      '?query=${Uri.encodeComponent(query)}&display=5&sort=date',
    );

    final response = await http
        .get(
          uri,
          headers: {
            'X-Naver-Client-Id': AppConstants.naverClientId,
            'X-Naver-Client-Secret': AppConstants.naverClientSecret,
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) continue;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final link = (item['link'] as String? ?? '').trim();
      if (link.isEmpty || newSeenIds.contains(link)) continue;

      if (isFirstBaselinePending) {
        newSeenIds.add(link);
        continue;
      }

      final title = _stripHtml(item['title'] as String? ?? '');
      final description = _stripHtml(item['description'] as String? ?? '');

      // 앱의 AlertRepository와 동일한 JSON 구조로 저장
      final alertJson = jsonEncode({
        'id': 'bg_${DateTime.now().millisecondsSinceEpoch}_$alertIndex',
        'keyword': '속보',
        'region': '전체',
        'title': title,
        'message': description.isNotEmpty ? description : title,
        'newsUrl': link,
        'riskLevel': 3,
        'alertType': 'breaking_news',
        'createdAt': DateTime.now().toIso8601String(),
        'readAt': null,
        'isRead': false,
        'changeRate': 0.0,
        'currentMentionCount': 1,
        'previousMentionCount': 0,
      });

      newAlertJsonList.add(alertJson);
      newSeenIds.add(link);
      alertIndex++;
    }
  }

  final trimmed = newSeenIds.toList();
  if (trimmed.length > 500) trimmed.removeRange(0, trimmed.length - 500);
  await prefs.setStringList('bg_seen_article_ids', trimmed);

  if (isFirstBaselinePending) {
    return;
  }

  if (newAlertJsonList.isNotEmpty) {
    // 첫 번째 새 기사로 푸시 알림 표시
    final firstTitle =
        (jsonDecode(newAlertJsonList.first) as Map<String, dynamic>)['title']
            as String;
    await _showLocalNotification(firstTitle);

    // 앱의 cached_alerts에 새 알림 prepend (앱이 열릴 때 목록에 표시됨)
    const alertsKey = 'cached_alerts';
    final existing = prefs.getStringList(alertsKey) ?? [];
    final combined = [...newAlertJsonList, ...existing];
    // 최대 300개 유지
    if (combined.length > 300) combined.removeRange(300, combined.length);
    await prefs.setStringList(alertsKey, combined);
  }
}

/// 백그라운드 isolate에서 직접 flutter_local_notifications를 초기화하고 알림을 표시합니다.
Future<void> _showLocalNotification(String title) async {
  final plugin = FlutterLocalNotificationsPlugin();

  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    'StockHub 속보',
    title,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'stockhub_breaking',
        '속보 알림',
        channelDescription: 'StockHub 속보 및 시장 급변 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

String _stripHtml(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    })
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);', caseSensitive: false), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    })
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&middot;', '·')
    .replaceAll('&hellip;', '…')
    .replaceAll('&mdash;', '—')
    .replaceAll('&ndash;', '–')
    .replaceAll('&rsquo;', "'")
    .replaceAll('&lsquo;', "'")
    .replaceAll('&rdquo;', '"')
    .replaceAll('&ldquo;', '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    // 네이버 API trailing 말줄임표 제거
    .replaceAll(RegExp(r'[.…]{2,}\s*$'), '')
    .trim();
