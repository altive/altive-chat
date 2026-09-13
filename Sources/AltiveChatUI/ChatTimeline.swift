import Foundation
import SwiftUI

enum ChatTimelineScrollAnchor {
  static let latest = UnitPoint.bottom
}

enum ChatTimelineContentLayout {
  static func contentWidth(
    viewportWidth: CGFloat,
    contentInsets: EdgeInsets,
    maximumContentWidth: CGFloat?
  ) -> CGFloat {
    let availableWidth = max(
      0,
      viewportWidth - contentInsets.leading - contentInsets.trailing
    )
    guard let maximumContentWidth else { return availableWidth }
    return min(availableWidth, max(0, maximumContentWidth))
  }
}

enum ChatTimelineViewportLayout {
  static func isReady(_ size: CGSize) -> Bool {
    size.width.isFinite
      && size.height.isFinite
      && size.width > 0
      && size.height > 0
  }
}

/// viewportと末尾anchorの距離から最新付近を判定する。
enum ChatTimelineProximity {
  /// 末尾anchorがviewport末尾から閾値内にあるかを返す。
  static func isNearBottom(
    bottomOffset: CGFloat,
    viewportHeight: CGFloat,
    threshold: CGFloat
  ) -> Bool {
    bottomOffset <= viewportHeight + max(0, threshold)
  }

  /// 末尾anchorがviewport末端へ配置済みかを返す。
  static func isAtBottom(
    bottomOffset: CGFloat,
    viewportHeight: CGFloat,
    contentBottomInset: CGFloat,
    tolerance: CGFloat = 44
  ) -> Bool {
    let expectedBottomOffset = viewportHeight - contentBottomInset
    return viewportHeight > 0
      && abs(bottomOffset - expectedBottomOffset) <= max(0, tolerance)
  }
}

/// チャットタイムラインのスクロール操作を提供する。
@MainActor
public struct ChatTimelineProxy {
  fileprivate let scrollProxy: ScrollViewProxy
  fileprivate let bottomAnchorID: ChatTimelineBottomAnchorID
  fileprivate let prepareForProxyPositioning: @MainActor () -> Void

  /// 指定した表示要素へ移動する。
  public func scrollTo<ID: Hashable>(
    _ id: ID,
    anchor: UnitPoint? = nil,
    animation: Animation? = nil
  ) {
    prepareForProxyPositioning()
    perform(animation: animation) {
      scrollProxy.scrollTo(id, anchor: anchor)
    }
  }

  /// タイムラインの末尾へ移動する。
  public func scrollToBottom(animation: Animation? = nil) {
    prepareForProxyPositioning()
    perform(animation: animation) {
      scrollProxy.scrollTo(bottomAnchorID, anchor: ChatTimelineScrollAnchor.latest)
    }
  }

  /// Bindingの末尾目標を維持したまま実ScrollViewへ末尾位置を再適用する。
  fileprivate func enforceBottomPosition(animation: Animation? = nil) {
    perform(animation: animation) {
      scrollProxy.scrollTo(bottomAnchorID, anchor: ChatTimelineScrollAnchor.latest)
    }
  }

  /// 履歴追加後も指定した表示要素の位置を維持する。
  public func preservePosition<ID: Hashable>(
    at id: ID,
    anchor: UnitPoint = .top,
    while operation: @MainActor () async -> Void
  ) async {
    prepareForProxyPositioning()
    await operation()
    await waitForTimelineLayout()
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      scrollProxy.scrollTo(id, anchor: anchor)
    }
  }

  private func perform(animation: Animation?, action: () -> Void) {
    if let animation {
      withAnimation(animation, action)
    } else {
      action()
    }
  }

  private func waitForTimelineLayout() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        DispatchQueue.main.async {
          continuation.resume()
        }
      }
    }
  }
}

/// タイムラインを最初に表示する位置。
public enum ChatTimelineInitialPosition<ID: Hashable>: Hashable {
  /// 最新項目が見える末尾。
  case latest
  /// 指定項目と配置anchor。
  case item(ID, anchor: UnitPoint)

