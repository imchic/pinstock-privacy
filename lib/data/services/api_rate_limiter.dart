import 'package:flutter/foundation.dart';

/// API Rate Limiter 서비스
/// NewsAPI의 rate limit 문제를 방지하기 위한 지능형 제한기
class ApiRateLimiter {
  static const _maxRequestsPerHour = 4; // 하루 100개 제한을 고려하여 시간당 4개로 제한
  static const _cooldownMinutes = 15; // API 실패 후 15분 대기

  static final _instance = ApiRateLimiter._internal();
  factory ApiRateLimiter() => _instance;
  ApiRateLimiter._internal();

  final List<DateTime> _requestTimes = [];
  DateTime? _lastFailureTime;
  int _consecutiveFailures = 0;

  /// API 요청이 허용되는지 확인
  bool canMakeRequest() {
    final now = DateTime.now();

    // 연속 실패 시 쿨다운 적용
    if (_lastFailureTime != null) {
      final timeSinceFailure = now.difference(_lastFailureTime!);
      final requiredCooldown = Duration(
        minutes: _cooldownMinutes * _consecutiveFailures,
      );

      if (timeSinceFailure < requiredCooldown) {
        debugPrint(
          '⏳ [RateLimiter] 쿨다운 중: ${requiredCooldown.inMinutes - timeSinceFailure.inMinutes}분 남음',
        );
        return false;
      }
    }

    // 시간당 요청 제한 확인
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    _requestTimes.removeWhere((time) => time.isBefore(oneHourAgo));

    if (_requestTimes.length >= _maxRequestsPerHour) {
      final oldestRequest = _requestTimes.first;
      final nextAllowedTime = oldestRequest.add(const Duration(hours: 1));
      final waitMinutes = nextAllowedTime.difference(now).inMinutes;
      debugPrint('⏳ [RateLimiter] 시간당 제한 초과: $waitMinutes분 후 재시도 가능');
      return false;
    }

    return true;
  }

  /// API 요청 기록 (성공 시)
  void recordRequest() {
    _requestTimes.add(DateTime.now());
    _consecutiveFailures = 0;
    _lastFailureTime = null;
    debugPrint(
      '✅ [RateLimiter] 요청 기록: ${_requestTimes.length}/$_maxRequestsPerHour/hr',
    );
  }

  /// API 실패 기록 (rate limit이나 기타 오류)
  void recordFailure() {
    _lastFailureTime = DateTime.now();
    _consecutiveFailures++;
    debugPrint('❌ [RateLimiter] 실패 기록: $_consecutiveFailures회 연속 실패');
  }

  /// 현재 상태 정보
  Map<String, dynamic> getStatus() {
    final now = DateTime.now();
    final recentRequests = _requestTimes
        .where((time) => time.isAfter(now.subtract(const Duration(hours: 1))))
        .length;

    return {
      'canMakeRequest': canMakeRequest(),
      'recentRequests': recentRequests,
      'maxPerHour': _maxRequestsPerHour,
      'consecutiveFailures': _consecutiveFailures,
      'lastFailure': _lastFailureTime?.toIso8601String(),
    };
  }
}
