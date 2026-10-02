// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

/// Indexes the latest known public read position once per timeline update.
/// Both lists are newest first. Unknown/unloaded receipt targets are omitted.
/// Sending a message also implies a read position, as in Element. These local
/// positions never send receipts or change the room's server receipt state.
Map<String, List<User>> readReceiptPositions(
  Room room,
  List<Event> visibleEvents,
  List<Event> timelineEvents, {
  String? threadId,
}) {
  final indexes = <String, int>{
    for (var i = 0; i < visibleEvents.length; i++)
      if ({
        EventTypes.Message,
        EventTypes.Sticker,
        EventTypes.CallInvite,
        PollEventContent.startType,
      }.contains(visibleEvents[i].type))
        visibleEvents[i].eventId: i,
  };
  final anchors = <String, String>{};
  String? previousVisible;
  for (final event in timelineEvents.reversed) {
    if (indexes.containsKey(event.eventId)) previousVisible = event.eventId;
    final inThread =
        threadId == null ||
        event.eventId == threadId ||
        (event.relationshipType == RelationshipTypes.thread &&
            event.relationshipEventId == threadId);
    if (!inThread && event.relationshipType != RelationshipTypes.edit) continue;
    final editTarget = event.relationshipType == RelationshipTypes.edit
        ? event.relationshipEventId
        : null;
    if (editTarget != null) {
      final anchor = indexes.containsKey(editTarget)
          ? editTarget
          : anchors[editTarget];
      if (anchor != null) anchors[event.eventId] = anchor;
    } else if (previousVisible != null && inThread) {
      anchors[event.eventId] = previousVisible;
    }
  }

  final byUser = <String, String>{};
  // Only messages in this view imply a position: a reply in another thread
  // must not move somebody's main-timeline marker. Newest first means the first
  // message we encounter is already the sender's furthest known position.
  for (final event in visibleEvents) {
    if (!indexes.containsKey(event.eventId) ||
        event.senderId == room.client.userID) {
      continue;
    }
    byUser.putIfAbsent(event.senderId, () => event.eventId);
  }
  final scopes = [
    room.receiptState.global,
    if (threadId == null && room.receiptState.mainThread != null)
      room.receiptState.mainThread!,
    if (threadId != null && room.receiptState.byThread[threadId] != null)
      room.receiptState.byThread[threadId]!,
  ];
  for (final scope in scopes) {
    for (final entry in scope.otherUsers.entries) {
      if (entry.key == room.client.userID) continue;
      final anchor = anchors[entry.value.eventId];
      if (anchor == null) continue;
      final previous = byUser[entry.key];
      if (previous == null || indexes[anchor]! < indexes[previous]!) {
        byUser[entry.key] = anchor;
      }
    }
  }
  final result = <String, List<User>>{};
  final userIds = byUser.keys.toList()..sort();
  for (final userId in userIds) {
    (result[byUser[userId]!] ??= []).add(
      room.unsafeGetUserFromMemoryOrFallback(userId),
    );
  }
  return result;
}
