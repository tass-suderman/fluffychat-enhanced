// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/space_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Client client;
  setUp(() => client = Client('space order test', database: _UnusedDatabase()));
  Room space(String id, {Object? order}) {
    final room = Room(
      id: id,
      client: client,
      roomAccountData: {
        if (order != null)
          spaceOrderEventType: BasicEvent(
            type: spaceOrderEventType,
            content: {'order': order},
          ),
      },
    );
    room.setState(
      Event.fromJson({
        'type': 'm.room.create',
        'state_key': '',
        'event_id': 'create-$id',
        'sender': '@test:example.org',
        'origin_server_ts': 1,
        'content': {'type': 'm.space'},
      }, room),
    );
    return room;
  }

  test(
    'Element orders sort lexically, with room ID resolving ties and unset orders',
    () {
      final rooms = [
        space('z'),
        space('b', order: 'B'),
        space('a', order: 'A'),
        space('c', order: 'A'),
        space('y', order: 12),
      ];
      expect(orderedSpaces(rooms).map((room) => room.id), [
        'a',
        'c',
        'b',
        'y',
        'z',
      ]);
    },
  );

  test('Order validation follows Element printable ASCII and length limit', () {
    expect(validSpaceOrder(''), '');
    expect(validSpaceOrder(' !~'), ' !~');
    expect(validSpaceOrder('x' * 50), 'x' * 50);
    for (final value in ['x' * 51, 'é', '\n', 10, null]) {
      expect(validSpaceOrder(value), isNull);
    }
  });

  test('Dragging down or up keeps hidden spaces in their slots', () {
    expect(reorderVisibleSpaces(['a', 'hidden', 'b', 'c'], {'hidden'}, 0, 2), [
      'b',
      'hidden',
      'c',
      'a',
    ]);
    expect(reorderVisibleSpaces(['a', 'hidden', 'b', 'c'], {'hidden'}, 2, 0), [
      'c',
      'hidden',
      'a',
      'b',
    ]);
  });

  test(
    'Saved ranks are Element-compatible, ordered and reproducible after reload',
    () {
      final reordered = reorderVisibleSpaces(['a', 'b', 'c'], {}, 0, 2);
      final rooms = [
        for (var i = 0; i < reordered.length; i++)
          space(reordered[i], order: spaceOrderAt(i)),
      ];
      expect(
        rooms.every(
          (room) =>
              validSpaceOrder(
                room.roomAccountData[spaceOrderEventType]?.content['order'],
              ) !=
              null,
        ),
        true,
      );
      expect(orderedSpaces(rooms.reversed).map((room) => room.id), reordered);
    },
  );

  test('Local pending orders override sync until acknowledged', () {
    final rooms = [space('a', order: 'A'), space('b', order: 'B')];
    expect(
      orderedSpaces(rooms, localOrders: {'a': 'C'}).map((room) => room.id),
      ['b', 'a'],
    );
  });
}

class _UnusedDatabase implements DatabaseApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
