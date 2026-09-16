import 'package:flutter/widgets.dart';

/// 複数画像メッセージの配置方法。
enum ChatMultipleImageLayout {
  /// 3枚では先頭を横長にし、残りを下段の2列で表示する。
  ///
  /// 4枚以上は2×2へ収め、4枚目に超過件数を表示する。
  leadingWideGrid,

  /// 3枚では先頭を大きく、残り2枚を右側へ並べる。
  ///
  /// 4枚以上は2×2へ収め、4枚目に超過件数を表示する。
  mosaic,
}

/// 単一画像メッセージの配置設定。
@immutable
class ChatSingleImageLayout {
  /// 正方形で表示する設定。
  const ChatSingleImageLayout.square()
    : minHeight = null,
      maxHeight = null,
      maxWidthFraction = null,
      maxHeightWidthRatio = null,
      fit = BoxFit.cover;

  /// 元の縦横比を尊重し、指定した高さの範囲で表示する設定。
  const ChatSingleImageLayout.adaptiveBounded({
    double minHeight = 160,
    double maxHeight = 260,
    this.fit = BoxFit.cover,
  }) : minHeight = minHeight,
       maxHeight = maxHeight,
       maxWidthFraction = null,
       maxHeightWidthRatio = null,
       assert(minHeight > 0),
       assert(maxHeight >= minHeight);

  /// 元画像の比率を保ち、画面幅に対する上限内で実画像の幅に合わせる設定。
  const ChatSingleImageLayout.intrinsicBounded({
    double maxWidthFraction = 0.5,
    double maxHeightWidthRatio = 1.5,
  }) : minHeight = null,
       maxHeight = null,
       maxWidthFraction = maxWidthFraction,
       maxHeightWidthRatio = maxHeightWidthRatio,
       fit = BoxFit.contain,
       assert(maxWidthFraction > 0 && maxWidthFraction <= 1),
       assert(maxHeightWidthRatio > 0);

  /// 最小表示高さ。`null`の場合は正方形表示。
  final double? minHeight;

  /// 最大表示高さ。`null`の場合は正方形表示。
  final double? maxHeight;

  /// 画面幅に対する画像幅の上限。実画像幅に合わせる設定以外では`null`。
  final double? maxWidthFraction;

  /// 最大幅に対する画像高さの上限倍率。実画像幅に合わせる設定以外では`null`。
  final double? maxHeightWidthRatio;

  /// 画像の収め方。
  final BoxFit fit;

  /// 最小高と最大高を使う可変比率表示かどうか。
  bool get isAdaptive => minHeight != null;

  /// 実画像の幅に合わせて単一画像を表示するかどうか。
  bool get isIntrinsicBounded => maxWidthFraction != null;
}

/// チャット画像のレイアウト設定。
@immutable
class ChatImageLayoutConfiguration {
  /// チャット画像のレイアウト設定を生成する。
  const ChatImageLayoutConfiguration({
    this.singleImageLayout = const ChatSingleImageLayout.adaptiveBounded(),
    this.multipleImageLayout = ChatMultipleImageLayout.leadingWideGrid,
  });

  /// 単一画像の配置設定。
  final ChatSingleImageLayout singleImageLayout;

  /// 複数画像の配置方法。
  final ChatMultipleImageLayout multipleImageLayout;
}
