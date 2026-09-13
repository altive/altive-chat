# SwiftUI 画像メッセージ設計

> 実装済み。公開APIの利用例と責務分担を含む実装仕様として維持する。

## 目的

SwiftUI版のチャット入力欄で、テキストフィールドの左にカメラボタンと写真取得元menuを
表示し、取得した画像を確認して送信できるようにする。また、送信中、送信済み、
送信失敗の画像メッセージをテキストメッセージと同じタイムラインへ表示する。

本設計では、チャットUIの再利用性を保つため、画像取得と外部I/Oを分離する。
`AltiveChatUI`は写真ライブラリのPickerと選択状態を所有するが、Pickerから得た画像の
正規化、カメラ、権限、アップロード、永続化は所有しない。

## 対象範囲

本仕様では次を対象とする。

- カメラの独立ボタンと、写真ライブラリ・file・clipboardをまとめる写真menu
- 写真ライブラリのOS標準シート表示
- 入力欄の標準paste操作による画像添付とplain text pasteの維持
- 複数画像の選択、プレビュー、個別取り消し、送信
- 1回の送信操作で指定できる最大画像数をアプリから注入し、既定値は4枚
- テキストだけ、画像だけ、テキストと画像の同時送信
- ローカル一時ファイルを使った楽観的な画像メッセージ表示
- リモート画像メッセージの表示、読み込み中、読み込み失敗
- 画像タップのコールバック
- 既存の送信中、送信失敗、再送UIとの統合

画像は複数選択と複数表示へ対応する。アプリが指定する最大数にPackage固有の
上限は設けないが、1以上を要求する。動画、Live Photos、画像編集、選択後の並び替え、
全画面ビューアは本仕様の対象外とする。

## 写真ライブラリの表示方式

写真menu内の「写真ライブラリ」を`PhotosPicker`のlabelとして使用し、iOS標準のPickerを
画面上へ表示する。
OS標準の検索、アルバム、複数選択、プライバシー保護をそのまま利用でき、実装と保守が
最も小さい。選択順を保持するため`selectionBehavior: .ordered`を使う。

写真一覧はキーボードやステッカー入力面へ埋め込まない。表示方式を切り替える設定は
公開せず、常にOS標準シートを表示する。

## 責務の境界

| AltiveChatが所有する | アプリが所有する |
| --- | --- |
| カメラ・写真menuの配置、見た目、アクセシビリティ | カメラ画面の表示とdismiss |
| 写真menuと入力欄からの画像paste検出 | file pickerのpresentationと取得画像の読み出し |
| `PhotosPicker`の標準シート表示と一時的な選択状態 | カメラ利用可否と権限状態の判定 |
| 最大選択数、選択順、残り選択可能数の制御 | `PhotosPickerItem`と撮影結果の正規化 |
| 複数画像プレビュー、個別削除、送信導線 | EXIF orientationの正規化、縮小、圧縮、形式変換 |
| 単一／複数画像メッセージと読み込み状態の表示 | Packageが読める一時ファイルの作成と寿命管理 |
| 送信中・失敗表示、再送操作の通知 | Storageへのアップロード、Firestore等への永続化 |
| 画像タップ時のメッセージIDと位置の通知 | 全画面ビューアや画面遷移 |
| 標準URLローダーと差し替え可能な読み込み契約 | 認証付き取得、キャッシュ、再試行方針 |

`AltiveChatCore`はFoundationだけに依存する。`AltiveChatUI`は標準Pickerのために
`PhotosUI`へ依存するが、`AVFoundation`、Firebase SDK、アプリのStoreへ依存しない。
特にカメラ権限はホストアプリの`Info.plist`と画面遷移に関係するため、アプリ側に残す。

## 値モデル

### 画像取得元

`AltiveChatUI`に入力元と最大選択数の設定を提供する。

```swift
public enum ChatImageInputSource: Hashable, Identifiable, Sendable {
  case camera
  case photoLibrary
  case file
  case clipboard

  public var id: Self { self }
}

public struct ChatImageInputConfiguration: Hashable, Sendable {
  public var maximumSelectionCount: Int

  public init(maximumSelectionCount: Int = 4) {
    precondition(maximumSelectionCount > 0)
    self.maximumSelectionCount = maximumSelectionCount
  }
}
```

写真ライブラリとclipboardの標準paste controlはPackageが表示する。アプリは
`onRequestCamera`と`onRequestImageFiles`を受け、カメラ画面と標準file pickerを表示する。
カメラを利用できない端末などでは、
`availableImageInputSources`から`.camera`を除外する。

