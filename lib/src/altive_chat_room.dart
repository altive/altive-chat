import 'dart:async';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bottom_widget.dart';
import 'chat_link_preview_scope.dart';
import 'chat_reply_scope.dart';
import 'common_cached_network_image.dart';
import 'extension.dart';
import 'inherited_altive_chat_room_theme.dart';
import 'message_item.dart';
import 'models.dart';

/// 新着メッセージ受信時のスクロール方針。
enum NewMessageScrollPolicy {
  /// 常に最新へ移動する。
  always,

  /// 最新付近にいる場合、または自分の送信時に最新へ移動する。
  whenNearLatest,

  /// 自動では移動しない。
  never,
}

/// Roomで返信を開始・表示するための設定。
class ChatReplyConfiguration {
  /// 返信設定を作成する。
  const ChatReplyConfiguration({
    this.canReply = _defaultCanReply,
    this.makeReference = _defaultMakeReference,
    this.onReferenceTap,
  });

  /// App固有条件として返信可能か判定する。
  final bool Function(ChatUserMessage message) canReply;

  /// 標準messageから軽量な返信参照を作る。
  final ChatReplyReference? Function(ChatUserMessage message, int? imageIndex)
  makeReference;

  /// 引用をタップしたときの処理。
  final void Function(String messageId, int? imageIndex)? onReferenceTap;

  /// package標準条件とApp固有条件を満たす返信参照を返す。
  ChatReplyReference? referenceFor(ChatUserMessage message, {int? imageIndex}) {
    if (!_defaultCanReply(message) || !canReply(message)) {
      return null;
    }
    return makeReference(message, imageIndex);
  }

  static bool _defaultCanReply(ChatUserMessage message) =>
      message.deliveryState == ChatMessageDeliveryState.sent;

  static ChatReplyReference _defaultMakeReference(
    ChatUserMessage message,
    int? imageIndex,
  ) => message.toReplyReference(imageIndex: imageIndex);
}

/// 呼び出し側の並び順に依存せず、Flutterの反転ListView向けに新しい順へ正規化する。
List<ChatMessage> _newestFirstMessages(List<ChatMessage> messages) {
  return messages.toList(growable: false)..sort((left, right) {
    final createdAtOrder = right.createdAt.compareTo(left.createdAt);
    return createdAtOrder != 0 ? createdAtOrder : right.id.compareTo(left.id);
  });
}

/// メッセージ一覧の最新要素を返す。
ChatMessage? _latestMessage(List<ChatMessage> messages) {
  if (messages.isEmpty) {
    return null;
  }
  return _newestFirstMessages(messages).first;
}

/// 端末の暦日で同じ日付か判定する。
bool _isSameLocalDate(DateTime left, DateTime right) {
  final localLeft = left.toLocal();
  final localRight = right.toLocal();
  return localLeft.year == localRight.year &&
      localLeft.month == localRight.month &&
      localLeft.day == localRight.day;
}

/// {@template altive_chat_room.AltiveChatRoom}
/// チャットルームを表示するWidget。
///
/// メッセージバブルの長押しでポップアップメニューを表示する。
/// {@endtemplate}
class AltiveChatRoom extends StatefulWidget {
  /// {@macro altive_chat_room.AltiveChatRoom}
  const AltiveChatRoom({
    super.key,
    required this.theme,
    required this.currentUserId,
    required this.messages,
    required this.onSendIconPressed,
    this.onSubmit,
    this.linkPreviewResolver,
    this.linkPreviewImageBuilder,
    this.onWebLinkTap,
    this.linkPreviewSemanticLabel = 'Link preview',
    this.linkPreviewLoadingSemanticLabel = 'Loading link preview',
    this.replyConfiguration,
    this.replyActionLabel = 'Reply',
    this.cancelReplyLabel = 'Cancel reply',
    this.textEditingController,
    this.draftPolicy = const ChatDraftPolicy.unrestricted(),
    this.isGroupChat = false,
    this.scrollController,
    this.selectableTextMessageId,
    this.contextMenuBuilder,
    this.onRefresh,
    this.onScrollToTop,
    this.emptyWidget,
    this.hideBottomWidget = false,
    this.messageBubbleBuilder,
    this.messageBottomWidgetBuilder,
    this.popupMenuAccessoryBuilder,
    this.dateTextBuilder,
    this.dateTextFormatter,
    this.onAvatarTap,
    this.onImageMessageTap,
    this.onImageTap,
    this.onStickerMessageTap,
    this.onActionButtonTap,
    this.incomingAvatarSizeDimension = 30,
    this.hintText = 'Message',
    this.showSendButtonInTextField = false,
    this.sendButtonWidget,
    this.expandButtonIcon,
    this.textFieldSuffixBuilder,
    this.bottomLeadingWidgets,
    this.replyToMessageBar,
    this.stickerPackages = const [],
    this.stickerPickerFooter,
    this.onLockedStickerTap,
    this.lockedStickerSemanticLabel,
    this.outgoingTextMessagePopupMenuLayout,
    this.outgoingImageMessagePopupMenuLayout,
    this.outgoingStickerMessagePopupMenuLayout,
    this.outgoingVoiceCallMessagePopupMenuLayout,
    this.incomingTextMessagePopupMenuLayout,
    this.incomingImageMessagePopupMenuLayout,
    this.incomingStickerMessagePopupMenuLayout,
    this.incomingVoiceCallMessagePopupMenuLayout,
    this.readStatusWidget,
    this.pendingIndicator,
    this.pendingMessageIds = const <String>[],
    this.onRetryMessage,
    this.failedIndicator,
    this.imageLayoutConfiguration = const ChatImageLayoutConfiguration(),
    this.newMessageScrollPolicy = NewMessageScrollPolicy.whenNearLatest,
    this.latestThreshold = 80,
    this.showScrollToLatestButton = true,
    this.scrollToLatestButtonBuilder,
    this.showOutgoingMessageAppearAnimation = false,
    this.outgoingMessageAnimationDuration = const Duration(milliseconds: 300),
    this.outgoingMessageAnimationCurve = Curves.easeOutCubic,
    this.outgoingMessageAnimationOffset = 10,
  });

