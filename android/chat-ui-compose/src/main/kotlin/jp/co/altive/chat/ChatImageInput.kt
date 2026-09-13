package jp.co.altive.chat

/** 入力欄へ表示できる画像取得元。 */
enum class ChatImageInputSource { Camera, PhotoLibrary, File, Clipboard }

/** 複数画像入力の表示設定。 */
data class ChatImageInputConfiguration(
  val maximumSelectionCount: Int = 4,
) {
  init {
    require(maximumSelectionCount > 0) { "maximumSelectionCount must be greater than zero" }
  }
}

object ChatImageGridMetrics {
  fun visibleCount(imageCount: Int): Int = imageCount.coerceIn(0, 4)

  fun overflowCount(imageCount: Int): Int = (imageCount - 4).coerceAtLeast(0)
}

object ChatComposerSendPolicy {
  fun canSend(
    draft: String,
    imageCount: Int,
    maximumImageCount: Int? = null,
    isPreparingImages: Boolean,
    isSending: Boolean,
    draftPolicy: ChatDraftPolicy,
  ): Boolean {
    val isWithinImageLimit = maximumImageCount?.let { imageCount <= it } ?: true
    return !isPreparingImages &&
      !isSending &&
      isWithinImageLimit &&
      (draftPolicy.normalizedText(draft) != null || imageCount > 0)
  }
}

internal fun multiplePhotoPickerLimit(remainingCapacity: Int, platformMaximum: Int): Int =
  remainingCapacity.coerceAtLeast(2).coerceAtMost(platformMaximum.coerceAtLeast(2))

internal fun canReceivePastedImages(remainingCapacity: Int): Boolean = remainingCapacity > 0

internal val chatImageMenuSourceOrder = listOf(
  ChatImageInputSource.PhotoLibrary,
  ChatImageInputSource.File,
  ChatImageInputSource.Clipboard,
)

internal fun menuImageInputSources(
  availableSources: Set<ChatImageInputSource>,
  hasFileHandler: Boolean,
  hasClipboardHandler: Boolean,
): List<ChatImageInputSource> = chatImageMenuSourceOrder.filter { source ->
  source in availableSources && when (source) {
    ChatImageInputSource.Camera -> false
    ChatImageInputSource.PhotoLibrary -> true
    ChatImageInputSource.File -> hasFileHandler
    ChatImageInputSource.Clipboard -> hasClipboardHandler
  }
}
