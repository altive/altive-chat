package jp.co.altive.chat

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/** 対象、変化、操作主体、詳細の順で表示する。業務値は呼び出し側が解決する。 */
@Composable
fun ChatSystemEventSummary(
  title: String,
  value: String,
  metadata: String,
  details: String? = null,
  modifier: Modifier = Modifier,
) {
  Column(modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(6.dp)) {
    Text(title, style = MaterialTheme.typography.titleSmall, textAlign = TextAlign.Start)
    if (value.isNotBlank()) Text(value, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Start)
    Text(metadata, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Start)
    if (details != null) Text(details, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Start)
  }
}