  /// AltiveChatRoomのテーマ。
  final AltiveChatRoomTheme theme;

  /// ログインユーザーのID。
  ///
  /// ログインユーザーが送信したメッセージかどうか判別するために使用する。
  final String currentUserId;

  /// メッセージの配列。
  final List<ChatMessage> messages;

  /// 送信ボタンを押した時の処理。
  ///
  /// テキストメッセージを送信する際に使用する。
  /// ステッカーが選択されている場合はステッカーメッセージも送信する。
  final ValueChanged<({String text, Sticker? sticker})> onSendIconPressed;

  /// 型付きの送信値を受け取る処理。
  ///
  /// 指定時は[onSendIconPressed]より優先される。
  final ValueChanged<ChatComposerSubmission>? onSubmit;

  /// 入力中の先頭Web URLを解決する任意の処理。
  final ChatLinkPreviewResolver? linkPreviewResolver;

  /// リンクプレビュー画像をアプリ側で構築する任意の処理。
  final ChatLinkPreviewImageBuilder? linkPreviewImageBuilder;

  /// 本文またはカードのWebリンクを操作した時の任意の処理。
  final ChatWebLinkTapCallback? onWebLinkTap;

  /// リンクプレビューの読み上げ文。
  final String linkPreviewSemanticLabel;

  /// 読み込み中リンクプレビューの読み上げ文。
  final String linkPreviewLoadingSemanticLabel;

  /// 返信機能を有効化する任意設定。
  final ChatReplyConfiguration? replyConfiguration;

  /// 長押しメニューへ表示する返信文言。
  final String replyActionLabel;

  /// 返信選択の取消ボタン文言。
  final String cancelReplyLabel;

  /// グループチャットかどうか。
  final bool isGroupChat;

  /// テキストフィールドのコントローラー。
  final TextEditingController? textEditingController;

  /// 入力値の長さ、上限、送信時の正規化を制御する方針。
  final ChatDraftPolicy draftPolicy;

  /// スクロールコントローラー。
  final ScrollController? scrollController;

  /// 選択可能なテキストメッセージのID。
  final String? selectableTextMessageId;

  /// 選択可能なテキストメッセージで表示するコンテキストメニューをカスタマイズするビルダー。
  ///
  /// [selectableTextMessageId]と一致したテキストメッセージのみ適用される。
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// リフレッシュインジケータをドラッグした時の処理。
  final AsyncCallback? onRefresh;

  /// スクロールが一番上に到達した時の処理。
  final VoidCallback? onScrollToTop;

  /// メッセージがない場合に表示するWidget。
  final Widget? emptyWidget;

  /// ボトムのWidgetを非表示にするかどうか。
  final bool hideBottomWidget;

  /// デフォルトのメッセージバブルをカスタマイズするビルダー。
  ///
  /// Parameters:
  ///   `child` - バブル内にレンダリングされるWidget。
  ///   `message` - 表示するメッセージ。
  final Widget Function(Widget child, {required ChatMessage message})?
  messageBubbleBuilder;

  /// メッセージバブルの直下に表示するWidgetを構築するビルダー。
  final MessageBottomWidgetBuilder? messageBottomWidgetBuilder;

  /// ポップアップメニュー周辺に表示する付属Widgetを構築するビルダー。
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;

  /// デフォルトの日付表示をカスタマイズするビルダー。
  ///
  /// Parameters:
  ///   `dateText` - [dateTextFormatter]またはパッケージ標準で生成した文字列。
  final Widget Function({required String dateText})? dateTextBuilder;

  /// 日付ラベルの文字列を日時から生成する処理。
  ///
  /// 未指定時はパッケージ標準の英語表記を使用する。
  final String Function(DateTime dateTime)? dateTextFormatter;

