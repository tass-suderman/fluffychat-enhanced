// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

// Element's MSC3230 per-room account data; not shared space state.
const spaceOrderEventType = 'org.matrix.msc3230.space_order';

String? validSpaceOrder(Object? value) {
  if (value is! String ||
      value.length > 50 ||
      value.codeUnits.any((c) => c < 0x20 || c > 0x7e)) {
    return null;
  }
  return value;
}

List<Room> orderedSpaces(
  Iterable<Room> rooms, {
  Map<String, String> localOrders = const {},
}) {
  final spaces = rooms.where((room) => room.isSpace).toList();
  String? order(Room room) => validSpaceOrder(
    localOrders[room.id] ??
        room.roomAccountData[spaceOrderEventType]?.content['order'],
  );
  spaces.sort((a, b) {
    final left = order(a);
    final right = order(b);
    if (left != null && right == null) return -1;
    if (left == null && right != null) return 1;
    final result = left != null && right != null ? left.compareTo(right) : 0;
    return result != 0 ? result : a.id.compareTo(b.id);
  });
  return spaces;
}

/// Reorder visible slots while retaining hidden spaces in their original slots.
List<String> reorderVisibleSpaces(
  List<String> all,
  Set<String> hidden,
  int oldIndex,
  int newIndex,
) {
  final visible = all.where((id) => !hidden.contains(id)).toList();
  visible.insert(newIndex, visible.removeAt(oldIndex));
  var index = 0;
  return all.map((id) => hidden.contains(id) ? id : visible[index++]).toList();
}

String spaceOrderAt(int index) => index.toString().padLeft(10, '0');
