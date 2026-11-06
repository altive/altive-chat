package jp.co.altive.chat

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlin.math.abs
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ChatTimelineTest {
  @get:Rule val compose = createComposeRule()

  @Test
  fun `通常起動では実LazyColumnを末尾へ配置する`() {
    lateinit var timelineState: ChatTimelineState
    compose.setContent {
      timelineState = rememberChatTimelineState()
      MaterialTheme {
        Box(Modifier.height(200.dp)) {
          TestTimeline(state = timelineState, initialPosition = ChatTimelineInitialPosition.Latest)
        }
      }
    }

    compose.waitForIdle()
    compose.runOnIdle {
      assertFalse(timelineState.listState.canScrollForward)
      assertEquals(19, timelineState.listState.layoutInfo.visibleItemsInfo.last().index)
    }
  }

  @Test
  fun `指定項目を実LazyColumnの中央へ配置する`() {
    lateinit var timelineState: ChatTimelineState
    compose.setContent {
      timelineState = rememberChatTimelineState()
      MaterialTheme {
        Box(Modifier.height(200.dp)) {
          TestTimeline(
            state = timelineState,
            initialPosition = ChatTimelineInitialPosition.Item(10),
          )
        }
      }
    }

    compose.waitForIdle()
    compose.runOnIdle {
      val layout = timelineState.listState.layoutInfo
      val item = checkNotNull(layout.visibleItemsInfo.firstOrNull { it.index == 10 })
      val viewportCenter = (layout.viewportStartOffset + layout.viewportEndOffset) / 2
      assertTrue(abs((item.offset + item.size / 2) - viewportCenter) < 4)
    }
  }

  @Test
  fun `履歴追加後も実LazyColumnで基準項目の位置を維持する`() {
    lateinit var timelineState: ChatTimelineState
    var items by mutableStateOf((0 until 20).toList())
    compose.setContent {
      timelineState = rememberChatTimelineState()
      MaterialTheme {
        Box(Modifier.height(200.dp)) {
          ChatTimeline(
            timelineId = "history-test",
            itemIds = items,
            itemIndex = items::indexOf,
            latestItemIndex = items.lastIndex,
            isReadyForInitialPositioning = true,
            initialPosition = ChatTimelineInitialPosition.Item(0, ChatTimelineItemAnchor.Start),
            followLatestTrigger = 0,
            state = timelineState,
            history = ChatTimelineHistoryConfiguration.manual(
              canLoadOlder = true,
              isLoading = false,
              anchorId = 0,
              loadOlderLabel = "履歴を読み込む",
              onLoadOlder = { items = (-5 until 0).toList() + items },
            ),
          ) {
            items(items, key = { it }) { id -> TimelineTestItem(id) }
          }
        }
      }
    }

    compose.waitForIdle()
    compose.runOnIdle {
      runBlocking { timelineState.listState.scrollToItem(0) }
    }
    compose.waitForIdle()
    val previousOffset = compose.runOnIdle {
      checkNotNull(timelineState.listState.layoutInfo.visibleItemsInfo.firstOrNull { it.key == 0 }).offset
    }

    compose.onNodeWithTag("AltiveChatUI.HistoryControl").performClick()
    compose.waitForIdle()

    compose.runOnIdle {
      val anchor = checkNotNull(timelineState.listState.layoutInfo.visibleItemsInfo.firstOrNull { it.key == 0 })
      assertEquals(previousOffset, anchor.offset)
      assertEquals(25, items.size)
    }
  }

  @Test
  fun `自動履歴の失敗後は明示再試行まで取得を繰り返さない`() {
    lateinit var timelineState: ChatTimelineState
    var failure by mutableStateOf<String?>(null)
    var attempts = 0
    val items = (0 until 20).toList()
    compose.setContent {
      timelineState = rememberChatTimelineState()
      MaterialTheme {
        Box(Modifier.height(200.dp)) {
          ChatTimeline(
            timelineId = "history-retry",
            itemIds = items,
            itemIndex = items::indexOf,
            latestItemIndex = items.lastIndex,
            isReadyForInitialPositioning = true,
            followLatestTrigger = 0,
            state = timelineState,
            history = ChatTimelineHistoryConfiguration.automatic(
              canLoadOlder = true,
              isLoading = false,
              anchorId = 0,
              loadOlderLabel = "履歴を読み込む",
              failureMessage = failure,
              retryLabel = "再試行",
              onLoadOlder = {
                attempts += 1
                failure = "履歴を取得できませんでした"
              },
            ),
          ) {
            items(items, key = { it }) { id -> TimelineTestItem(id) }
          }
        }
      }
    }
    compose.waitForIdle()
    compose.runOnIdle { runBlocking { timelineState.listState.scrollToItem(0) } }
    compose.waitForIdle()
    compose.runOnIdle { assertEquals(1, attempts) }
    compose.onNodeWithText("再試行").performClick()
    compose.waitForIdle()
    compose.runOnIdle { assertEquals(2, attempts) }
  }

  @Test
  fun `過去を閲覧中の新着では末尾へ移動しない`() {
    lateinit var timelineState: ChatTimelineState
    var items by mutableStateOf((0 until 20).toList())
    compose.setContent {
      timelineState = rememberChatTimelineState()
      MaterialTheme {
        Box(Modifier.height(200.dp)) {
          ChatTimeline(
            timelineId = "follow-near-latest",
            itemIds = items,
            itemIndex = items::indexOf,
            latestItemIndex = items.lastIndex,
            isReadyForInitialPositioning = true,
            followLatestTrigger = items.last(),
            followLatestConfiguration = ChatTimelineFollowLatestConfiguration(
              mode = ChatTimelineFollowLatestMode.WhenNearLatestOrForced,
            ),
            state = timelineState,
          ) {
            items(items, key = { it }) { id -> TimelineTestItem(id) }
          }
        }
      }
    }

    compose.waitForIdle()
    compose.runOnIdle { runBlocking { timelineState.listState.scrollToItem(0) } }
    compose.waitForIdle()
    compose.runOnIdle { items = items + 20 }
    compose.waitForIdle()

    compose.runOnIdle {
      assertTrue(timelineState.listState.canScrollForward)
      assertFalse(timelineState.listState.layoutInfo.visibleItemsInfo.any { it.key == 20 })
    }
  }

  @Test
  fun `過去を閲覧中でも強制指定した新着は末尾へ移動する`() {
    lateinit var timelineState: ChatTimelineState
    var items by mutableStateOf((0 until 20).toList())
    var forceFollow by mutableStateOf(false)
    compose.setContent {
      timelineState = rememberChatTimelineState()
      MaterialTheme {
        Box(Modifier.height(200.dp)) {
          ChatTimeline(
            timelineId = "follow-forced",
            itemIds = items,
            itemIndex = items::indexOf,
            latestItemIndex = items.lastIndex,
            isReadyForInitialPositioning = true,
            followLatestTrigger = items.last(),
            followLatestConfiguration = ChatTimelineFollowLatestConfiguration(
              mode = ChatTimelineFollowLatestMode.WhenNearLatestOrForced,
            ),
            forceFollowLatest = forceFollow,
            state = timelineState,
          ) {
            items(items, key = { it }) { id -> TimelineTestItem(id) }
          }
        }
      }
    }

    compose.waitForIdle()
    compose.runOnIdle { runBlocking { timelineState.listState.scrollToItem(0) } }
    compose.waitForIdle()
    compose.runOnIdle {
      forceFollow = true
      items = items + 20
    }
    compose.waitForIdle()

    compose.runOnIdle {
      assertFalse(timelineState.listState.canScrollForward)
      assertTrue(timelineState.listState.layoutInfo.visibleItemsInfo.any { it.key == 20 })
    }
  }

  @Composable
  private fun TestTimeline(
    state: ChatTimelineState,
    initialPosition: ChatTimelineInitialPosition<Int>,
  ) {
    val items = remember { (0 until 20).toList() }
    ChatTimeline(
      timelineId = "test",
      itemIds = items,
      itemIndex = items::indexOf,
      latestItemIndex = items.lastIndex,
      isReadyForInitialPositioning = true,
      initialPosition = initialPosition,
      followLatestTrigger = 0,
      state = state,
    ) {
      items(items, key = { it }) { id -> TimelineTestItem(id) }
    }
  }

  @Composable
  private fun TimelineTestItem(id: Int) {
    Text(
      text = "項目$id",
      modifier = Modifier.fillMaxWidth().height(40.dp).testTag("item-$id"),
    )
  }
}
