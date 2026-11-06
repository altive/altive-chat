import Foundation
import Testing

@testable import AltiveChatCore

@Suite("通常投稿のまとまり")
struct ChatMessageGroupingTests {
  @Test("同じ人の同日5分以内だけをまとめ、日付と明示境界をまたがない")
  func boundaries() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = Date(timeIntervalSince1970: 1_700_006_400)
    let first = ChatMessageGroupingItem(senderID: "a", occurredAt: date)
    func item(
      _ seconds: TimeInterval, _ sender: String? = "a", regular: Bool = true,
      boundary: Bool = false
    ) -> ChatMessageGroupingItem {
      .init(
        senderID: sender, occurredAt: date.addingTimeInterval(seconds),
        isRegularMessage: regular, startsNewGroup: boundary)
    }
    for seconds in [0.0, 299, 300] {
      #expect(
        ChatMessageGrouping.isContinuation(
          previous: first, current: item(seconds), calendar: calendar))
    }
    for candidate in [
      item(-1), item(301), item(1, "b"), item(1, nil), item(1, ""),
      item(1, regular: false), item(1, boundary: true), item(86400),
    ] {
      #expect(
        !ChatMessageGrouping.isContinuation(previous: first, current: candidate, calendar: calendar)
      )
    }
    #expect(!ChatMessageGrouping.isContinuation(previous: nil, current: first, calendar: calendar))
    #expect(
      !ChatMessageGrouping.isContinuation(
        previous: item(0, regular: false), current: item(1), calendar: calendar))
    let midnight = calendar.startOfDay(for: date)
    let crossesMidnight = ChatMessageGrouping.isContinuation(
      previous: .init(senderID: "a", occurredAt: midnight.addingTimeInterval(-1)),
      current: .init(senderID: "a", occurredAt: midnight), calendar: calendar)
    #expect(!crossesMidnight)
  }
}
