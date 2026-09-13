package jp.co.altive.chat

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class ChatImageInputTest {
  @Test
  fun `画像取得元メニューは写真、ファイル、ペーストの順になる`() {
    assertEquals(
      listOf(
        ChatImageInputSource.PhotoLibrary,
        ChatImageInputSource.File,
        ChatImageInputSource.Clipboard,
      ),
      chatImageMenuSourceOrder,
    )
  }

  @Test fun defaultsToFourPickerImages() {
    val configuration = ChatImageInputConfiguration()
    assertEquals(4, configuration.maximumSelectionCount)
  }

  @Test fun rejectsNonPositiveMaximum() {
    assertFailsWith<IllegalArgumentException> {
      ChatImageInputConfiguration(maximumSelectionCount = 0)
    }
  }

  @Test fun calculatesGridCounts() {
    assertEquals(0, ChatImageGridMetrics.visibleCount(-1))
    assertEquals(4, ChatImageGridMetrics.visibleCount(8))
    assertEquals(0, ChatImageGridMetrics.overflowCount(4))
    assertEquals(3, ChatImageGridMetrics.overflowCount(7))
  }

  @Test fun keepsMultiplePickerContractLimitAboveOne() {
    assertEquals(2, multiplePhotoPickerLimit(remainingCapacity = 0, platformMaximum = 1))
    assertEquals(2, multiplePhotoPickerLimit(remainingCapacity = 1, platformMaximum = 50))
    assertEquals(4, multiplePhotoPickerLimit(remainingCapacity = 4, platformMaximum = 50))
    assertEquals(3, multiplePhotoPickerLimit(remainingCapacity = 4, platformMaximum = 3))
  }

  @Test fun `残り枠がある場合だけペースト画像を受け取る`() {
    assertFalse(canReceivePastedImages(remainingCapacity = 0))
    assertFalse(canReceivePastedImages(remainingCapacity = -1))
    assertTrue(canReceivePastedImages(remainingCapacity = 1))
  }

  @Test fun `handlerがある取得元だけを画像メニューへ表示する`() {
    val sources = setOf(
      ChatImageInputSource.Camera,
      ChatImageInputSource.PhotoLibrary,
      ChatImageInputSource.File,
      ChatImageInputSource.Clipboard,
    )
    assertEquals(
      listOf(ChatImageInputSource.PhotoLibrary, ChatImageInputSource.Clipboard),
      menuImageInputSources(
        availableSources = sources,
        hasFileHandler = false,
        hasClipboardHandler = true,
      ),
    )
  }

  @Test fun allowsTextImagesAndBothButRejectsBusyOrOverLimit() {
    assertTrue(canSend("hello", 0))
    assertTrue(canSend("", 1))
    assertTrue(canSend("hello", 2))
    assertFalse(canSend("", 0))
    assertFalse(canSend("hello", 1, isPreparing = true))
    assertFalse(canSend("hello", 1, isSending = true))
    assertFalse(canSend("hello", 5, maximumImageCount = 4))
  }

  private fun canSend(
    draft: String,
    imageCount: Int,
    maximumImageCount: Int? = null,
    isPreparing: Boolean = false,
    isSending: Boolean = false,
  ) = ChatComposerSendPolicy.canSend(
    draft = draft,
    imageCount = imageCount,
    maximumImageCount = maximumImageCount,
    isPreparingImages = isPreparing,
    isSending = isSending,
    draftPolicy = ChatDraftPolicy.Unrestricted,
  )
}
