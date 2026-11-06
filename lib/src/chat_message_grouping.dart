/// 隣接投稿の表示上のまとまりに必要な値。
class ChatMessageGroupingItem {
  /// 表示上の送信者と時刻、境界を受け取る。
  const ChatMessageGroupingItem({
    required this.senderId,
    required this.occurredAt,
    this.isRegularMessage = true,
    this.startsNewGroup = false,
  });

  /// 認証IDから呼び出し側が変換した表示上の送信者。
  final String? senderId;

  /// 投稿の発生日時。
  final DateTime occurredAt;

  /// 人が送信した通常投稿かどうか。
  final bool isRegularMessage;

  /// 現在投稿の直前に未読等の境界があるかどうか。
  final bool startsNewGroup;
}

/// 保存や投稿の操作単位を変えずに連続性を判定する。
// 各実装で同じ名前の純粋判定APIを提供する。
// ignore: avoid_classes_with_only_static_members
abstract final class ChatMessageGrouping {
  /// 同じ現地日付・送信者で、時間差が閾値内の通常投稿だけをまとめる。
  static bool isContinuation({
    required ChatMessageGroupingItem? previous,
    required ChatMessageGroupingItem current,
    Duration maximumInterval = const Duration(minutes: 5),
  }) {
    if (previous == null ||
        current.senderId == null ||
        current.senderId!.isEmpty ||
        previous.senderId != current.senderId ||
        !previous.isRegularMessage ||
        !current.isRegularMessage ||
        current.startsNewGroup) {
      return false;
    }
    final before = previous.occurredAt.toLocal();
    final after = current.occurredAt.toLocal();
    final interval = after.difference(before);
    return before.year == after.year &&
        before.month == after.month &&
        before.day == after.day &&
        !interval.isNegative &&
        interval <= maximumInterval;
  }
}
