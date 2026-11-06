# 構造化イベントと会話のまとまり

## 互換性と責務

既存の本文カード、独立camera、公開callbackと保存modelを維持する。新しい配置方針は
呼び出し側が明示選択する。対象名、変化、操作主体、時刻、詳細と業務actionは呼び出し側が
解決し、ライブラリは情報階層、余白、入力配置、隣接判定だけを所有する。

## 構造化システム要約

SwiftUI、Compose、Flutterは`ChatSystemEventSummary(title, value, metadata, details?)`を提供する。
全引数はローカライズ済み文字列で、`details`だけ省略可能。対象、強調した変化、補足metadata、
詳細の順にleading揃えで折り返す。`value`が空白だけなら変化の行とその余白を表示しない。人が送信した通常メッセージのAvatarを付けない。
SwiftUIとComposeは既存`ChatSystemEventGroup`の`summary`slot内へ配置し、業務操作を既存
`actions`へ渡す。従来の短い本文とカードlaneは中央揃えを維持する。
Flutterは同じ要約Widgetを提供するが、system groupの展開shellは引き続き呼び出し側が所有する。

## 添付配置

SwiftUIの`ChatImageComposer`へ`sourcePresentation: .attachmentMenu`、Composeでは
`sourcePresentation = ChatComposerSourcePresentation.AttachmentMenu`を指定すると、
camera、写真ライブラリ、file、clipboardをこの順の「＋」menuへ集約する。
未提供callback、利用不可sourceはmenuへ出さない。camera準備中のcamera再起動、添付上限超過を
抑止し、既存の写真選択上限、画像paste、送信前preview、失敗通知を維持する。
既定値はSwiftUIの`.separateCamera`、Composeの`SeparateCamera`で従来の独立cameraを維持する。
`additionalSourceButton` / `additionalSourceContent`は集約方針でfocus中も直接表示し、
sticker切替をここへ配置する。stickerのcatalog、権限と選択callbackは既存APIを使用する。

Flutterは`ChatAttachmentMenu(label, labels, sources, onSelected, enabled, cameraEnabled)`を
`AltiveChatRoom.bottomLeadingWidgets`へ渡し、`sourcePresentation: ChatComposerSourcePresentation.attachmentMenu`
でfocus中も維持する。取得処理は`onSelected`から呼び出し側が既存処理へ接続する。
`textFieldSuffixBuilder`のsticker切替は直接操作として維持し、menuへ含めない。

focus、画像準備、sticker入力面を切り替えても入力欄のView/Composable/Widget識別を変えず、
下書き・返信・添付と入力接続を維持する。policyの変更はRoomの構築時に確定する。

## 通常投稿の連続判定

3実装とも`ChatMessageGroupingItem`と`ChatMessageGrouping.isContinuation`を提供する。
入力は表示上のsender ID、発生時刻、`isRegularMessage`、`startsNewGroup`。
直前投稿が存在し、両方が通常投稿、同じ空でないsender、同じ現地日付、時間差が0以上
5分以下の場合だけ連続とする。`startsNewGroup`は現在投稿の直前にある日付・未読・その他境界を表す。
Swiftは`calendar`、Composeは`zoneId`を注入可能。Flutterは端末local timezoneを使用する。
最大時間差は任意設定でき、負の時間差と負の閾値では連続にしない。

呼び出し側は返り値に応じて名前とAvatarの反復を抑え、Avatar列の幅を維持し、行間を狭める。
投稿ID、日時、本文、送信状態、返信、再送、リアクション、削除の操作単位は結合しない。
システム投稿とその後の通常投稿の間でまとまりを切り、履歴page境界も隣接データが確定後に再評価する。

## 履歴追加

SwiftUI/Composeの`ChatTimelineHistoryConfiguration.manual/automatic`は、任意の`failureMessage`
と`retryLabel`を受け付ける。失敗中は上端へ説明と明示再試行を表示し、自動取得を停止する。
同じanchorの要求が無進展で完了した場合も自動再要求を抑止する。
Composeの自動取得jobは取得可否・失敗表示のeffect更新で取消さず、最後のpageでcontrolが消える場合も
位置復元まで完了する。loading中もボタンを測定し、文字拡大・改行を含めてidleと同じ高さを維持する。
取得中にroomや初期配置scopeが切り替わった場合は、新しいscopeへ古い位置を復元しない。取得、cursor、権限、課金判断は
呼び出し側が所有する。SwiftUIのiOS実装では各行の`.id(id)`に続けて`.chatTimelineItem(id)`を付けると、
実ScrollViewの先頭可視IDとviewport内offsetでprepend後の位置を保持する。
集約行は構成元投稿の安定IDを同じ行へ登録でき、行IDが再編成されても元投稿のmarkerから復元する。
iOSの復元は描画frameへの反映後に行い、待機中の送信追従・明示移動を優先する。Taskキャンセル後は復元しない。
macOSの同modifierは互換のためのno-opとし、従来anchorによる復元を維持する。
modifier未採用の既存呼び出し側も従来anchorによる復元を維持する。

## 検証

共通条件は[`fixtures/collaborative-timeline.json`](fixtures/collaborative-timeline.json)に置く。
各実装の純粋判定testで5分境界、負時間、日跨ぎ、sender差、system、未読境界を確認する。
入力は新旧policy、全取得元、添付上限、準備中、sticker、focus中の直接操作を検証する。
要約は長文、狭幅、文字拡大、Dark、RTLで内容欠落と操作領域を確認する。
iOS入力変更は実Simulatorのfocus・keyboard・入力・dismissを含める。
API追加は3実装と公開contractを揃えたSemVer minor候補として検証する。
