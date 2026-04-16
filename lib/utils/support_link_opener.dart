import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/feed/views/news_web_view_screen.dart';
import 'app_toast.dart';

Future<void> openSupportLink(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    showAppToast(
      context,
      '링크 주소가 올바르지 않습니다.',
      color: Colors.red,
      icon: Icons.error_rounded,
    );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) {
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NewsWebViewScreen(url: url, title: title),
    ),
  );
}
