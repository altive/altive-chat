import 'package:altive_chat_room/altive_chat_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 履歴取得時の表示確認に使う短いテキストメッセージを作る。
ChatTextMessage _message(int index) => ChatTextMessage(
  id: 'message_$index',
  createdAt: DateTime.now().subtract(Duration(minutes: index)),
  sender: const ChatUser(id: 'me', name: 'Me', avatarImageUrl: 'data:'),
  text: '$index',
);

/// 初回履歴と日付ラベルの回帰テスト。
void main() {
  testWidgets('初回ページが画面を満たさない場合はスクロール可能になるまで履歴を取得する', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var messages = [_message(0)];
    var loadCount = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return AltiveChatRoom(
              theme: const AltiveChatRoomTheme(),
              currentUserId: 'me',
              messages: messages,
              onSendIconPressed: (_) {},
              onScrollToTop: () {
                loadCount++;
                // 2回目の追加取得で表示領域を満たす履歴を渡す。
                rebuild(
                  () => messages = List.generate(
                    loadCount == 1 ? 5 : 30,
                    _message,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(loadCount, 2);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('日付文字列を呼び出し側で日本語に変更できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AltiveChatRoom(
          theme: const AltiveChatRoomTheme(),
          currentUserId: 'me',
          messages: [_message(0)],
          onSendIconPressed: (_) {},
          dateTextFormatter: (_) => '今日',
        ),
      ),
    );
    expect(find.text('今日'), findsOneWidget);
  });
}
