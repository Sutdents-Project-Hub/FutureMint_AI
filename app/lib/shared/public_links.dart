import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/release_config.dart';

bool _isPublicHttps(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host.isNotEmpty &&
    uri.host != 'localhost' &&
    uri.userInfo.isEmpty &&
    !uri.host.endsWith('.localhost');

Future<void> openPublicLink(
  BuildContext context,
  Uri uri, {
  required String label,
}) async {
  if (!_isPublicHttps(uri)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label尚未完成設定，請稍後再試。')));
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Platform handlers can fail even when a URL is well-formed.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('目前無法開啟$label，請稍後再試。')));
  }
}

class PrivacySupportLinks extends StatelessWidget {
  const PrivacySupportLinks({super.key, this.centered = false});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    final config = ReleaseConfig.current;
    final children = [
      TextButton.icon(
        onPressed: () =>
            openPublicLink(context, config.privacyPolicyUri, label: '隱私權政策'),
        icon: const Icon(Icons.privacy_tip_outlined),
        label: const Text('隱私權政策'),
      ),
      TextButton.icon(
        onPressed: () =>
            openPublicLink(context, config.supportUri, label: '支援頁面'),
        icon: const Icon(Icons.support_agent_outlined),
        label: const Text('聯絡支援'),
      ),
    ];
    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: children,
    );
  }
}