  /// 指定項目を中央へ表示する初期位置を返す。
  public static func item(_ id: ID) -> Self {
    .item(id, anchor: .center)
  }
}

/// タイムライン上端で履歴を追加する方法。
public enum ChatTimelineHistoryLoadingMode: Hashable, Sendable {
  /// 利用者の操作で追加する。
  case manual
  /// 上端へ到達したときに自動で追加する。
  case automatic
}

/// 履歴読み込み操作の外観。
public enum ChatTimelineHistoryControlStyle: Hashable, Sendable {
  /// テキスト中心の簡潔な表示。
  case plain
  /// システム画像と枠線を持つボタン表示。
  case bordered(systemImage: String)
}

/// 新しい項目が追加された際の末尾追従方法。
public enum ChatTimelineLatestFollowingPolicy: Hashable, Sendable {
  /// 閲覧位置に関係なく末尾へ移動する従来動作。
  case always

  /// 末尾付近を閲覧している場合だけ末尾へ移動する。
  case whenNearBottom
}

/// 過去の項目を閲覧中に最新位置へ戻る操作の設定。
public struct ChatTimelineLatestControlConfiguration: Hashable, Sendable {
  fileprivate let isEnabled: Bool
  fileprivate let label: String
  fileprivate let systemImage: String

  /// 最新位置へ戻る操作を表示しない設定。
  public static let disabled = Self(isEnabled: false, label: "", systemImage: "")

  /// 最新位置へ戻る標準ボタンを表示する設定を作成する。
  public static func button(
    label: String,
    systemImage: String = "arrow.down"
  ) -> Self {
    .init(isEnabled: true, label: label, systemImage: systemImage)
  }
}

/// タイムラインの履歴追加設定。
@MainActor
public struct ChatTimelineHistoryConfiguration<ID: Hashable> {
  fileprivate let mode: ChatTimelineHistoryLoadingMode?
  fileprivate let canLoadOlder: Bool
  fileprivate let isLoading: Bool
  fileprivate let anchorID: ID?
  fileprivate let loadOlderLabel: String
  fileprivate let controlStyle: ChatTimelineHistoryControlStyle
  fileprivate let onLoadOlder: () async -> Void

  /// 履歴追加を使用しない設定。
  public static var disabled: Self {
    .init(
      mode: nil,
      canLoadOlder: false,
      isLoading: false,
      anchorID: nil,
      loadOlderLabel: "",
      controlStyle: .plain,
      onLoadOlder: {}
    )
  }

  /// 利用者の操作で履歴を追加する設定を作成する。
  public static func manual(
    canLoadOlder: Bool,
    isLoading: Bool,
    anchorID: ID?,
    loadOlderLabel: String,
    controlStyle: ChatTimelineHistoryControlStyle = .plain,
    onLoadOlder: @escaping () async -> Void
  ) -> Self {
    .init(
      mode: .manual,
      canLoadOlder: canLoadOlder,
      isLoading: isLoading,
      anchorID: anchorID,
      loadOlderLabel: loadOlderLabel,
      controlStyle: controlStyle,
      onLoadOlder: onLoadOlder
    )
  }

  /// 上端への到達時に履歴を自動追加する設定を作成する。
  public static func automatic(
    canLoadOlder: Bool,
    isLoading: Bool,
    anchorID: ID?,
    loadOlderLabel: String,
    controlStyle: ChatTimelineHistoryControlStyle = .plain,
    onLoadOlder: @escaping () async -> Void
  ) -> Self {
    .init(
      mode: .automatic,
      canLoadOlder: canLoadOlder,
      isLoading: isLoading,
      anchorID: anchorID,
      loadOlderLabel: loadOlderLabel,
      controlStyle: controlStyle,
      onLoadOlder: onLoadOlder
    )
  }
}

