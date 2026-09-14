# Reply message contract

## 目的

SwiftUI、Jetpack Compose、Flutterで同じ状態と操作結果を持つリプライ機能を提供する。
AltiveChatは返信先の取得や永続化を行わず、利用アプリが検証して渡した軽量な返信参照を表示する。

本書はAltiveChat内の公開model、Composer、表示、操作契約の正本とする。Firestoreなどの
保存schemaは対象外とし、利用アプリごとに本書の表示modelへ変換する。

## 基本方針

- `ChatMessage`全体を返信先へ入れず、再帰しない`ChatReplyReference`を使用する。
- 返信参照は対象messageが現在のpageに存在しなくても単独で表示できるsnapshotとする。
- packageは選択中の返信先、選択preview、送信済みmessage内の引用表示を所有する。
- appは権限、保存、対象messageの検証、引用tap後の取得とnavigationを所有する。
- replyだけでは送信できない。本文、画像、ステッカーのいずれかが必要である。
- system messageは既定で返信対象外とする。

## 責務

AltiveChatが所有する。

- 返信可能な標準messageから`ChatReplyReference`を作る変換
- 長押し操作内の返信actionと、選択中の返信先の置換・取消
- 選択中の返信previewと送信済みmessage内の引用表示
- 本文の最大行数、画像・ステッカーthumbnail、欠損時fallback、theme
- 返信action、取消、引用tapのアクセシビリティとローカライズ
- 返信参照を型付きsubmissionへ含め、callback直後にdraftと返信選択を消す状態遷移
- 引用tap時に安定したmessage IDと任意の画像indexを通知する操作契約
- reactionや本文選択など、同じ長押し面にある操作との競合回避

利用アプリが所有する。

- app固有messageと`ChatMessage`、`ChatReplyReference`の相互変換
- Firestoreなどへの返信参照の保存と読込、既存messageのmigration
- 返信元が同じroomに属すること、閲覧可能であること、返信可能であることの検証
- 削除、非表示、block、課金、moderationなどによる操作可否
- 引用tap後の対象message取得、page追加、scrollまたは別画面へのnavigation
- snapshotを保持するか`unavailable`へ置換するかという削除・privacy方針
- 送信時に受け取ったclient snapshotを信頼せず、backendで対象を再検証すること
- Analytics、Push通知、mentionなどのproduct固有動作

AltiveChatはRepository、Firebase SDK、保存document、room ID、通知payloadへ依存しない。

## 表示model

3platformで次の意味を持つ値型を公開する。言語ごとの命名規約には従うが、fieldの意味を
変えない。

### `ChatReplyReference`

| field | 必須 | 内容 |
| --- | --- | --- |
| `messageId` | Yes | 返信元を識別する安定したmessage ID |
| `senderId` | Yes | 送信者判定とapp側検証に使う安定したuser ID |
| `senderDisplayName` | Yes | 対象messageを再取得せず表示できる送信時点の表示名 |
| `content` | Yes | 再帰しない`ChatReplyPreviewContent` |
| `imageIndex` | No | 複数画像の特定画像への返信。message全体への返信では`nil` |

avatar、作成日時、delivery state、reaction、link preview、元messageの`replyTo`は含めない。
これにより返信の入れ子を防ぎ、引用表示をpageやappのdomain modelから独立させる。

### `ChatReplyPreviewContent`

次の閉じた型を共通化する。

- `text(value)`: 通常本文。表示は最大2行とし、model値自体は切り詰めない。
- `image(thumbnail, caption, totalCount)`: 画像。`thumbnail`と`caption`は任意、
  `totalCount`は1以上とする。特定画像への返信ではその画像をthumbnailに使用する。
- `sticker(reference)`: 構造化されたステッカー参照。
- `label(value)`: 汎用カードなど、標準型にないが短い文言で安全に表せる内容。
- `unavailable`: 削除・非表示・権限不足など、内容を表示してはならない状態。

`image.thumbnail`には既存の`ChatImage`、`sticker.reference`には既存の
`ChatStickerReference`を使用し、画像の実dataや認証情報を保持しない。画像loaderと
sticker loaderも既存のRoom設定を再利用する。

## 公開interface

### Core model

Swift / Kotlinでは既存modelへdefault `nil`の任意propertyを加える。

```swift
public struct ChatMessage {
  public let replyTo: ChatReplyReference?
}

public struct ChatComposerSubmission {
  public let replyTo: ChatReplyReference?
}
```

```kotlin
data class ChatMessage(
  // 既存field
  val replyTo: ChatReplyReference? = null,
)

data class ChatComposerSubmission(
  // 既存field
  val replyTo: ChatReplyReference? = null,
)
```

Flutterは既存の`replyTo: ChatUserMessage?`を直ちに型変更しない。新しい
`replyReference: ChatReplyReference?`を追加し、表示と新規送信ではこちらを正本とする。
`replyTo`と`replyImageIndex`はdeprecatedな互換入力として次のmajor versionまで維持し、
新旧両方が渡された場合は`replyReference`を優先する。legacy値は表示直前に非再帰snapshotへ
変換し、返信への返信を保持しない。`ChatComposerSubmission`へdefault `null`の
`replyTo`を追加する。

```dart
sealed class ChatReplyPreviewContent extends Equatable { /* closed variants */ }

class ChatReplyReference extends Equatable {
  const ChatReplyReference({
    required this.messageId,
    required this.senderId,
    required this.senderDisplayName,
    required this.content,
    this.imageIndex,
  });
}

class ChatComposerSubmission extends Equatable {
  const ChatComposerSubmission({
    // 既存field
    this.replyTo,
  });
  final ChatReplyReference? replyTo;
}
```

