import SwiftUI

struct ChatTimelineHistoryPosition {
  let id: AnyHashable
  let offset: CGFloat
  let generation: Int
}

extension View {
  /// 履歴を前へ追加するとき、行IDとviewport内の位置を保持するための目印を付ける。
  /// `ChatTimeline`の各行へ、その行の安定したIDを渡す。既存の`.id`も維持する。
  public func chatTimelineItem<ID: Hashable>(_ id: ID) -> some View {
    #if os(iOS)
      background { ChatTimelineHistoryItemMarker(id: AnyHashable(id)) }
    #else
      self
    #endif
  }
}

#if os(iOS)
  import UIKit

  /// SwiftUIの差分が次の描画へ反映されるまで待つ。main queueの空きだけでは旧markerが残る。
  @MainActor
  final class ChatTimelineLayoutFrameWaiter: NSObject {
    private var displayLink: CADisplayLink?
    private var continuation: CheckedContinuation<Void, Never>?
    private var remainingFrames = 2

    func wait() async {
      await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
          guard !Task.isCancelled else {
            continuation.resume()
            return
          }
          self.continuation = continuation
          let link = CADisplayLink(target: self, selector: #selector(didRenderFrame))
          displayLink = link
          link.add(to: .main, forMode: .common)
        }
      } onCancel: {
        Task { @MainActor in self.finish() }
      }
    }

    @objc private func didRenderFrame() {
      remainingFrames -= 1
      if remainingFrames == 0 { finish() }
    }

    private func finish() {
      displayLink?.invalidate()
      displayLink = nil
      let pending = continuation
      continuation = nil
      pending?.resume()
    }
  }

  private struct ChatTimelineHistoryPositionTrackerKey: EnvironmentKey {
    static let defaultValue: ChatTimelineHistoryPositionTracker? = nil
  }

  extension EnvironmentValues {
    var chatTimelineHistoryPositionTracker: ChatTimelineHistoryPositionTracker? {
      get { self[ChatTimelineHistoryPositionTrackerKey.self] }
      set { self[ChatTimelineHistoryPositionTrackerKey.self] = newValue }
    }
  }

  @MainActor
  final class ChatTimelineHistoryPositionTracker {
    // 同じ投稿IDの旧行・新行が差分更新中に共存しても、旧viewの更新で新登録を失わない。
    private var markers: [ObjectIdentifier: WeakMarker] = [:]
    private var generation = 0

    private struct WeakMarker {
      let id: AnyHashable
      weak var view: UIView?
    }

    func register(_ view: UIView, id: AnyHashable) {
      markers[ObjectIdentifier(view)] = WeakMarker(id: id, view: view)
    }

    func invalidatePosition() {
      generation += 1
    }

    func capture() -> ChatTimelineHistoryPosition? {
      markers = markers.filter { $0.value.view != nil }
      let visible = markers.values.compactMap { marker -> (AnyHashable, CGFloat)? in
        guard let view = marker.view, view.window != nil,
          let scrollView = enclosingScrollView(of: view)
        else { return nil }
        let frame = view.convert(view.bounds, to: scrollView)
        guard frame.intersects(scrollView.bounds) else { return nil }
        return (marker.id, frame.minY - scrollView.bounds.minY)
      }
      guard let first = visible.min(by: { $0.1 < $1.1 }) else { return nil }
      return ChatTimelineHistoryPosition(id: first.0, offset: first.1, generation: generation)
    }

    /// 明示scrollが割り込んだ場合は、その操作を優先し古いsnapshotを適用しない。
    func restore(_ position: ChatTimelineHistoryPosition) -> Bool {
      guard position.generation == generation else { return true }
      markers = markers.filter { $0.value.view != nil }
      guard
        let view = markers.values.first(where: {
          $0.id == position.id && $0.view?.window != nil
        })?.view,
        let scrollView = enclosingScrollView(of: view)
      else { return false }
      scrollView.superview?.layoutIfNeeded()
      scrollView.layoutIfNeeded()
      let offset = view.convert(view.bounds, to: scrollView).minY - scrollView.bounds.minY
      let target = scrollView.contentOffset.y + offset - position.offset
      let minimum = -scrollView.adjustedContentInset.top
      let maximum = max(
        minimum,
        scrollView.contentSize.height - scrollView.bounds.height
          + scrollView.adjustedContentInset.bottom)
      scrollView.setContentOffset(
        CGPoint(x: scrollView.contentOffset.x, y: min(maximum, max(minimum, target))),
        animated: false
      )
      return true
    }

    private func enclosingScrollView(of view: UIView) -> UIScrollView? {
      var ancestor = view.superview
      while let current = ancestor {
        if let scrollView = current as? UIScrollView { return scrollView }
        ancestor = current.superview
      }
      return nil
    }
  }

  private struct ChatTimelineHistoryItemMarker: UIViewRepresentable {
    let id: AnyHashable
    @Environment(\.chatTimelineHistoryPositionTracker) private var tracker

    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.isUserInteractionEnabled = false
      view.isAccessibilityElement = false
      tracker?.register(view, id: id)
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
      tracker?.register(uiView, id: id)
    }
  }
#endif
