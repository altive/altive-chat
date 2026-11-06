import 'package:flutter/material.dart';

/// 添付操作の配置方針。従来配置は既存APIで維持する。
enum ChatComposerSourcePresentation {
  /// 従来の独立カメラ配置。
  separateCamera,

  /// 「＋」menuをfocus中も維持する配置。
  attachmentMenu,
}

/// 呼び出し側が用意する画像取得元。取得処理はライブラリへ持ち込まない。
enum ChatAttachmentSource {
  /// カメラ。
  camera,

  /// 写真ライブラリ。
  photoLibrary,

  /// 画像ファイル。
  file,

  /// 明示操作による画像ペースト。
  clipboard,
}

/// camera、写真、file、pasteの順に表示する添付メニュー。
/// ステッカーはこのmenuへ含めず、入力欄の直接操作として配置する。
class ChatAttachmentMenu extends StatelessWidget {
  /// 表示文字列と利用可能な取得元、既存取得処理を受け取る。
  const ChatAttachmentMenu({
    super.key,
    required this.label,
    required this.labels,
    required this.onSelected,
    required this.sources,
    this.enabled = true,
    this.cameraEnabled = true,
  });

  /// menu操作の読み上げ文言。
  final String label;

  /// 取得元のローカライズ済み表示名。
  final Map<ChatAttachmentSource, String> labels;

  /// 選択された取得元を通知する。
  final ValueChanged<ChatAttachmentSource> onSelected;

  /// 利用可能な取得元。
  final Set<ChatAttachmentSource> sources;

  /// 添付上限と準備状態から決定した操作可否。
  final bool enabled;

  /// camera準備中の重複起動を抑止する。
  final bool cameraEnabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<ChatAttachmentSource>(
    tooltip: label,
    enabled: enabled && sources.isNotEmpty,
    icon: const Icon(Icons.add),
    onSelected: onSelected,
    itemBuilder: (_) => [
      for (final source in ChatAttachmentSource.values)
        if (sources.contains(source))
          PopupMenuItem(
            value: source,
            enabled: source != ChatAttachmentSource.camera || cameraEnabled,
            child: Text(labels[source] ?? source.name),
          ),
    ],
  );
}
