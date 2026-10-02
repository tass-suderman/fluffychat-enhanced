// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class SeenByRow extends StatelessWidget {
  final Event event;
  final List<User>? users;
  const SeenByRow({super.key, required this.event, this.users});

  void _showReaders(BuildContext context, List<User> readers) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).readBy),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final user in readers)
                  ListTile(
                    title: Text(user.calcDisplayname()),
                    subtitle: SelectableText(user.id),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L10n.of(context).close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliedUsers = users;
    if (suppliedUsers != null) return _buildRow(context, suppliedUsers);
    return StreamBuilder(
      stream: event.room.client.onSync.stream.where(
        (sync) =>
            sync.rooms?.join?[event.room.id]?.ephemeral?.any(
              (event) => event.type == 'm.receipt',
            ) ??
            false,
      ),
      builder: (context, _) => _buildRow(
        context,
        event.receipts
            .map((receipt) => receipt.user)
            .where(
              (user) =>
                  user.id != event.room.client.userID &&
                  user.id != event.senderId,
            )
            .toList(),
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<User> readers) {
    if (readers.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    const maxAvatars = 7;
    final overflow = readers.skip(maxAvatars).toList();
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: FluffyThemes.maxTimelineWidth,
        ),
        alignment: event.senderId == event.room.client.userID
            ? Alignment.topRight
            : Alignment.topLeft,
        padding: const EdgeInsets.only(bottom: 4, top: 1, left: 8, right: 8),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final user in readers.take(maxAvatars))
              Tooltip(
                message: '${user.calcDisplayname()}\n${user.id}',
                child: Avatar(
                  client: event.room.client,
                  mxContent: user.avatarUrl,
                  name: user.calcDisplayname(),
                  size: 16,
                  onTap: () => _showReaders(context, [user]),
                ),
              ),
            if (overflow.isNotEmpty)
              Tooltip(
                message: overflow
                    .map((user) => user.calcDisplayname())
                    .join('\n'),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  child: InkWell(
                    onTap: () => _showReaders(context, readers),
                    borderRadius: BorderRadius.circular(32),
                    child: SizedBox(
                      width: 24,
                      height: 16,
                      child: Center(
                        child: Text(
                          '+${overflow.length}',
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
