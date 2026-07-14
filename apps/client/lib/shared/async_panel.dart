import 'package:flutter/material.dart';

import '../design/soft_components.dart';
import '../design/tokens.dart';

class AsyncPanel extends StatelessWidget {
  const AsyncPanel({
    super.key,
    required this.busy,
    required this.errorMessage,
    required this.child,
    this.onRetry,
  });

  final bool busy;
  final String? errorMessage;
  final Widget child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SoftCard(
            color: Theme.of(context).brightness == Brightness.dark
                ? FutureMintTokens.darkSurfaceRaised
                : FutureMintTokens.mintSoft,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在整理你的資料…'),
              ],
            ),
          ),
        ),
      );
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SoftCard(
            color: Theme.of(context).brightness == Brightness.dark
                ? FutureMintTokens.darkSurfaceRaised
                : Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text('暫時連不上服務', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(errorMessage!, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('再試一次'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return child;
  }
}
