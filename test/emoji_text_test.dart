// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/html_message.dart';
import 'package:fluffychat/utils/emoji_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

const emojiSamples = [
  '😎',
  '😂',
  '🥳',
  '✨',
  '☺',
  '☺️',
  '♥',
  '♥️',
  '☎',
  '☎️',
  '👍🏽',
  '👩‍💻',
  '🏳️‍🌈',
  '🇨🇦',
  '1️⃣',
  '#️⃣',
  '*️⃣',
  '1\u20E3',
  '👨‍👩‍👧‍👦',
  '🏴\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}',
];

Iterable<TextSpan> leaves(TextSpan span) sync* {
  if (span.text != null) yield span;
  for (final child in span.children ?? <InlineSpan>[]) {
    if (child is TextSpan) yield* leaves(child);
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
  });
  for (final sample in emojiSamples) {
    test('Styles the complete sequence $sample without changing it', () {
      expect(sample.characters.length, 1);
      final span = applyLinuxEmojiFont(TextSpan(text: sample), enabled: true);
      expect(span.toPlainText(), sample);
      expect(leaves(span).single.text, sample);
      expect(leaves(span).single.style?.fontFamily, 'Noto Color Emoji');
    });
  }

  test('VS15 stays in a text font and ordinary typography is inherited', () {
    const normal = 'Normal text 123 # * ©opyright ';
    const textEmoji = '😎\uFE0E 😂\uFE0E ☺\uFE0E ♥\uFE0E ☎\uFE0E';
    final span = applyLinuxEmojiFont(
      const TextSpan(
        text: '$normal$textEmoji',
        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
      ),
      enabled: true,
    );
    expect(span.style?.fontFamily, 'Roboto');
    expect(span.style?.fontWeight, FontWeight.bold);
    expect(span.toPlainText(), '$normal$textEmoji');
    for (final leaf in leaves(span)) {
      if (leaf.text!.contains('\uFE0E')) {
        expect(leaf.style?.fontFamily, 'DejaVu Sans');
      } else if (leaf.text!.contains('Normal text')) {
        expect(leaf.style, isNull);
      }
    }
  });

  test('Link recognizers, nested formatting and widget spans survive', () {
    final recognizer = TapGestureRecognizer();
    addTearDown(recognizer.dispose);
    const widget = WidgetSpan(child: Text('mention'));
    final original = TextSpan(
      children: [
        TextSpan(
          text: 'link 😎',
          recognizer: recognizer,
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
        const TextSpan(
          text: 'bold 😂',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        widget,
      ],
    );
    final styled = applyLinuxEmojiFont(original, enabled: true);
    final link = styled.children!.first as TextSpan;
    expect(link.style, (original.children!.first as TextSpan).style);
    for (final leaf in leaves(link)) {
      expect(leaf.recognizer, same(recognizer));
    }
    expect(styled.children!.last, same(widget));
    expect(styled.toPlainText(), original.toPlainText());
  });

  test('Other platforms retain their existing span tree', () {
    const original = TextSpan(text: '😎 text');
    expect(applyLinuxEmojiFont(original, enabled: false), same(original));
  });

  testWidgets('Formatted messages keep link actions and selectable text', (
    tester,
  ) async {
    final room = Room(
      id: '!test:example.org',
      client: Client('emoji test', database: _UnusedDatabase()),
    );
    const text =
        'Bold 😎 😂 🥳 ✨ ☺ ☺️ ♥ ♥️ ☎ ☎️ 👍🏽 👩‍💻 🏳️‍🌈 🇨🇦 1️⃣ ♥\uFE0E https://example.org';
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: SelectionArea(
            child: HtmlMessage(
              html: '<b>$text</b>',
              room: room,
              fontSize: 16,
              textColor: Colors.black,
              linkStyle: const TextStyle(color: Colors.blue),
              onOpen: (link) => opened = link.url,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final richText = find.byType(RichText).first;
    final box = tester.renderObject<RenderParagraph>(richText);
    // Exercise the real hit-tested link after splitting emoji text spans.
    final paragraph = tester.widget<RichText>(richText).text as TextSpan;
    final start = paragraph.toPlainText().indexOf('https://example.org');
    final bounds = box.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + 19),
    );
    await tester.tapAt(box.localToGlobal(bounds.first.toRect().center));
    expect(opened, 'https://example.org');
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    region.contextMenuButtonItems
        .firstWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    expect(copied, text);
  });

  testWidgets('Composer preserves values, selection, copy and IME clusters', (
    tester,
  ) async {
    final controller = EmojiMessageEditingController();
    addTearDown(controller.dispose);
    final text = 'Hello ${emojiSamples.join(' ')} ♥\uFE0E';
    final zwj = text.indexOf('👩‍💻');
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      // Deliberately intersects the UTF-16 middle of a ZWJ sequence.
      composing: TextRange(start: zwj + 2, end: zwj + 3),
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return TextField(controller: controller);
            },
          ),
        ),
      ),
    );
    final before = controller.value;
    final span = controller.buildTextSpan(
      context: context,
      withComposing: true,
    );
    expect(span.toPlainText(), text);
    expect(controller.value, before);
    expect(
      leaves(
        span,
      ).where((leaf) => leaf.text == '👩‍💻').single.style?.decoration,
      TextDecoration.underline,
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    editable.copySelection(SelectionChangedCause.keyboard);
    await tester.pump();
    expect(copied, text);
    expect(controller.text, text);
  });
}

class _UnusedDatabase extends Fake implements MatrixSdkDatabase {}
