import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/standalone.dart' as tz;

import '../data/models/index.dart';

/// 로컬 푸시 알림 서비스
///
/// 사용법:
///   1. `main()` 에서 `await NotificationService.init()` 호출
///   2. 새 속보/급등·폭락 이벤트 발생 시 `show(alert)` 호출
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _androidRecoveryChannel = MethodChannel(
    'com.imchic.stockhub/notification_cache',
  );
  static const _marketAlertsScheduledKey = 'market_alerts_scheduled';
  static const _deepLinkDedupWindow = Duration(seconds: 2);

  // ─── 딥링크 스트림 ─────────────────────────────────
  /// 알림 탭 시 payload 스트림. HomeScreen에서 구독하여 탭 전환 / 웹뷰 열기에 사용
  static final _deepLinkController = StreamController<String>.broadcast();
  static String? _lastDeepLinkSignature;
  static DateTime? _lastDeepLinkDispatchedAt;
  static Stream<String> get deepLinkStream => _deepLinkController.stream;

  static void _dispatchDeepLink(
    String payload, {
    int? notificationId,
    String? actionId,
  }) {
    if (payload.isEmpty) {
      return;
    }

    final signature = '${notificationId ?? -1}|${actionId ?? ''}|$payload';
    final now = DateTime.now();
    final isDuplicate =
        _lastDeepLinkSignature == signature &&
        _lastDeepLinkDispatchedAt != null &&
        now.difference(_lastDeepLinkDispatchedAt!) <= _deepLinkDedupWindow;

    if (isDuplicate) {
      return;
    }

    _lastDeepLinkSignature = signature;
    _lastDeepLinkDispatchedAt = now;
    _deepLinkController.add(payload);
  }

  // ─── Android 채널 ─────────────────────────────────
  static const _channelId = 'stockhub_breaking';
  static const _channelName = '속보 알림';
  static const _channelDesc = 'StockHub 속보 및 시장 급변 알림';

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
  );

  // ─── 장 시작/마감 채널 ──────────────────────────────
  static const _marketChannelId = 'stockhub_market';
  static const _marketChannelName = '장 시작/마감 알림';
  static const _marketChannelDesc = '코스피 개장·마감 알림';
  static const _marketOpenId = 1001;
  static const _marketCloseId = 1002;

  static const _marketChannel = AndroidNotificationChannel(
    _marketChannelId,
    _marketChannelName,
    description: _marketChannelDesc,
  );

  // ─── 키워드 채널 ──────────────────────────────────
  static const _keywordChannelId = 'stockhub_keyword';
  static const _keywordChannelName = '키워드 알림';
  static const _keywordChannelDesc = '등록한 키워드가 뉴스에 포함될 때 알림';

  static const _keywordChannel = AndroidNotificationChannel(
    _keywordChannelId,
    _keywordChannelName,
    description: _keywordChannelDesc,
  );

  // ─── 초기화 ───────────────────────────────────────
  static Future<void> init() async {
    tz_data.initializeTimeZones();
    // Android 채널 생성 (Android 8+ 필수)
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_marketChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_keywordChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _dispatchDeepLink(
            payload,
            notificationId: response.id,
            actionId: response.actionId,
          );
        }
      },
    );

    // 앱이 종료된 상태에서 알림 탭으로 시작된 경우 처리
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        // HomeScreen이 준비된 후 emit 되도록 지연
        Future.delayed(const Duration(milliseconds: 500), () {
          _dispatchDeepLink(
            payload,
            notificationId: launchDetails.notificationResponse?.id,
            actionId: launchDetails.notificationResponse?.actionId,
          );
        });
      }
    }
  }

  static Future<bool> requestNotificationsPermission() async {
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      return granted ?? false;
    }

    if (Platform.isMacOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      return granted ?? false;
    }

    return true;
  }

  static Future<bool> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();

    return granted ?? false;
  }

  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
  }

  // ─── 장 시작/마감 예약 알림 ───────────────────────────

  static bool _isCorruptedScheduleCacheError(Object error) {
    final errorText = error.toString();
    return error is PlatformException &&
        (error.message?.contains('Missing type parameter') ??
            false ||
                error.details?.toString().contains('Missing type parameter') ==
                    true ||
                errorText.contains('Missing type parameter'));
  }

  static Future<bool> _wasMarketAlertsScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_marketAlertsScheduledKey) ?? false;
  }

  static Future<void> _setMarketAlertsScheduled(bool scheduled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_marketAlertsScheduledKey, scheduled);
  }

  static Future<void> _clearAndroidScheduledNotificationsCache() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _androidRecoveryChannel.invokeMethod<void>(
      'clearScheduledNotificationsCache',
    );
  }

  static Future<void> _cancelMarketAlertsNatively() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _androidRecoveryChannel.invokeMethod<void>(
      'cancelScheduledNotificationIds',
      <String, Object>{
        'ids': <int>[_marketOpenId, _marketCloseId],
      },
    );
  }

  static Future<void> _runWithRecoveredAndroidScheduleCache(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on PlatformException catch (error) {
      if (!_isCorruptedScheduleCacheError(error) || !Platform.isAndroid) {
        rethrow;
      }

      await _clearAndroidScheduledNotificationsCache();
      await action();
    }
  }

  /// 코스피 09:00 개장 · 15:30 마감 알림을 매일 반복 예약
  static Future<void> scheduleMarketAlerts() async {
    try {
      await _runWithRecoveredAndroidScheduleCache(() async {
        final seoul = tz.getLocation('Asia/Seoul');
        final now = tz.TZDateTime.now(seoul);

        const notifDetails = NotificationDetails(
          android: AndroidNotificationDetails(
            _marketChannelId,
            _marketChannelName,
            channelDescription: _marketChannelDesc,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        );

        var openTime = tz.TZDateTime(seoul, now.year, now.month, now.day, 9);
        if (openTime.isBefore(now)) {
          openTime = openTime.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          _marketOpenId,
          '코스피 개장',
          '주식 시장이 개장했습니다. (KRX 09:00)',
          openTime,
          notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );

        var closeTime = tz.TZDateTime(
          seoul,
          now.year,
          now.month,
          now.day,
          15,
          30,
        );
        if (closeTime.isBefore(now)) {
          closeTime = closeTime.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          _marketCloseId,
          '코스피 마감',
          '주식 시장이 마감됐습니다. (KRX 15:30)',
          closeTime,
          notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      });
      await _setMarketAlertsScheduled(true);
    } catch (_) {
      // 스케줄 실패는 앱 구동에 영향 없음
    }
  }

  /// 장 시작/마감 예약 알림 취소
  static Future<void> cancelMarketAlerts() async {
    if (!await _wasMarketAlertsScheduled()) {
      return;
    }

    try {
      await _plugin.cancel(_marketOpenId);
      await _plugin.cancel(_marketCloseId);
    } on PlatformException catch (error) {
      if (!_isCorruptedScheduleCacheError(error) || !Platform.isAndroid) {
        rethrow;
      }

      await _clearAndroidScheduledNotificationsCache();
      await _cancelMarketAlertsNatively();
    } finally {
      await _setMarketAlertsScheduled(false);
    }
  }

  // ─── 알림 표시 ────────────────────────────────────

  /// Alert 객체로 로컬 푸시 알림 전송
  static Future<void> show(Alert alert) async {
    final (title, body) = _buildContent(alert);
    final isKeyword = alert.alertType == 'keyword_match';

    final notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        isKeyword ? _keywordChannelId : _channelId,
        isKeyword ? _keywordChannelName : _channelName,
        channelDescription: isKeyword ? _keywordChannelDesc : _channelDesc,
        importance: isKeyword ? Importance.defaultImportance : Importance.high,
        priority: isKeyword ? Priority.defaultPriority : Priority.high,
        icon: '@mipmap/ic_launcher',
        ticker: title,
        color: isKeyword
            ? const Color(0xFF3B82F6) // accent blue
            : alert.alertType == 'finance_surge'
            ? const Color(0xFF22C55E) // green
            : alert.alertType == 'finance_fall'
            ? const Color(0xFFEF4444) // red
            : const Color(0xFFEF4444), // breaking red
        category: isKeyword
            ? AndroidNotificationCategory.reminder
            : AndroidNotificationCategory.event,
        styleInformation: isKeyword
            ? BigTextStyleInformation(
                body,
                contentTitle: title,
                summaryText: '키워드 매칭',
              )
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isKeyword
            ? InterruptionLevel.active
            : InterruptionLevel.timeSensitive,
        subtitle: isKeyword ? alert.keyword : null,
      ),
    );

    await _plugin.show(
      alert.id.hashCode & 0x7FFFFFFF,
      title,
      body,
      notifDetails,
      payload: jsonEncode(alert.toJson()),
    );
  }

  // ─── 내부 헬퍼 ────────────────────────────────────

  static (String title, String body) _buildContent(Alert alert) {
    if (alert.alertType == 'keyword_match') {
      final keyword = alert.keyword.isNotEmpty ? alert.keyword : '키워드';
      final title = '[$keyword] 관련 뉴스';
      final body = alert.title.isNotEmpty ? alert.title : alert.message;
      return (title, body);
    }

    final prefix = switch (alert.alertType) {
      'finance_surge' => '급등',
      'finance_fall' => '급락',
      _ => '속보',
    };

    final title = '[$prefix] ${alert.title}';
    final body = alert.message.isNotEmpty ? alert.message : alert.title;
    return (title, body);
  }
}
