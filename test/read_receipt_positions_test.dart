// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/seen_by_row.dart';
import 'package:fluffychat/utils/read_receipt_positions.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

void main() {
  late Room room;
  setUp(() {
    room = Room(id: '!room:example.org', client: _ReceiptClient());
    for (final name in [
      'me',
      'alice',
      'bob',
      'carol',
      for (var i = 0; i < 9; i++) 'reader$i',
    ]) {
      final id = '@$name:example.org';
      room.setState(
        Event.fromJson({
          'event_id': 'member-$name',
          'type': EventTypes.RoomMember,
          'state_key': id,
          'sender': id,
          'origin_server_ts': 1,
          'content': {'membership': 'join', 'displayname': name},
        }, room),
      );
    }
  });

  Event message(
    String id, {
    String? thread,
    String? edit,
    String? type,
    String? sender,
  }) => Event.fromJson({
    'event_id': id,
    'type': type ?? EventTypes.Message,
    'sender': sender ?? '@me:example.org',
    'origin_server_ts': 1,
    'content': {
      'msgtype': MessageTypes.Text,
      'body': 'Message',
      if (thread != null || edit != null)
        'm.relates_to': {
          'rel_type': edit != null
              ? RelationshipTypes.edit
              : RelationshipTypes.thread,
          'event_id': edit ?? thread,
        },
    },
  }, room);

  void receipt(
    String user,
    String eventId, {
    LatestReceiptStateForTimeline? scope,
  }) {
    (scope ?? room.receiptState.global).otherUsers[user] =
        LatestReceiptStateData(eventId, 1);
  }

  Map<String, List<String>> positions(
    List<Event> visible, {
    List<Event>? all,
    String? thread,
  }) => readReceiptPositions(
    room,
    visible,
    all ?? visible,
    threadId: thread,
  ).map((id, users) => MapEntry(id, users.map((user) => user.id).toList()));

  test('Each reader appears once and moves to their new read position', () {
    final events = [message('new'), message('old')];
    receipt('@bob:example.org', 'old');
    receipt('@alice:example.org', 'old');
    expect(positions(events), {
      'old': ['@alice:example.org', '@bob:example.org'],
    });
    receipt('@bob:example.org', 'new');
    expect(positions(events), {
      'old': ['@alice:example.org'],
      'new': ['@bob:example.org'],
    });
  });

  test('Sending implies a read position without explicit receipts', () {
    final events = [
      message('new', sender: '@alice:example.org'),
      message('middle', sender: '@bob:example.org'),
      message('old', sender: '@alice:example.org'),
    ];
    expect(positions(events), {
      'new': ['@alice:example.org'],
      'middle': ['@bob:example.org'],
    });
    expect(room.receiptState.global.otherUsers, isEmpty);
  });

  test('Explicit and implied positions choose the furthest message', () {
    final events = [
      message('new'),
      message('middle', sender: '@alice:example.org'),
      message('old'),
    ];
    receipt('@alice:example.org', 'old');
    expect(positions(events), {
      'middle': ['@alice:example.org'],
    });
    receipt('@alice:example.org', 'new');
    expect(positions(events), {
      'new': ['@alice:example.org'],
    });
  });

  test('Sending in another thread does not imply a main read position', () {
    final main = message('main');
    final reply = message(
      'reply',
      thread: 'root',
      sender: '@alice:example.org',
    );
    expect(positions([main], all: [reply, main]), isEmpty);
    expect(positions([reply], all: [reply, main], thread: 'root'), {
      'reply': ['@alice:example.org'],
    });
  });

  test('Global/main receipts deduplicate at the furthest loaded position', () {
    final events = [message('new'), message('old')];
    room.receiptState.mainThread = LatestReceiptStateForTimeline.empty();
    receipt('@bob:example.org', 'old');
    receipt('@bob:example.org', 'new', scope: room.receiptState.mainThread);
    expect(positions(events), {
      'new': ['@bob:example.org'],
    });
  });

  test(
    'Own/private positions do not render; authors may have public positions',
    () {
      final events = [message('new')];
      receipt('@me:example.org', 'new');
      receipt('@alice:example.org', 'new');
      room.receiptState.global.ownPrivate = LatestReceiptStateData('new', 1);
      expect(positions(events), {
        'new': ['@alice:example.org'],
      });
    },
  );

  test(
    'Thread positions stay in the correct thread and do not leak to main',
    () {
      final root = message('root');
      final threaded = message('threaded', thread: 'root');
      final other = message('other', thread: 'another-root');
      final main = message('main');
      final all = [other, threaded, main, root];
      final threadScope = LatestReceiptStateForTimeline.empty();
      room.receiptState.byThread['root'] = threadScope;
      receipt('@bob:example.org', 'threaded', scope: threadScope);
      receipt('@carol:example.org', 'other');
      expect(positions([threaded, root], all: all, thread: 'root'), {
        'threaded': ['@bob:example.org'],
      });
      expect(
        positions([main, root], all: all).values.expand((users) => users),
        isNot(contains('@bob:example.org')),
      );
    },
  );

  test(
    'Edits map to their original message and hidden events to the prior visible message',
    () {
      final old = message('old');
      final newMessage = message('new');
      final edit = message('edit', edit: 'old');
      final hidden = message('hidden', type: EventTypes.RoomMember);
      receipt('@bob:example.org', 'edit');
      receipt('@carol:example.org', 'hidden');
      expect(
        positions([newMessage, old], all: [hidden, edit, newMessage, old]),
        {
          'old': ['@bob:example.org'],
          'new': ['@carol:example.org'],
        },
      );
    },
  );

  test('Unloaded targets and edits of unloaded messages are not guessed', () {
    final events = [message('new'), message('old')];
    receipt('@bob:example.org', 'unloaded');
    receipt('@carol:example.org', 'edit');
    expect(
      positions(
        events,
        all: [
          message('edit', edit: 'unloaded'),
          ...events,
        ],
      ),
      isEmpty,
    );
  });

  testWidgets('Reader avatars show names and a tappable overflow list', (
    tester,
  ) async {
    final readers = List.generate(
      9,
      (i) => room.unsafeGetUserFromMemoryOrFallback('@reader$i:example.org'),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: SeenByRow(event: message('new'), users: readers),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Avatar), findsNWidgets(7));
    expect(find.text('+2'), findsOneWidget);
    expect(
      find.byTooltip('${readers.first.calcDisplayname()}\n${readers.first.id}'),
      findsOneWidget,
    );
    await tester.tap(find.text('+2'));
    await tester.pumpAndSettle();
    expect(find.text('Read by'), findsOneWidget);
    for (final user in readers) {
      expect(find.text(user.id), findsOneWidget);
    }
  });
}

class _UnusedDatabase extends Fake implements MatrixSdkDatabase {}

class _ReceiptClient extends Client {
  _ReceiptClient() : super('receipt test', database: _UnusedDatabase());
  @override
  String? get userID => '@me:example.org';
}
