import 'package:altive_chat_room/altive_chat_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('変化の表示値が空なら行と空白を追加しない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatSystemEventSummary(
            title: '対象',
            value: '   ',
            metadata: '操作した人・12:00',
          ),
        ),
      ),
    );
    expect(find.text('   '), findsNothing);
    expect(find.text('対象'), findsOneWidget);
    expect(find.text('操作した人・12:00'), findsOneWidget);
  });

  test('同じ人の同日5分以内だけをまとめる', () {
    final date = DateTime(2026, 11, 6, 12);
    ChatMessageGroupingItem item(
      int seconds, {
      String? sender = 'a',
      bool regular = true,
      bool boundary = false,
    }) => ChatMessageGroupingItem(
      senderId: sender,
      occurredAt: date.add(Duration(seconds: seconds)),
      isRegularMessage: regular,
      startsNewGroup: boundary,
    );
    for (final seconds in [0, 299, 300]) {
      expect(
        ChatMessageGrouping.isContinuation(
          previous: item(0),
          current: item(seconds),
        ),
        isTrue,
      );
    }
    for (final current in [
      item(-1),
      item(301),
      item(1, sender: 'b'),
      item(1, sender: null),
      item(1, sender: ''),
      item(1, regular: false),
      item(1, boundary: true),
    ]) {
      expect(
        ChatMessageGrouping.isContinuation(previous: item(0), current: current),
        isFalse,
      );
    }
    expect(
      ChatMessageGrouping.isContinuation(previous: null, current: item(0)),
      isFalse,
    );
    expect(
      ChatMessageGrouping.isContinuation(
        previous: item(0, regular: false),
        current: item(1),
      ),
      isFalse,
    );
    expect(
      ChatMessageGrouping.isContinuation(
        previous: ChatMessageGroupingItem(
          senderId: 'a',
          occurredAt: DateTime(2026, 11, 5, 23, 59, 59),
        ),
        current: ChatMessageGroupingItem(
          senderId: 'a',
          occurredAt: DateTime(2026, 11, 6),
        ),
      ),
      isFalse,
    );
  });

  testWidgets('添付menuは固定順で取得元を呼び分ける', (tester) async {
    ChatAttachmentSource? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAttachmentMenu(
            label: '添付',
            labels: const {
              ChatAttachmentSource.camera: 'カメラ',
              ChatAttachmentSource.photoLibrary: '写真',
              ChatAttachmentSource.file: 'ファイル',
              ChatAttachmentSource.clipboard: 'ペースト',
            },
            sources: ChatAttachmentSource.values.toSet(),
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('カメラ')).dy,
      lessThan(tester.getTopLeft(find.text('写真')).dy),
    );
    await tester.tap(find.text('ファイル'));
    await tester.pumpAndSettle();
    expect(selected, ChatAttachmentSource.file);
  });

  testWidgets('構造化要約は長文を省略せず狭幅へ折り返す', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: ChatSystemEventSummary(
              title: '長い対象名を複数行で表示する例',
              value: '3 → 2',
              metadata: '操作した人・12:00',
              details: '任意の補足説明',
            ),
          ),
        ),
      ),
    );
    expect(find.text('3 → 2'), findsOneWidget);
    expect(find.text('任意の補足説明'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
