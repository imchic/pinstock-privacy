/// 지역/국제정세 모델
class Region {
  final String code; // "MidEast", "USA", "Asia", "Europe"
  final String name; // "중동", "미국", "아시아", "유럽"
  final String iconEmoji;
  final String description;
  final List<String> countries; // 포함된 국가들
  final List<String> relatedKeywords; // 관련 키워드들

  Region({
    required this.code,
    required this.name,
    required this.iconEmoji,
    required this.description,
    required this.countries,
    required this.relatedKeywords,
  });

  /// 기본 지역들 반환
  static List<Region> getDefaultRegions() {
    return [
      Region(
        code: 'MidEast',
        name: '중동',
        iconEmoji: '🕌',
        description: '중동 지역의 정세와 뉴스',
        countries: ['이란', '사우디', '이스라엘', '터키', '이라크'],
        relatedKeywords: ['유전', '종교분쟁', 'OPEC', '유가'],
      ),
      Region(
        code: 'USA',
        name: '미국',
        iconEmoji: '🦅',
        description: '미국 정치 및 경제 뉴스',
        countries: ['미국'],
        relatedKeywords: ['대선', '정책', '제재', '달러'],
      ),
      Region(
        code: 'Asia',
        name: '아시아',
        iconEmoji: '🏯',
        description: '아시아 지역 국제정세',
        countries: ['중국', '일본', '한국', '인도', '베트남'],
        relatedKeywords: ['지정학', '무역', 'CPTPP', '반도체'],
      ),
      Region(
        code: 'Europe',
        name: '유럽',
        iconEmoji: '🇪🇺',
        description: '유럽 정치 및 에너지',
        countries: ['러시아', '우크라이나', 'EU', '영국'],
        relatedKeywords: ['전쟁', '에너지', 'EU정책', '제재'],
      ),
      Region(
        code: 'Africa',
        name: '아프리카',
        iconEmoji: '🌍',
        description: '아프리카 대륙 뉴스',
        countries: ['이집트', '나이지리아', '남아공'],
        relatedKeywords: ['자원', '정치', '부족분쟁'],
      ),
    ];
  }

  /// JSON에서 Region 객체 생성
  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      iconEmoji: json['iconEmoji'] as String? ?? '🌐',
      description: json['description'] as String? ?? '',
      countries: List<String>.from(json['countries'] as List? ?? []),
      relatedKeywords: List<String>.from(
        json['relatedKeywords'] as List? ?? [],
      ),
    );
  }

  /// Region 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'iconEmoji': iconEmoji,
      'description': description,
      'countries': countries,
      'relatedKeywords': relatedKeywords,
    };
  }

  @override
  String toString() => 'Region(code: $code, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Region && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}