/// アプリ固有の行を差し込める、チャット向けの汎用タイムライン。
///
/// 初期位置、末尾追従、履歴追加時の位置保持を共通化し、行の内容やページング判断は
/// 利用アプリが所有する。
@MainActor
public struct ChatTimeline<ID: Hashable, FollowTrigger: Equatable, Content: View>: View {
  private let timelineID: AnyHashable
  private let isReadyForInitialPositioning: Bool
  private let initialPosition: ChatTimelineInitialPosition<ID>
  private let followLatestTrigger: FollowTrigger
  private let followLatestAnimation: Animation?
  private let latestFollowingPolicy: ChatTimelineLatestFollowingPolicy
  private let latestProximityThreshold: CGFloat
  private let forceFollowLatest: Bool
  private let latestControl: ChatTimelineLatestControlConfiguration
  private let history: ChatTimelineHistoryConfiguration<ID>
  private let spacing: CGFloat
  private let contentInsets: EdgeInsets
  private let maximumContentWidth: CGFloat?
  private let onInitialPositioning: (ChatTimelineProxy) -> Void
  private let content: (ChatTimelineProxy) -> Content

  @State private var positioningState = ChatTimelinePositioningState<AnyHashable>()
  @State private var bottomAnchorID = ChatTimelineBottomAnchorID()
  @State private var historyCoordinateSpaceID = UUID()
  @State private var historyTopOffset: CGFloat?
  @State private var isHistoryLoadScheduled = false
  @State private var visiblePosition: AnyHashable?
  @State private var visiblePositionAnchor = ChatTimelineScrollAnchor.latest
  @State private var isNearBottom = true
  @State private var showsLatestControl = false
  @State private var viewportHeight: CGFloat = 0
  @State private var bottomOffset: CGFloat?
  @State private var positioningAttempt = 0
  @State private var viewportMeasurement: ChatTimelinePositionMeasurement?
  @State private var bottomMeasurement: ChatTimelinePositionMeasurement?

  /// 汎用タイムラインを作成する。
  ///
  /// 通常起動では`initialPosition`へ`.latest`を、通知などで指定項目を表示するときは
  /// `.item(id)`を渡す。
  public init(
    timelineID: AnyHashable,
    isReadyForInitialPositioning: Bool,
    initialPosition: ChatTimelineInitialPosition<ID> = .latest,
    followLatestTrigger: FollowTrigger,
    followLatestAnimation: Animation? = .easeOut(duration: 0.2),
    latestFollowingPolicy: ChatTimelineLatestFollowingPolicy = .whenNearBottom,
    latestProximityThreshold: CGFloat = 80,
    forceFollowLatest: Bool = false,
    latestControl: ChatTimelineLatestControlConfiguration = .disabled,
    history: ChatTimelineHistoryConfiguration<ID> = .disabled,
    spacing: CGFloat = 12,
    contentInsets: EdgeInsets = EdgeInsets(),
    maximumContentWidth: CGFloat? = nil,
    onInitialPositioning: @escaping (ChatTimelineProxy) -> Void = { _ in },
    @ViewBuilder content: @escaping (ChatTimelineProxy) -> Content
  ) {
    self.timelineID = timelineID
    self.isReadyForInitialPositioning = isReadyForInitialPositioning
    self.initialPosition = initialPosition
    self.followLatestTrigger = followLatestTrigger
    self.followLatestAnimation = followLatestAnimation
    self.latestFollowingPolicy = latestFollowingPolicy
    self.latestProximityThreshold = max(0, latestProximityThreshold)
    self.forceFollowLatest = forceFollowLatest
    self.latestControl = latestControl
    self.history = history
    self.spacing = spacing
    self.contentInsets = contentInsets
    self.maximumContentWidth = maximumContentWidth
    self.onInitialPositioning = onInitialPositioning
    self.content = content
  }

