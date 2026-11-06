package jp.co.altive.chat

import java.time.Instant
import java.time.ZoneId

/** 隣接投稿の表示だけをまとめるための値。 */
data class ChatMessageGroupingItem(
  val senderId: String?,
  val occurredAtEpochMillis: Long,
  val isRegularMessage: Boolean = true,
  val startsNewGroup: Boolean = false,
)

object ChatMessageGrouping {
  fun isContinuation(
    previous: ChatMessageGroupingItem?,
    current: ChatMessageGroupingItem,
    zoneId: ZoneId = ZoneId.systemDefault(),
    maximumIntervalMillis: Long = 300_000,
  ): Boolean {
    if (previous == null || current.senderId.isNullOrEmpty() ||
      previous.senderId != current.senderId || !previous.isRegularMessage ||
      !current.isRegularMessage || current.startsNewGroup) return false
    if (current.occurredAtEpochMillis < previous.occurredAtEpochMillis || maximumIntervalMillis < 0) return false
    // 差のoverflowを避けるため、日時の範囲をInstantで比較する。
    val before = Instant.ofEpochMilli(previous.occurredAtEpochMillis)
    val after = Instant.ofEpochMilli(current.occurredAtEpochMillis)
    return before.atZone(zoneId).toLocalDate() == after.atZone(zoneId).toLocalDate() &&
      java.time.Duration.between(before, after) <= java.time.Duration.ofMillis(maximumIntervalMillis)
  }
}
