import 'package:flutter/material.dart';

void showAppToast(
  BuildContext context,
  String message, {
  Color? color,
  IconData icon = Icons.check_circle_rounded,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final defaultBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFF2C2C2E);
  const textColor = Colors.white;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor.withValues(alpha: 0.9)),
            const SizedBox(width: 7),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
        backgroundColor: color ?? defaultBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isDark
              ? const BorderSide(color: Color(0xFF4A4A4C), width: 0.5)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
        elevation: isDark ? 8 : 4,
      ),
    );
}
