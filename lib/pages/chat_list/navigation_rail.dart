// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/navi_rail_item.dart';
import 'package:fluffychat/pages/chat_list/start_chat_fab.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/space_order.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class SpacesNavigationRail extends StatefulWidget {
  final String? activeSpaceId;
  final void Function() onGoToChats;
  final void Function(String) onGoToSpaceId;

  const SpacesNavigationRail({
    required this.activeSpaceId,
    required this.onGoToChats,
    required this.onGoToSpaceId,
    super.key,
  });

  @override
  State<SpacesNavigationRail> createState() => _SpacesNavigationRailState();
}

class _SpacesNavigationRailState extends State<SpacesNavigationRail> {
  final Map<String, String> _localOrders = {};
  Client? _orderClient;
  bool _savingOrder = false;

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_savingOrder || oldIndex == newIndex) return;
    final client = Matrix.of(context).client;
    final all = orderedSpaces(client.rooms, localOrders: _localOrders);
    final hidden = AppSettings.hiddenSpaces.value;
    final ids = reorderVisibleSpaces(
      all.map((room) => room.id).toList(),
      all
          .where((room) => hidden.contains(_spaceKey(room)))
          .map((room) => room.id)
          .toSet(),
      oldIndex,
      newIndex,
    );
    final changes = <Room, String>{};
    for (var i = 0; i < ids.length; i++) {
      final room = client.getRoomById(ids[i])!;
      final order = spaceOrderAt(i);
      if ((_localOrders[room.id] ??
              room.roomAccountData[spaceOrderEventType]?.content['order']) !=
          order) {
        changes[room] = order;
      }
    }
    setState(() {
      _savingOrder = true;
      _localOrders.addAll(
        changes.map((room, order) => MapEntry(room.id, order)),
      );
    });
    final pending = changes.keys.toSet();
    try {
      for (final entry in changes.entries) {
        await client.setAccountDataPerRoom(
          client.userID!,
          entry.key.id,
          spaceOrderEventType,
          {
            ...?entry.key.roomAccountData[spaceOrderEventType]?.content,
            'order': entry.value,
          },
        );
        pending.remove(entry.key);
      }
    } catch (error) {
      if (!mounted || Matrix.of(context).client != client) return;
      for (final room in pending) {
        _localOrders.remove(room.id);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toLocalizedString(context))));
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  String _spaceKey(Room room) => '${room.client.userID}|${room.id}';

  Future<void> _setHidden(Room space, bool hidden) async {
    final ids = AppSettings.hiddenSpaces.value.toSet();
    if (hidden) {
      ids.add(_spaceKey(space));
    } else {
      ids.remove(_spaceKey(space));
    }
    await AppSettings.hiddenSpaces.setItem(ids.toList());
    if (!mounted) return;
    if (hidden && widget.activeSpaceId == space.id) widget.onGoToChats();
    setState(() {});
  }

  Future<void> _spaceMenu(Room space, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final hide = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: true, child: Text(L10n.of(context).hideSpace)),
      ],
    );
    if (hide == true) await _setHidden(space, true);
  }

  void _showHidden(List<Room> spaces) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.of(context).hiddenSpaces),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: spaces
                .map(
                  (space) => ListTile(
                    title: Text(space.getLocalizedDisplayname()),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      widget.onGoToSpaceId(space.id);
                    },
                    trailing: IconButton(
                      tooltip: L10n.of(context).restoreSpace,
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _setHidden(space, false);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L10n.of(context).close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    if (_orderClient != client) {
      _orderClient = client;
      _localOrders.clear();
    }
    final coloredMode = !FluffyThemes.isColumnMode(context);
    final theme = Theme.of(context);
    return Material(
      color: coloredMode ? theme.colorScheme.surfaceContainer : null,
      child: SafeArea(
        child: StreamBuilder(
          key: ValueKey(client.userID.toString()),
          stream: client.onSync.stream
              .where((s) => s.hasRoomUpdate)
              .rateLimit(const Duration(seconds: 1)),
          builder: (context, _) {
            _localOrders.removeWhere(
              (id, order) =>
                  client
                      .getRoomById(id)
                      ?.roomAccountData[spaceOrderEventType]
                      ?.content['order'] ==
                  order,
            );

            final hiddenIds = AppSettings.hiddenSpaces.value;
            final sortedSpaces = orderedSpaces(
              client.rooms,
              localOrders: _localOrders,
            );
            final hiddenSpaces = sortedSpaces
                .where(
                  (room) => room.isSpace && hiddenIds.contains(_spaceKey(room)),
                )
                .toList();
            final allSpaces = sortedSpaces
                .where(
                  (room) =>
                      room.isSpace && !hiddenIds.contains(_spaceKey(room)),
                )
                .toList();

            return SizedBox(
              width: FluffyThemes.isColumnMode(context)
                  ? FluffyThemes.navRailWidth
                  : FluffyThemes.navRailWidth - 8,
              child: Column(
                children: [
                  NaviRailItem(
                    isSelected: widget.activeSpaceId == null,
                    onTap: widget.onGoToChats,
                    icon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.forum_outlined),
                    ),
                    selectedIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.forum),
                    ),
                    toolTip: L10n.of(context).chats,
                    unreadBadgeFilter: (room) => true,
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: allSpaces.length,
                      onReorderItem: _reorder,
                      itemBuilder: (context, i) {
                        final space = allSpaces[i];
                        final displayname = allSpaces[i]
                            .getLocalizedDisplayname(
                              MatrixLocals(L10n.of(context)),
                            );
                        final spaceChildrenIds = space.spaceChildren
                            .map((c) => c.roomId)
                            .toSet();
                        final tile = GestureDetector(
                          onSecondaryTapDown: (details) =>
                              _spaceMenu(space, details.globalPosition),
                          onLongPressStart: (details) =>
                              _spaceMenu(space, details.globalPosition),
                          child: NaviRailItem(
                            toolTip: displayname,
                            isSelected: widget.activeSpaceId == space.id,
                            onTap: () => widget.onGoToSpaceId(allSpaces[i].id),
                            unreadBadgeFilter: (room) =>
                                spaceChildrenIds.contains(room.id),
                            icon: Avatar(
                              mxContent: allSpaces[i].avatar,
                              name: displayname,
                              //size: 36,
                              shapeBorder: RoundedSuperellipseBorder(
                                side: BorderSide(
                                  width: 1,
                                  color: Theme.of(context).dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppConfig.spaceBorderRadius,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppConfig.spaceBorderRadius,
                              ),
                            ),
                          ),
                        );
                        return Stack(
                          key: ValueKey(space.id),
                          children: [
                            if (!PlatformInfos.isMobile && !_savingOrder)
                              ReorderableDragStartListener(
                                index: i,
                                child: tile,
                              )
                            else
                              tile,
                            if (PlatformInfos.isMobile && !_savingOrder)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    // Preserve the drag target without drawing an icon.
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: ColoredBox(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  NaviRailItem(
                    isSelected: false,
                    onTap: () => context.go('/rooms/newspace'),
                    icon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.add),
                    ),
                    toolTip: L10n.of(context).createNewSpace,
                  ),
                  if (hiddenSpaces.isNotEmpty)
                    NaviRailItem(
                      toolTip: L10n.of(context).hiddenSpaces,
                      isSelected: hiddenSpaces.any(
                        (space) => space.id == widget.activeSpaceId,
                      ),
                      onTap: () => _showHidden(hiddenSpaces),
                      icon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.visibility_off_outlined),
                      ),
                    ),
                  if (FluffyThemes.isColumnMode(context))
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: StartChatFab(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
