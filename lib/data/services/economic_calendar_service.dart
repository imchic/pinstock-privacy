import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/constants.dart';
import '../models/economic_calendar_event.dart';

class EconomicCalendarException implements Exception {
  final String message;

  const EconomicCalendarException(this.message);

  @override
  String toString() => message;
}

class EconomicCalendarService {
  static const _baseUrl = 'https://financialmodelingprep.com/stable';
  static const _relevantCountries = {
    'us',
    'united states',
    'united states of america',
    'korea',
    'south korea',
    'korea, republic of',
    'kr',
  };
  static const _priorityKeywords = {
    'cpi',
    'ppi',
    'pce',
    'gdp',
    'payroll',
    'employment',
    'unemployment',
    'jobless',
    'interest rate',
    'fomc',
    'retail sales',
    'consumer confidence',
    'pmi',
    'manufacturing',
    'trade balance',
    'exports',
    'imports',
  };

  final http.Client _client;

  EconomicCalendarService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<EconomicCalendarEvent>> fetchUpcomingEvents({
    int lookAheadDays = 14,
  }) async {
    if (AppConstants.fmpApiKey.isEmpty) {
      debugPrint('ℹ️ [EconomicCalendar] FMP_API_KEY 없음 → 실시간 캘린더 생략');
      return [];
    }

    final now = DateTime.now();
    final uri = Uri.parse('$_baseUrl/economic-calendar').replace(
      queryParameters: {
        'from': _formatDate(now.subtract(const Duration(days: 1))),
        'to': _formatDate(now.add(Duration(days: lookAheadDays))),
        'apikey': AppConstants.fmpApiKey,
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw EconomicCalendarException(
        _buildErrorMessage(response.statusCode, response.body),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw EconomicCalendarException(
        _extractErrorMessage(response.body) ?? '경제일정 응답 형식이 올바르지 않습니다',
      );
    }

    final events = decoded
        .whereType<Map<String, dynamic>>()
        .map(EconomicCalendarEvent.fromJson)
        .where((event) => event.event.isNotEmpty && event.country.isNotEmpty)
        .toList();

    return _selectRelevantEvents(events, now);
  }

  String _buildErrorMessage(int statusCode, String responseBody) {
    final apiMessage = _extractErrorMessage(responseBody);
    final normalized = apiMessage?.toLowerCase() ?? '';

    if (statusCode == 402 && normalized.contains('restricted endpoint')) {
      return '현재 FMP 요금제에서는 실시간 경제일정 API를 사용할 수 없어요.';
    }

    if (statusCode == 403 && normalized.contains('legacy endpoint')) {
      return '현재 키로는 지원 종료된 FMP 레거시 엔드포인트만 응답하고 있어요.';
    }

    if (apiMessage != null && apiMessage.isNotEmpty) {
      return '경제일정 조회 실패: $apiMessage';
    }

    return '경제일정 조회 실패: HTTP $statusCode';
  }

  String? _extractErrorMessage(String responseBody) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['Error Message', 'error', 'message']) {
          final value = decoded[key]?.toString().trim();
          if (value != null && value.isNotEmpty) {
            return value;
          }
        }
      }
    } on FormatException {
      return trimmed;
    }

    return trimmed;
  }

  List<EconomicCalendarEvent> _selectRelevantEvents(
    List<EconomicCalendarEvent> events,
    DateTime now,
  ) {
    final filtered =
        events.where((event) {
          if (event.date.isBefore(now.subtract(const Duration(hours: 2)))) {
            return false;
          }

          final country = event.country.toLowerCase();
          final title = event.event.toLowerCase();
          final isRelevantCountry = _relevantCountries.any(country.contains);
          final isPriorityEvent = _priorityKeywords.any(title.contains);

          return isRelevantCountry &&
              (event.impactScore > 0 || isPriorityEvent);
        }).toList()..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          final impactCompare = b.impactScore.compareTo(a.impactScore);
          if (impactCompare != 0) return impactCompare;
          return a.event.compareTo(b.event);
        });

    final unique = <EconomicCalendarEvent>[];
    final seen = <String>{};

    for (final event in filtered) {
      final key =
          '${event.country.toLowerCase()}|${event.event.toLowerCase()}|${event.date.toIso8601String()}';
      if (seen.add(key)) {
        unique.add(event);
      }
    }

    return unique.take(10).toList();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
