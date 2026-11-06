package jp.co.altive.chat

import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ChatMessageGroupingTest {
  @Test fun `同一送信者の同日5分以内だけをまとめる`() {
    val zone = ZoneId.of("UTC")
    val first = ChatMessageGroupingItem("a", 1_700_006_400_000)
    for (delta in listOf(0L, 299_000L, 300_000L)) {
      assertTrue(ChatMessageGrouping.isContinuation(first, first.copy(occurredAtEpochMillis = first.occurredAtEpochMillis + delta), zone))
    }
    for (candidate in listOf(
      first.copy(occurredAtEpochMillis = first.occurredAtEpochMillis - 1),
      first.copy(occurredAtEpochMillis = first.occurredAtEpochMillis + 300_001),
      first.copy(senderId = "b"), first.copy(senderId = null), first.copy(senderId = ""),
      first.copy(isRegularMessage = false), first.copy(startsNewGroup = true),
    )) assertFalse(ChatMessageGrouping.isContinuation(first, candidate, zone))
    assertFalse(ChatMessageGrouping.isContinuation(null, first, zone))
    assertFalse(ChatMessageGrouping.isContinuation(first.copy(isRegularMessage = false), first, zone))
    assertFalse(ChatMessageGrouping.isContinuation(ChatMessageGroupingItem("a", 86_399_000), ChatMessageGroupingItem("a", 86_400_000), zone))
  }
}
