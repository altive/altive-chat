package jp.co.altive.chat

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch

/** タイムライン項目をviewport内へ配置する位置。 */
enum class ChatTimelineItemAnchor {
  /** viewport先頭。 */
  Start,

  /** viewport中央。 */
  Center,

  /** viewport末尾。 */
  End,
}

/** タイムラインを最初に表示する位置。 */
sealed interface ChatTimelineInitialPosition<out ID> {
  /** 最新項目が見える末尾。 */
  data object Latest : ChatTimelineInitialPosition<Nothing>

  /** 指定項目と配置位置。 */
  data class Item<ID>(
    val id: ID,
    val anchor: ChatTimelineItemAnchor = ChatTimelineItemAnchor.Center,
  ) : ChatTimelineInitialPosition<ID>
}

/** タイムライン上端で履歴を追加する方法。 */
enum class ChatTimelineHistoryLoadingMode {
  /** 利用者の操作で追加する。 */
  Manual,

  /** 上端へ到達したとき自動で追加する。 */
  Automatic,
}

/** 履歴追加操作の外観。 */
enum class ChatTimelineHistoryControlStyle {
  /** テキスト操作。 */
  Plain,

  /** Materialのボタン操作。 */
  Bordered,
}

/** 新着項目を受け取ったときの末尾追従方法。 */
enum class ChatTimelineFollowLatestMode {
  /** 閲覧位置にかかわらず追従する従来動作。 */
  Always,

  /** 末尾付近にいる場合だけ追従する。 */
  WhenNearLatest,

  /** 末尾付近、または呼び出し側が強制追従を指定した場合に追従する。 */
  WhenNearLatestOrForced,
}

/** 新着項目への末尾追従設定。 */
data class ChatTimelineFollowLatestConfiguration(
  val mode: ChatTimelineFollowLatestMode = ChatTimelineFollowLatestMode.WhenNearLatestOrForced,
  /** 末尾から何項目以内を「末尾付近」とみなすか。 */
  val maximumDistanceFromLatestItems: Int = 1,
) {
  init {
    require(maximumDistanceFromLatestItems >= 0) {
      "maximumDistanceFromLatestItems must not be negative"
    }
  }
}

/** タイムラインの履歴追加設定。 */
class ChatTimelineHistoryConfiguration<ID> private constructor(
  internal val mode: ChatTimelineHistoryLoadingMode?,
  internal val canLoadOlder: Boolean,
  internal val isLoading: Boolean,
  internal val anchorId: ID?,
  internal val loadOlderLabel: String,
  internal val controlStyle: ChatTimelineHistoryControlStyle,
  internal val failureMessage: String?,
  internal val retryLabel: String?,
  internal val onLoadOlder: suspend () -> Unit,
) {
  companion object {
    /** 履歴追加を無効にする設定。 */
    fun <ID> disabled(): ChatTimelineHistoryConfiguration<ID> =
      ChatTimelineHistoryConfiguration(null, false, false, null, "", ChatTimelineHistoryControlStyle.Plain, null, null) {}

    /** 手動で履歴を追加する設定を作成する。 */
    fun <ID> manual(
      canLoadOlder: Boolean,
      isLoading: Boolean,
      anchorId: ID? = null,
      loadOlderLabel: String,
      controlStyle: ChatTimelineHistoryControlStyle = ChatTimelineHistoryControlStyle.Plain,
      failureMessage: String? = null,
      retryLabel: String? = null,
      onLoadOlder: suspend () -> Unit,
    ): ChatTimelineHistoryConfiguration<ID> = ChatTimelineHistoryConfiguration(
      ChatTimelineHistoryLoadingMode.Manual,
      canLoadOlder,
      isLoading,
      anchorId,
      loadOlderLabel,
      controlStyle,
      failureMessage,
      retryLabel,
      onLoadOlder,
    )

    /** 上端で自動的に履歴を追加する設定を作成する。 */
    fun <ID> automatic(
      canLoadOlder: Boolean,
      isLoading: Boolean,
      anchorId: ID? = null,
      loadOlderLabel: String,
      controlStyle: ChatTimelineHistoryControlStyle = ChatTimelineHistoryControlStyle.Plain,
      failureMessage: String? = null,
      retryLabel: String? = null,
      onLoadOlder: suspend () -> Unit,
    ): ChatTimelineHistoryConfiguration<ID> = ChatTimelineHistoryConfiguration(
      ChatTimelineHistoryLoadingMode.Automatic,
      canLoadOlder,
      isLoading,
      anchorId,
      loadOlderLabel,
      controlStyle,
      failureMessage,
      retryLabel,
      onLoadOlder,
    )
  }
}

