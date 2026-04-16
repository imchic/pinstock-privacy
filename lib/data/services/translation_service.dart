import 'package:translator/translator.dart';
import 'package:flutter/foundation.dart';

/// 번역 서비스 (Google Translate 기반)
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  final GoogleTranslator _translator = GoogleTranslator();

  TranslationService._internal();

  factory TranslationService() {
    return _instance;
  }

  /// 텍스트를 영어에서 한국어로 번역
  Future<String> translateToKorean(String text) async {
    try {
      if (text.isEmpty) return '';

      // 이미 한국어이면 그대로 반환
      if (_isKorean(text)) return text;

      debugPrint('🌐 번역 중: "$text"');
      final translation = await _translator.translate(
        text,
        from: 'en',
        to: 'ko',
      );
      debugPrint('✅ 번역 완료: "${translation.text}"');
      return translation.text;
    } catch (e) {
      debugPrint('❌ 번역 실패: $e');
      return text; // 번역 실패 시 원문 반환
    }
  }

  /// 텍스트가 한국어인지 판단
  bool _isKorean(String text) {
    final koreanRegex = RegExp(r'[\uAC00-\uD7A3]');
    return koreanRegex.hasMatch(text);
  }

  /// 여러 텍스트를 동시에 번역
  Future<List<String>> translateMultiple(List<String> texts) async {
    try {
      final futures = texts.map((text) => translateToKorean(text)).toList();
      return await Future.wait(futures);
    } catch (e) {
      debugPrint('❌ 다중 번역 실패: $e');
      return texts; // 번역 실패 시 원문 반환
    }
  }
}
