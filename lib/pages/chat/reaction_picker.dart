// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'sticker_picker_dialog.dart';

class ReactionOption {
  final String value;
  final String name;
  final bool custom;

  const ReactionOption(this.value, this.name, {this.custom = false});
}

List<ReactionOption> searchReactions(
  String query,
  Iterable<ReactionOption> options,
) {
  final normalized = query.trim().toLowerCase().replaceAll(':', '');
  return options.where((option) {
    return option.name.toLowerCase().contains(normalized) ||
        (!option.custom && option.value.contains(normalized));
  }).toList();
}

List<ReactionOption> reactionOptions(Room room, Locale locale) {
  final emojiSet = Config().emojiSet!;
  final englishNames = {
    for (final category in emojiSet(const Locale('en')))
      for (final emoji in category.emoji) emoji.emoji: emoji.name,
  };
  return <ReactionOption>[
    for (final category in emojiSet(locale))
      for (final emoji in category.emoji)
        ReactionOption(
          emoji.emoji,
          '${emoji.name} ${englishNames[emoji.emoji] ?? ''}',
        ),
    for (final pack in room.getImagePacks(ImagePackUsage.emoticon).values)
      for (final entry in pack.images.entries)
        ReactionOption(
          entry.value.url.toString(),
          '${entry.key} ${entry.value.body ?? ''}',
          custom: true,
        ),
  ];
}

class ReactionPicker extends StatefulWidget {
  final Room room;

  const ReactionPicker({required this.room, super.key});

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final options = reactionOptions(widget.room, locale);
    final results = searchReactions(_query, options);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customReaction),
        leading: const CloseButton(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [
                            Tab(text: l10n.emojis),
                            Tab(text: l10n.customEmojis),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              EmojiPicker(
                                onEmojiSelected: (_, emoji) =>
                                    Navigator.of(context).pop(emoji.emoji),
                                config: Config(
                                  locale: locale,
                                  emojiViewConfig: EmojiViewConfig(
                                    backgroundColor:
                                        theme.colorScheme.onInverseSurface,
                                  ),
                                  categoryViewConfig: CategoryViewConfig(
                                    backgroundColor: theme.colorScheme.surface,
                                    backspaceColor: theme.colorScheme.primary,
                                    iconColor: theme.colorScheme.primary
                                        .withAlpha(128),
                                    iconColorSelected:
                                        theme.colorScheme.primary,
                                    indicatorColor: theme.colorScheme.primary,
                                  ),
                                  skinToneConfig: SkinToneConfig(
                                    dialogBackgroundColor: Color.lerp(
                                      theme.colorScheme.surface,
                                      theme.colorScheme.primaryContainer,
                                      0.75,
                                    )!,
                                    indicatorColor: theme.colorScheme.onSurface,
                                  ),
                                  bottomActionBarConfig:
                                      const BottomActionBarConfig(
                                        enabled: false,
                                      ),
                                ),
                              ),
                              StickerPickerDialog(
                                room: widget.room,
                                showSearch: false,
                                usage: ImagePackUsage.emoticon,
                                onSelected: (image) => Navigator.of(
                                  context,
                                ).pop(image.url.toString()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : results.isEmpty
                ? Center(child: Text(l10n.noEmotesFound))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: results.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 64,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemBuilder: (context, index) {
                      final option = results[index];
                      return Tooltip(
                        message: option.name.trim(),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(option.value),
                          child: Center(
                            child: option.custom
                                ? MxcImage(
                                    uri: Uri.parse(option.value),
                                    client: widget.room.client,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.contain,
                                    animated: true,
                                    isThumbnail: false,
                                  )
                                : Text(
                                    option.value,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