/** 汎用タイムラインのスクロール状態。 */
@Stable
class ChatTimelineState internal constructor(
  /** Composeのリスト状態。 */
  val listState: LazyListState,
) {
  internal var positionedScope: Any? by mutableStateOf(null)
  internal var contentPrefixCount: Int = 0
  internal var latestContentIndex: Int? = null

  /** 初期位置の適用が完了しているか返す。 */
  val hasPositioned: Boolean get() = positionedScope != null

  /** 最新項目が見える末尾へ移動する。 */
  suspend fun scrollToLatest(animated: Boolean = true) {
    val contentIndex = latestContentIndex ?: return
    val index = contentPrefixCount + contentIndex
    if (animated) listState.animateScrollToItem(index) else listState.scrollToItem(index)
  }

  /** 現在の表示位置が最新項目付近か返す。 */
  fun isNearLatest(maximumDistanceFromLatestItems: Int = 1): Boolean {
    val latestIndex = latestContentIndex ?: return true
    val lastVisibleIndex = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index
      ?: return !listState.canScrollForward
    val latestFullIndex = contentPrefixCount + latestIndex
    return latestFullIndex - lastVisibleIndex <= maximumDistanceFromLatestItems
  }
}

/** 汎用タイムラインのスクロール状態を保持する。 */
@Composable
fun rememberChatTimelineState(): ChatTimelineState {
  val listState = rememberLazyListState()
  return remember(listState) { ChatTimelineState(listState) }
}

private data class ChatTimelinePositioningScope<ID>(
  val timelineId: Any,
  val initialPosition: ChatTimelineInitialPosition<ID>,
)

private data class ChatTimelineHistoryAnchor<ID>(
  val id: ID,
  val offset: Int,
)

/**
 * アプリ固有の行を差し込める、チャット向けの汎用タイムライン。
 *
 * 初期位置、末尾追従、履歴追加時の位置保持を共通化し、行の内容やページング判断は
 * 利用アプリが所有する。`itemIndex`と`latestItemIndex`は`content`内の0始まりindexを渡す。
 */
