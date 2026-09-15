# Altive Chat

Altive Chat は、チャットの表示モデル、UIコンポーネントと操作契約を提供する
マルチプラットフォームライブラリです。認証・送信・永続化は利用アプリが担当します。

現在は次のパッケージを提供します。

- Flutter: `altive_chat_room`。既存アプリとの互換性を維持します。
- Swift: `AltiveChatCore` と `AltiveChatUI`。iOS 17 以降に対応します。
- Jetpack Compose: `chat-core` と `chat-ui-compose`。
  minSdk 26、compileSdk 37の構成です。

仕様の入口は[`contract/README.md`](contract/README.md)です。
プラットフォーム間で共有する責務と機能差は、
[`contract/chat-ui-contract.md`](contract/chat-ui-contract.md) と
[`contract/feature-matrix.md`](contract/feature-matrix.md) を正本とします。
リンクプレビューの公開APIとUI境界は
[`contract/link-preview-contract.md`](contract/link-preview-contract.md)に定義しています。
リプライの公開model、UI状態、appとの責務境界は
[`contract/reply-message-contract.md`](contract/reply-message-contract.md)に定義しています。

## 配布方法と識別子

ソースコードの正規リポジトリは
[`altive/altive-chat`](https://github.com/altive/altive-chat)です。
リポジトリ名と各プラットフォームのパッケージ名は別の識別子です。
既存利用との互換性のため、パッケージ名・import名・Maven coordinatesは変更しません。

| プラットフォーム | パッケージ・製品 | 導入方法 |
| --- | --- | --- |
| Flutter | `altive_chat_room` | このリポジトリへのGit依存、またはローカルpath依存 |
| Swift | `AltiveChatCore` / `AltiveChatUI` | このリポジトリへのSwift Package Manager依存 |
| Android | `jp.co.altive.chat:chat-core` / `jp.co.altive.chat:chat-ui-compose` | ソースから生成したローカルMaven成果物、またはcomposite build |

Flutterは`publish_to: none`を維持し、pub.devへは公開しません。
AndroidのMaven公開先は固定していません。ソースコードの公開とMaven成果物の公開は別であり、
Maven Central等から取得できることを前提にしないでください。
ビルド・配布手順は[`android/README.md`](android/README.md)を参照してください。

## Flutter

Flutter パッケージは従来どおりリポジトリルートの `lib/`、`test/`、`example/` に
配置しています。既存利用側の `path` dependency と import path は変更しません。

### 特徴

- チャット画面ウィジェット: `AltiveChatRoom`
- テキスト、画像、スタンプ、音声通話、システムメッセージ
- `AltiveChatRoomTheme` によるテーマカスタマイズ
- メッセージバブル、汎用メッセージカード、ポップアップメニュー、アクションの拡張コールバック

### Git依存

```yaml
dependencies:
  altive_chat_room:
    git:
      url: https://github.com/altive/altive-chat.git
      ref: main
```

`main`は導入確認用の例です。継続利用では`LICENSE`を含むリリースタグまたは
コミットSHAへ`ref`を固定し、利用アプリの`pubspec.lock`も管理してください。
リポジトリがPrivateの間はGitHubへの読み取り認証が必要です。

### ローカル参照

リポジトリを隣の`altive-chat/`へcloneした場合の例です。
既存checkoutを改名する必要はなく、`path`は手元の配置に合わせてください。

```yaml
dependencies:
  altive_chat_room:
    path: ../altive-chat
```

### 使い方

最小構成の例:

```dart
import 'package:altive_chat_room/altive_chat_room.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    const me = ChatUser(
      id: '1',
      name: 'Me',
      avatarImageUrl: 'https://example.com/avatar_me.png',
    );
    const other = ChatUser(
      id: '2',
      name: 'Other',
      avatarImageUrl: 'https://example.com/avatar_other.png',
    );

    final messages = <ChatMessage>[
      ChatTextMessage(
        id: 'm1',
        createdAt: DateTime.now(),
        sender: other,
        text: 'Hello!',
      ),
    ];

    return AltiveChatRoom(
      theme: const AltiveChatRoomTheme(),
      currentUserId: me.id,
      messages: messages,
      draftPolicy: ChatDraftPolicy(
        maximumLength: 1_000,
        warningThreshold: 900,
        lengthUnit: ChatDraftLengthUnit.utf16,
      ),
      onSendIconPressed: (value) {
        // 送信処理
      },
    );
  }
}
```

ステッカーは`ChatMessageContent.sticker`として渡します。catalog取得、固定revisionの
asset検証と画像dataの解決はアプリ側で行い、表示寸法、読み込み・失敗・再試行、
送信状態はパッケージが揃えます。

```swift
let stickerLoader = ChatStickerImageLoader { reference in
  let asset = try await stickerRepository.asset(for: reference)
  return ChatResolvedSticker(
    imageData: try await stickerRepository.imageData(for: asset),
    accessibilityLabel: asset.accessibilityLabel
  )
}
```

削除確認はpackageの共通UIを表示し、削除が選ばれた場合だけアプリ側の処理を実行します。

```dart
final shouldDelete = await showChatDeletionConfirmation(
  context: context,
  strings: const ChatDeletionConfirmationStrings(
    title: 'メッセージを削除しますか？',
    message: 'この操作は取り消せません。',
    deleteButton: '削除',
    cancelButton: 'キャンセル',
  ),
);
if (shouldDelete) {
  await repository.deleteMessage(messageId);
}
```

詳細なサンプルは `example/lib/main.dart` を参照してください。

## SwiftUI

Swift Package Manager は次の2製品を提供します。

- `AltiveChatCore`: Foundationだけに依存する表示モデル、入力方針、送信状態、
  楽観的更新、最近使った項目の純粋な状態遷移。
- `AltiveChatUI`: `AltiveChatCore`を利用するSwiftUIコンポーネント。

見た目と操作感は公開contract、theme、Previewとtestを基準とします。
特定の利用アプリの画面や非公開仕様へのアクセスは不要です。

アプリ固有の行を表示するRoomでは、`ChatRoomLayout`と`ChatTimeline`を組み合わせます。
通常起動の末尾表示、指定項目の中央表示、末尾追従、手動／自動の履歴追加、履歴追加時の
位置保持を共通化できます。データ取得、権限、課金、navigationはアプリ側が担当します。

```swift
ChatRoomLayout {
  ChatTimeline(
    timelineID: roomID,
    isReadyForInitialPositioning: hasLoaded,
    initialPosition: highlightedItemID.map(ChatTimelineInitialPosition.item) ?? .latest,
    followLatestTrigger: pendingMessageIDs,
    history: .automatic(
      canLoadOlder: canLoadOlder,
      isLoading: isLoadingOlder,
      anchorID: items.first?.id,
      loadOlderLabel: "以前のメッセージを読み込む",
      onLoadOlder: loadOlder
    )
  ) { _ in
    ForEach(items) { item in
      AppSpecificChatRow(item: item)
        .id(item.id)
    }
  }
} composer: {
  AppSpecificComposer()
}
```

`isReadyForInitialPositioning`は、初期データを行として渡せる状態になってから`true`にします。
SwiftUI版の末尾配置は、実際の最新行が画面内へ表示されることを契約上の成功条件としています。
タイムラインのstackや末尾anchorを変更する場合は、遅延ロードと100件の可変高行を含む
[初期表示の回帰防止条件](contract/chat-ui-contract.md#初期表示の回帰防止条件)を維持してください。

吹き出し、入力欄、送信状態と再送導線、リアクションと長押し操作、ステッカーpicker、
アバター、システムイベントの展開、汎用メッセージカード、複数画像メッセージ、OS標準の複数選択Photos Picker、
キーボードとスタンプ入力面のレイアウト計算を
共通コンポーネントとして提供します。各アプリ固有のStore、権限、外部I/O、課金、
画面遷移はパッケージへ持ち込みません。

Swift Package Managerから正規リポジトリURLを指定します。
次は開発ブランチで導入を確認する例です。

```swift
.package(
  url: "https://github.com/altive/altive-chat.git",
  branch: "main"
)
```

継続利用では`LICENSE`を含むリリースタグを選び、`branch`を`from`または`exact`の
バージョン指定へ変更してください。コミットSHAを固定する場合は`revision`を指定します。
`Package.resolved`も利用アプリ側で管理してください。
リポジトリがPrivateの間はGitHubへの読み取り認証が必要です。

ローカルで統合する場合は、利用側の `Package.swift` から参照します。
パスはclone先に合わせてください。

```swift
.package(path: "../altive-chat")
```

最小構成では、表示するメッセージと入力中テキストをアプリ側が所有します。
ライブラリは再送ボタンや楽観的更新の純粋な状態遷移を提供しますが、実際の送信、
永続化、オフライン方針、ページングはアプリ側が担当します。

```swift
import AltiveChatUI
import SwiftUI

struct ChatScreen: View {
  @State private var draft = ""

  let messages: [ChatMessage]
  let currentUserID: String
  let send: (String) -> Void

  var body: some View {
    AltiveChatRoom(
      messages: messages,
      currentUserID: currentUserID,
      draft: $draft,
      draftPolicy: ChatDraftPolicy(
        maximumLength: 1_000,
        warningThreshold: 900,
        lengthUnit: .utf16
      ),
      onRetry: { messageID in
        // 同じoperation IDで再送
      },
      onSend: send
    )
  }
}
```

画像入力を有効にする場合は、選択中画像もアプリ側で保持します。既定の最大数は4枚です。
`resolvePhotoLibraryItem`では、選択画像を向き補正・縮小・圧縮してアプリ管理の一時ファイルへ
保存し、そのURLを返します。カメラ画面、権限、アップロード、永続化はアプリ側の責務です。

```swift
import AltiveChatUI
import PhotosUI
import SwiftUI

struct ImageChatScreen: View {
  @State private var draft = ""
  @State private var imageDrafts: [ChatImageDraft] = []

  let messages: [ChatMessage]
  let currentUserID: String
  let makeImageDraft: @Sendable (PhotosPickerItem) async throws -> ChatImageDraft

  var body: some View {
    AltiveChatRoom(
      messages: messages,
      currentUserID: currentUserID,
      draft: $draft,
      imageDrafts: $imageDrafts,
      imageInputConfiguration: .init(maximumSelectionCount: 4),
      onRequestCamera: {
        // アプリ側のカメラ画面を表示し、結果をimageDraftsへ追加
      },
      resolvePhotoLibraryItem: { item in
        try await makeImageDraft(item)
      },
      onImagePreparationFailure: { error in
        // AlertやToastを表示
      },
      onImageTap: { messageID, imageIndex in
        // アプリ側の画像ビューアを表示
      },
      onSubmit: { submission in
        // submission.textとsubmission.imagesを同じ送信操作として保存・アップロード
      }
    )
  }
}
```

## Jetpack Compose

Android実装はFlutter exampleから独立した`android/` Gradle projectです。

- `chat-core`: UI frameworkに依存しない表示モデル、入力方針、送信状態、
  リアクションの楽観的更新、最近使った項目。
- `chat-ui-compose`: Room、Composer、再送UI、リアクション、ステッカーpicker、
  アバター、システムイベント、汎用メッセージカード、タイムライン境界、複数画像入力と画像メッセージ。

アプリ固有の行を表示するRoomでは、SwiftUI版と同じ責務分担で`ChatTimeline`を使用します。
通常起動は`Latest`、通知・ディープリンクは`Item(id)`を渡し、末尾追従、手動／自動の
履歴追加、追加後の位置保持をライブラリへ任せます。取得処理と行の内容はアプリ側が所有します。

```kotlin
val initialPosition = highlightedItemId
  ?.let { ChatTimelineInitialPosition.Item(it) }
  ?: ChatTimelineInitialPosition.Latest

ChatTimeline(
  timelineId = roomId,
  itemIds = items.map(Item::id),
  itemIndex = { id -> items.indexOfFirst { it.id == id }.takeIf { it >= 0 } },
  latestItemIndex = items.lastIndex,
  isReadyForInitialPositioning = hasLoaded,
  initialPosition = initialPosition,
  followLatestTrigger = pendingMessageIds,
  history = ChatTimelineHistoryConfiguration.automatic(
    canLoadOlder = canLoadOlder,
    isLoading = isLoadingOlder,
    anchorId = items.firstOrNull()?.id,
    loadOlderLabel = "以前のメッセージを読み込む",
    onLoadOlder = ::loadOlder,
  ),
) {
  items(items, key = Item::id) { item -> AppSpecificChatRow(item) }
}
```

Composeでも`ChatMessageContent.Sticker`と`ChatStickerImageLoader`を使用します。
loaderは検証済み画像dataだけを返し、RepositoryやFirebaseをpackageへ渡しません。

```kotlin
val stickerLoader = ChatStickerImageLoader { reference ->
  val asset = stickerRepository.asset(reference)
  ChatResolvedSticker(
    imageData = stickerRepository.imageData(asset),
    accessibilityLabel = asset.accessibilityLabel,
  )
}
```

開発中にソースから利用する場合は、利用アプリ側の`settings.gradle.kts`で
composite buildとして追加し、`jp.co.altive.chat:chat-core`と
`jp.co.altive.chat:chat-ui-compose`をprojectへ置換します。絶対pathは
local property等から注入し、リポジトリへcommitしません。
ローカルMaven成果物の生成と任意のリモートMavenへの公開手順は
[`android/README.md`](android/README.md)を参照してください。

```kotlin
var draft by remember { mutableStateOf("") }

AltiveChatRoom(
  messages = messages,
  currentUserId = currentUserId,
  draft = draft,
  onDraftChange = { draft = it },
  draftPolicy = ChatDraftPolicy(
    maximumLength = 1_000,
    warningThreshold = 900,
    lengthUnit = ChatDraftLengthUnit.Utf16,
  ),
  onRetry = viewModel::retry,
  onSend = viewModel::send,
)
```

画像入力はOS標準Photo Pickerを使用し、写真一覧を入力欄内へ埋め込む設定は公開しません。
非対応端末でのフォールバックを含む契約は
[`contract/android-image-message-design.md`](contract/android-image-message-design.md)を参照してください。
カメラ、URIの正規化・圧縮、アップロード、永続化、画像ローダーはアプリ側が担当します。

```kotlin
var draft by remember { mutableStateOf("") }
var imageDrafts by remember { mutableStateOf(emptyList<ChatImageDraft>()) }

AltiveChatRoom(
  messages = messages,
  currentUserId = currentUserId,
  draft = draft,
  onDraftChange = { draft = it },
  imageDrafts = imageDrafts,
  onImageDraftsChange = { imageDrafts = it },
  imageInputConfiguration = ChatImageInputConfiguration(maximumSelectionCount = 4),
  resolvePhotoLibraryUri = viewModel::makeImageDraft,
  onRequestCamera = {
    // アプリ側のカメラ画面を表示し、結果をimageDraftsへ追加
  },
  onImagePreparationFailure = viewModel::showImageError,
  imageContent = { image ->
    AsyncImage(
      model = when (val resource = image.resource) {
        is ChatImageResource.LocalUri -> resource.value
        is ChatImageResource.RemoteUrl -> resource.value
      },
      contentDescription = image.accessibilityLabel,
      modifier = Modifier.fillMaxSize(),
      contentScale = ContentScale.Crop,
    )
  },
  onImageTap = viewModel::openImageViewer,
  onSubmit = viewModel::send,
)
```

## 開発

全プラットフォームをまとめて検証:

```bash
make verify
```

Flutter:

```bash
make flutter_verify
```

SwiftUI:

```bash
make swift_verify
```

Android/Compose:

```bash
make android_verify
```

Flutter example の起動:

```bash
cd example
flutter pub get
flutter run
```

## ライセンス

Altive Chatは[MIT License](LICENSE)で提供します。
利用・改変・再配布時は著作権表示とライセンス文を保持してください。
依存する第三者ライブラリや、利用アプリが用意する画像・データには、それぞれの
ライセンスと権利条件が適用されます。
