import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'chat_link_preview_card.dart';
import 'chat_link_preview_scope.dart';
import 'chat_reply_scope.dart';
import 'common_cached_network_image.dart';
import 'extension.dart';
import 'inherited_altive_chat_room_theme.dart';
import 'message_link.dart';
import 'models.dart';
import 'popup_menu_overlay.dart';

/// {@template altive_chat_room.UserMessageBubble}
/// [ChatUserMessage]を表示するWidget。
///
/// ユーザーメッセージの内容に応じてバブル表示を切り替える。
/// {@endtemplate}
class UserMessageBubble extends StatelessWidget {
  /// {@macro altive_chat_room.UserMessageBubble}
  const UserMessageBubble({
    super.key,
    required this.currentUserId,
    required this.message,
    required this.selectableTextMessageId,
    required this.contextMenuBuilder,
    required this.onImageMessageTap,
    required this.onImageTap,
    required this.onStickerMessageTap,
    required this.onActionButtonTap,
    required this.popupMenuLayoutForText,
    required this.popupMenuLayoutForImage,
    required this.popupMenuLayoutForSticker,
    required this.popupMenuLayoutForVoiceCall,
    required this.popupMenuAccessoryBuilder,
    required this.imageLayoutConfiguration,
    this.popupMenuEnabled = true,
  });

  /// ログイン中ユーザーの ID。
  final String currentUserId;

  /// 表示対象のユーザーメッセージ。
  final ChatUserMessage message;

  /// テキスト選択を有効化するメッセージ ID。
  final String? selectableTextMessageId;

  /// テキスト選択時のコンテキストメニュー構築処理。
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// 画像メッセージタップ時のコールバック。
  final ImageMessageTapCallback? onImageMessageTap;

  /// 画像タップ時にメッセージIDと位置を通知するコールバック。
  final ChatImageTapCallback? onImageTap;

  /// ステッカーメッセージタップ時のコールバック。
  final ValueChanged<ChatStickerMessage>? onStickerMessageTap;

  /// テキスト内アクションボタンタップ時のコールバック。
  final ValueChanged<Object?>? onActionButtonTap;

  /// テキストメッセージ用ポップアップメニューレイアウト。
  final PopupMenuLayout? popupMenuLayoutForText;

  /// 画像メッセージ用ポップアップメニューレイアウト。
  final PopupMenuLayout? popupMenuLayoutForImage;

  /// ステッカーメッセージ用ポップアップメニューレイアウト。
  final PopupMenuLayout? popupMenuLayoutForSticker;

  /// 通話メッセージ用ポップアップメニューレイアウト。
  final PopupMenuLayout? popupMenuLayoutForVoiceCall;

  /// ポップアップメニュー付属領域の構築処理。
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;

  /// 画像メッセージのレイアウト設定。
  final ChatImageLayoutConfiguration imageLayoutConfiguration;

  /// ポップアップメニューを有効化するかどうか。
  final bool popupMenuEnabled;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * .75),
      child: switch (message) {
        ChatTextMessage() => _TextMessageBubble(
          currentUserId: currentUserId,
          message: message,
          canSelect: message.id == selectableTextMessageId,
          contextMenuBuilder: contextMenuBuilder,
          onActionButtonTap: onActionButtonTap,
          popupMenuLayout: popupMenuLayoutForText,
          popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
          popupMenuEnabled: popupMenuEnabled,
        ),
        ChatImagesMessage() => _ImagesMessageBubble(
          currentUserId: currentUserId,
          message: message,
          onImageMessageTap: onImageMessageTap,
          onImageTap: onImageTap,
          popupMenuLayout: popupMenuLayoutForImage,
          popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
          popupMenuEnabled: popupMenuEnabled,
          imageLayoutConfiguration: imageLayoutConfiguration,
        ),
        ChatStickerMessage() => StickerMessageBubble(
          currentUserId: currentUserId,
          message: message,
          onStickerMessageTap: onStickerMessageTap,
          popupMenuLayout: popupMenuLayoutForSticker,
          popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
          popupMenuEnabled: popupMenuEnabled,
        ),
        ChatVoiceCallMessage() => _VoiceCallMessageBubble(
          currentUserId: currentUserId,
          message: message,
          popupMenuLayout: popupMenuLayoutForVoiceCall,
          popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
          popupMenuEnabled: popupMenuEnabled,
        ),
      },
    );
  }
}

/// [ChatTextMessage]を表示するWidget。
class _TextMessageBubble extends StatelessWidget {
  const _TextMessageBubble({
    required this.currentUserId,
    required this.message,
    required this.canSelect,
    required this.contextMenuBuilder,
    required this.onActionButtonTap,
    required this.popupMenuLayout,
    required this.popupMenuAccessoryBuilder,
    required this.popupMenuEnabled,
  });

  final String currentUserId;
  final ChatTextMessage message;
  final bool canSelect;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final ValueChanged<Object?>? onActionButtonTap;
  final PopupMenuLayout? popupMenuLayout;
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;
  final bool popupMenuEnabled;

  @override
  Widget build(BuildContext context) {
    final popupMenuLayout = this.popupMenuLayout;
    if (!popupMenuEnabled || popupMenuLayout == null) {
      return _TextMessageBubbleContents(
        currentUserId: currentUserId,
        message: message,
        canSelect: canSelect,
        contextMenuBuilder: contextMenuBuilder,
        onActionButtonTap: onActionButtonTap,
      );
    }

    // ポップアップメニューを表示する為のキーを生成する。
    final widgetKey = GlobalObjectKey(context);

    final config = InheritedAltiveChatRoomTheme.of(
      context,
    ).theme.popupMenuConfig;
    // ポップアップメニューが設定されている場合、表示する為の `GestureDetector` を追加する。
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => PopupMenuOverlay(
        layout: popupMenuLayout,
        userMessage: message,
        config: config,
        widgetKey: widgetKey,
        popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
      ).show(context: context),
      child: _TextMessageBubbleContents(
        widgetKey: widgetKey,
        currentUserId: currentUserId,
        message: message,
        canSelect: canSelect,
        contextMenuBuilder: contextMenuBuilder,
        onActionButtonTap: onActionButtonTap,
      ),
    );
  }
}

