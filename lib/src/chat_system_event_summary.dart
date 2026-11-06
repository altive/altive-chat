import 'package:flutter/material.dart';

/// 呼び出し側が解決した対象、変化、操作主体、詳細を順に表示する。
class ChatSystemEventSummary extends StatelessWidget {
  /// ローカライズ済み表示文字列から要約を作成する。
  const ChatSystemEventSummary({
    super.key,
    required this.title,
    required this.value,
    required this.metadata,
    this.details,
  });

  /// 対象名。
  final String title;

  /// 強調する変化。
  final String value;

  /// 操作主体と時刻等の補足。
  final String metadata;

  /// 任意の詳細。
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
          if (value.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            metadata,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.start,
          ),
          if (details != null) ...[
            const SizedBox(height: 6),
            Text(
              details!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.start,
            ),
          ],
        ],
      ),
    );
  }
}
