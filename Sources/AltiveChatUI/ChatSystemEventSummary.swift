import SwiftUI

/// 呼び出し側が解決した対象、変化、操作主体、詳細を順に表示する。
@MainActor
public struct ChatSystemEventSummary: View {
  private let title: String
  private let value: String
  private let metadata: String
  private let details: String?

  public init(title: String, value: String, metadata: String, details: String? = nil) {
    self.title = title
    self.value = value
    self.metadata = metadata
    self.details = details
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline.weight(.semibold))
      if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(value).font(.headline)
      }
      Text(metadata).font(.caption).foregroundStyle(.secondary)
      if let details { Text(details).font(.caption) }
    }
    .multilineTextAlignment(.leading)
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .combine)
  }
}
