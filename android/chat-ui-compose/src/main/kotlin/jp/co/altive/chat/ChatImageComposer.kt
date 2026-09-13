package jp.co.altive.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.content.MediaType
import androidx.compose.foundation.content.TransferableContent
import androidx.compose.foundation.content.consume
import androidx.compose.foundation.content.contentReceiver
import androidx.compose.foundation.content.hasMediaType
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

internal fun shouldShowChatComposerSourceButtons(
  isFocused: Boolean,
): Boolean = !isFocused

@Composable
@OptIn(ExperimentalFoundationApi::class)
fun ChatImageComposer(
  draft: String,
  onDraftChange: (String) -> Unit,
  imageDrafts: List<ChatImageDraft>,
  configuration: ChatImageInputConfiguration,
  availableImageInputSources: Set<ChatImageInputSource>,
  isPreparingImages: Boolean,
  isPreparingCameraImage: Boolean,
  isSending: Boolean,
  strings: ChatRoomStrings,
  draftPolicy: ChatDraftPolicy,
  theme: ChatRoomTheme,
  onRequestCamera: () -> Unit,
  onRequestPhotoLibrary: () -> Unit,
  onRemoveImage: (String) -> Unit,
  onSubmit: () -> Unit,
  imageContent: @Composable BoxScope.(ChatImage) -> Unit,
  additionalSourceContent: (@Composable () -> Unit)? = null,
  focusRequester: FocusRequester = remember { FocusRequester() },
  /** 選択画像と入力欄の間へ表示するdraftリンクプレビュー。 */
  linkPreviewContent: @Composable () -> Unit = {},
  onRequestFile: (() -> Unit)? = null,
  onRequestClipboard: (() -> Unit)? = null,
  onReceiveImageUris: ((List<String>) -> Unit)? = null,
) {
  val canSend = ChatComposerSendPolicy.canSend(
    draft = draft,
    imageCount = imageDrafts.size,
    maximumImageCount = configuration.maximumSelectionCount,
    isPreparingImages = isPreparingImages,
    isSending = isSending,
    draftPolicy = draftPolicy,
  )
  var isComposerFocused by remember { mutableStateOf(false) }
  val focusManager = LocalFocusManager.current
  val keyboardController = LocalSoftwareKeyboardController.current
  val menuImageInputSources = menuImageInputSources(
    availableSources = availableImageInputSources,
    hasFileHandler = onRequestFile != null,
    hasClipboardHandler = onRequestClipboard != null,
  )
  val hasSourceButtons = additionalSourceContent != null || availableImageInputSources.isNotEmpty()
  val showsSourceButtons = shouldShowChatComposerSourceButtons(
    isFocused = isComposerFocused,
  )
  Column(
    Modifier.fillMaxWidth()
      .background(MaterialTheme.colorScheme.surface)
      .padding(horizontal = 16.dp, vertical = 10.dp),
    horizontalAlignment = Alignment.End,
    verticalArrangement = Arrangement.spacedBy(7.dp),
  ) {
    if (imageDrafts.isNotEmpty() || isPreparingImages) {
      Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
      ) {
        imageDrafts.forEach { draftImage ->
          Box(Modifier.size(76.dp)) {
            ChatImageTile(
              image = draftImage.previewImage,
              imageLabel = strings.imageLabel,
              modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(10.dp)),
              imageContent = imageContent,
            )
            IconButton(
              onClick = { onRemoveImage(draftImage.id) },
              modifier = Modifier.align(Alignment.TopEnd).size(32.dp)
                .semantics { contentDescription = strings.removeImageButtonLabel },
            ) {
              Icon(Icons.Default.Close, contentDescription = null)
            }
          }
        }
        if (isPreparingImages) {
          Box(
            Modifier.size(76.dp)
              .background(MaterialTheme.colorScheme.surfaceContainerHighest, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center,
          ) {
            CircularProgressIndicator(Modifier.size(22.dp))
          }
        }
      }
    }

    linkPreviewContent()

    Row(
      verticalAlignment = Alignment.Bottom,
      horizontalArrangement = Arrangement.spacedBy(7.dp),
    ) {
      if (hasSourceButtons) {
        if (showsSourceButtons) {
          Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) {
            additionalSourceContent?.invoke()
            if (ChatImageInputSource.Camera in availableImageInputSources) {
              IconButton(
                onClick = onRequestCamera,
                enabled = imageDrafts.size < configuration.maximumSelectionCount &&
                  !isPreparingCameraImage,
                modifier = Modifier.size(44.dp)
                  .semantics { contentDescription = strings.cameraButtonLabel },
              ) {
                if (isPreparingCameraImage) CircularProgressIndicator(Modifier.size(18.dp))
                else Icon(Icons.Default.CameraAlt, contentDescription = null)
              }
            }
            if (menuImageInputSources.isNotEmpty()) {
              ChatImageSourceMenu(
                availableImageInputSources = menuImageInputSources,
                enabled = imageDrafts.size < configuration.maximumSelectionCount,
                strings = strings,
                onRequestPhotoLibrary = onRequestPhotoLibrary,
                onRequestFile = onRequestFile,
                onRequestClipboard = onRequestClipboard,
              )
            }
          }
        } else {
          IconButton(
            onClick = {
              isComposerFocused = false
              focusManager.clearFocus(force = true)
              keyboardController?.hide()
            },
            modifier = Modifier.size(44.dp)
              .testTag("AltiveChatUI.ExpandSourceButtons")
              .semantics { contentDescription = strings.expandSourceButtonsLabel },
          ) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
          }
        }
      }

      BasicTextField(
        value = draft,
        onValueChange = { onDraftChange(draftPolicy.limited(it)) },
        modifier = Modifier.weight(1f)
          .background(theme.composerField, RoundedCornerShape(24.dp))
          .testTag("AltiveChatUI.Composer")
          .focusRequester(focusRequester)
          .onFocusChanged { focusState ->
            isComposerFocused = focusState.isFocused
          }
          .contentReceiver { content ->
            content.consumeImageUris(onReceiveImageUris)
          }
          .padding(horizontal = 14.dp, vertical = 12.dp),
        textStyle = MaterialTheme.typography.bodyLarge.copy(
          color = MaterialTheme.colorScheme.onSurface,
        ),
        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
        decorationBox = { inner ->
          if (draft.isEmpty()) {
            Text(strings.messagePlaceholder, color = MaterialTheme.colorScheme.onSurfaceVariant)
          }
          inner()
        },
      )

      IconButton(
        onClick = onSubmit,
        enabled = canSend,
        modifier = Modifier.size(42.dp)
          .testTag("AltiveChatUI.SendButton")
          .clip(CircleShape)
          .background(theme.sendButtonBackground)
          .semantics { contentDescription = strings.sendButtonLabel },
      ) {
        if (isPreparingImages || isSending) {
          CircularProgressIndicator(Modifier.size(20.dp), color = theme.sendButtonForeground)
        } else {
          Icon(
            Icons.AutoMirrored.Filled.Send,
            contentDescription = null,
            tint = theme.sendButtonForeground,
          )
        }
      }
    }

    if (draftPolicy.shouldShowLength(draft) && draftPolicy.maximumLength != null) {
      Text(
        "${draftPolicy.length(draft)}/${draftPolicy.maximumLength}",
        style = MaterialTheme.typography.labelSmall,
      )
    }

  }
}

