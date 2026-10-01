// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/chat_sorting.dart';
import 'package:fluffychat/widgets/settings_switch_list_tile.dart';
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
  late Client client;
  setUp(() async {
    client = Client('sorting test', database: _UnusedDatabase());
    await AppSettings.store.clear();
    await AppSettings.pinFavorites.setItem(false);
    await AppSettings.lowPriorityLast.setItem(false);
  });

  Room room(String id, {String? tag, bool unread = false}) => Room(
    id: id,
    client: client,
    notificationCount: unread ? 1 : 0,
    roomAccountData: {
      if (tag != null)
        'm.tag': BasicEvent(
          type: 'm.tag',
          content: {
            'tags': {tag: <String, dynamic>{}},
          },
        ),
    },
  );

  testWidgets(
    'Favorites switch matches sorter defaults and saves before notifying',
    (tester) async {
      await AppSettings.store.remove(AppSettings.pinFavorites.key);
      bool? savedAtCallback;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSwitchListTile.adaptive(
              title: 'Pin favorites',
              setting: AppSettings.pinFavorites,
              onChanged: (_) =>
                  savedAtCallback = AppSettings.pinFavorites.value,
            ),
          ),
        ),
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      expect(AppSettings.pinFavorites.value, true);
      await tester.tap(find.text('Pin favorites'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      expect(AppSettings.pinFavorites.value, false);
      expect(savedAtCallback, false);
    },
  );

  test(
    'Disabled sorting retains the supplied order, including favorites and unread',
    () {
      final rooms = [
        room('read'),
        room('low', tag: 'm.lowpriority'),
        room('unread', unread: true),
        room('favorite', tag: 'm.favourite'),
      ];
      expect(sortChats(rooms, (room) => room), rooms);
    },
  );

  test(
    'Favorites, unread and low priority combine with stable order',
    () async {
      await AppSettings.pinFavorites.setItem(true);
      await AppSettings.sortUnreadFirst.setItem(true);
      await AppSettings.lowPriorityLast.setItem(true);
      final rooms = [
        room('read1'),
        room('low', tag: 'm.lowpriority', unread: true),
        room('unread', unread: true),
        room('favorite', tag: 'm.favourite'),
        room('read2'),
      ];
      expect(sortChats(rooms, (room) => room).map((room) => room.id), [
        'favorite',
        'unread',
        'read1',
        'read2',
        'low',
      ]);
    },
  );

  test(
    'Turning off pinning restores activity order from an SDK-sorted list',
    () async {
      final favorite = room('favorite', tag: 'm.favourite');
      final recent = room('recent');
      for (final entry in [(favorite, 1000), (recent, 2000)]) {
        entry.$1.lastEvent = Event.fromJson({
          'event_id': 'event-${entry.$2}',
          'type': 'm.room.message',
          'sender': '@other:example.org',
          'origin_server_ts': entry.$2,
          'content': {'msgtype': 'm.text', 'body': 'hello'},
        }, entry.$1);
      }
      final source = [favorite, recent];
      expect(sortChats(source, (room) => room, byActivity: true), [
        recent,
        favorite,
      ]);
      await AppSettings.pinFavorites.setItem(true);
      expect(sortChats(source, (room) => room, byActivity: true), [
        favorite,
        recent,
      ]);
    },
  );

  test(
    'Muted new messages are sortable even without a notification count',
    () async {
      final muted = _MutedRoom(id: 'muted', client: client);
      muted.lastEvent = Event.fromJson({
        'event_id': 'muted-event',
        'type': 'm.room.message',
        'sender': '@other:example.org',
        'origin_server_ts': 2000,
        'content': {'msgtype': 'm.text', 'body': 'hello'},
      }, muted);
      final read = room('read');
      await AppSettings.sortUnreadFirst.setItem(true);
      expect(sortChats([read, muted], (room) => room), [read, muted]);
      await AppSettings.sortMutedUnreadFirst.setItem(true);
      expect(sortChats([read, muted], (room) => room), [muted, read]);
    },
  );

  test('Muted unread requires both unread sorting and include muted', () {
    int rank({required bool unreadFirst, required bool includeMuted}) =>
        chatSortRank(
          lowPriority: false,
          favorite: false,
          unread: true,
          muted: true,
          lowPriorityLast: true,
          pinFavorites: true,
          unreadFirst: unreadFirst,
          includeMuted: includeMuted,
        );
    expect(rank(unreadFirst: true, includeMuted: false), 2);
    expect(rank(unreadFirst: true, includeMuted: true), 1);
    expect(rank(unreadFirst: false, includeMuted: true), 2);
  });

  test(
    'Hierarchy entries without a joined room retain their relative order',
    () async {
      await AppSettings.sortUnreadFirst.setItem(true);
      final joined = room('unread', unread: true);
      expect(
        sortChats([
          'unknown1',
          'unread',
          'unknown2',
        ], (id) => id == 'unread' ? joined : null),
        ['unread', 'unknown1', 'unknown2'],
      );
    },
  );
}

// Sorting reads room state without opening a database.
class _UnusedDatabase implements DatabaseApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MutedRoom extends Room {
  _MutedRoom({required super.id, required super.client});
  @override
  PushRuleState get pushRuleState => PushRuleState.mentionsOnly;
}
