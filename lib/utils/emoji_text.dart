// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/widgets.dart';

import 'platform_infos.dart';

const linuxEmojiFallback = ['Noto Color Emoji'];

// A fallback cannot override a monochrome glyph in the primary text font.
// Choose the emoji font only for complete grapheme clusters. Keep VS15 in a
// text font because the Linux engine may otherwise select the color font anyway.
TextStyle? _clusterStyle(String cluster) {
  final matches = EmojiPickerUtils().getEmojiRegex().allMatches(cluster);
  final hasEmojiBase = matches.any(
    (match) => match.group(0) != '\u200D' && match.group(0) != '\uFE0F',
  );
  if (!hasEmojiBase) return null;
  // Unicode's Emoji property includes ordinary digits, # and *.
  if (RegExp(r'^[0-9#*]').hasMatch(cluster) && !cluster.contains('\u20E3')) {
    return null;
  }
  if (cluster.contains('\uFE0E')) {
    return const TextStyle(
      fontFamily: 'DejaVu Sans',
      fontFamilyFallback: ['Noto Sans Symbols 2', 'Noto Sans Symbols'],
    );
  }
  return const TextStyle(
    fontFamily: 'Noto Color Emoji',
    fontFamilyFallback: linuxEmojiFallback,
  );
}

/// Styles existing rich text without altering its text or interactive spans.
/// Widget spans (custom emotes, mentions, spoilers, etc.) remain untouched.
TextSpan applyLinuxEmojiFont(TextSpan span, {bool? enabled}) {
  if (!(enabled ?? PlatformInfos.isLinux)) return span;
  final children = <InlineSpan>[];
  final text = span.text;
  if (text != null) {
    final runs = _textRuns(text);
    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      children.add(
        TextSpan(
          text: run.text,
          style: run.style,
          // Recognizers are not inherited by TextSpan children.
          recognizer: span.recognizer,
          mouseCursor: span.mouseCursor,
          onEnter: span.onEnter,
          onExit: span.onExit,
          semanticsLabel: span.semanticsLabel == null
              ? null
              : (i == 0 ? span.semanticsLabel : ''),
          semanticsIdentifier: i == 0 ? span.semanticsIdentifier : null,
        ),
      );
    }
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    children.add(
      child is TextSpan ? applyLinuxEmojiFont(child, enabled: true) : child,
    );
  }
  return TextSpan(
    style: span.style,
    children: children,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

List<TextSpan> _textRuns(String text, {TextRange? composing}) {
  final result = <TextSpan>[];
  var offset = 0;
  var buffer = StringBuffer();
  TextStyle? previousStyle;
  void flush() {
    if (buffer.isEmpty) return;
    result.add(TextSpan(text: buffer.toString(), style: previousStyle));
    buffer = StringBuffer();
  }

  for (final cluster in text.characters) {
    var style = _clusterStyle(cluster);
    final end = offset + cluster.length;
    if (composing != null && composing.start < end && composing.end > offset) {
      style = (style ?? const TextStyle()).copyWith(
        decoration: TextDecoration.underline,
      );
    }
    if (style != previousStyle) flush();
    previousStyle = style;
    buffer.write(cluster);
    offset = end;
  }
  flush();
  return result;
}

/// Keeps editing values, selections and IME ranges unchanged. A composing
/// range that intersects a grapheme underlines the whole grapheme rather than
/// splitting a flag, skin tone, keycap or ZWJ sequence between font spans.
class EmojiMessageEditingController extends TextEditingController {
  EmojiMessageEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!PlatformInfos.isLinux) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      children: _textRuns(
        text,
        composing: withComposing && value.isComposingRangeValid
            ? value.composing
            : null,
      ),
    );
  }
}