  /// アバターをタップした時の処理。
  final ValueChanged<ChatUser>? onAvatarTap;

  /// 画像メッセージをタップした時の処理。
  final ImageMessageTapCallback? onImageMessageTap;

  /// 画像タップ時にメッセージIDと画像位置を通知する処理。
  ///
  /// 指定時は[onImageMessageTap]より優先される。
  final ChatImageTapCallback? onImageTap;

  /// ステッカーメッセージをタップした時の処理。
  final ValueChanged<ChatStickerMessage>? onStickerMessageTap;

  /// メッセージのアクションボタンをタップした時の処理。
  final ValueChanged<Object?>? onActionButtonTap;

  /// 受信メッセージに表示するアバター画像の直径。
  final double incomingAvatarSizeDimension;

  /// 入力欄のプレースホルダーテキスト。
  final String hintText;

  /// 送信ボタンをTextField内に表示するかどうか。
  final bool showSendButtonInTextField;

  /// 送信ボタンに表示するWidget。
  final Widget? sendButtonWidget;

  /// 非表示状態の[bottomLeadingWidgets]を表示するボタンのアイコン。
  final Icon? expandButtonIcon;

  /// [TextField.decoration]の[InputDecoration.suffixIcon]に配置するWidget。
  final Widget Function(MessageInputType type)? textFieldSuffixBuilder;

  /// ボトムの先頭に配置するWidgetの配列。
  ///
  /// テキストフィールドにフォーカスがあたると非表示になる。
  /// [expandButtonIcon]をタップすることで表示できる。
  final List<Widget>? bottomLeadingWidgets;

  /// リプライ先のメッセージを表示するWidget。
  final Widget? replyToMessageBar;

  /// ステッカーパッケージの配列。
  final List<StickerPackage> stickerPackages;

  /// ステッカー一覧の最下部に表示するWidget。
  ///
  /// アプリ固有の案内や導線を、ステッカー一覧と一緒にスクロールして表示する場合に使用する。
  final Widget? stickerPickerFooter;

  /// ロック中のステッカーをタップした時の処理。
  final VoidCallback? onLockedStickerTap;

  /// ロック中のパッケージとステッカーへ付与する読み上げ文。
  final String? lockedStickerSemanticLabel;

  /// ログインユーザーが送信したテキストメッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  ///
  /// `null`の場合はポップアップメニューが表示されず、テキストが選択可能になる。
  final PopupMenuLayout? outgoingTextMessagePopupMenuLayout;

  /// ログインユーザーが送信した画像メッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  final PopupMenuLayout? outgoingImageMessagePopupMenuLayout;

  /// ログインユーザーが送信したステッカーメッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  final PopupMenuLayout? outgoingStickerMessagePopupMenuLayout;

  /// ログインユーザーが送信した音声通話メッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  final PopupMenuLayout? outgoingVoiceCallMessagePopupMenuLayout;

  /// 相手が送信したテキストメッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  ///
  /// `null`の場合はポップアップメニューが表示されず、テキストが選択可能になる。
  final PopupMenuLayout? incomingTextMessagePopupMenuLayout;

  /// 相手が送信した画像メッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  final PopupMenuLayout? incomingImageMessagePopupMenuLayout;

  /// 相手が送信したステッカーメッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  final PopupMenuLayout? incomingStickerMessagePopupMenuLayout;

  /// 相手が送信した音声通話メッセージのポップアップメニューで使用するタップ可能なアイテムの配列。
  final PopupMenuLayout? incomingVoiceCallMessagePopupMenuLayout;

  /// 既読表示に使用するWidget。
  final Widget? readStatusWidget;

  /// 送信保留中メッセージのインジケーター。
  final Widget? pendingIndicator;

  /// 未同期メッセージのID一覧。
  final List<String> pendingMessageIds;

  /// 送信失敗メッセージを同じIDで再送する処理。
  final ValueChanged<String>? onRetryMessage;

  /// 送信失敗時に表示するWidget。
  final Widget? failedIndicator;

  /// 画像メッセージのレイアウト設定。
  final ChatImageLayoutConfiguration imageLayoutConfiguration;

  /// 新着メッセージ受信時のスクロール方針。
  final NewMessageScrollPolicy newMessageScrollPolicy;

  /// 最新付近とみなすスクロール距離。
  final double latestThreshold;

  /// 最新へ移動する標準ボタンを表示するかどうか。
  final bool showScrollToLatestButton;

  /// 最新へ移動するボタンを構築する処理。
  final Widget Function(VoidCallback onPressed)? scrollToLatestButtonBuilder;

  /// 送信メッセージの出現アニメーションを有効にするかどうか。
  ///
  /// [ChatUserMessage] でログインユーザーが送信したメッセージにのみ適用される。
  final bool showOutgoingMessageAppearAnimation;

  /// 送信メッセージの出現アニメーション時間。
  final Duration outgoingMessageAnimationDuration;