  /// 従来の位置指定引数から汎用タイムラインを作成する。
  @available(
    *,
    deprecated,
    message: "timelineIDとChatTimelineInitialPositionを使用してください。"
  )
  public init(
    positioningScope: AnyHashable,
    isReadyForInitialPositioning: Bool,
    initialTargetID: ID? = nil,
    initialTargetAnchor: UnitPoint = .center,
    followLatestTrigger: FollowTrigger,
    followLatestAnimation: Animation? = .easeOut(duration: 0.2),
    latestFollowingPolicy: ChatTimelineLatestFollowingPolicy = .whenNearBottom,
    latestProximityThreshold: CGFloat = 80,
    forceFollowLatest: Bool = false,
    latestControl: ChatTimelineLatestControlConfiguration = .disabled,
    history: ChatTimelineHistoryConfiguration<ID> = .disabled,
    spacing: CGFloat = 12,
    contentInsets: EdgeInsets = EdgeInsets(),
    maximumContentWidth: CGFloat? = nil,
    onInitialPositioning: @escaping (ChatTimelineProxy) -> Void = { _ in },
    @ViewBuilder content: @escaping (ChatTimelineProxy) -> Content
  ) {
    self.init(
      timelineID: positioningScope,
      isReadyForInitialPositioning: isReadyForInitialPositioning,
      initialPosition: initialTargetID.map {
        .item($0, anchor: initialTargetAnchor)
      } ?? .latest,
      followLatestTrigger: followLatestTrigger,
      followLatestAnimation: followLatestAnimation,
      latestFollowingPolicy: latestFollowingPolicy,
      latestProximityThreshold: latestProximityThreshold,
      forceFollowLatest: forceFollowLatest,
      latestControl: latestControl,
      history: history,
      spacing: spacing,
      contentInsets: contentInsets,
      maximumContentWidth: maximumContentWidth,
      onInitialPositioning: onInitialPositioning,
      content: content
    )
  }