### 選択中の画像

Picker固有型や`UIImage`を`AltiveChatCore`へ含めず、アプリが一時ファイルへ正規化した
後の値だけをCoreへ渡す。`AltiveChatUI`は`PhotosPickerItem`ごとの非同期resolverを
アプリから受け取り、解決済みの`ChatImageDraft`をBindingへ追加する。

```swift
public struct ChatImageDraft: Hashable, Identifiable, Sendable {
  public let id: String
  public let fileURL: URL
  public let pixelWidth: Int?
  public let pixelHeight: Int?
  public let accessibilityLabel: String?
}

public struct ChatComposerSubmission: Hashable, Sendable {
  public let text: String?
  public let images: [ChatImageDraft]
}
```

`fileURL`はPackageから読み取れるローカルファイルURLに限定する。アプリは選択開始時に
処理中状態を表示し、Pickerが返したデータをアプリ管理の一時領域へコピーしてから
`imageDrafts` Bindingを更新する。セキュリティスコープやPhotos Pickerの一時URLを
そのまま長期保持しない。アプリは送信成功、送信の明示的な破棄、または再送不要の確定まで
一時ファイルを保持し、その後に削除する。

`ChatComposerSubmission`は正規化後のテキストと選択画像を1回のコールバックで渡す。
少なくとも一方が存在する場合だけ生成する。アプリは1回のsubmissionを1つの複合Entityへ
保存しても、同じclient operationに属する画像メッセージとテキストメッセージへ分けてもよい。
Packageから画像用、テキスト用の2コールバックを別々に呼ばない。

Packageは一時的な`PhotosPickerItem`と、resolverが返した`ChatImageDraft.ID`の対応を保持する。
これにより、写真由来とカメラ由来のドラフトを区別し、写真の選択解除時に対応するドラフトだけを
削除できる。`PhotosPickerItem`自体は送信値や永続化対象に含めない。

### 表示する画像

送信中はローカル一時ファイル、送信確定後はリモートURLを表示できるようにする。

```swift
public enum ChatImageResource: Hashable, Sendable {
  case localFile(URL)
  case remote(URL)
}

public struct ChatImage: Hashable, Identifiable, Sendable {
  public let id: String
  public let resource: ChatImageResource
  public let pixelWidth: Int?
  public let pixelHeight: Int?
  public let accessibilityLabel: String?
}

public enum ChatMessageContent: Hashable, Sendable {
  case text(String)
  case images([ChatImage])
  case system(String)
}
```

`.images`は1件以上を前提とする。送信前後でメッセージIDと画像IDを維持し、アプリが
`resource`と`deliveryState`を差し替える。

## AltiveChatUIの公開API

既存のテキスト専用initializerは維持する。画像機能を使う場合だけ、次の引数を指定する。

```swift
AltiveChatRoom(
  messages: messages,
  currentUserID: currentUserID,
  draft: $draft,
  imageDrafts: $imageDrafts,
  imageInputConfiguration: .init(maximumSelectionCount: 4),
  availableImageInputSources: [.camera, .photoLibrary],
  isPreparingCameraImage: isPreparingCameraImage,
  imageLoader: imageLoader,
  onRequestCamera: {
    presentedImagePicker = .camera
  },
  onRequestImageFiles: {
    isShowingImageFileImporter = true
  },
  onPasteImages: { providers in
    imageDraftFactory.appendPastedImages(from: providers)
  },
  resolvePhotoLibraryItem: { item in
    try await imageDraftFactory.makeDraft(from: item)
  },
  onImagePreparationFailure: { error in
    imageInputError = error
  },
  onImageTap: { messageID, imageIndex in
    // アプリの画像ビューアを表示
  },
  onSubmit: { submission in
    chatStore.send(submission)
  },
  onRetry: chatStore.retry
)
```

入力は次のとおりとする。

```swift
imageDrafts: Binding<[ChatImageDraft]> = .constant([])
imageInputConfiguration: ChatImageInputConfiguration = .init()
availableImageInputSources: Set<ChatImageInputSource> = []
isPreparingCameraImage: Bool = false
isSending: Bool = false
imageLoader: ChatImageLoader = .standard
onRequestCamera: (() -> Void)? = nil
onRequestImageFiles: (() -> Void)? = nil
onPasteImages: (([NSItemProvider]) -> Void)? = nil
onPasteUnavailable: (() -> Void)? = nil
resolvePhotoLibraryItem: (@Sendable (PhotosPickerItem) async throws -> ChatImageDraft)? = nil
onImagePreparationFailure: ((Error) -> Void)? = nil
onImageTap: ((_ messageID: String, _ imageIndex: Int) -> Void)? = nil
onSubmit: (ChatComposerSubmission) -> Void
```

