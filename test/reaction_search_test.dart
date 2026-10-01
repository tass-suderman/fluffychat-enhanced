// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/reaction_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  late Room room;
  setUp(() {
    room = Room(
      id: '!room:example.org',
      client: Client('reaction search', database: _UnusedDatabase()),
    );
    room.setState(
      Event.fromJson({
        'type': 'im.ponies.room_emotes',
        'state_key': '',
        'event_id': 'pack',
        'sender': '@user:example.org',
        'origin_server_ts': 1,
        'content': {
          'images': {
            'smile_custom': {
              'url': 'mxc://example.org/smile',
              'body': 'Happy mascot',
              'usage': ['emoticon'],
            },
            'sticker_only': {
              'url': 'mxc://example.org/sticker',
              'usage': ['sticker'],
            },
          },
        },
      }, room),
    );
  });

  testWidgets('Built-in reaction picker follows dark and light app themes', (
    tester,
  ) async {
    for (final theme in [ThemeData.dark(), ThemeData.light()]) {
      final emptyRoom = Room(
        id: '!empty:example.org',
        client: Client('theme test', database: _UnusedDatabase()),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: ReactionPicker(room: emptyRoom),
        ),
      );
      await tester.pumpAndSettle();
      final config = tester
          .widget<EmojiPicker>(find.byType(EmojiPicker))
          .config;
      expect(
        config.emojiViewConfig.backgroundColor,
        theme.colorScheme.onInverseSurface,
      );
      expect(
        config.categoryViewConfig.backgroundColor,
        theme.colorScheme.surface,
      );
      expect(
        config.categoryViewConfig.iconColorSelected,
        theme.colorScheme.primary,
      );
      expect(config.skinToneConfig.indicatorColor, theme.colorScheme.onSurface);
    }
  });

  test('One search includes Unicode names and room custom emotes', () {
    final results = searchReactions(
      ' :SMILE: ',
      reactionOptions(room, const Locale('en')),
    );
    expect(results.any((option) => !option.custom), isTrue);
    expect(
      results.any((option) => option.value == 'mxc://example.org/smile'),
      isTrue,
    );
    expect(
      results.any((option) => option.value == 'mxc://example.org/sticker'),
      isFalse,
    );
  });

  test('Search finds custom descriptions and excludes nonmatches', () {
    final options = reactionOptions(room, const Locale('en'));
    expect(
      searchReactions('mascot', options).single.value,
      'mxc://example.org/smile',
    );
    expect(searchReactions('not-an-emote-name', options), isEmpty);
  });

  test('English names and Unicode glyphs work in another locale', () {
    final options = reactionOptions(room, const Locale('de'));
    expect(
      searchReactions('grinning', options).any((option) => !option.custom),
      isTrue,
    );
    expect(searchReactions('😀', options).single.value, '😀');
  });
}

class _UnusedDatabase extends Fake implements MatrixSdkDatabase {}
