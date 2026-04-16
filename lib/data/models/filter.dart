/// 필터 모델
class NewsFilter {
  final List<String> selectedRegions; // 선택된 지역 코드들
  final List<String> selectedCategories; // "정치", "에너지", "군사" 등
  final List<int> importanceLevels; // 1~5
  final String searchKeyword; // 검색어
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedSources; // 뉴스 소스 필터
  final bool onlyBookmarked; // 북마크만 표시
  final String sortBy; // "latest", "trending", "importance"

  NewsFilter({
    this.selectedRegions = const [],
    this.selectedCategories = const [],
    this.importanceLevels = const [1, 2, 3, 4, 5],
    this.searchKeyword = '',
    this.startDate,
    this.endDate,
    this.selectedSources = const [],
    this.onlyBookmarked = false,
    this.sortBy = 'latest',
  });

  /// JSON에서 NewsFilter 객체 생성
  factory NewsFilter.fromJson(Map<String, dynamic> json) {
    return NewsFilter(
      selectedRegions: List<String>.from(
        json['selectedRegions'] as List? ?? [],
      ),
      selectedCategories: List<String>.from(
        json['selectedCategories'] as List? ?? [],
      ),
      importanceLevels: List<int>.from(
        json['importanceLevels'] as List? ?? [1, 2, 3, 4, 5],
      ),
      searchKeyword: json['searchKeyword'] as String? ?? '',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      selectedSources: List<String>.from(
        json['selectedSources'] as List? ?? [],
      ),
      onlyBookmarked: json['onlyBookmarked'] as bool? ?? false,
      sortBy: json['sortBy'] as String? ?? 'latest',
    );
  }

  /// NewsFilter 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'selectedRegions': selectedRegions,
      'selectedCategories': selectedCategories,
      'importanceLevels': importanceLevels,
      'searchKeyword': searchKeyword,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'selectedSources': selectedSources,
      'onlyBookmarked': onlyBookmarked,
      'sortBy': sortBy,
    };
  }

  /// 복사본 생성
  NewsFilter copyWith({
    List<String>? selectedRegions,
    List<String>? selectedCategories,
    List<int>? importanceLevels,
    String? searchKeyword,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? selectedSources,
    bool? onlyBookmarked,
    String? sortBy,
  }) {
    return NewsFilter(
      selectedRegions: selectedRegions ?? this.selectedRegions,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      importanceLevels: importanceLevels ?? this.importanceLevels,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedSources: selectedSources ?? this.selectedSources,
      onlyBookmarked: onlyBookmarked ?? this.onlyBookmarked,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// 필터 활성 여부 확인
  bool get isActive {
    return selectedRegions.isNotEmpty ||
        selectedCategories.isNotEmpty ||
        importanceLevels.length < 5 ||
        searchKeyword.isNotEmpty ||
        startDate != null ||
        endDate != null ||
        selectedSources.isNotEmpty ||
        onlyBookmarked ||
        sortBy != 'latest';
  }

  /// 필터 초기화
  NewsFilter reset() {
    return NewsFilter();
  }

  @override
  String toString() =>
      'NewsFilter(regions: ${selectedRegions.length}, categories: ${selectedCategories.length})';
}