  public var body: some View {
    ScrollViewReader { scrollProxy in
      let timelineProxy = ChatTimelineProxy(
        scrollProxy: scrollProxy,
        bottomAnchorID: bottomAnchorID,
        prepareForProxyPositioning: { visiblePosition = nil }
      )
      GeometryReader { viewport in
        let isViewportReady = ChatTimelineViewportLayout.isReady(viewport.size)
        let contentWidth = ChatTimelineContentLayout.contentWidth(
          viewportWidth: viewport.size.width,
          contentInsets: contentInsets,
          maximumContentWidth: maximumContentWidth
        )
        ScrollView(.vertical) {
          // 末尾anchorだけの遅延生成で空白表示になるのを防ぎ、位置決め前に行高を確定する。
          VStack(spacing: spacing) {
            historyControl(using: timelineProxy)
            content(timelineProxy)
            Color.clear
              .frame(height: 1)
              .id(AnyHashable(bottomAnchorID))
              .background {
                GeometryReader { geometry in
                  Color.clear.preference(
                    key: ChatTimelineBottomOffsetKey.self,
                    value: ChatTimelinePositionMeasurement(
                      attempt: positioningAttempt,
                      value: geometry.frame(in: .named(historyCoordinateSpaceID)).maxY
                    )
                  )
                }
              }
          }
          .scrollTargetLayout()
          .frame(width: contentWidth)
          .padding(contentInsets)
          .frame(width: viewport.size.width)
          #if os(iOS)
            .background {
              ChatTimelineHorizontalPositionGuard(
                isEnabled: isReadyForInitialPositioning && isViewportReady
              )
            }
          #endif
        }
        .coordinateSpace(name: historyCoordinateSpaceID)
        .background {
          GeometryReader { geometry in
            Color.clear.preference(
              key: ChatTimelineViewportHeightKey.self,
              value: ChatTimelinePositionMeasurement(
                attempt: positioningAttempt,
                value: geometry.size.height
              )
            )
          }
        }
        .defaultScrollAnchor(ChatTimelineScrollAnchor.latest)
        .scrollPosition(id: $visiblePosition, anchor: visiblePositionAnchor)
        .overlay(alignment: .bottomTrailing) {
          if latestControl.isEnabled, showsLatestControl {
            Button {
              showsLatestControl = false
              positionLatest(using: timelineProxy, animation: followLatestAnimation)
            } label: {
              Label(latestControl.label, systemImage: latestControl.systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel(latestControl.label)
            .padding(12)
          }
        }
        .onPreferenceChange(ChatTimelineHistoryTopOffsetKey.self) { offset in
          historyTopOffset = offset
          requestAutomaticHistoryIfNeeded(using: timelineProxy)
        }
        .onPreferenceChange(ChatTimelineViewportHeightKey.self) { measurement in
          guard let measurement else { return }
          let previousViewportHeight = viewportHeight
          viewportHeight = measurement.value
          if measurement.attempt == positioningAttempt {
            viewportMeasurement = measurement
          }
          if previousViewportHeight != measurement.value,
            isNearBottom,
            case .latest = initialPosition
          {
            // Composerなどでviewportが変わっても、最新付近なら末尾目標を実ScrollViewへ反映する。
            positionLatest(using: timelineProxy)
          }
          updateLatestProximity()
          completeInitialLatestPositionIfNeeded(using: timelineProxy)
        }
        .onPreferenceChange(ChatTimelineBottomOffsetKey.self) { measurement in
          bottomOffset = measurement?.value
          if measurement?.attempt == positioningAttempt {
            bottomMeasurement = measurement
          }
          guard measurement != nil else {
            // 末尾anchorを画面外で取得できない場合は、過去閲覧中として扱う。
            isNearBottom = false
            return
          }
          updateLatestProximity()
          completeInitialLatestPositionIfNeeded(using: timelineProxy)
        }
        .onChange(of: visiblePosition) { _, position in
          if position == AnyHashable(bottomAnchorID) {
            isNearBottom = true
            showsLatestControl = false
          } else {
            updateLatestProximity()
          }
        }
        .onAppear {
          positionInitiallyIfNeeded(using: timelineProxy, viewportSize: viewport.size)
        }
        .onChange(of: positioningScope) { _, _ in
          positioningState.reset()
          invalidatePositionMeasurements()
          positionInitiallyIfNeeded(using: timelineProxy, viewportSize: viewport.size)
        }
        .onChange(of: isReadyForInitialPositioning) { _, isReady in
          guard isReady else {
            positioningState.cancelInitialPositioning(scope: positioningScope)
            invalidatePositionMeasurements()
            return
          }
          positionInitiallyIfNeeded(using: timelineProxy, viewportSize: viewport.size)
        }
        .onChange(of: viewport.size) { previousSize, size in
          guard
            !ChatTimelineViewportLayout.isReady(previousSize),
            ChatTimelineViewportLayout.isReady(size)
          else { return }
          positionInitiallyIfNeeded(using: timelineProxy, viewportSize: size)
        }
        .onChange(of: followLatestTrigger) { previousTrigger, trigger in
          guard
            positioningState.shouldFollowLatest(
              scope: positioningScope,
              previousTrigger: previousTrigger,
              trigger: trigger
            )
          else { return }
          let shouldFollow = positioningState.shouldFollowLatest(
            isNearBottom: isNearBottom,
            policy: latestFollowingPolicy,
            isForced: forceFollowLatest
          )
          guard shouldFollow else {
            showsLatestControl = true
            return
          }
          showsLatestControl = false
          positionLatest(using: timelineProxy, animation: followLatestAnimation)
          Task { @MainActor in
            await Task.yield()
            guard positioningState.positionedScope == positioningScope else { return }
            positionLatest(using: timelineProxy)
          }
        }
      }
    }
  }

  /// viewportと末尾anchorの距離から最新付近かを更新する。
  private func updateLatestProximity() {
    guard let bottomOffset, viewportHeight > 0 else { return }
    let isNear = ChatTimelineProximity.isNearBottom(
      bottomOffset: bottomOffset,
      viewportHeight: viewportHeight,
      threshold: latestProximityThreshold
    )
    isNearBottom = isNear
    if isNear {
      showsLatestControl = false
    }
  }

  @ViewBuilder
  private func historyControl(using proxy: ChatTimelineProxy) -> some View {
    if history.mode != nil, history.canLoadOlder {
      historyButton(using: proxy)
        .background {
          if history.mode == .automatic {
            GeometryReader { geometry in
              Color.clear.preference(
                key: ChatTimelineHistoryTopOffsetKey.self,
                value: geometry.frame(in: .named(historyCoordinateSpaceID)).minY
              )
            }
          }
        }
    }
  }

  @ViewBuilder
  private func historyButton(using proxy: ChatTimelineProxy) -> some View {
    let button = Button {
      requestHistory(using: proxy)
    } label: {
      if history.isLoading {
        ProgressView()
          .padding(.bottom, history.controlStyle.isBordered ? 4 : 0)
      } else {
        switch history.controlStyle {
        case .plain:
          Text(history.loadOlderLabel)
        case .bordered(let systemImage):
          Label(history.loadOlderLabel, systemImage: systemImage)
        }
      }
    }
    .disabled(history.isLoading || isHistoryLoadScheduled)

    switch history.controlStyle {
    case .plain:
      button
    case .bordered:
      button
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
  }

  private func requestAutomaticHistoryIfNeeded(using proxy: ChatTimelineProxy) {
    guard history.mode == .automatic, historyTopOffset.map({ $0 >= -1 }) == true else { return }
    requestHistory(using: proxy)
  }

  private func requestHistory(using proxy: ChatTimelineProxy) {
    guard
      positioningState.positionedScope == positioningScope,
      history.canLoadOlder,
      !history.isLoading,
      !isHistoryLoadScheduled
    else { return }

    isHistoryLoadScheduled = true
    Task { @MainActor in
      defer { isHistoryLoadScheduled = false }
      if let anchorID = history.anchorID {
        await proxy.preservePosition(at: anchorID) {
          await history.onLoadOlder()
        }
      } else {
        await history.onLoadOlder()
      }
    }
  }

  private func positionInitiallyIfNeeded(
    using proxy: ChatTimelineProxy,
    viewportSize: CGSize
  ) {
    guard
      positioningState.beginInitialPositioning(
        scope: positioningScope,
        isReady: isReadyForInitialPositioning
          && ChatTimelineViewportLayout.isReady(viewportSize)
      )
    else { return }

    let scope = positioningScope
    if case .latest = initialPosition {
      startPositioningAttempt()
    }
    applyInitialPosition(using: proxy)
    Task { @MainActor in
      await waitForInitialLayout()
      guard
        isReadyForInitialPositioning,
        positioningState.pendingScope == scope,
        positioningScope == scope
      else { return }
      applyInitialPosition(using: proxy)
      switch initialPosition {
      case .latest:
        completeInitialLatestPositionIfNeeded(using: proxy)
      case .item:
        // 指定項目は従来どおりProxyで再適用した後に完了する。今回の永続targetはlatestだけに限定する。
        completeInitialPositioning(scope: scope, using: proxy)
      }
    }
  }

  private var positioningScope: AnyHashable {
    AnyHashable(
      ChatTimelinePositioningScope(
        timelineID: timelineID,
        initialPosition: initialPosition
      )
    )
  }

  private func applyInitialPosition(using proxy: ChatTimelineProxy) {
    switch initialPosition {
    case .latest:
      positionLatest(using: proxy)
    case .item(let id, let anchor):
      position(id, anchor: anchor, using: proxy)
    }
  }

  /// 指定項目へ移動し、次の位置監視に使うanchorを更新する。
  private func position(
    _ id: ID,
    anchor: UnitPoint,
    using proxy: ChatTimelineProxy
  ) {
    visiblePositionAnchor = anchor
    visiblePosition = nil
    proxy.scrollTo(id, anchor: anchor)
  }

  /// SwiftUIが末尾anchorを配置できるまで最新位置をscroll targetとして保持する。
  private func positionLatest(
    using proxy: ChatTimelineProxy,
    animation: Animation? = nil
  ) {
    let target = AnyHashable(bottomAnchorID)
    visiblePositionAnchor = ChatTimelineScrollAnchor.latest
    if let animation {
      withAnimation(animation) {
        visiblePosition = target
      }
    } else {
      visiblePosition = target
    }
    proxy.enforceBottomPosition(animation: animation)
  }

  /// 末尾anchorがviewport内へ到達した時点で初期配置を完了する。
  private func completeInitialLatestPositionIfNeeded(using proxy: ChatTimelineProxy) {
    let scope = positioningScope
    guard
      isReadyForInitialPositioning,
      positioningState.pendingScope == scope,
      case .latest = initialPosition,
      let viewportMeasurement,
      let bottomMeasurement,
      viewportMeasurement.attempt == positioningAttempt,
      bottomMeasurement.attempt == positioningAttempt,
      viewportMeasurement.value > 0
    else { return }

    guard
      ChatTimelineProximity.isAtBottom(
        bottomOffset: bottomMeasurement.value,
        viewportHeight: viewportMeasurement.value,
        contentBottomInset: contentInsets.bottom
      )
    else {
      positionLatest(using: proxy)
      return
    }
    completeInitialPositioning(scope: scope, using: proxy)
  }

  /// 初期配置の完了通知と自動履歴読み込みをスコープごとに一度だけ実行する。
  private func completeInitialPositioning(
    scope: AnyHashable,
    using proxy: ChatTimelineProxy
  ) {
    guard
      isReadyForInitialPositioning,
      positioningScope == scope,
      positioningState.completeInitialPositioning(scope: scope)
    else { return }
    onInitialPositioning(proxy)
    guard positioningState.positionedScope == positioningScope else { return }
    requestAutomaticHistoryIfNeeded(using: proxy)
  }

  private func waitForInitialLayout() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        DispatchQueue.main.async {
          continuation.resume()
        }
      }
    }
  }

