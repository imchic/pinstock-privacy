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
    'com.imchic.pinstock/notification_cache',
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
  static const _channelId = 'PinStock_breaking';
  static const _channelName = '속보 알림';
  static const _channelDesc = 'PinStock 속보 및 시장 급변 알림';

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
  );

  // ─── 장 시작/마감 채널 ──────────────────────────────
  static const _marketChannelId = 'PinStock_market';
  static const _marketChannelName = '장 시작/마감 알림';
  static const _marketChannelDesc = '코스피·NXT 주요 장 시작 및 마감 사전 알림';
  static const _nxtOpenFiveMinId = 1001;
  static const _nxtOpenOneMinId = 1002;
  static const _nxtOpenId = 1003;
  static const _marketOpenFiveMinId = 1004;
  static const _marketOpenOneMinId = 1005;
  static const _marketOpenId = 1006;
  static const _marketCloseFiveMinId = 1007;
  static const _marketCloseOneMinId = 1008;
  static const _marketCloseId = 1009;
  static const _nxtClosingAuctionFiveMinId = 1010;
  static const _nxtClosingAuctionOneMinId = 1011;
  static const _nxtClosingAuctionId = 1012;
  static const _nxtAfterMarketFiveMinId = 1013;
  static const _nxtAfterMarketOneMinId = 1014;
  static const _nxtAfterMarketId = 1015;
  static const _marketAlertIds = <int>[
    _nxtOpenFiveMinId,
    _nxtOpenOneMinId,
    _nxtOpenId,
    _marketOpenFiveMinId,
    _marketOpenOneMinId,
    _marketOpenId,
    _marketCloseFiveMinId,
    _marketCloseOneMinId,
    _marketCloseId,
    _nxtClosingAuctionFiveMinId,
    _nxtClosingAuctionOneMinId,
    _nxtClosingAuctionId,
    _nxtAfterMarketFiveMinId,
    _nxtAfterMarketOneMinId,
    _nxtAfterMarketId,
  ];

  static const _marketChannel = AndroidNotificationChannel(
    _marketChannelId,
    _marketChannelName,
    description: _marketChannelDesc,
  );

  // ─── 키워드 채널 ──────────────────────────────────
  static const _keywordChannelId = 'PinStock_keyword';
  static const _keywordChannelName = '키워드 알림';
  static const _keywordChannelDesc = '등록한 키워드가 뉴스에 포함될 때 알림';

  static const _keywordChannel = AndroidNotificationChannel(
    _keywordChannelId,
    _keywordChannelName,
    description: _keywordChannelDesc,
  );

  // ─── 경제일정 채널 ───────────────────────────────
  static const _economicChannelId = 'PinStock_economic_calendar';
  static const _economicChannelName = '경제일정 알림';
  static const _economicChannelDesc = '중요 경제지표 발표 전 미리 알려주는 알림';
  static const _economicAlertIdsKey = 'economic_calendar_alert_ids';

  static const _economicChannel = AndroidNotificationChannel(
    _economicChannelId,
    _economicChannelName,
    description: _economicChannelDesc,
    importance: Importance.high,
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

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_economicChannel);

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
      <String, Object>{'ids': _marketAlertIds},
    );
  }

  static Future<void> _scheduleDailyMarketAlert({
    required int id,
    required String title,
    required String body,
    required tz.Location location,
    required tz.TZDateTime now,
    required int hour,
    required int minute,
    required NotificationDetails details,
  }) async {
    var scheduledAt = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    final isSameMinuteToday =
        now.hour == hour && now.minute == minute && now.second < 55;

    if (isSameMinuteToday) {
      scheduledAt = now.add(const Duration(seconds: 3));
    } else if (scheduledAt.isBefore(now)) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
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

  /// NXT와 코스피 주요 장 시작·마감 알림을 매일 반복 예약
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

        await _scheduleDailyMarketAlert(
          id: _nxtOpenFiveMinId,
          title: 'NXT 장 시작 5분 전',
          body: '5분 뒤 NXT 프리마켓이 시작합니다. (08:00)',
          location: seoul,
          now: now,
          hour: 7,
          minute: 55,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtOpenOneMinId,
          title: 'NXT 장 시작 1분 전',
          body: '1분 뒤 NXT 프리마켓이 시작합니다. (08:00)',
          location: seoul,
          now: now,
          hour: 7,
          minute: 59,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtOpenId,
          title: 'NXT 장 시작',
          body: 'NXT 프리마켓이 시작됐습니다. (08:00)',
          location: seoul,
          now: now,
          hour: 8,
          minute: 0,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _marketOpenFiveMinId,
          title: '코스피 개장 5분 전',
          body: '5분 뒤 주식 시장이 개장합니다. (KRX 09:00)',
          location: seoul,
          now: now,
          hour: 8,
          minute: 55,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _marketOpenOneMinId,
          title: '코스피 개장 1분 전',
          body: '1분 뒤 주식 시장이 개장합니다. (KRX 09:00)',
          location: seoul,
          now: now,
          hour: 8,
          minute: 59,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _marketOpenId,
          title: '코스피 개장',
          body: '주식 시장이 개장했습니다. (KRX 09:00)',
          location: seoul,
          now: now,
          hour: 9,
          minute: 0,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _marketCloseFiveMinId,
          title: '코스피 마감 5분 전',
          body: '5분 뒤 주식 시장이 마감됩니다. (KRX 15:30)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 25,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _marketCloseOneMinId,
          title: '코스피 마감 1분 전',
          body: '1분 뒤 주식 시장이 마감됩니다. (KRX 15:30)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 29,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _marketCloseId,
          title: '코스피 마감',
          body: '주식 시장이 마감됐습니다. (KRX 15:30)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 30,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtClosingAuctionFiveMinId,
          title: 'NXT 종가매매 시작 5분 전',
          body: '5분 뒤 NXT 종가매매시장이 시작합니다. (15:30)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 25,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtClosingAuctionOneMinId,
          title: 'NXT 종가매매 시작 1분 전',
          body: '1분 뒤 NXT 종가매매시장이 시작합니다. (15:30)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 29,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtClosingAuctionId,
          title: 'NXT 종가매매 시작',
          body: 'NXT 종가매매시장이 시작됐습니다. (15:30)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 30,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtAfterMarketFiveMinId,
          title: 'NXT 애프터마켓 시작 5분 전',
          body: '5분 뒤 NXT 애프터마켓이 시작합니다. (15:40)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 35,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtAfterMarketOneMinId,
          title: 'NXT 애프터마켓 시작 1분 전',
          body: '1분 뒤 NXT 애프터마켓이 시작합니다. (15:40)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 39,
          details: notifDetails,
        );

        await _scheduleDailyMarketAlert(
          id: _nxtAfterMarketId,
          title: 'NXT 애프터마켓 시작',
          body: 'NXT 애프터마켓이 시작됐습니다. (15:40)',
          location: seoul,
          now: now,
          hour: 15,
          minute: 40,
          details: notifDetails,
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
      for (final id in _marketAlertIds) {
        await _plugin.cancel(id);
      }
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

  static Future<Set<String>> getScheduledEconomicAlertEventIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_economicAlertIdsKey) ?? []).toSet();
  }

  static Future<void> _setScheduledEconomicAlertEventIds(
    Set<String> ids,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_economicAlertIdsKey, ids.toList()..sort());
  }

  static int _economicAlertNotificationId(String eventId) {
    return 2000000 + (eventId.hashCode & 0x0FFFFFFF);
  }

  static String _formatEconomicEventTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  static String _formatEconomicCountry(String country) {
    final normalized = country.toLowerCase();
    if (normalized.contains('united states') || normalized == 'us') {
      return '미국';
    }
    if (normalized.contains('korea')) {
      return '한국';
    }
    return country;
  }

  static Future<int> scheduleEconomicEventAlerts(
    List<EconomicCalendarEvent> events, {
    Duration leadTime = const Duration(minutes: 30),
  }) async {
    await cancelEconomicEventAlerts();

    if (events.isEmpty) {
      return 0;
    }

    final location = tz.getLocation('Asia/Seoul');
    final now = tz.TZDateTime.now(location);
    final scheduledIds = <String>{};

    const notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _economicChannelId,
        _economicChannelName,
        channelDescription: _economicChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _runWithRecoveredAndroidScheduleCache(() async {
      for (final event in events) {
        final eventAt = tz.TZDateTime.from(event.date, location);
        if (!eventAt.isAfter(now.add(const Duration(minutes: 2)))) {
          continue;
        }

        var scheduledAt = tz.TZDateTime.from(
          event.date.subtract(leadTime),
          location,
        );
        if (!scheduledAt.isAfter(now.add(const Duration(seconds: 10)))) {
          scheduledAt = now.add(const Duration(seconds: 10));
        }

        if (!scheduledAt.isBefore(eventAt)) {
          continue;
        }

        await _plugin.zonedSchedule(
          _economicAlertNotificationId(event.id),
          '경제일정 임박',
          '${_formatEconomicCountry(event.country)} ${event.event} 발표가 ${_formatEconomicEventTime(event.date)} 예정이에요.',
          scheduledAt,
          notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: event.id,
        );
        scheduledIds.add(event.id);
      }
    });

    await _setScheduledEconomicAlertEventIds(scheduledIds);
    return scheduledIds.length;
  }

  static Future<void> cancelEconomicEventAlerts([
    Iterable<String>? eventIds,
  ]) async {
    final storedIds = await getScheduledEconomicAlertEventIds();
    final targetIds = eventIds == null ? storedIds : eventIds.toSet();

    if (targetIds.isEmpty) {
      if (eventIds == null) {
        await _setScheduledEconomicAlertEventIds(<String>{});
      }
      return;
    }

    for (final eventId in targetIds) {
      await _plugin.cancel(_economicAlertNotificationId(eventId));
    }

    final updatedIds = eventIds == null
        ? <String>{}
        : storedIds.difference(targetIds.toSet());
    await _setScheduledEconomicAlertEventIds(updatedIds);
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
