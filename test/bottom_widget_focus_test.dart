import 'package:altive_chat_room/altive_chat_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('集約menuは入力中も維持し同じ入力欄に下書きを残す', (tester) async {
    await tester.pumpWidget(
      _testApp(
        sourcePresentation: ChatComposerSourcePresentation.attachmentMenu,
      ),
    );
    final textField = tester.widget<TextField>(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '下書き');
    textField.focusNode!.requestFocus();
    await tester.pump();
    expect(find.byKey(const Key('先頭ボタン')), findsOneWidget);
    expect(find.byKey(const Key('展開ボタン')), findsNothing);
    final updated = tester.widget<TextField>(find.byType(TextField));
    expect(identical(textField.controller, updated.controller), isTrue);
    expect(updated.controller!.text, '下書き');
    expect(updated.focusNode!.hasFocus, isTrue);
  });

  testWidgets('入力欄にフォーカスが当たると先頭ボタンを閉じる', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.byKey(const Key('先頭ボタン')), findsOneWidget);
    expect(find.byKey(const Key('展開ボタン')), findsNothing);

    final textField = tester.widget<TextField>(find.byType(TextField));
    textField.focusNode!.requestFocus();
    await tester.pump();

    expect(find.byKey(const Key('先頭ボタン')), findsNothing);
    expect(find.byKey(const Key('展開ボタン')), findsOneWidget);
  });

  testWidgets('展開ボタンを押すとフォーカスを外して先頭ボタンを再表示する', (tester) async {
    await tester.pumpWidget(_testApp());

    final textField = tester.widget<TextField>(find.byType(TextField));
    textField.focusNode!.requestFocus();
    await tester.pump();

    await tester.tap(find.byKey(const Key('展開ボタン')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('先頭ボタン')), findsOneWidget);
    expect(find.byKey(const Key('展開ボタン')), findsNothing);
    expect(textField.focusNode!.hasFocus, isFalse);
  });

  testWidgets('展開後に入力欄を押すと先頭ボタンを閉じる', (tester) async {
    await tester.pumpWidget(_testApp());

    final textField = tester.widget<TextField>(find.byType(TextField));
    textField.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('展開ボタン')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('先頭ボタン')), findsNothing);
    expect(find.byKey(const Key('展開ボタン')), findsOneWidget);
    expect(textField.focusNode!.hasFocus, isTrue);
  });
}

Widget _testApp({
  ChatComposerSourcePresentation sourcePresentation =
      ChatComposerSourcePresentation.separateCamera,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AltiveChatRoom(
        theme: const AltiveChatRoomTheme(),
        currentUserId: 'current-user',
        messages: const [],
        onSendIconPressed: (_) {},
        expandButtonIcon: const Icon(
          Icons.arrow_forward_ios,
          key: Key('展開ボタン'),
        ),
        sourcePresentation: sourcePresentation,
        bottomLeadingWidgets: [
          IconButton(
            key: const Key('先頭ボタン'),
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ),
  );
}
