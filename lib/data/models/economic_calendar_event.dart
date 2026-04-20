class EconomicCalendarEvent {
  final String id;
  final String event;
  final String country;
  final DateTime date;
  final String impact;
  final String? actual;
  final String? previous;
  final String? estimate;
  final String? change;
  final String? changePercentage;
  final String? currency;
  final String? unit;

  EconomicCalendarEvent({
    required this.id,
    required this.event,
    required this.country,
    required this.date,
    required this.impact,
    this.actual,
    this.previous,
    this.estimate,
    this.change,
    this.changePercentage,
    this.currency,
    this.unit,
  });

  factory EconomicCalendarEvent.fromJson(Map<String, dynamic> json) {
    final parsedDate = _parseDate(
      json['date'] ?? json['datetime'] ?? json['releaseDate'],
    );

    return EconomicCalendarEvent(
      id:
          json['id']?.toString() ??
          '${json['country'] ?? ''}_${json['event'] ?? ''}_${parsedDate.toIso8601String()}',
      event: (json['event'] ?? json['name'] ?? '').toString().trim(),
      country: (json['country'] ?? json['countryName'] ?? '').toString().trim(),
      date: parsedDate,
      impact: (json['impact'] ?? '').toString().trim(),
      actual: _cleanValue(json['actual']),
      previous: _cleanValue(json['previous']),
      estimate: _cleanValue(
        json['estimate'] ?? json['estimated'] ?? json['forecast'],
      ),
      change: _cleanValue(json['change']),
      changePercentage: _cleanValue(json['changePercentage']),
      currency: _cleanValue(json['currency']),
      unit: _cleanValue(json['unit']),
    );
  }

  static DateTime _parseDate(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return DateTime.now();
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static String? _cleanValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final normalized = text.toLowerCase();
    if (normalized == 'null' || normalized == 'none' || normalized == 'n/a') {
      return null;
    }
    return text;
  }

  bool get hasActual => actual != null && actual!.isNotEmpty;

  int get impactScore {
    final normalized = impact.toLowerCase();
    if (normalized.contains('high')) return 3;
    if (normalized.contains('medium')) return 2;
    if (normalized.contains('low')) return 1;
    return 0;
  }
}