  private func startPositioningAttempt() {
    positioningAttempt &+= 1
    viewportMeasurement = nil
    bottomMeasurement = nil
  }

  private func invalidatePositionMeasurements() {
    positioningAttempt &+= 1
    viewportMeasurement = nil
    bottomMeasurement = nil
  }
}

struct ChatTimelinePositioningScope<ID: Hashable>: Hashable {
  let timelineID: AnyHashable
  let initialPosition: ChatTimelineInitialPosition<ID>
}

extension ChatTimelineHistoryControlStyle {
  fileprivate var isBordered: Bool {
    if case .bordered = self { return true }
    return false
  }
}

private struct ChatTimelineBottomAnchorID: Hashable {
  let rawValue = UUID()
}

private struct ChatTimelineHistoryTopOffsetKey: PreferenceKey {
  static let defaultValue: CGFloat? = nil

  static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
    value = nextValue() ?? value
  }
}

private struct ChatTimelinePositionMeasurement: Equatable {
  let attempt: Int
  let value: CGFloat
}

private struct ChatTimelineViewportHeightKey: PreferenceKey {
  static let defaultValue: ChatTimelinePositionMeasurement? = nil

  static func reduce(
    value: inout ChatTimelinePositionMeasurement?,
    nextValue: () -> ChatTimelinePositionMeasurement?
  ) {
    value = nextValue() ?? value
  }
}

