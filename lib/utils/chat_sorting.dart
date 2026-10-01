// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:matrix/matrix.dart';

/// Group chats by priority, then activity or their existing hierarchy order.
List<T> sortChats<T>(
  Iterable<T> items,
  Room? Function(T) roomOf, {
  bool byActivity = false,
}) {
  final indexed = items.toList().asMap().entries.toList();
  int rank(T item) {
    final room = roomOf(item);
    if (room == null) return 2;
    final muted = room.pushRuleState != PushRuleState.notify;
    return chatSortRank(
      lowPriority: room.tags.containsKey('m.lowpriority'),
      favorite: room.tags.containsKey('m.favourite'),
      unread: room.isUnreadOrInvited || (muted && room.hasNewMessages),
      muted: muted,
      lowPriorityLast: AppSettings.lowPriorityLast.value,
      pinFavorites: AppSettings.pinFavorites.value,
      unreadFirst: AppSettings.sortUnreadFirst.value,
      includeMuted: AppSettings.sortMutedUnreadFirst.value,
    );
  }

  final ranked = indexed
      .map(
        (entry) => (
          index: entry.key,
          item: entry.value,
          rank: rank(entry.value),
          timestamp: byActivity
              ? roomOf(
                      entry.value,
                    )?.latestEventReceivedTime.millisecondsSinceEpoch ??
                    0
              : 0,
        ),
      )
      .toList();
  ranked.sort((a, b) {
    final result = a.rank.compareTo(b.rank);
    if (result != 0) return result;
    final activity = b.timestamp.compareTo(a.timestamp);
    return activity != 0 ? activity : a.index.compareTo(b.index);
  });
  return ranked.map((entry) => entry.item).toList();
}

int chatSortRank({
  required bool lowPriority,
  required bool favorite,
  required bool unread,
  required bool muted,
  required bool lowPriorityLast,
  required bool pinFavorites,
  required bool unreadFirst,
  required bool includeMuted,
}) {
  if (lowPriorityLast && lowPriority) return 4;
  if (pinFavorites && favorite) return 0;
  if (unreadFirst && unread && (includeMuted || !muted)) return 1;
  return 2;
}
