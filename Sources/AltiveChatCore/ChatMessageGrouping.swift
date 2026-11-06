import Foundation

/// 隣接する通常投稿のまとまりを判定するための表示値。
public struct ChatMessageGroupingItem: Hashable, Sendable {
  public let senderID: String?
  public let occurredAt: Date
  public let isRegularMessage: Bool
  public let startsNewGroup: Bool

  public init(
    senderID: String?, occurredAt: Date, isRegularMessage: Bool = true,
    startsNewGroup: Bool = false
  ) {
    self.senderID = senderID
    self.occurredAt = occurredAt
    self.isRegularMessage = isRegularMessage
    self.startsNewGroup = startsNewGroup
  }
}

/// 保存データを結合せず、表示上の連続性だけを判定する。
public enum ChatMessageGrouping {
  public static func isContinuation(
    previous: ChatMessageGroupingItem?, current: ChatMessageGroupingItem,
    calendar: Calendar = .current, maximumInterval: TimeInterval = 300
  ) -> Bool {
    guard let previous, let senderID = current.senderID, !senderID.isEmpty,
      previous.senderID == senderID, previous.isRegularMessage, current.isRegularMessage,
      !current.startsNewGroup, calendar.isDate(previous.occurredAt, inSameDayAs: current.occurredAt)
    else { return false }
    let interval = current.occurredAt.timeIntervalSince(previous.occurredAt)
    return interval >= 0 && interval <= maximumInterval
  }
}
