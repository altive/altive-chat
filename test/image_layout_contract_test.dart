import 'dart:io';

import 'package:altive_chat_room/altive_chat_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _onePixelPng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mNk+M/wHwAE/wJ/l4v2WQAAAABJRU5ErkJggg==';

/// 元画像の縦横比を検証するためのローカル画像を読み込む。
String _imageDataUri(int width, int height) {
  final bytes = File('test/fixtures/${width}x$height.png').readAsBytesSync();
  return Uri.dataFromBytes(
    bytes,
    mimeType: 'image/png',
  ).toString();
}

/// 一枚画像と既読・時刻の位置を確認できる画面を表示する。
Future<void> _pumpSingleImage(
  WidgetTester tester, {
  required String imageUrl,
  required bool isOutgoing,
  ChatSingleImageLayout layout = const ChatSingleImageLayout.intrinsicBounded(),
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AltiveChatRoom(
        theme: const AltiveChatRoomTheme(),
        currentUserId: 'me',
        messages: [
          ChatImagesMessage(
            id: 'single-image',
            createdAt: DateTime(2026, 8, 27, 12, 34),
            sender: ChatUser(
              id: isOutgoing ? 'me' : 'other',
              name: 'Other',
              avatarImageUrl: _onePixelPng,
            ),
            imageUrls: [imageUrl],
            isRead: isOutgoing,
          ),
        ],
        imageLayoutConfiguration: ChatImageLayoutConfiguration(
          singleImageLayout: layout,
        ),
        onSendIconPressed: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  // 初期スクロールで親が再構築されるため、最後に表示された画像providerの完了を待つ。
  for (var attempt = 0; attempt < 5; attempt++) {
    final image = find.byType(Image).last;
    final provider = tester.widget<Image>(image).image;
    await tester.runAsync(() => precacheImage(provider, tester.element(image)));
    await tester.pumpAndSettle();
    if (find.byType(RawImage).evaluate().length >= (isOutgoing ? 1 : 2)) {
      break;
    }
  }
}

/// 単一画像の実描画領域を返す。
Rect _singleImageRect(WidgetTester tester) {
  // 受信側ではアバターが先に生成されるため、最後のImageが本文画像になる。
  final images = find.byType(Image);
  expect(images, findsWidgets);
  return tester.getRect(images.last);
}

void main() {
  test('単一画像は可変比率を既定とする', () {
    const configuration = ChatImageLayoutConfiguration();
    expect(configuration.singleImageLayout.isAdaptive, isTrue);
  });

  for (final (width, height) in [(400, 200), (200, 400)]) {
    for (final isOutgoing in [false, true]) {
      testWidgets('実画像幅の配置: ${width}x$height、${isOutgoing ? '送信' : '受信'}', (
        tester,
      ) async {
        final imageUrl = _imageDataUri(width, height);
        await _pumpSingleImage(
          tester,
          imageUrl: imageUrl,
          isOutgoing: isOutgoing,
        );

        final imageRect = _singleImageRect(tester);
        expect(imageRect.width, lessThanOrEqualTo(200));
        expect(imageRect.height, lessThanOrEqualTo(300));
        expect(
          imageRect.width / imageRect.height,
          closeTo(width / height, 0.01),
        );
        if (isOutgoing) {
          final readRect = tester.getRect(find.text('既読'));
          final timeRect = tester.getRect(find.text('12:34'));
          expect(imageRect.right, closeTo(384, 1));
          expect(imageRect.left - readRect.right, closeTo(6, 1));
          expect(timeRect.right, closeTo(readRect.right, 1));
        } else {
          final timeRect = tester.getRect(find.text('12:34'));
          expect(imageRect.left, closeTo(48, 1));
          expect(timeRect.left - imageRect.right, closeTo(6, 1));
        }
      });
    }
  }

  testWidgets('既定の単一画像レイアウトは従来の表示幅を維持する', (tester) async {
    await _pumpSingleImage(
      tester,
      imageUrl: _imageDataUri(400, 200),
      isOutgoing: true,
      layout: const ChatSingleImageLayout.adaptiveBounded(),
    );

    expect(_singleImageRect(tester).width, greaterThan(200));
  });

  testWidgets('4枚超は2×2へ収めて超過件数を表示する', (tester) async {
    final message = ChatImagesMessage(
      id: 'five-images',
      createdAt: DateTime(2026, 8, 27),
      sender: const ChatUser(id: 'me', name: 'Me', avatarImageUrl: 'data:'),
      imageUrls: List.filled(5, _onePixelPng),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 700,
          child: AltiveChatRoom(
            theme: const AltiveChatRoomTheme(),
            currentUserId: 'me',
            messages: [message],
            onSendIconPressed: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('data URIからURLへ変わる画像はgapless表示を利用する', (tester) async {
    final notifier = ValueNotifier(_onePixelPng);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<String>(
          valueListenable: notifier,
          builder: (context, imageUrl, _) => AltiveChatRoom(
            theme: const AltiveChatRoomTheme(),
            currentUserId: 'me',
            messages: [
              ChatImagesMessage(
                id: 'transition-image',
                createdAt: DateTime(2026, 8, 27),
                sender: const ChatUser(
                  id: 'me',
                  name: 'Me',
                  avatarImageUrl: 'data:',
                ),
                imageUrls: [imageUrl],
              ),
            ],
            onSendIconPressed: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any((image) => image.gaplessPlayback),
      isTrue,
    );

    notifier.value = 'https://example.com/image.png';
    await tester.pump();

    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any((image) => image.gaplessPlayback),
      isTrue,
    );
  });
}