class _TextMessageBubbleContents extends StatelessWidget {
  const _TextMessageBubbleContents({
    this.widgetKey,
    required this.currentUserId,
    required this.message,
    required this.canSelect,
    required this.contextMenuBuilder,
    required this.onActionButtonTap,
  });

  final GlobalObjectKey? widgetKey;
  final String currentUserId;
  final ChatTextMessage message;
  final bool canSelect;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final ValueChanged<Object?>? onActionButtonTap;

  @override
  Widget build(BuildContext context) {
    final altiveChatRoomTheme = InheritedAltiveChatRoomTheme.of(context).theme;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(10);

    final isOutgoing = message.isOutgoing(currentUserId: currentUserId);

    final outgoingMessageBoxDecoration = message.highlight
        ? altiveChatRoomTheme.outgoingMessageHighlightBoxDecoration ??
              BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: borderRadius,
                color: theme.highlightColor,
              )
        : altiveChatRoomTheme.outgoingMessageBoxDecoration ??
              BoxDecoration(
                borderRadius: borderRadius,
                color: theme.primaryColor,
              );
    final incomingMessageBoxDecoration = message.highlight
        ? altiveChatRoomTheme.incomingMessageHighlightBoxDecoration ??
              BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: borderRadius,
                color: theme.highlightColor,
              )
        : altiveChatRoomTheme.incomingMessageBoxDecoration ??
              BoxDecoration(
                borderRadius: borderRadius,
                color: colorScheme.surfaceContainerHighest,
              );
    final decoration = isOutgoing
        ? outgoingMessageBoxDecoration
        : incomingMessageBoxDecoration;

    final outgoingMessageTextStyle = message.highlight
        ? altiveChatRoomTheme.outgoingMessageHighlightTextStyle ??
              theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)
        : altiveChatRoomTheme.outgoingMessageTextStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary,
              );
    final incomingMessageTextStyle = message.highlight
        ? altiveChatRoomTheme.incomingHighlightMessageTextStyle ??
              theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)
        : altiveChatRoomTheme.incomingMessageTextStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              );
    final textStyle = isOutgoing
        ? outgoingMessageTextStyle
        : incomingMessageTextStyle;
    final textStyleColor = textStyle?.color;

    final outgoingEmojiMessageTextStyle =
        altiveChatRoomTheme.outgoingEmojiMessageTextStyle ?? textStyle;
    final incomingEmojiMessageTextStyle =
        altiveChatRoomTheme.incomingEmojiMessageTextStyle ?? textStyle;
    // 配色を統一するため、絵文字の配色は`textStyle`の配色を適用する。
    final emojiTextStyle =
        (isOutgoing
                ? outgoingEmojiMessageTextStyle
                : incomingEmojiMessageTextStyle)
            ?.copyWith(color: textStyleColor);

    final outgoingSpecialMessageTextStyle =
        altiveChatRoomTheme.outgoingSpecialMessageTextStyle ?? textStyle;
    final incomingSpecialMessageTextStyle =
        altiveChatRoomTheme.incomingSpecialMessageTextStyle ?? textStyle;
    // 配色を統一するため、特殊文字の配色は`textStyle`の配色を適用する。
    final specialTextStyle =
        (isOutgoing
                ? outgoingSpecialMessageTextStyle
                : incomingSpecialMessageTextStyle)
            ?.copyWith(color: textStyleColor);

    final linkStyle = TextStyle(
      color: isOutgoing ? colorScheme.onPrimary : colorScheme.primary,
      fontSize: 14,
      decoration: TextDecoration.underline,
    );
    final cursorColor =
        altiveChatRoomTheme.popupMenuConfig.backgroundColor ??
        theme.colorScheme.secondary;

    final linkPreviewScope = ChatLinkPreviewScope.maybeOf(context);
    void onOpen(MessageLink link) {
      final onWebLinkTap = linkPreviewScope?.onWebLinkTap;
      if (link.kind == MessageLinkKind.web && onWebLinkTap != null) {
        onWebLinkTap(link.destination);
        return;
      }
      unawaited(openMessageLink(context, link));
    }

    final messageButton = message.button;
    final hasPopupMenu = widgetKey != null;
    final replyTo = message.effectiveReplyReference;

    final messageLinkSpans = buildMessageLinkSpans(
      text: message.text,
      style: textStyle,
      linkStyle: linkStyle,
      onOpen: onOpen,
    );

    // 複数のテキストスタイルを適用する。
    final inlineSpans = _applyTextStyles(
      inlineSpans: messageLinkSpans,
      textStyle: textStyle,
      linkStyle: linkStyle,
      emojiTextStyle: emojiTextStyle,
      specialTextStyle: specialTextStyle,
    );

    final textSpan = TextSpan(children: inlineSpans);

    return DecoratedBox(
      key: widgetKey,
      decoration: decoration,
      // リプライ先情報と送信メッセージの区切り線である `Divider` の幅を
      // `Divider` 以外の Widget の最大幅に合わせる為に `IntrinsicWidth` を使用。
      // 使用しない場合、メッセージの長さに関わらず横幅いっぱいに `Divider` が表示される。
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyTo != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: _ReplyToMessageContents(
                  replyTo: replyTo,
                  isOutgoing: isOutgoing,
                ),
              ),
              Divider(
                height: 1,
                color: isOutgoing
                    ? altiveChatRoomTheme.outgoingReplyToDividerColor
                    : altiveChatRoomTheme.incomingReplyToDividerColor,
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                // OGP 情報が表示される場合でも、メッセージのテキストを左寄せにする。
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canSelect || !hasPopupMenu)
                    // 選択できるテキストかポップアップメニューが設定されていない場合、テキストは選択可能にする。
                    Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          // 選択範囲の前後に表示するカーソルの配色を変更する。
                          primary: cursorColor,
                        ),
                        textSelectionTheme: TextSelectionThemeData(
                          // カーソルの配色を変更する。
                          cursorColor: cursorColor,
                          // 選択範囲の配色を変更する。
                          selectionColor: cursorColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: SelectableText.rich(
                        textSpan,
                        contextMenuBuilder: contextMenuBuilder,
                      ),
                    )
                  else
                    Text.rich(textSpan),
                  if (messageButton != null) ...[
                    const SizedBox(height: 10),
                    // メッセージのボタンは中央寄せにする。
                    Center(
                      child: FilledButton(
                        style: altiveChatRoomTheme.messageActionButtonStyle,
                        onPressed: () =>
                            onActionButtonTap?.call(messageButton.value),
                        child: Text(messageButton.text),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (message.linkPreview case final preview?
                      when preview.isDisplayable) ...[
                    const SizedBox(height: 8),
                    ChatLinkPreviewCard(
                      preview: preview,
                      imageBuilder: linkPreviewScope?.imageBuilder,
                      semanticLabel:
                          linkPreviewScope?.semanticLabel ?? 'Link preview',
                      onTap: () {
                        final onWebLinkTap = linkPreviewScope?.onWebLinkTap;
                        if (onWebLinkTap != null) {
                          onWebLinkTap(preview.sourceUrl);
                        } else {
                          onOpen(
                            MessageLink(
                              text: preview.sourceUrl.toString(),
                              destination: preview.sourceUrl,
                              kind: MessageLinkKind.web,
                              hasExplicitScheme: true,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 指定されたスタイルに従ってテキストを分割し、適切なスタイルを適用する。
List<InlineSpan> _applyTextStyles({
  List<InlineSpan>? inlineSpans,
  TextStyle? textStyle,
  TextStyle? linkStyle,
  TextStyle? emojiTextStyle,
  TextStyle? specialTextStyle,
}) {
  if (inlineSpans == null) {
    return [];
  }

  final children = <InlineSpan>[];

  for (final span in inlineSpans) {
    // リンク以外のテキストにスタイルを適用する。
    if (span is TextSpan && span.text != null && span.style != linkStyle) {
      children.addAll(
        _processTextStyle(span, textStyle, emojiTextStyle, specialTextStyle),
      );
    } else {
      children.add(span);
    }
  }

  return children;
}

/// テキストをスタイルに従って処理する。
List<InlineSpan> _processTextStyle(
  TextSpan span,
  TextStyle? textStyle,
  TextStyle? emojiTextStyle,
  TextStyle? specialTextStyle,
) {
  final source = span.text;
  if (source == null || source.isEmpty) {
    return const <InlineSpan>[];
  }

  final children = <InlineSpan>[];
  final buffer = StringBuffer();
  TextStyle? currentStyle;

  // 文字列バッファを吐き出す。
  void flushMessageBuffer() {
    if (buffer.isEmpty) {
      return;
    }
    children.add(TextSpan(text: buffer.toString(), style: currentStyle));
    buffer.clear();
  }

  for (final character in source.characters) {
    final isEmoji = _isEmoji(character);
    final isNormalChar = _isNormalChar(character);
    TextStyle? newStyle;
    // isEmojiは一部数字や漢字にもマッチしてしまうため、isNormalCharよりも先に判定する。
    if (isNormalChar) {
      newStyle = textStyle;
    } else if (isEmoji) {
      newStyle = emojiTextStyle;
    } else {
      newStyle = specialTextStyle;
    }

    // スタイルが切り替わる境界で一度吐き出す。
    if (currentStyle != newStyle) {
      flushMessageBuffer();
      currentStyle = newStyle;
    }
    buffer.write(character);
  }

  flushMessageBuffer();
  return children;
}

/// 文字が絵文字かどうかを判定する。
/// NOTE: VS16（絵文字指定コード: U+FE0F）がついている場合は絵文字扱いする。
/// 結合用の文字（Zero Width Joiner: U+200D）を含む場合も絵文字扱いする。
bool _isEmoji(String char) {
  // 顔・物・動物などの基本的な絵文字
  // 形式: 絵文字コード +（任意）VS16 +（任意）肌色
  // e.g. 😀, 😂, 🚗, 🐶, 👍🏻, 👍🏽, 👍🏿
  if (RegExp(
    // cspell:ignore DBFF, DFFF, DFFB
    r'^[\uD83C-\uDBFF][\uDC00-\uDFFF]\uFE0F?(?:\uD83C[\uDFFB-\uDFFF])?$',
  ).hasMatch(char)) {
    return true;
  }

  // 結合用の文字を含むものは絵文字扱いする。
  // 形式: 絵文字/記号 + U+200D + 絵文字/記号
  // e.g. 🏳️‍🌈（レインボーフラッグ）, 🏳️‍⚧️（トランスジェンダーフラッグ）
  if (char.contains('\u200D')) {
    return true;
  }

  // キーキャップ（数字・#・* に枠が付くもの）
  // 形式: 「#」「*」「0〜9」+（任意）VS16 + U+20E3
  // e.g. 1️⃣, 2️⃣, #️⃣, *️⃣
  if (RegExp(r'^[#*0-9]\uFE0F?\u20E3$').hasMatch(char)) {
    return true;
  }

  // 国旗（地域コード2文字の組み合わせ）
  // e.g. 🇯🇵, 🇺🇸, 🇫🇷
  if (RegExp(
    // cspell:ignore DDFF
    r'^\uD83C[\uDDE6-\uDDFF]\uD83C[\uDDE6-\uDDFF]$',
  ).hasMatch(char)) {
    return true;
  }

  // 地域旗
  // 形式: 黒旗 + 地域タグ列 + 終端タグ
  // e.g. 🏴󠁧󠁢󠁥󠁮󠁧󠁿（イングランド）, 🏴󠁧󠁢󠁳󠁣󠁴󠁿（スコットランド）, 🏴󠁧󠁢󠁷󠁬󠁳󠁿（ウェールズ）
  if (RegExp(
    r'^\uD83C\uDFF4(?:\uDB40[\uDC60-\uDC7F]){2,}\uDB40\uDC7F$',
  ).hasMatch(char)) {
    return true;
  }

  // 矢印や記号は VS16 が付いているときだけ絵文字扱いする。
  // 形式: 記号 + VS16
  // e.g. ↔️, ☀️, ✈️, ⚠️,
  // VS16がない場合: ↔, ☀, ✈, ⚠
  if (RegExp(r'^[\u2194-\u3299]\uFE0F$').hasMatch(char)) {
    return true;
  }

  return false;
}

/// 文字が英数字または日本語かどうかを判定する。
bool _isNormalChar(String char) {
  final normalCharRegExp = RegExp(
    // 日本語判定のため、正規表現内で日本語文字を明示的に扱う。
    // ignore: altive_lints/avoid_hardcoded_japanese
    '[a-zA-Z0-9ａ-ｚＡ-Ｚ０-９ぁ-んァ-ヶー一-龠々ｦ-ﾟ]',
  );
  return normalCharRegExp.hasMatch(char);
}

class _ImagesMessageBubble extends StatelessWidget {
  const _ImagesMessageBubble({
    required this.currentUserId,
    required this.message,
    required this.onImageMessageTap,
    required this.onImageTap,
    required this.popupMenuLayout,
    required this.popupMenuAccessoryBuilder,
    required this.popupMenuEnabled,
    required this.imageLayoutConfiguration,
  });

  final String currentUserId;
  final ChatImagesMessage message;
  final ImageMessageTapCallback? onImageMessageTap;
  final ChatImageTapCallback? onImageTap;
  final PopupMenuLayout? popupMenuLayout;
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;
  final bool popupMenuEnabled;
  final ChatImageLayoutConfiguration imageLayoutConfiguration;

  @override
  Widget build(BuildContext context) {
    final popupMenuLayout = this.popupMenuLayout;
    final isOutgoing = message.isOutgoing(currentUserId: currentUserId);
    final replyTo = message.effectiveReplyReference;

    return Column(
      crossAxisAlignment: isOutgoing
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (replyTo != null) ...[
          _ReplyToMessageBubble(replyTo: replyTo, isOutgoing: isOutgoing),
          const SizedBox(height: 4),
        ],
        _ImagesMessageBubbleContents(
          message: message,
          isOutgoing: isOutgoing,
          onImageMessageTap: onImageMessageTap,
          onImageTap: onImageTap,
          popupMenuLayout: popupMenuLayout,
          popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
          popupMenuEnabled: popupMenuEnabled,
          imageLayoutConfiguration: imageLayoutConfiguration,
        ),
        if (message.caption case final caption?) ...[
          const SizedBox(height: 6),
          _TextMessageBubbleContents(
            currentUserId: currentUserId,
            message: ChatTextMessage(
              id: message.id,
              createdAt: message.createdAt,
              sender: message.sender,
              text: caption,
              isRead: message.isRead,
              label: message.label,
            ),
            canSelect: false,
            contextMenuBuilder: null,
            onActionButtonTap: null,
          ),
        ],
      ],
    );
  }
}

class _ImagesMessageBubbleContents extends StatelessWidget {
  const _ImagesMessageBubbleContents({
    required this.message,
    required this.isOutgoing,
    required this.onImageMessageTap,
    required this.onImageTap,
    required this.popupMenuLayout,
    required this.popupMenuAccessoryBuilder,
    required this.popupMenuEnabled,
    required this.imageLayoutConfiguration,
  });

  /// 画像同士の間隔。
  static const spacing = 4.0;

  final ChatImagesMessage message;
  final bool isOutgoing;
  final ImageMessageTapCallback? onImageMessageTap;
  final ChatImageTapCallback? onImageTap;
  final PopupMenuLayout? popupMenuLayout;
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;
  final bool popupMenuEnabled;
  final ChatImageLayoutConfiguration imageLayoutConfiguration;

  @override
  Widget build(BuildContext context) {
    final imageUrls = message.imageUrls;

    void handleTap(int index) {
      if (onImageTap != null) {
        onImageTap!(messageId: message.id, index: index);
      } else {
        onImageMessageTap?.call(imageUrls: message.imageUrls, index: index);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final tileSize = (totalWidth - spacing) / 2;

        /// 長押し時にポップアップメニューを表示するためのコールバックを生成する。
        VoidCallback? buildOnLongPress(
          BuildContext overlayContext,
          GlobalObjectKey key,
          int index,
        ) {
          final popupMenuLayout = this.popupMenuLayout;
          if (!popupMenuEnabled || popupMenuLayout == null) {
            return null;
          }

          final config = InheritedAltiveChatRoomTheme.of(
            overlayContext,
          ).theme.popupMenuConfig;

          return () {
            PopupMenuOverlay(
              layout: popupMenuLayout,
              userMessage: message.copyWith(selectedImageIndex: index),
              config: config,
              widgetKey: key,
              popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
            ).show(context: overlayContext);
          };
        }

        final sectionChildren = switch (imageUrls.length) {
          // 画像が1枚のみの場合は全幅表示する。
          1 => [
            _SingleImageSection(
              message: message,
              isOutgoing: isOutgoing,
              size: totalWidth,
              onTap: handleTap,
              buildOnLongPress: buildOnLongPress,
              layout: imageLayoutConfiguration.singleImageLayout,
            ),
          ],
          3
              when imageLayoutConfiguration.multipleImageLayout ==
                  ChatMultipleImageLayout.mosaic =>
            [
              _MosaicImageSection(
                message: message,
                width: totalWidth,
                spacing: spacing,
                onTap: handleTap,
                buildOnLongPress: buildOnLongPress,
              ),
            ],
          final length when length >= 4 => [
            _ImagesGrid(
              message: message,
              imageUrls: imageUrls.take(4).toList(growable: false),
              startIndex: 0,
              roundTop: true,
              totalWidth: totalWidth,
              tileSize: tileSize,
              spacing: spacing,
              overflowCount: imageUrls.length - 4,
              onTap: handleTap,
              buildOnLongPress: buildOnLongPress,
            ),
          ],
          // 3枚の先頭横長配置では、先頭を全幅、残りを下段へ表示する。
          3 => [
            _LeadingWideImageSection(
              message: message,
              width: totalWidth,
              spacing: spacing,
              onTap: handleTap,
              buildOnLongPress: buildOnLongPress,
            ),
            _ImagesGrid(
              message: message,
              imageUrls: imageUrls,
              startIndex: 1,
              roundTop: false,
              totalWidth: totalWidth,
              tileSize: tileSize,
              spacing: spacing,
              overflowCount: 0,
              onTap: handleTap,
              buildOnLongPress: buildOnLongPress,
            ),
          ],
          // 偶数枚の場合は全てをグリッド表示する。
          final length when length.isEven => [
            _ImagesGrid(
              message: message,
              imageUrls: imageUrls,
              startIndex: 0,
              roundTop: true,
              totalWidth: totalWidth,
              tileSize: tileSize,
              spacing: spacing,
              overflowCount: 0,
              onTap: handleTap,
              buildOnLongPress: buildOnLongPress,
            ),
          ],
          _ => null,
        };
        // 画像が1枚もない場合は何も表示しない。
        if (sectionChildren == null) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          // 実画像幅に合わせる場合は余白を画像幅と誤認させず、時刻を画像端に寄せる。
          crossAxisAlignment:
              imageUrls.length == 1 &&
                  imageLayoutConfiguration.singleImageLayout.isIntrinsicBounded
              ? isOutgoing
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start
              : CrossAxisAlignment.stretch,
          children: sectionChildren,
        );
      },
    );
  }
}

/// 画像の長押し時にポップアップメニューを表示するためのコールバック。
typedef PopupMenuLongPressBuilder =
    VoidCallback? Function(
      BuildContext context,
      GlobalObjectKey key,
      int index,
    );

class _SingleImageSection extends StatelessWidget {
  const _SingleImageSection({
    required this.message,
    required this.isOutgoing,
    required this.size,
    required this.onTap,
    required this.buildOnLongPress,
    required this.layout,
  });

  final ChatImagesMessage message;
  final bool isOutgoing;
  final double size;
  final ValueChanged<int> onTap;
  final PopupMenuLongPressBuilder buildOnLongPress;
  final ChatSingleImageLayout layout;

  @override
  Widget build(BuildContext context) {
    const index = 0;
    final key = GlobalObjectKey('img_${message.id}_$index');
    final longPress = buildOnLongPress(context, key, index);

    final adaptiveHeight = layout.isIntrinsicBounded
        ? null
        : layout.isAdaptive && message.hasExplicitImageAspectRatios
        ? (size * message.imageAspectRatios.first).clamp(
            layout.minHeight!,
            layout.maxHeight!,
          )
        : layout.isAdaptive
        ? null
        : size;
    return _ImageTile(
      key: key,
      width: size,
      height: adaptiveHeight,
      intrinsicMaxWidth: layout.isIntrinsicBounded
          ? min(MediaQuery.widthOf(context) * layout.maxWidthFraction!, size)
          : null,
      intrinsicMaxHeightWidthRatio: layout.maxHeightWidthRatio,
      isOutgoing: isOutgoing,
      intrinsicMinHeight: layout.isAdaptive ? layout.minHeight : null,
      intrinsicMaxHeight: layout.isAdaptive ? layout.maxHeight : null,
      borderRadius: BorderRadius.circular(10),
      imageUrl: message.imageUrls[index],
      onTap: () => onTap(index),
      onLongPress: longPress,
      fit: layout.fit,
    );
  }
}

/// 先頭画像を左へ大きく配置する3枚用レイアウト。
class _MosaicImageSection extends StatelessWidget {
  const _MosaicImageSection({
    required this.message,
    required this.width,
    required this.spacing,
    required this.onTap,
    required this.buildOnLongPress,
  });

  final ChatImagesMessage message;
  final double width;
  final double spacing;
  final ValueChanged<int> onTap;
  final PopupMenuLongPressBuilder buildOnLongPress;

  @override
  Widget build(BuildContext context) {
    final largeWidth = (width - spacing) * 2 / 3;
    final smallWidth = width - spacing - largeWidth;
    final key0 = GlobalObjectKey('img_${message.id}_0');
    final key1 = GlobalObjectKey('img_${message.id}_1');
    final key2 = GlobalObjectKey('img_${message.id}_2');
    return SizedBox(
      height: largeWidth,
      child: Row(
        children: [
          _ImageTile(
            key: key0,
            width: largeWidth,
            height: largeWidth,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(10),
            ),
            imageUrl: message.imageUrls[0],
            onTap: () => onTap(0),
            onLongPress: buildOnLongPress(context, key0, 0),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              children: [
                _ImageTile(
                  key: key1,
                  width: smallWidth,
                  height: (largeWidth - spacing) / 2,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                  ),
                  imageUrl: message.imageUrls[1],
                  onTap: () => onTap(1),
                  onLongPress: buildOnLongPress(context, key1, 1),
                ),
                SizedBox(height: spacing),
                _ImageTile(
                  key: key2,
                  width: smallWidth,
                  height: (largeWidth - spacing) / 2,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(10),
                  ),
                  imageUrl: message.imageUrls[2],
                  onTap: () => onTap(2),
                  onLongPress: buildOnLongPress(context, key2, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadingWideImageSection extends StatelessWidget {
  const _LeadingWideImageSection({
    required this.message,
    required this.width,
    required this.spacing,
    required this.onTap,
    required this.buildOnLongPress,
  });

  final ChatImagesMessage message;
  final double width;
  final double spacing;
  final ValueChanged<int> onTap;
  final PopupMenuLongPressBuilder buildOnLongPress;

  @override
  Widget build(BuildContext context) {
    const index = 0;
    final key = GlobalObjectKey('img_${message.id}_$index');
    final longPress = buildOnLongPress(context, key, index);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImageTile(
          key: key,
          width: width,
          height: width * 3 / 4,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          imageUrl: message.imageUrls[index],
          onTap: () => onTap(index),
          onLongPress: longPress,
        ),
        SizedBox(height: spacing),
      ],
    );
  }
}

/// 画像をグリッド表示するWidget。
class _ImagesGrid extends StatelessWidget {
  const _ImagesGrid({
    required this.message,
    required this.imageUrls,
    required this.startIndex,
    required this.roundTop,
    required this.totalWidth,
    required this.tileSize,
    required this.spacing,
    required this.overflowCount,
    required this.onTap,
    required this.buildOnLongPress,
  });

  final ChatImagesMessage message;
  final List<String> imageUrls;
  final int startIndex;
  final bool roundTop;
  final double totalWidth;
  final double tileSize;
  final double spacing;
  final int overflowCount;
  final ValueChanged<int> onTap;
  final PopupMenuLongPressBuilder buildOnLongPress;

  @override
  Widget build(BuildContext context) {
    // 表示する画像の枚数。
    final count = imageUrls.length - startIndex;
    // 2列で表示するため、行数は画像の枚数を2で割って切り上げる。
    final rows = (count / 2).ceil();

    // グリッド内の位置（行・列）に応じて角を丸め、外枠のみ丸みを付与する。
    BorderRadius borderRadiusForGrid({required int row, required int column}) {
      const radius = Radius.circular(10);
      final isFirstRow = row == 0;
      final isLastRow = row == rows - 1;
      return BorderRadius.only(
        topLeft: isFirstRow && column == 0 && roundTop ? radius : Radius.zero,
        topRight: isFirstRow && column == 1 && roundTop ? radius : Radius.zero,
        bottomLeft: isLastRow && column == 0 ? radius : Radius.zero,
        bottomRight: isLastRow && column == 1 ? radius : Radius.zero,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      // 行ごとにRowで画像を並べる。
      children: List.generate(rows, (row) {
        final leftIndex = startIndex + row * 2;
        final rightIndex = leftIndex + 1;

        assert(
          rightIndex < imageUrls.length,
          '''The first image is extracted when the count is odd, so the remaining count is always even here.''',
        );

        final leftKey = GlobalObjectKey('img_${message.id}_$leftIndex');
        final rightKey = GlobalObjectKey('img_${message.id}_$rightIndex');

        return Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : spacing),
          child: SizedBox(
            width: totalWidth,
            child: Row(
              children: [
                _ImageTile(
                  key: leftKey,
                  width: tileSize,
                  height: tileSize,
                  borderRadius: borderRadiusForGrid(row: row, column: 0),
                  imageUrl: imageUrls[leftIndex],
                  onTap: () => onTap(leftIndex),
                  onLongPress: buildOnLongPress(context, leftKey, leftIndex),
                ),
                SizedBox(width: spacing),
                _ImageTile(
                  key: rightKey,
                  width: tileSize,
                  height: tileSize,
                  borderRadius: borderRadiusForGrid(row: row, column: 1),
                  imageUrl: imageUrls[rightIndex],
                  onTap: () => onTap(rightIndex),
                  onLongPress: buildOnLongPress(context, rightKey, rightIndex),
                  overflowCount: rightIndex == 3 ? overflowCount : 0,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.imageUrl,
    required this.onTap,
    this.onLongPress,
    this.fit = BoxFit.cover,
    this.intrinsicMinHeight,
    this.intrinsicMaxHeight,
    this.intrinsicMaxWidth,
    this.intrinsicMaxHeightWidthRatio,
    this.isOutgoing = false,
    this.overflowCount = 0,
  });

  final double width;
  final double? height;
  final BorderRadius borderRadius;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final BoxFit fit;
  final double? intrinsicMinHeight;
  final double? intrinsicMaxHeight;
  final double? intrinsicMaxWidth;
  final double? intrinsicMaxHeightWidthRatio;
  final bool isOutgoing;
  final int overflowCount;

  @override
  Widget build(BuildContext context) {
    final intrinsicMaxWidth = this.intrinsicMaxWidth;
    if (intrinsicMaxWidth != null) {
      return Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        widthFactor: 1,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: intrinsicMaxWidth,
              maxHeight: intrinsicMaxWidth * intrinsicMaxHeightWidthRatio!,
            ),
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: CommonCachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                retainPreviousImage: true,
              ),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (height == null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width,
                  minHeight: intrinsicMinHeight ?? 0,
                  maxHeight: intrinsicMaxHeight ?? double.infinity,
                ),
                child: CommonCachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  retainPreviousImage: true,
                ),
              )
            else
              SizedBox(
                width: width,
                height: height,
                child: CommonCachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: fit,
                  retainPreviousImage: true,
                ),
              ),
            if (overflowCount > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x7A000000),
                  child: Center(
                    child: Text(
                      '+$overflowCount',
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// {@template altive_chat_room.StickerMessageBubble}
/// [ChatStickerMessage]を表示するWidget。
///
/// ステッカーメッセージのバブルを表示する。
/// {@endtemplate}
class StickerMessageBubble extends StatelessWidget {
  /// {@macro altive_chat_room.StickerMessageBubble}
  const StickerMessageBubble({
    super.key,
    required this.currentUserId,
    required this.message,
    required this.onStickerMessageTap,
    required this.popupMenuLayout,
    required this.popupMenuAccessoryBuilder,
    required this.popupMenuEnabled,
  });

  /// ログイン中ユーザーの ID。
  final String currentUserId;

  /// 表示対象のステッカーメッセージ。
  final ChatStickerMessage message;

  /// ステッカーメッセージタップ時のコールバック。
  final ValueChanged<ChatStickerMessage>? onStickerMessageTap;

  /// ステッカーメッセージ用ポップアップメニューレイアウト。
  final PopupMenuLayout? popupMenuLayout;

  /// ポップアップメニュー付属領域の構築処理。
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;

  /// ポップアップメニューを有効化するかどうか。
  final bool popupMenuEnabled;

  @override
  Widget build(BuildContext context) {
    final popupMenuLayout = this.popupMenuLayout;
    if (!popupMenuEnabled || popupMenuLayout == null) {
      return _StickerMessageBubbleContents(
        onStickerMessageTap: onStickerMessageTap,
        message: message,
      );
    }

    // ポップアップメニューを表示する為のキーを生成する。
    final widgetKey = GlobalObjectKey(context);

    final config = InheritedAltiveChatRoomTheme.of(
      context,
    ).theme.popupMenuConfig;

    final isOutgoing = message.isOutgoing(currentUserId: currentUserId);
    final replyTo = message.effectiveReplyReference;

    return Column(
      crossAxisAlignment: isOutgoing
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (replyTo != null) ...[
          _ReplyToMessageBubble(replyTo: replyTo, isOutgoing: isOutgoing),
          const SizedBox(height: 4),
        ],
        // ポップアップメニューが設定されている場合、表示する為の `GestureDetector` を追加する。
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () => PopupMenuOverlay(
            layout: popupMenuLayout,
            userMessage: message,
            config: config,
            widgetKey: widgetKey,
            popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
          ).show(context: context),
          child: _StickerMessageBubbleContents(
            widgetKey: widgetKey,
            onStickerMessageTap: onStickerMessageTap,
            message: message,
          ),
        ),
      ],
    );
  }
}

class _StickerMessageBubbleContents extends StatelessWidget {
  const _StickerMessageBubbleContents({
    this.widgetKey,
    required this.onStickerMessageTap,
    required this.message,
  });

  final GlobalObjectKey? widgetKey;
  final ValueChanged<ChatStickerMessage>? onStickerMessageTap;
  final ChatStickerMessage message;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widgetKey,
      onTap: () => onStickerMessageTap?.call(message),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: CommonCachedNetworkImage(
          imageUrl: message.sticker.imageUrl,
          width: 180,
        ),
      ),
    );
  }
}

/// [ChatVoiceCallMessage]を表示するWidget。
class _VoiceCallMessageBubble extends StatelessWidget {
  const _VoiceCallMessageBubble({
    required this.currentUserId,
    required this.message,
    required this.popupMenuLayout,
    required this.popupMenuAccessoryBuilder,
    required this.popupMenuEnabled,
  });

  final String currentUserId;
  final ChatVoiceCallMessage message;
  final PopupMenuLayout? popupMenuLayout;
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;
  final bool popupMenuEnabled;

  @override
  Widget build(BuildContext context) {
    final popupMenuLayout = this.popupMenuLayout;
    if (!popupMenuEnabled || popupMenuLayout == null) {
      return _VoiceCallMessageBubbleContents(
        currentUserId: currentUserId,
        message: message,
      );
    }

    // ポップアップメニューを表示する為のキーを生成する。
    final widgetKey = GlobalObjectKey(context);
    final config = InheritedAltiveChatRoomTheme.of(
      context,
    ).theme.popupMenuConfig;

    return // ポップアップメニューが設定されている場合、表示する為の `GestureDetector` を追加する。
    GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => PopupMenuOverlay(
        layout: popupMenuLayout,
        userMessage: message,
        config: config,
        widgetKey: widgetKey,
        popupMenuAccessoryBuilder: popupMenuAccessoryBuilder,
      ).show(context: context),
      child: _VoiceCallMessageBubbleContents(
        widgetKey: widgetKey,
        currentUserId: currentUserId,
        message: message,
      ),
    );
  }
}

class _VoiceCallMessageBubbleContents extends StatelessWidget {
  const _VoiceCallMessageBubbleContents({
    this.widgetKey,
    required this.currentUserId,
    required this.message,
  });

  final GlobalObjectKey? widgetKey;
  final String currentUserId;
  final ChatVoiceCallMessage message;

  @override
  Widget build(BuildContext context) {
    final altiveChatRoomTheme = InheritedAltiveChatRoomTheme.of(context).theme;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderRadius = BorderRadius.circular(10);
    final outgoingMessageBoxDecoration =
        altiveChatRoomTheme.outgoingMessageBoxDecoration ??
        BoxDecoration(borderRadius: borderRadius, color: theme.primaryColor);
    final incomingMessageBoxDecoration =
        altiveChatRoomTheme.incomingMessageBoxDecoration ??
        BoxDecoration(
          borderRadius: borderRadius,
          color: colorScheme.surfaceContainerHighest,
        );

    final isOutgoing = message.isOutgoing(currentUserId: currentUserId);
    final decoration = isOutgoing
        ? outgoingMessageBoxDecoration
        : incomingMessageBoxDecoration;

    final outgoingMessageTextStyle =
        altiveChatRoomTheme.outgoingMessageTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
        );
    final incomingMessageTextStyle =
        altiveChatRoomTheme.incomingMessageTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
    // テキストスタイルに太字を適用する。
    final textStyle =
        (isOutgoing ? outgoingMessageTextStyle : incomingMessageTextStyle)!
            .copyWith(fontWeight: FontWeight.bold);
    final defaultTimeTextStyle = theme.textTheme.labelSmall?.copyWith(
      color: isOutgoing ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
    );
    final timeTextStyle =
        altiveChatRoomTheme.timeTextStyle ?? defaultTimeTextStyle;

    final durationSeconds = message.durationSeconds;
    return Container(
      key: widgetKey,
      padding: EdgeInsets.symmetric(
        horizontal: altiveChatRoomTheme.voiceCallMessageInsetsHorizontal,
        vertical: altiveChatRoomTheme.voiceCallMessageInsetsVertical,
      ),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.57,
            ),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.call),
            ),
          ),
          const SizedBox(width: 5),
          Column(
            children: [
              Text(
                message.voiceCallType.text(isOutgoing: isOutgoing),
                style: textStyle,
              ),
              if (durationSeconds != null)
                Text(
                  Duration(seconds: durationSeconds).hmmssText,
                  style: timeTextStyle,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// リプライ先メッセージを表示する吹き出しWidget。
/// 左下にリプライを表すアイコンが表示される。
class _ReplyToMessageBubble extends StatelessWidget {
  const _ReplyToMessageBubble({
    required this.replyTo,
    required this.isOutgoing,
  });

  /// 返信先のメッセージ。
  final ChatReplyReference replyTo;

  /// 返信するメッセージがログインユーザーのものかどうか。
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final altiveChatRoomTheme = InheritedAltiveChatRoomTheme.of(context).theme;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(10);

    final outgoingMessageBoxDecoration =
        altiveChatRoomTheme.outgoingMessageBoxDecoration ??
        BoxDecoration(borderRadius: borderRadius, color: theme.primaryColor);
    final incomingMessageBoxDecoration =
        altiveChatRoomTheme.incomingMessageBoxDecoration ??
        BoxDecoration(
          borderRadius: borderRadius,
          color: colorScheme.surfaceContainerHighest,
        );
    final decoration = isOutgoing
        ? outgoingMessageBoxDecoration
        : incomingMessageBoxDecoration;

    return IntrinsicWidth(
      child: Column(
        children: [
          Align(
            alignment: isOutgoing
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: DecoratedBox(
              decoration: decoration,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: _ReplyToMessageContents(
                  replyTo: replyTo,
                  isOutgoing: isOutgoing,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: RotatedBox(
              quarterTurns: 2,
              child: Icon(
                Icons.reply,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// メッセージの返信先を表示するWidget。
class _ReplyToMessageContents extends StatelessWidget {
  const _ReplyToMessageContents({
    required this.replyTo,
    required this.isOutgoing,
  });

  /// 返信先のメッセージ。
  final ChatReplyReference replyTo;

  /// 返信するメッセージがログインユーザーのものかどうか。
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final altiveChatRoomTheme = InheritedAltiveChatRoomTheme.of(context).theme;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final onReferenceTap = ChatReplyScope.maybeOf(context)?.onReferenceTap;
    return Semantics(
      button: onReferenceTap != null,
      label: 'Reply to ${replyTo.senderDisplayName}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onReferenceTap == null
            ? null
            : () => onReferenceTap(replyTo.messageId, replyTo.imageIndex),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyTo.senderDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isOutgoing
                        ? altiveChatRoomTheme
                                  .outgoingReplyToUserNameTextStyle ??
                              theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              )
                        : altiveChatRoomTheme
                                  .incomingReplyToUserNameTextStyle ??
                              theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                  ),
                  Text(
                    switch (replyTo.content) {
                      ChatReplyTextPreview(:final value) => value,
                      ChatReplyImagePreview(
                        :final caption,
                        :final totalCount,
                      ) =>
                        caption ?? 'Image $totalCount',
                      ChatReplyStickerPreview() => 'Sticker',
                      ChatReplyLabelPreview(:final value) => value,
                      ChatReplyUnavailablePreview() =>
                        'This message is unavailable',
                    },
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: isOutgoing
                        ? altiveChatRoomTheme.outgoingReplyToMessageTextStyle ??
                              theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              )
                        : altiveChatRoomTheme.incomingReplyToMessageTextStyle ??
                              theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                  ),
                ],
              ),
            ),
            ...switch (replyTo.content) {
              ChatReplyImagePreview(:final thumbnailUrl?) => [
                const SizedBox(width: 70),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  child: CommonCachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    width: 39,
                    height: 34,
                  ),
                ),
              ],
              ChatReplyStickerPreview(:final sticker) => [
                const SizedBox(width: 70),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  child: CommonCachedNetworkImage(
                    imageUrl: sticker.imageUrl,
                    width: 39,
                    height: 34,
                  ),
                ),
              ],
              _ => [const SizedBox.shrink()],
            },
          ],
        ),
      ),
    );
  }
}
