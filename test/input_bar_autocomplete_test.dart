// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/pages/chat/input_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
  });
  late Room room;
  late TextEditingController controller;
  late FocusNode focus;
  var sent = 0;
  setUp(() {
    sent = 0;
    final client = Client('autocomplete test', database: _UnusedDatabase());
    room = Room(id: '!room:example.org', client: client);
    room.setState(
      Event.fromJson({
        'type': 'im.ponies.room_emotes',
        'state_key': '',
        'event_id': 'pack',
        'sender': '@test:example.org',
        'origin_server_ts': 1,
        'content': {
          'images': {
            'smile': {'url': 'mxc://example.org/smile'},
            'smirk': {'url': 'mxc://example.org/smirk'},
          },
        },
      }, room),
    );
    controller = TextEditingController();
    focus = FocusNode(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          sent++;
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 400,
              child: _TextOnlyInputBar(
                room: room,
                controller: controller,
                focusNode: focus,
                decoration: const InputDecoration(),
                suggestionEmojis: const [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), ':smi');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'First option starts highlighted; Enter completes without sending',
    (tester) async {
      await mount(tester);
      final background = tester.widget<Material>(
        find
            .ancestor(of: find.text('smile'), matching: find.byType(Material))
            .first,
      );
      expect(
        background.color,
        Theme.of(
          tester.element(find.text('smile')),
        ).colorScheme.secondaryContainer,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.text, ':smile: ');
      expect(sent, 0);
      expect(find.text('smile'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, 1);
    },
  );

  testWidgets('Arrows change the highlighted option and Enter selects it', (
    tester,
  ) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, ':smirk: ');
    expect(sent, 0);
    await tester.enterText(find.byType(TextField), ':smi');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, ':smile: ');
  });

  testWidgets('Enter also completes the mouse-hovered option', (tester) async {
    await mount(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('smirk')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, ':smirk: ');
    expect(sent, 0);
    await mouse.removePointer();
  });

  testWidgets('Completion preserves text after the caret', (tester) async {
    await mount(tester);
    controller.value = const TextEditingValue(
      text: 'hello :smi tail',
      selection: TextSelection.collapsed(offset: 10),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, 'hello :smile:  tail');
    expect(controller.selection.baseOffset, 'hello :smile: '.length);
    expect(sent, 0);
  });

  testWidgets(
    'Escape dismisses suggestions and restores composer Enter handling',
    (tester) async {
      await mount(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, 1);
      expect(controller.text, ':smi');
    },
  );
}

// Keep suggestion rendering independent of image downloads in these keyboard tests.
class _TextOnlyInputBar extends InputBar {
  const _TextOnlyInputBar({
    required super.room,
    required super.controller,
    required super.focusNode,
    required super.decoration,
    required super.suggestionEmojis,
  });
  @override
  Widget buildSuggestion(
    BuildContext context,
    Map<String, String?> suggestion,
    void Function(Map<String, String?>) onSelected,
    Client? client,
  ) => ListTile(
    title: Text(suggestion['name']!),
    onTap: () => onSelected(suggestion),
  );
}

class _UnusedDatabase implements DatabaseApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
