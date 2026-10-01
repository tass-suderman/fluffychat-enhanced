// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/media_spoiler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Builds media only after explicit disclosure, preventing thumbnail, blurhash,
/// animation and accessibility leaks from a hidden child.
class SpoilerMedia extends StatefulWidget {
  final Event event;
  final WidgetBuilder builder;
  final bool initiallyRevealed;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SpoilerMedia({
    required this.event,
    required this.builder,
    this.initiallyRevealed = false,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  @override
  State<SpoilerMedia> createState() => _SpoilerMediaState();
}

class _SpoilerMediaState extends State<SpoilerMedia> {
  String get _currentIdentity =>
      '${widget.event.room.id}|${widget.event.eventId}|${jsonEncode(widget.event.content)}';
  late String _identity;
  late bool _revealed;

  @override
  void initState() {
    super.initState();
    _identity = _currentIdentity;
    _revealed = widget.initiallyRevealed;
  }

  @override
  void didUpdateWidget(covariant SpoilerMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_identity != _currentIdentity) {
      _identity = _currentIdentity;
      _revealed = widget.initiallyRevealed;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.event.isMediaSpoiler || _revealed) {
      return widget.builder(context);
    }
    final l10n = L10n.of(context);
    final reason = widget.event.mediaSpoilerReason;
    return Material(
      color: Colors.black,
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => setState(() => _revealed = true),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: l10n.revealSpoiler,
                    child: const Icon(
                      Icons.visibility_off_outlined,
                      color: Colors.white,
                    ),
                  ),
                  if (reason != null && reason.trim().isNotEmpty)
                    Flexible(
                      child: Text(
                        reason,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