@Composable
private fun ChatImageSourceMenu(
  availableImageInputSources: Collection<ChatImageInputSource>,
  enabled: Boolean,
  strings: ChatRoomStrings,
  onRequestPhotoLibrary: () -> Unit,
  onRequestFile: (() -> Unit)?,
  onRequestClipboard: (() -> Unit)?,
) {
  var expanded by remember { mutableStateOf(false) }
  Box {
    IconButton(
      onClick = { expanded = true },
      enabled = enabled,
      modifier = Modifier.size(44.dp)
        .testTag("AltiveChatUI.ImageSourceMenuButton")
        .semantics { contentDescription = strings.imageSourceMenuButtonLabel },
    ) {
      Icon(Icons.Default.PhotoLibrary, contentDescription = null)
    }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
      if (ChatImageInputSource.PhotoLibrary in availableImageInputSources) {
        DropdownMenuItem(
          text = { Text(strings.photoLibraryButtonLabel) },
          leadingIcon = { Icon(Icons.Default.PhotoLibrary, contentDescription = null) },
          onClick = {
            expanded = false
            onRequestPhotoLibrary()
          },
        )
      }
      if (ChatImageInputSource.File in availableImageInputSources) {
        DropdownMenuItem(
          text = { Text(strings.fileButtonLabel) },
          leadingIcon = { Icon(Icons.Default.Folder, contentDescription = null) },
          onClick = {
            expanded = false
            onRequestFile?.invoke()
          },
        )
      }
      if (ChatImageInputSource.Clipboard in availableImageInputSources) {
        DropdownMenuItem(
          text = { Text(strings.clipboardButtonLabel) },
          leadingIcon = { Icon(Icons.Default.ContentPaste, contentDescription = null) },
          onClick = {
            expanded = false
            onRequestClipboard?.invoke()
          },
        )
      }
    }
  }
}

@OptIn(ExperimentalFoundationApi::class)
private fun TransferableContent.consumeImageUris(
  onReceiveImageUris: ((List<String>) -> Unit)?,
): TransferableContent? {
  if (onReceiveImageUris == null || !hasMediaType(MediaType.Image)) return this

  val imageUris = mutableListOf<String>()
  val remainingContent = consume { item ->
    val uri = item.uri ?: return@consume false
    imageUris += uri.toString()
    true
  }
  if (imageUris.isNotEmpty()) onReceiveImageUris(imageUris)
  return remainingContent
}