`onPasteUnavailable`は、system paste操作から利用可能な画像providerが渡されなかった場合だけ
通知する。アプリは空状態を実エラーへ変換せず、画像をコピーしてから再操作する案内を表示する。
providerの読込、decode、正規化に失敗した場合は`onPasteImages`以降のアプリ側処理で実エラーとして
扱う。

画像対応initializerでは`AltiveChatUI`の公開APIに`PhotosPickerItem`が現れる。これは
UI targetだけの契約とし、CoreやアプリのStore／Entityへ保存しない。既存の
`onSend: (String) -> Void` initializerは維持し、内部でテキストだけのsubmissionと同じ
正規化規則を使う。

`ChatImageLoader`は画像resourceからデータを非同期取得する軽量なclosure clientとする。
```swift
public struct ChatImageLoader: Sendable {
  public init(loadData: @escaping @Sendable (ChatImageResource) async throws -> Data)
  public func data(for resource: ChatImageResource) async throws -> Data
}
```

標準実装はローカルファイルと通常のHTTP(S) URLを読み込む。認証ヘッダーや独自キャッシュが
必要なアプリは差し替える。ロード結果のデコード、プレースホルダー、失敗表示はUI側が
担当し、キャンセルは通常終了として扱う。

## Composerの振る舞い

1. テキストフィールドの左に、SF Symbolsの`camera`と`photo`を使う44pt以上のタップ領域を置く。
2. `availableImageInputSources`に含まれるボタンだけを表示する。
3. カメラボタン押下時はキーボードを閉じ、`onRequestCamera`を通知する。
4. 写真ボタン押下時はキーボードを閉じ、OS標準の複数選択Pickerを表示する。
7. 新規追加可能数は`maximumSelectionCount - imageDrafts.count`とし、0なら両画像入力を無効化する。
8. 写真選択順を保持し、各項目をresolverで非同期処理する。選択解除された項目の処理はcancelする。
9. プレビューは横スクロールとし、全画像に選択順と個別削除ボタンを表示する。
10. 画像選択中もテキストフィールドを編集可能にする。
11. 送信ボタンは正規化済みテキストまたは1枚以上の画像があれば有効にする。
12. 送信時はテキストと全画像を1つの`ChatComposerSubmission`として`onSubmit`へ渡す。
13. コールバック呼び出し後にテキスト、画像、`PhotosPickerItem`の選択状態をまとめて空にする。
14. アプリはコールバック内で安定したIDの`.sending`メッセージを即座に追加する。

写真項目の解決中は送信を無効化し、項目単位の`ProgressView`を表示する。1項目だけ失敗した
場合は成功済みの画像を保持し、失敗項目を選択から外してアプリへエラーを通知する。
送信可否に使う処理中状態は、Package内の写真resolver実行状態とアプリから渡された
`isPreparingCameraImage`の論理和とする。
ボタン順は`Set`の列挙順に依存させず、カメラを独立して先頭に置き、写真menu内を常に
写真ライブラリ、file、clipboardの順とする。

`PhotosPicker.maxSelectionCount`には、現在選択済みの写真を含めた
`maximumSelectionCount - cameraDraftCount`を渡す。単純な新規追加可能数は渡さない。
アプリが実行中に上限を現在の選択数より小さく変更した場合、既存ドラフトは暗黙に削除せず、
追加だけを無効化して、ユーザーが上限以下まで個別削除できるようにする。

## タイムラインの振る舞い

- 1枚は縦横比を尊重した単一表示、2枚は2列、3枚は先頭を大きくして残りを並べ、
  4枚は2x2で表示する。
- 5枚以上では先頭4枚を2x2で表示し、4枚目に残り枚数を`+N`で重ねる。
- 極端な比率でも画像メッセージの最大幅と最大高を超えないようにする。
- 送信中のローカル画像にもリモート画像と同じレイアウトを適用し、切り替え時の跳ねを抑える。
- 読み込み中は画像領域と同じ比率のプレースホルダーを出す。
- 読み込み失敗は画像領域内に再読み込み可能な失敗表示を出す。メッセージ送信失敗の
  `ChatDeliveryIndicator`とは意味を分ける。
