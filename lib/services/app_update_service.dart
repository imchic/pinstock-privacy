import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreUpdateStatus {
  const StoreUpdateStatus({
    required this.isSupported,
    required this.isUpdateAvailable,
    required this.immediateUpdateAllowed,
    this.message,
  });

  final bool isSupported;
  final bool isUpdateAvailable;
  final bool immediateUpdateAllowed;
  final String? message;
}

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.currentVersion,
    this.previousVersion,
    this.lastUpdatedAt,
    this.releaseNotes = const [],
  });

  final String currentVersion;
  final String? previousVersion;
  final DateTime? lastUpdatedAt;
  final List<String> releaseNotes;

  bool get hasJustUpdated =>
      previousVersion != null && previousVersion != currentVersion;

  String? get releaseSummary {
    if (releaseNotes.isEmpty) return null;
    return releaseNotes.first;
  }
}

class AppUpdateService {
  static const String _installedVersionKey = 'installed_app_version';
  static const String _lastUpdatedFromKey = 'last_updated_from_version';
  static const String _lastUpdatedAtKey = 'last_updated_at';
  static const String _androidPackageName = 'com.imchic.stockhub';

  static const Map<String, List<String>> _releaseNotesByVersion = {
    '1.0.0+14': [
      '앱 업데이트 완료 안내를 홈에서 바로 확인할 수 있어요.',
      '설정에서 현재 버전과 최근 업데이트 이력을 볼 수 있어요.',
      'AI 요약 새로고침과 광고 흐름이 더 안정적으로 동작해요.',
    ],
  };

  static Future<AppUpdateStatus> checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _formatVersion(packageInfo);
    final installedVersion = prefs.getString(_installedVersionKey);

    if (installedVersion == null) {
      await prefs.setString(_installedVersionKey, currentVersion);
      return AppUpdateStatus(
        currentVersion: currentVersion,
        releaseNotes: getReleaseNotes(currentVersion),
      );
    }

    if (installedVersion != currentVersion) {
      final updatedAt = DateTime.now();
      await prefs.setString(_installedVersionKey, currentVersion);
      await prefs.setString(_lastUpdatedFromKey, installedVersion);
      await prefs.setString(_lastUpdatedAtKey, updatedAt.toIso8601String());

      return AppUpdateStatus(
        currentVersion: currentVersion,
        previousVersion: installedVersion,
        lastUpdatedAt: updatedAt,
        releaseNotes: getReleaseNotes(currentVersion),
      );
    }

    return AppUpdateStatus(
      currentVersion: currentVersion,
      previousVersion: prefs.getString(_lastUpdatedFromKey),
      lastUpdatedAt: DateTime.tryParse(
        prefs.getString(_lastUpdatedAtKey) ?? '',
      ),
      releaseNotes: getReleaseNotes(currentVersion),
    );
  }

  static List<String> getReleaseNotes(String version) {
    return List.unmodifiable(_releaseNotesByVersion[version] ?? const []);
  }

  static Future<StoreUpdateStatus> checkStoreUpdateStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const StoreUpdateStatus(
        isSupported: false,
        isUpdateAvailable: false,
        immediateUpdateAllowed: false,
        message: '안드로이드에서만 스토어 업데이트 확인을 지원해요.',
      );
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      final isAvailable =
          updateInfo.updateAvailability == UpdateAvailability.updateAvailable;

      return StoreUpdateStatus(
        isSupported: true,
        isUpdateAvailable: isAvailable,
        immediateUpdateAllowed: updateInfo.immediateUpdateAllowed,
        message: isAvailable ? '새 버전을 설치할 수 있어요.' : '현재 최신 버전을 사용 중이에요.',
      );
    } catch (_) {
      return const StoreUpdateStatus(
        isSupported: false,
        isUpdateAvailable: false,
        immediateUpdateAllowed: false,
        message: 'Play 스토어 설치본이 아니면 업데이트를 확인할 수 없어요.',
      );
    }
  }

  static Future<bool> launchUpdate() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final updateInfo = await InAppUpdate.checkForUpdate();
        final isAvailable =
            updateInfo.updateAvailability == UpdateAvailability.updateAvailable;
        if (isAvailable && updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        }
      } catch (_) {
        // Play Core 실패 시 스토어 이동으로 폴백
      }
    }

    final marketUri = Uri.parse('market://details?id=$_androidPackageName');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_androidPackageName',
    );

    if (await canLaunchUrl(marketUri)) {
      return launchUrl(marketUri, mode: LaunchMode.externalApplication);
    }
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  static String _formatVersion(PackageInfo packageInfo) {
    final buildNumber = packageInfo.buildNumber.trim();
    if (buildNumber.isEmpty) {
      return packageInfo.version;
    }
    return '${packageInfo.version}+$buildNumber';
  }
}