### Room configuration

Roomは任意の`ChatReplyConfiguration`を受け取る。未指定時は返信actionを表示せず、既存の
consumerの操作を変えない。

返信参照を渡せない旧式の文字列send callbackだけが接続されている場合も返信actionを
表示しない。返信を有効化するconsumerは`ChatComposerSubmission`を受ける型付きcallbackを
接続する。

```text
ChatReplyConfiguration
  canReply(message) -> Bool
  makeReference(message, imageIndex?) -> ChatReplyReference?
  onReferenceTap(messageId, imageIndex?)
```

- `canReply`はpackage既定条件に追加するapp固有条件であり、省略時は標準条件だけを使う。
- 標準条件は「system以外、送信者あり、delivery stateがsent」である。
- `makeReference`を省略した場合、packageがtext、images、images with caption、stickerを
  変換する。`nil`を返したmessageは返信対象外とする。
- `onReferenceTap`は任意。未指定時も引用表示は行うがtap操作は無効にする。
- `makeReference`はapp固有contentの表示変換用であり、保存やnetwork accessを行わない。

各platformでは同じ意味を保ちつつ、Swiftのclosure、Kotlinのfunction type、Dartのtypedefを
使用する。選択中の返信先はRoom内部の一時UI stateとし、app側のStoreへ重複保持させない。

## 操作と状態遷移

1. 利用者が返信可能なmessageまたは画像を長押しし、返信actionを選ぶ。
2. packageが軽量snapshotを作り、既存の選択を置き換えてComposerへfocusする。
3. 選択中の対象messageと取消操作を入力欄の近くへ表示する。
4. 本文、画像、ステッカーのいずれかと一緒に送信すると、同じsnapshotを
   `ChatComposerSubmission.replyTo`へ含める。
5. packageは送信callback呼出し直後に入力内容、添付、ステッカー、返信選択を消す。
6. appは安定した新規message IDを発行し、`replyTo`を持つsending messageを一覧へ再注入する。
7. 成否は同じmessage IDのdelivery stateで更新する。失敗時の再送にも同じreply snapshotを使う。

返信選択だけがある状態ではsend buttonを有効にしない。返信対象がpage外へ出ても選択中の
snapshotは維持する。送信時に対象が削除済みなどで無効なら、app/backendが通常の
送信失敗と同じ契約で反映する。

返信済みmessage内の引用をtapした場合、packageは`messageId`と`imageIndex`だけを通知する。
URLやbackend pathは渡さない。appは必要なら履歴を取得し、既存の型付きtimeline位置指定を
使って対象へ移動する。

## 表示契約

- 引用は本文・画像・ステッカーの前に置き、返信messageの吹き出し内で一体表示する。
- 送信者名は1行、本文またはlabelは最大2行、thumbnailは固定上限内で縦横比を維持する。
- `imageIndex`が不正でもcrashせず、渡されたthumbnailまたは画像labelへfallbackする。
- `unavailable`はpackageのlocalized stringで「このメッセージは表示できません」相当を
  表示する。
- 選択中の返信previewには明示的な取消buttonを44pt / 48dp相当のhit targetで提供する。
- 引用全体を1つのアクセシビリティ要素として、返信先、送信者名、内容の順に
  読み上げる。
- context menu、popover、hapticなどの外観はOS標準を優先し、操作結果だけを揃える。

SwiftUIでは選択中にタイムラインだけへblurをかけ、元の大きさを保った対象messageを
入力欄の直上へ重ねて表示する。入力欄自体はblurせず、選択中も通常どおり入力できること。

## 後方互換性

- `replyTo == nil`を既定とし、未対応messageは従来どおり表示する。
- `ChatReplyConfiguration`未指定時は返信開始UIを追加しない。ただし渡された`replyTo`の
  引用表示は行い、read-only consumerでも履歴を正しく表示できるようにする。
- Swift / Kotlinのinitializerとsubmission factoryはdefault引数でsource互換を維持する。
- Flutterは既存の`replyToMessageBar`をdeprecatedにし、新しいpackage標準barを優先する。
  移行期間後にapp注入barを削除し、platform間の表示差分を残さない。
- 保存済みmessageに返信fieldがない場合、appのreaderは`nil`へ変換する。
- 保存schemaの未知のpreview kindは`unavailable`へ変換し、message全体は表示し続ける。

## 共通fixtureと検証

[`reply-message-cases.json`](fixtures/reply-message-cases.json)を表示modelの共通fixtureとし、
少なくとも次を3platformで復元する。

- 自分・相手のtextへの返信、長文、改行、絵文字
- 単一画像、複数画像の先頭、特定index、範囲外index、captionあり
- sticker、label、unavailable
- 返信への返信が再帰せず、直近の対象内容だけを引用すること
- sending、sent、failedと同一ID再送
- 対象が現在pageにない状態と、引用tap callback

Core testではmodel変換、標準返信可否、入れ子除去、submissionを検証する。UI testでは
選択、置換、取消、空送信抑止、callback直後のclear、長押し競合、文字拡大、light / dark、
画像失敗を検証する。fixtureとvisual testは外部networkへ接続しない。

## 利用アプリへの導入

1. 保存済みデータを軽量な返信参照へ変換し、欠損fieldと未知kindのfallbackを確認する。
2. 返信を有効化する画面で型付きsubmission callbackと`ChatReplyConfiguration`を接続する。
3. 権限・保存・対象messageの再検証、引用tap後の取得とnavigationを利用アプリ側で実装する。
4. 対象platformで選択・取消・引用表示・再送・対象がpage外にある状態を統合検証する。

公開API・互換性の判断は本書に従い、製品固有の導入順と承認は利用側で管理する。