private struct ChatTimelineBottomOffsetKey: PreferenceKey {
  static let defaultValue: ChatTimelinePositionMeasurement? = nil

  static func reduce(
    value: inout ChatTimelinePositionMeasurement?,
    nextValue: () -> ChatTimelinePositionMeasurement?
  ) {
    value = nextValue() ?? value
  }
}

struct ChatTimelinePositioningState<Scope: Hashable> {
  private(set) var pendingScope: Scope?
  private(set) var positionedScope: Scope?

  mutating func beginInitialPositioning(scope: Scope, isReady: Bool) -> Bool {
    guard isReady, positionedScope != scope, pendingScope != scope else { return false }
    pendingScope = scope
    return true
  }

  mutating func completeInitialPositioning(scope: Scope) -> Bool {
    guard pendingScope == scope else { return false }
    pendingScope = nil
    positionedScope = scope
    return true
  }

  mutating func cancelInitialPositioning(scope: Scope) {
    guard pendingScope == scope else { return }
    pendingScope = nil
  }

  mutating func reset() {
    pendingScope = nil
    positionedScope = nil
  }

  func shouldFollowLatest<Trigger: Equatable>(
    scope: Scope,
    previousTrigger: Trigger,
    trigger: Trigger
  ) -> Bool {
    positionedScope == scope && previousTrigger != trigger
  }

  /// 現在の閲覧位置と方針から、追加された項目へ追従するかを返す。
  func shouldFollowLatest(
    isNearBottom: Bool,
    policy: ChatTimelineLatestFollowingPolicy,
    isForced: Bool
  ) -> Bool {
    isForced || policy == .always || isNearBottom
  }
}
