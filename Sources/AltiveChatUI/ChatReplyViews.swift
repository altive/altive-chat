import AltiveChatCore
import SwiftUI

/// メッセージ内へ表示する返信元の引用。
@MainActor
public struct ChatReplyQuote: View {
  private let reference: ChatReplyReference
  private let strings: ChatRoomStrings
  private let imageLoader: ChatImageLoader
  private let stickerImageLoader: ChatStickerImageLoader?
  private let onTap: (() -> Void)?

  /// 返信元の引用を作成する。
  public init(
    reference: ChatReplyReference,
    strings: ChatRoomStrings = .localized,
    imageLoader: ChatImageLoader = .standard,
    stickerImageLoader: ChatStickerImageLoader? = nil,
    onTap: (() -> Void)? = nil
  ) {
    self.reference = reference
    self.strings = strings
    self.imageLoader = imageLoader
    self.stickerImageLoader = stickerImageLoader
    self.onTap = onTap
  }

  public var body: some View {
    HStack(spacing: 8) {
      Capsule()
        .fill(.secondary)
        .frame(width: 3, height: 44)

      VStack(alignment: .leading, spacing: 2) {
        Text(reference.senderDisplayName)
          .font(.caption.bold())
          .lineLimit(1)
        Text(previewText)
          .font(.caption)
          .lineLimit(2)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      thumbnail
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    .padding(8)
    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
    .contentShape(.rect)
    .onTapGesture { onTap?() }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(strings.replyToLabel), \(reference.senderDisplayName), \(previewText)"
    )
    .accessibilityAddTraits(onTap == nil ? [] : .isButton)
  }

  private var previewText: String {
    switch reference.content {
    case .text(let value): value
    case .image(_, let caption, let totalCount):
      if let caption, !caption.isEmpty {
        caption
      } else {
        "\(strings.imageLabel) \(totalCount)"
      }
    case .sticker: strings.stickerLabel
    case .label(let value): value
    case .unavailable: strings.replyUnavailableLabel
    }
  }

  @ViewBuilder
  private var thumbnail: some View {
    switch reference.content {
    case .image(let image, _, _):
      if let image {
        ChatImageTile(
          image: image,
          imageLoader: imageLoader,
          fallbackLabel: strings.imageLabel,
          loadingFailureLabel: strings.imageLoadingFailedLabel,
          overflowCount: 0,
          onTap: nil
        )
      }
    case .sticker(let reference):
      ChatStickerMessageContent(
        reference: reference,
        imageLoader: stickerImageLoader,
        stickerLabel: strings.stickerLabel,
        loadingFailureLabel: strings.stickerLoadingFailedLabel,
        displayLength: 44
      )
    default:
      EmptyView()
    }
  }
}

/// Composer上部へ表示する選択中の返信元。
@MainActor
public struct ChatReplyComposerBar: View {
  private let reference: ChatReplyReference
  private let strings: ChatRoomStrings
  private let imageLoader: ChatImageLoader
  private let stickerImageLoader: ChatStickerImageLoader?
  private let onCancel: () -> Void

  /// 選択中の返信元と取消操作を作成する。
  public init(
    reference: ChatReplyReference,
    strings: ChatRoomStrings = .localized,
    imageLoader: ChatImageLoader = .standard,
    stickerImageLoader: ChatStickerImageLoader? = nil,
    onCancel: @escaping () -> Void
  ) {
    self.reference = reference
    self.strings = strings
    self.imageLoader = imageLoader
    self.stickerImageLoader = stickerImageLoader
    self.onCancel = onCancel
  }

  public var body: some View {
    HStack(spacing: 4) {
      ChatReplyQuote(
        reference: reference,
        strings: strings,
        imageLoader: imageLoader,
        stickerImageLoader: stickerImageLoader
      )
      Button(action: onCancel) {
        Image(systemName: "xmark")
          .frame(width: 44, height: 44)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(strings.cancelReplyLabel)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
  }
}
