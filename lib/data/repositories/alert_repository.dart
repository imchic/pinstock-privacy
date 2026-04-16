import '../models/index.dart';
import '../services/index.dart';

/// 알림 Repository
class AlertRepository {
  final LocalStorageService localService;

  AlertRepository({required this.localService});

  /// 알림 조회
  Future<List<Alert>> getAlerts({bool unreadOnly = false}) async {
    var alerts = localService.getCachedAlerts();

    if (unreadOnly) {
      alerts = alerts.where((a) => !a.isRead).toList();
    }

    // 최신순 정렬
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return alerts;
  }

  /// 알림 마크 읽음
  Future<void> markAsRead(String alertId) async {
    final alerts = localService.getCachedAlerts();
    final alertIndex = alerts.indexWhere((a) => a.id == alertId);

    if (alertIndex != -1) {
      final updatedAlert = alerts[alertIndex].copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
      alerts[alertIndex] = updatedAlert;
      await localService.saveAlerts(alerts);
    }
  }

  /// 모든 알림 읽음으로 표시
  Future<void> markAllAsRead() async {
    final alerts = localService.getCachedAlerts();
    final updatedAlerts = alerts
        .map((alert) => alert.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();

    await localService.saveAlerts(updatedAlerts);
  }

  /// 알림 추가
  Future<void> addAlert(Alert alert) async {
    final alerts = localService.getCachedAlerts();
    alerts.insert(0, alert); // 최신 알림이 맨 앞
    await localService.saveAlerts(alerts);
  }

  /// 알림 삭제
  Future<void> deleteAlert(String alertId) async {
    final alerts = localService.getCachedAlerts();
    alerts.removeWhere((a) => a.id == alertId);
    await localService.saveAlerts(alerts);
  }

  /// 읽은 알림만 삭제
  Future<void> deleteReadAlerts() async {
    final alerts = localService.getCachedAlerts();
    final unread = alerts.where((a) => !a.isRead).toList();
    await localService.saveAlerts(unread);
  }

  /// 모든 알림 삭제
  Future<void> deleteAllAlerts() async {
    await localService.saveAlerts([]);
  }

  /// 읽지 않은 알림 개수
  Future<int> getUnreadCount() async {
    final alerts = localService.getCachedAlerts();
    return alerts.where((a) => !a.isRead).length;
  }

  /// 알림 저장
  Future<void> saveAlerts(List<Alert> alerts) async {
    await localService.saveAlerts(alerts);
  }

  /// 캐시된 알림 조회
  List<Alert> getCachedAlerts() {
    return localService.getCachedAlerts();
  }
}