- 送信中は既存の`ChatDeliveryIndicator`を表示する。
- 送信失敗時はローカル画像を保持したまま既存の再送操作を通知する。
- 画像タップ時は`messageID`と配列indexをアプリへ返す。Packageは画面遷移を行わない。
- VoiceOverでは`accessibilityLabel`を優先し、未指定時はローカライズした「画像」を使う。
- カメラ、写真ライブラリ、画像削除、画像送信、画像読み込み失敗にもPackage内の
  ローカライズ済みアクセシビリティ文言を用意する。

## アプリ側の処理フロー

```text
ボタン操作
  -> camera: アプリが権限確認とカメラ表示
  -> photoLibrary: PackageがOS標準のPhotosPickerを表示
  -> Packageが選択順と最大数を管理
  -> アプリのresolverが各PhotosPickerItemを読み出す
  -> 取得結果を向き補正・縮小・圧縮
  -> アプリ管理の一時ファイルへ保存
  -> imageDrafts Bindingへ反映
  -> ユーザーが必要に応じてテキストを入力して送信
  -> onSubmit(text + images)
  -> ローカルURLを持つ sending メッセージとテキストを即時追加
  -> Storageへアップロード
  -> 成功: 同じIDのremote URL + sentへ更新
  -> 失敗: ローカルURLを維持してfailedへ更新
```

キャンセル時はBindingを変更しない。読み出し、加工、保存に失敗した場合はアプリがAlertや
Toastを表示する。カメラ権限が拒否済みの場合の設定画面誘導もアプリが担当する。

写真ライブラリにはSwiftUIの`PhotosPicker`を使用する。選択項目数には、設定された上限から
カメラ由来ドラフト数を除いた値を渡す。選択結果はプレースホルダーであり、
iCloud上の画像読み込みが失敗する可能性があるため、`loadTransferable`の処理中、失敗、
キャンセルを区別する。カメラにはシステムのカメラUIを使用し、利用前にカメラの存在と
権限を確認する。ホストアプリは`NSCameraUsageDescription`を設定する。

## 後方互換

- `ChatMessageContent`へのcase追加は既存アプリの網羅的`switch`でコンパイルエラーを起こし得る。
  SemVer上はminor追加でも、利用アプリの移行を先に確認してからリリースする。
- `AltiveChatRoom`の既存initializerは残し、画像関連引数は既定値で無効にする。
- 画像ボタンは取得元が空の場合に表示しない。カメラは`onRequestCamera`、写真ライブラリは
  resolverがない場合にも対応するボタンを表示しないため、既存画面の見た目と余白は変わらない。
- Flutterの公開APIは変更しない。各platformの対応状況はfeature matrixを参照する。

## ライブラリと利用アプリの検証

公開model、画像loader、画像表示、Picker、Composer、Roomの回帰は、このリポジトリの
単体test、iOS build、Previewとホスト画面で確認する。特定の製品画面を必須参照にしない。
利用アプリはcamera、resolver、一時ファイル、アップロード、永続化を接続し、自身の画面で
選択・送信・失敗・再送を統合検証する。製品固有の導入順とリリース承認は利用側で管理する。

## テスト観点

- 画像機能を指定しない既存initializerでボタンが表示されない。
- 利用可能な取得元に応じて各ボタンが表示され、正しい値をコールバックする。
- OS標準Pickerで複数選択と選択順が維持される。
- 既定上限が4で、アプリ指定上限と残り選択可能数が反映される。
- 写真とカメラを混在させても合計上限を超えず、上限の動的縮小で既存画像を暗黙に削除しない。
- 処理中は多重起動と送信ができず、選択解除で処理がcancelされる。
- 選択、個別削除、送信後のBindingとPicker選択状態が仕様どおり変化する。
- テキストだけ、画像だけ、テキスト＋画像がそれぞれ1回のsubmissionで送信される。
- 空の画像配列を送信しない。
- local、remote、縦長、横長、読み込み中、読み込み失敗を表示できる。
- 送信中、送信失敗、再送操作が画像メッセージでも機能する。
- 画像タップが正しいメッセージIDとindexを返す。
- Dynamic Type、VoiceOver、ダークモードで操作と表示が破綻しない。
- Pickerキャンセル、iCloud取得失敗、権限拒否、アップロード失敗後に復帰できる。

## 参照するApple API

- [PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker)
- [UIImagePickerController](https://developer.apple.com/documentation/uikit/uiimagepickercontroller)
- [Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
