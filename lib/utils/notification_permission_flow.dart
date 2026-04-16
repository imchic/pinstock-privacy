import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/index.dart';
import '../providers/index.dart';
import '../services/notification_service.dart';
import 'app_toast.dart';

Future<bool> enableNotificationsFlow(
  BuildContext context,
  WidgetRef ref, {
  bool showIntroDialog = true,
  bool showSuccessToast = true,
}) async {
  if (showIntroDialog) {
    final shouldProceed = await _showNotificationPermissionDialog(context);
    if (!shouldProceed || !context.mounted) {
      return false;
    }
  }

  final notificationsGranted =
      await NotificationService.requestNotificationsPermission();
  if (!context.mounted) {
    return false;
  }

  if (!notificationsGranted) {
    showAppToast(
      context,
      '알림 권한이 허용되지 않아 활성화되지 않았어요.',
      color: AppColors.red,
      icon: Icons.notifications_off_rounded,
    );
    return false;
  }

  await ref.read(toggleNotificationsProvider(true).future);
  if (!context.mounted) {
    return true;
  }

  if (showSuccessToast) {
    showAppToast(context, '알림이 활성화됐어요.');
  }

  if (Theme.of(context).platform == TargetPlatform.android) {
    final shouldOptimize = await _showBatteryOptimizationDialog(context);
    if (!shouldOptimize || !context.mounted) {
      return true;
    }

    final batteryGranted =
        await NotificationService.requestBatteryOptimizationExemption();
    if (!context.mounted) {
      return true;
    }

    if (batteryGranted && showSuccessToast) {
      showAppToast(context, '백그라운드 알림 안정화 설정을 적용했어요.');
    }
  }

  return true;
}

Future<void> disableNotificationsFlow(
  BuildContext context,
  WidgetRef ref, {
  bool showToast = true,
}) async {
  await ref.read(toggleNotificationsProvider(false).future);
  if (!context.mounted || !showToast) {
    return;
  }

  showAppToast(context, '알림을 끄고 백그라운드 감시를 중지했어요.');
}

Future<bool> _showNotificationPermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        '알림 권한 안내',
        style: TextStyle(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: Text(
        '속보, 급등락, 관심 키워드 소식을 제때 보내드리기 위해 알림 권한이 필요해요. 다음 단계에서 시스템 권한 창이 표시됩니다.',
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            '나중에',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            '계속',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

Future<bool> _showBatteryOptimizationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        '백그라운드 알림 안정화',
        style: TextStyle(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: Text(
        '안드로이드에서는 배터리 최적화 때문에 주기 알림이 지연될 수 있어요. 다음 화면에서 예외를 허용하면 알림 신뢰도가 더 좋아집니다.',
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            '건너뛰기',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            '허용 안내',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}