  /// 送信メッセージの出現アニメーションカーブ。
  final Curve outgoingMessageAnimationCurve;

  /// 送信メッセージの出現時の縦方向オフセット。
  final double outgoingMessageAnimationOffset;

  @override
  State<AltiveChatRoom> createState() => _AltiveChatRoomState();
}

class _AltiveChatRoomState extends State<AltiveChatRoom> {
  // メッセージの種類を管理する。
  // TextField外をタップしたときに`MessageType.text`に切り替えるためにここで定義している。
  final messageTypeNotifier = ValueNotifier<MessageInputType>(
    MessageInputType.text,
  );

  /// 選択中のステッカー。
  Sticker? _selectedSticker;
  ChatReplyReference? _selectedReply;
  ScrollController? _scrollController;
  var _isNearLatest = true;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _scrollController!;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _scrollController = ScrollController();
    }
  }

  @override
  void didUpdateWidget(covariant AltiveChatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _scrollController?.dispose();
      _scrollController = widget.scrollController == null
          ? ScrollController()
          : null;
    }
    final latest = _latestMessage(widget.messages);
    final previousLatest = _latestMessage(oldWidget.messages);
    if (latest == null || latest.id == previousLatest?.id) {
      return;
    }
    final shouldFollow = switch (widget.newMessageScrollPolicy) {
      NewMessageScrollPolicy.always => true,
      NewMessageScrollPolicy.never => false,
      NewMessageScrollPolicy.whenNearLatest =>
        _isNearLatest ||
            latest is ChatUserMessage &&
                latest.isOutgoing(currentUserId: widget.currentUserId),
    };
    if (shouldFollow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  @override
  void dispose() {
    messageTypeNotifier.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    if (!_effectiveScrollController.hasClients) {
      return;
    }
    unawaited(
      _effectiveScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightThemeData = ThemeData.light();
    const refreshIndicator = CircularProgressIndicator.adaptive();
    final messages = _newestFirstMessages(widget.messages);
    // メッセージリストの高さを計算するために使用するキー。
    final messageListViewKey = GlobalObjectKey(context);
    final child = NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        // 最上部にスクロールしたか判定する。
        if (notification.metrics.extentAfter == 0) {
          widget.onScrollToTop?.call();
          return true;
        }
        return false;
      },
      child: _MessageListView(
        key: messageListViewKey,
        currentUserId: widget.currentUserId,
        messages: messages,
        isGroupChat: widget.isGroupChat,
        scrollController: _effectiveScrollController,
        selectableTextMessageId: widget.selectableTextMessageId,
        contextMenuBuilder: widget.contextMenuBuilder,
        messageBubbleBuilder: widget.messageBubbleBuilder,
        messageBottomWidgetBuilder: widget.messageBottomWidgetBuilder,
        popupMenuAccessoryBuilder: widget.popupMenuAccessoryBuilder,
        onReplyRequested:
            widget.replyConfiguration == null || widget.onSubmit == null
            ? null
            : (message) {
                final configuration = widget.replyConfiguration!;
                final reference = configuration.referenceFor(message);
                if (reference == null) {
                  return;
                }
                setState(() => _selectedReply = reference);
              },
        replyActionLabel: widget.replyActionLabel,
        dateTextBuilder: widget.dateTextBuilder,
        dateTextFormatter: widget.dateTextFormatter,
        onScrollToTop: widget.onScrollToTop,
        messageTypeNotifier: messageTypeNotifier,
        onAvatarTap: widget.onAvatarTap,
        onImageMessageTap: widget.onImageMessageTap,
        onImageTap: widget.onImageTap,
        onStickerMessageTap: widget.onStickerMessageTap,
        onActionButtonTap: widget.onActionButtonTap,
        incomingAvatarSizeDimension: widget.incomingAvatarSizeDimension,
        outgoingTextMessagePopupMenuLayout:
            widget.outgoingTextMessagePopupMenuLayout,
        outgoingImageMessagePopupMenuLayout:
            widget.outgoingImageMessagePopupMenuLayout,
        outgoingStickerMessagePopupMenuLayout:
            widget.outgoingStickerMessagePopupMenuLayout,
        outgoingVoiceCallMessagePopupMenuLayout:
            widget.outgoingVoiceCallMessagePopupMenuLayout,
        incomingTextMessagePopupMenuLayout:
            widget.incomingTextMessagePopupMenuLayout,
        incomingImageMessagePopupMenuLayout:
            widget.incomingImageMessagePopupMenuLayout,
        incomingStickerMessagePopupMenuLayout:
            widget.incomingStickerMessagePopupMenuLayout,
        incomingVoiceCallMessagePopupMenuLayout:
            widget.incomingVoiceCallMessagePopupMenuLayout,
        readStatusWidget: widget.readStatusWidget,
        pendingIndicator: widget.pendingIndicator,
        pendingMessageIds: widget.pendingMessageIds,
        onRetryMessage: widget.onRetryMessage,
        failedIndicator: widget.failedIndicator,
        imageLayoutConfiguration: widget.imageLayoutConfiguration,
        latestThreshold: widget.latestThreshold,
        onLatestProximityChanged: (isNearLatest) {
          if (_isNearLatest != isNearLatest) {
            setState(() => _isNearLatest = isNearLatest);
          }
        },
        showOutgoingMessageAppearAnimation:
            widget.showOutgoingMessageAppearAnimation,
        outgoingMessageAnimationDuration:
            widget.outgoingMessageAnimationDuration,
        outgoingMessageAnimationCurve: widget.outgoingMessageAnimationCurve,
        outgoingMessageAnimationOffset: widget.outgoingMessageAnimationOffset,
      ),
    );

    final onRefresh = widget.onRefresh;
    final emptyWidget = widget.emptyWidget ?? const SizedBox.shrink();
    final selectedSticker = _selectedSticker;
    return InheritedAltiveChatRoomTheme(
      theme: widget.theme,
      messageListViewKey: messageListViewKey,
      child: ChatReplyScope(
        onReferenceTap: widget.replyConfiguration?.onReferenceTap,
        child: ChatLinkPreviewScope(
          resolver: widget.linkPreviewResolver,
          imageBuilder: widget.linkPreviewImageBuilder,
          onWebLinkTap: widget.onWebLinkTap,
          semanticLabel: widget.linkPreviewSemanticLabel,
          loadingSemanticLabel: widget.linkPreviewLoadingSemanticLabel,
          child: Theme(
            data: Theme.of(context).copyWith(
              primaryColor: widget.theme.primaryColor,
              scaffoldBackgroundColor: widget.theme.backgroundColor,
              inputDecorationTheme: widget.theme.inputDecorationTheme,
              colorScheme: lightThemeData.colorScheme.copyWith(
                primary: widget.theme.primaryColor,
                surface: widget.theme.backgroundColor,
              ),
            ),
            child: Scaffold(
              body: SafeArea(
                // bottom部分は特定のカラーを指定したいのでfalseにする。
                // trueにすると、Scaffold.backgroundColorのカラーが表示されてしまう。
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          if (widget.messages.isEmpty)
                            // メッセージがない場合
                            emptyWidget
                          else
                            // メッセージがある場合
                            onRefresh == null
                                ? child
                                // NOTE: ListViewを反転させている為、
                                // 上に引っ張って Pull-to-Refreshを表示させる。
                                // この際、RefreshIndicatorは使用できないので、
                                // 代わりにCustomMaterialIndicatorを使用している。
                                : CustomMaterialIndicator(
                                    onRefresh: onRefresh,
                                    trailingScrollIndicatorVisible: false,
                                    leadingScrollIndicatorVisible: true,
                                    indicatorBuilder: (_, _) =>
                                        refreshIndicator,
                                    child: child,
                                  ),
                          if (selectedSticker != null)
                            _StickerPreview(
                              backgroundColor: widget.theme.backgroundColor
                                  ?.withValues(alpha: 0.5),
                              sticker: selectedSticker,
                              onSelected: (sticker) {
                                final onSubmit = widget.onSubmit;
                                if (onSubmit != null) {
                                  onSubmit(
                                    ChatComposerSubmission(
                                      text: '',
                                      sticker: sticker,
                                      replyTo: _selectedReply,
                                    ),
                                  );
                                } else {
                                  widget.onSendIconPressed.call((
                                    text: '',
                                    sticker: sticker,
                                  ));
                                }
                                setState(() {
                                  _selectedSticker = null;
                                  if (onSubmit != null) {
                                    _selectedReply = null;
                                  }
                                });
                              },
                              onClosed: () {
                                setState(() {
                                  _selectedSticker = null;
                                });
                              },
                            ),
                          if (widget.showScrollToLatestButton && !_isNearLatest)
                            Positioned(
                              right: 16,
                              bottom: 8,
                              child:
                                  widget.scrollToLatestButtonBuilder?.call(
                                    _scrollToLatest,
                                  ) ??
                                  FloatingActionButton.small(
                                    onPressed: _scrollToLatest,
                                    child: const Icon(Icons.arrow_downward),
                                  ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!widget.hideBottomWidget) ...[
                      BottomWidget(
                        textEditingController: widget.textEditingController,
                        draftPolicy: widget.draftPolicy,
                        onSubmit: (submission) {
                          final enrichedSubmission = ChatComposerSubmission(
                            text: submission.text,
                            sticker: submission.sticker,
                            linkPreview: submission.linkPreview,
                            replyTo: _selectedReply,
                          );
                          final onSubmit = widget.onSubmit;
                          if (onSubmit != null) {
                            onSubmit(enrichedSubmission);
                          } else {
                            widget.onSendIconPressed((
                              text: submission.text,
                              sticker: submission.sticker,
                            ));
                          }
                          setState(() {
                            _selectedSticker = null;
                            _selectedReply = null;
                          });
                        },
                        hintText: widget.hintText,
                        showSendButtonInTextField:
                            widget.showSendButtonInTextField,
                        sendButtonWidget: widget.sendButtonWidget,
                        expandButtonIcon: widget.expandButtonIcon,
                        textFieldSuffixBuilder: widget.textFieldSuffixBuilder,
                        messageTypeNotifier: messageTypeNotifier,
                        leadingWidgets: widget.bottomLeadingWidgets,
                        replyToMessageBar: _selectedReply == null
                            ? widget.replyToMessageBar
                            : _ChatReplyComposerBar(
                                reference: _selectedReply!,
                                cancelLabel: widget.cancelReplyLabel,
                                onCancel: () {
                                  setState(() => _selectedReply = null);
                                },
                              ),
                        stickerPackages: widget.stickerPackages,
                        stickerPickerFooter: widget.stickerPickerFooter,
                        onLockedStickerTap: widget.onLockedStickerTap,
                        lockedStickerSemanticLabel:
                            widget.lockedStickerSemanticLabel,
                        selectedSticker: _selectedSticker,
                        onStickerSelected: (sticker) {
                          setState(() {
                            _selectedSticker = sticker;
                          });
                        },
                      ),
                      // SafeAreaのbottomと同じ高さで、入力エリアと同じカラーのWidgetを配置する。
                      Container(
                        height: MediaQuery.paddingOf(context).bottom,
                        color: widget.theme.inputBackgroundColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatReplyComposerBar extends StatelessWidget {
  const _ChatReplyComposerBar({
    required this.reference,
    required this.cancelLabel,
    required this.onCancel,
  });

  final ChatReplyReference reference;
  final String cancelLabel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final preview = switch (reference.content) {
      ChatReplyTextPreview(:final value) => value,
      ChatReplyImagePreview(:final caption, :final totalCount) =>
        caption ?? 'Image $totalCount',
      ChatReplyStickerPreview() => 'Sticker',
      ChatReplyLabelPreview(:final value) => value,
      ChatReplyUnavailablePreview() => 'This message is unavailable',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reference.senderDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            tooltip: cancelLabel,
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// ステッカー送信プレビュー。
class _StickerPreview extends StatelessWidget {
  const _StickerPreview({
    required this.backgroundColor,
    required this.sticker,
    required this.onSelected,
    required this.onClosed,
  });

  final Color? backgroundColor;
  final Sticker sticker;
  final ValueChanged<Sticker> onSelected;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      width: double.infinity,
      color: backgroundColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ステッカー画像。
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: GestureDetector(
              key: const ValueKey('AltiveChatRoom.StickerPreview'),
              onTap: () => onSelected(sticker),
              child: CommonCachedNetworkImage(imageUrl: sticker.imageUrl),
            ),
          ),

          // 閉じるボタン。
          Positioned(
            top: 12,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClosed,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageListView extends StatefulWidget {
  const _MessageListView({
    super.key,
    required this.currentUserId,
    required this.messages,
    required this.isGroupChat,
    required this.scrollController,
    required this.selectableTextMessageId,
    required this.contextMenuBuilder,
    required this.messageBubbleBuilder,
    required this.messageBottomWidgetBuilder,
    required this.popupMenuAccessoryBuilder,
    required this.onReplyRequested,
    required this.replyActionLabel,
    required this.dateTextBuilder,
    required this.dateTextFormatter,
    required this.onScrollToTop,
    required this.messageTypeNotifier,
    required this.onAvatarTap,
    required this.onImageMessageTap,
    required this.onImageTap,
    required this.onStickerMessageTap,
    required this.onActionButtonTap,
    required this.incomingAvatarSizeDimension,
    required this.outgoingTextMessagePopupMenuLayout,
    required this.outgoingImageMessagePopupMenuLayout,
    required this.outgoingStickerMessagePopupMenuLayout,
    required this.outgoingVoiceCallMessagePopupMenuLayout,
    required this.incomingTextMessagePopupMenuLayout,
    required this.incomingImageMessagePopupMenuLayout,
    required this.incomingStickerMessagePopupMenuLayout,
    required this.incomingVoiceCallMessagePopupMenuLayout,
    required this.readStatusWidget,
    required this.pendingIndicator,
    required this.pendingMessageIds,
    required this.onRetryMessage,
    required this.failedIndicator,
    required this.imageLayoutConfiguration,
    required this.latestThreshold,
    required this.onLatestProximityChanged,
    required this.showOutgoingMessageAppearAnimation,
    required this.outgoingMessageAnimationDuration,
    required this.outgoingMessageAnimationCurve,
    required this.outgoingMessageAnimationOffset,
  });

  final String currentUserId;
  final List<ChatMessage> messages;
  final bool isGroupChat;
  final ScrollController? scrollController;
  final String? selectableTextMessageId;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final Widget Function(Widget child, {required ChatMessage message})?
  messageBubbleBuilder;
  final MessageBottomWidgetBuilder? messageBottomWidgetBuilder;
  final PopupMenuAccessoryBuilder? popupMenuAccessoryBuilder;
  final ValueChanged<ChatUserMessage>? onReplyRequested;
  final String replyActionLabel;
  final Widget Function({required String dateText})? dateTextBuilder;
  final String Function(DateTime dateTime)? dateTextFormatter;
  final VoidCallback? onScrollToTop;
  final ValueNotifier<MessageInputType> messageTypeNotifier;
  final ValueChanged<ChatUser>? onAvatarTap;
  final ImageMessageTapCallback? onImageMessageTap;
  final ChatImageTapCallback? onImageTap;
  final ValueChanged<ChatStickerMessage>? onStickerMessageTap;
  final ValueChanged<Object?>? onActionButtonTap;
  final double incomingAvatarSizeDimension;
  final PopupMenuLayout? outgoingTextMessagePopupMenuLayout;
  final PopupMenuLayout? outgoingImageMessagePopupMenuLayout;
  final PopupMenuLayout? outgoingStickerMessagePopupMenuLayout;
  final PopupMenuLayout? outgoingVoiceCallMessagePopupMenuLayout;
  final PopupMenuLayout? incomingTextMessagePopupMenuLayout;
  final PopupMenuLayout? incomingImageMessagePopupMenuLayout;
  final PopupMenuLayout? incomingStickerMessagePopupMenuLayout;
  final PopupMenuLayout? incomingVoiceCallMessagePopupMenuLayout;
  final Widget? readStatusWidget;
  final Widget? pendingIndicator;
  final List<String> pendingMessageIds;
  final ValueChanged<String>? onRetryMessage;
  final Widget? failedIndicator;
  final ChatImageLayoutConfiguration imageLayoutConfiguration;
  final double latestThreshold;
  final ValueChanged<bool> onLatestProximityChanged;
  final bool showOutgoingMessageAppearAnimation;
  final Duration outgoingMessageAnimationDuration;
  final Curve outgoingMessageAnimationCurve;
  final double outgoingMessageAnimationOffset;

  @override
  State<_MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<_MessageListView> {
  // 表示済みメッセージIDのセット。
  final _seenMessageIds = <String>{};
  // 今回の更新で出現アニメーションを適用するメッセージID。
  String? _showAnimationMessageId;

  /// 表示領域が埋まらないときに追加取得を要求した最後の最古メッセージID。
  String? _lastUnderfilledOldestMessageId;

  @override
  void initState() {
    super.initState();
    // 起動時は全てのメッセージIDを表示済みIDセットに追加する。
    _seenMessageIds.addAll(widget.messages.map((message) => message.id));
  }

  @override
  void didUpdateWidget(covariant _MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 表示済みのアニメーション対象IDをリセットする。
    _showAnimationMessageId = null;

    // アニメーションが無効、または表示対象メッセージがない場合は判定をスキップする。
    if (!widget.showOutgoingMessageAppearAnimation || widget.messages.isEmpty) {
      return;
    }
    // 出現アニメーションを適用するメッセージIDを決定する。
    _showAnimationMessageId = _resolveShowAnimationMessageId();

    // 画面上に存在しないIDを表示済みIDセットから削除し、存在するIDをセットに追加する。
    final currentMessageIds = widget.messages
        .map((message) => message.id)
        .toSet();
    _seenMessageIds
      ..removeWhere((id) => !currentMessageIds.contains(id))
      ..addAll(currentMessageIds);
  }

  /// 出現アニメーションは以下の順で判定する。
  /// - 最新メッセージが `ChatUserMessage` であること
  /// - 最新メッセージが未表示（新規）であること
  /// - 最新メッセージがログインユーザー送信であること
  String? _resolveShowAnimationMessageId() {
    final latestMessage = widget.messages.first;
    if (latestMessage is! ChatUserMessage) {
      return null;
    }
    if (_seenMessageIds.contains(latestMessage.id)) {
      return null;
    }
    final isOutgoing = latestMessage.isOutgoing(
      currentUserId: widget.currentUserId,
    );
    if (!isOutgoing) {
      return null;
    }
    return latestMessage.id;
  }

  @override
  Widget build(BuildContext context) {
    final altiveChatRoomTheme = InheritedAltiveChatRoomTheme.of(context).theme;

    // 初回ページが画面内に収まるとスクロール終了通知が発生せず、履歴取得の契機がない。
    // 最古のメッセージが変わるたびに空き領域を確認し、埋まるまで次ページを要求する。
    if (widget.onScrollToTop != null && widget.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.onScrollToTop == null) {
          return;
        }
        final controller = widget.scrollController;
        if (controller == null || !controller.hasClients) {
          return;
        }
        final oldestMessageId = widget.messages.last.id;
        if (controller.position.maxScrollExtent > 0 ||
            _lastUnderfilledOldestMessageId == oldestMessageId) {
          return;
        }
        _lastUnderfilledOldestMessageId = oldestMessageId;
        widget.onScrollToTop?.call();
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          widget.onLatestProximityChanged(
            notification.metrics.pixels <= widget.latestThreshold,
          );
        }
        return false;
      },
      child: GestureDetector(
        // Padding等でも反応させるために追加する。
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // キーボードを閉じるために追加する。
          FocusScope.of(context).unfocus();
          // テキストメッセージに切り替える。
          widget.messageTypeNotifier.value = MessageInputType.text;
        },
        child: ListView.builder(
          reverse: true,
          controller: widget.scrollController,
          itemCount: widget.messages.length,
          itemBuilder: (context, index) {
            final message = widget.messages[index];

            // reverse: true のため、1つ古いメッセージ（index + 1）と比較して
            // 日付の切り替わり位置でヘッダーを表示する。
            final isFirstInGroup =
                index == widget.messages.length - 1 ||
                !_isSameLocalDate(
                  widget.messages[index + 1].createdAt,
                  message.createdAt,
                );

            final messageItem = MessageItem(
              key: ValueKey(message.id),
              currentUserId: widget.currentUserId,
              message: message,
              isGroupChat: widget.isGroupChat,
              selectableTextMessageId: widget.selectableTextMessageId,
              contextMenuBuilder: widget.contextMenuBuilder,
              messageBottomWidgetBuilder: widget.messageBottomWidgetBuilder,
              popupMenuAccessoryBuilder: widget.popupMenuAccessoryBuilder,
              onReplyRequested: widget.onReplyRequested,
              replyActionLabel: widget.replyActionLabel,
              onAvatarTap: widget.onAvatarTap,
              onImageMessageTap: widget.onImageMessageTap,
              onImageTap: widget.onImageTap,
              onStickerMessageTap: widget.onStickerMessageTap,
              onActionButtonTap: widget.onActionButtonTap,
              incomingAvatarSizeDimension: widget.incomingAvatarSizeDimension,
              outgoingTextMessagePopupMenuLayout:
                  widget.outgoingTextMessagePopupMenuLayout,
              outgoingImageMessagePopupMenuLayout:
                  widget.outgoingImageMessagePopupMenuLayout,
              outgoingStickerMessagePopupMenuLayout:
                  widget.outgoingStickerMessagePopupMenuLayout,
              outgoingVoiceCallMessagePopupMenuLayout:
                  widget.outgoingVoiceCallMessagePopupMenuLayout,
              incomingTextMessagePopupMenuLayout:
                  widget.incomingTextMessagePopupMenuLayout,
              incomingImageMessagePopupMenuLayout:
                  widget.incomingImageMessagePopupMenuLayout,
              incomingStickerMessagePopupMenuLayout:
                  widget.incomingStickerMessagePopupMenuLayout,
              incomingVoiceCallMessagePopupMenuLayout:
                  widget.incomingVoiceCallMessagePopupMenuLayout,
              readStatusWidget: widget.readStatusWidget,
              pendingIndicator: widget.pendingIndicator,
              pendingMessageIds: widget.pendingMessageIds,
              onRetryMessage: widget.onRetryMessage,
              failedIndicator: widget.failedIndicator,
              imageLayoutConfiguration: widget.imageLayoutConfiguration,
              showOutgoingMessageAppearAnimation:
                  _showAnimationMessageId == message.id,
              outgoingMessageAnimationDuration:
                  widget.outgoingMessageAnimationDuration,
              outgoingMessageAnimationCurve:
                  widget.outgoingMessageAnimationCurve,
              outgoingMessageAnimationOffset:
                  widget.outgoingMessageAnimationOffset,
            );

            final messageBubbleBuilder = widget.messageBubbleBuilder;
            final dateTextBuilder = widget.dateTextBuilder;
            return Column(
              children: [
                // 同じ日付の中で先頭の場合のみヘッダーを表示する
                if (isFirstInGroup) ...[
                  if (dateTextBuilder == null)
                    _DateText(
                      dateTime: message.createdAt,
                      dateTextFormatter: widget.dateTextFormatter,
                    )
                  else
                    dateTextBuilder(
                      dateText:
                          widget.dateTextFormatter?.call(message.createdAt) ??
                          message.createdAt.dateText,
                    ),
                  SizedBox(height: altiveChatRoomTheme.messageInsetsVertical),
                ],

                if (messageBubbleBuilder == null)
                  messageItem
                else
                  messageBubbleBuilder(messageItem, message: message),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 日付を表示するWidget。
class _DateText extends StatelessWidget {
  const _DateText({required this.dateTime, this.dateTextFormatter});

  final DateTime dateTime;
  final String Function(DateTime dateTime)? dateTextFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        dateTextFormatter?.call(dateTime) ?? dateTime.dateText,
        style: theme.textTheme.labelSmall!.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
    );
  }
}