@Composable
fun <ID, FollowTrigger> ChatTimeline(
  timelineId: Any,
  itemIds: List<ID>,
  itemIndex: (ID) -> Int?,
  latestItemIndex: Int?,
  isReadyForInitialPositioning: Boolean,
  initialPosition: ChatTimelineInitialPosition<ID> = ChatTimelineInitialPosition.Latest,
  followLatestTrigger: FollowTrigger,
  followLatestConfiguration: ChatTimelineFollowLatestConfiguration =
    ChatTimelineFollowLatestConfiguration(),
  forceFollowLatest: Boolean = false,
  modifier: Modifier = Modifier,
  state: ChatTimelineState = rememberChatTimelineState(),
  history: ChatTimelineHistoryConfiguration<ID> = ChatTimelineHistoryConfiguration.disabled(),
  contentPadding: PaddingValues = PaddingValues(0.dp),
  verticalArrangement: Arrangement.Vertical = Arrangement.spacedBy(12.dp),
  onInitialPositioning: (ChatTimelineState) -> Unit = {},
  content: LazyListScope.() -> Unit,
) {
  val coroutineScope = rememberCoroutineScope()
  val positioningScope = remember(timelineId, initialPosition) {
    ChatTimelinePositioningScope(timelineId, initialPosition)
  }
  val historyItemCount = if (history.mode != null && history.canLoadOlder) 1 else 0
  val currentItemIndex by rememberUpdatedState(itemIndex)
  val currentHistory by rememberUpdatedState(history)
  val currentItemIds by rememberUpdatedState(itemIds)
  val currentHistoryItemCount by rememberUpdatedState(historyItemCount)
  state.contentPrefixCount = historyItemCount
  state.latestContentIndex = latestItemIndex
  var previousFollowTrigger by remember(timelineId) { mutableStateOf(followLatestTrigger) }
  var previousLatestContentIndex by remember(timelineId) { mutableStateOf(latestItemIndex) }
  var observedPositioningScope by remember(state) { mutableStateOf<Any?>(null) }
  var isHistoryLoadScheduled by remember(timelineId) { mutableStateOf(false) }
  var hasRequestedAutomaticHistory by remember(timelineId) { mutableStateOf(false) }
  var automaticHistoryAnchor by remember(timelineId) { mutableStateOf<ID?>(null) }
  if (previousFollowTrigger == followLatestTrigger) {
    // 履歴追加など、新着以外のindex変化は次の追従判定の基準へ反映する。
    previousLatestContentIndex = latestItemIndex
  }

  suspend fun waitForLayout() {
    withFrameNanos { }
    withFrameNanos { }
  }

  fun fullIndex(id: ID): Int? = currentItemIndex(id)
    ?.takeIf { it >= 0 }
    ?.let { currentHistoryItemCount + it }

  suspend fun positionItem(id: ID, anchor: ChatTimelineItemAnchor) {
    val index = fullIndex(id) ?: return
    state.listState.scrollToItem(index)
    waitForLayout()
    val item = state.listState.layoutInfo.visibleItemsInfo.firstOrNull { it.index == index } ?: return
    val layout = state.listState.layoutInfo
    val offset = when (anchor) {
      ChatTimelineItemAnchor.Start -> 0
      ChatTimelineItemAnchor.Center -> {
        val viewportSize = (layout.viewportEndOffset - layout.viewportStartOffset).coerceAtLeast(0)
        -(layout.viewportStartOffset + ((viewportSize - item.size).coerceAtLeast(0) / 2))
      }
      ChatTimelineItemAnchor.End -> {
        -(layout.viewportEndOffset - item.size).coerceAtLeast(0)
      }
    }
    state.listState.scrollToItem(index, offset)
  }

  suspend fun applyInitialPosition() {
    when (val position = initialPosition) {
      ChatTimelineInitialPosition.Latest -> state.scrollToLatest(animated = false)
      is ChatTimelineInitialPosition.Item -> positionItem(position.id, position.anchor)
    }
  }

  suspend fun requestHistory() {
    val configuration = currentHistory
    if (
      state.positionedScope != positioningScope ||
      !configuration.canLoadOlder ||
      configuration.isLoading ||
      isHistoryLoadScheduled
    ) return

    isHistoryLoadScheduled = true
    hasRequestedAutomaticHistory = true
    automaticHistoryAnchor = configuration.anchorId
    try {
      // 上端controlや独自headerを除いた、実際に見えている最初の投稿を優先する。
      val firstVisibleId = state.listState.layoutInfo.visibleItemsInfo.firstNotNullOfOrNull { item ->
        currentItemIds.firstOrNull { id -> fullIndex(id) == item.index }
      }
      val anchor = (firstVisibleId ?: configuration.anchorId)?.let { id ->
        val index = fullIndex(id)
        val offset = index?.let { target ->
          state.listState.layoutInfo.visibleItemsInfo.firstOrNull { it.index == target }?.offset
        } ?: 0
        ChatTimelineHistoryAnchor(id, offset)
      }
      configuration.onLoadOlder()
      waitForLayout()
      if (anchor != null && state.positionedScope == positioningScope) {
        // LazyListStateのscrollOffsetは項目の表示offsetと符号が逆になる。
        fullIndex(anchor.id)?.let { state.listState.scrollToItem(it, -anchor.offset) }
      }
    } finally {
      isHistoryLoadScheduled = false
    }
  }

  LaunchedEffect(positioningScope, isReadyForInitialPositioning, itemIds) {
    if (observedPositioningScope != positioningScope) {
      observedPositioningScope = positioningScope
      state.positionedScope = null
      previousFollowTrigger = followLatestTrigger
      previousLatestContentIndex = latestItemIndex
    }
    if (!isReadyForInitialPositioning || state.positionedScope == positioningScope) return@LaunchedEffect
    state.positionedScope = positioningScope
    applyInitialPosition()
    waitForLayout()
    if (state.positionedScope == positioningScope) {
      applyInitialPosition()
      onInitialPositioning(state)
    }
  }

  LaunchedEffect(followLatestTrigger) {
    val previous = previousFollowTrigger
    previousFollowTrigger = followLatestTrigger
    if (state.positionedScope != positioningScope || previous == followLatestTrigger) return@LaunchedEffect
    val latestFullIndex = previousLatestContentIndex?.let { state.contentPrefixCount + it }
    val lastVisibleIndex = state.listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index
    val wasNearLatest = latestFullIndex == null || lastVisibleIndex == null ||
      latestFullIndex - lastVisibleIndex <=
      followLatestConfiguration.maximumDistanceFromLatestItems
    previousLatestContentIndex = latestItemIndex
    val shouldFollow = when (followLatestConfiguration.mode) {
      ChatTimelineFollowLatestMode.Always -> true
      ChatTimelineFollowLatestMode.WhenNearLatest -> wasNearLatest
      ChatTimelineFollowLatestMode.WhenNearLatestOrForced -> wasNearLatest || forceFollowLatest
    }
    if (!shouldFollow) return@LaunchedEffect
    state.scrollToLatest(animated = true)
    waitForLayout()
    if (state.positionedScope == positioningScope) state.scrollToLatest(animated = false)
  }

  LaunchedEffect(history.mode, history.canLoadOlder, history.failureMessage, positioningScope) {
    if (history.mode != ChatTimelineHistoryLoadingMode.Automatic) return@LaunchedEffect
    snapshotFlow {
      state.positionedScope == positioningScope &&
        state.listState.firstVisibleItemIndex == 0 &&
        state.listState.firstVisibleItemScrollOffset <= 1
    }
      .distinctUntilChanged()
      .filter { it }
      .collect {
        val configuration = currentHistory
        if (configuration.failureMessage == null &&
          (!hasRequestedAutomaticHistory || automaticHistoryAnchor != configuration.anchorId)
        ) {
          // 取得可否・失敗状態によるeffect再起動で、復元前の取得jobを取消さない。
          coroutineScope.launch { requestHistory() }
        }
      }
  }

  LazyColumn(
    state = state.listState,
    modifier = modifier.fillMaxSize(),
    contentPadding = contentPadding,
    verticalArrangement = verticalArrangement,
  ) {
    if (historyItemCount == 1) {
      item(key = "AltiveChatUI.HistoryControl") {
        Column {
          if (history.failureMessage != null) Text(history.failureMessage)
          val historyLabel = if (history.failureMessage == null) history.loadOlderLabel
            else history.retryLabel ?: history.loadOlderLabel
          val loading = history.isLoading || isHistoryLoadScheduled
          // ボタンの測定は残す。文字拡大・改行を含め、spinner切替で行高を変えない。
          val controlModifier = Modifier.alpha(if (loading) 0f else 1f).then(
            if (loading) Modifier.clearAndSetSemantics {}
            else Modifier.testTag("AltiveChatUI.HistoryControl"),
          )
          Box(contentAlignment = Alignment.Center) {
            when (history.controlStyle) {
              ChatTimelineHistoryControlStyle.Bordered -> OutlinedButton(
                onClick = { coroutineScope.launch { requestHistory() } },
                enabled = !loading,
                modifier = controlModifier,
              ) { Text(historyLabel) }
              ChatTimelineHistoryControlStyle.Plain -> TextButton(
                onClick = { coroutineScope.launch { requestHistory() } },
                enabled = !loading,
                modifier = controlModifier,
              ) { Text(historyLabel) }
            }
            if (loading) CircularProgressIndicator()
          }
        }
      }
    }
    content()
  }
}
