// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:material_ui/material_ui.dart';

class MessageHoverActions extends StatefulWidget {
  final Widget child;
  final List<Widget> actions;

  const MessageHoverActions({
    required this.child,
    required this.actions,
    super.key,
  });

  @override
  State<MessageHoverActions> createState() => _MessageHoverActionsState();
}

class _MessageHoverActionsState extends State<MessageHoverActions> {
  final _portal = OverlayPortalController();
  Timer? _hideTimer;

  void _show() {
    _hideTimer?.cancel();
    if (widget.actions.isNotEmpty) _portal.show();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    // Allow the pointer to cross from the message to the floating toolbar.
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _portal.hide();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        final rect = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        return Positioned(
          right: info.overlaySize.width - rect.right + 8,
          bottom: info.overlaySize.height - rect.top,
          child: MouseRegion(
            onEnter: (_) => _show(),
            onExit: (_) => _scheduleHide(),
            // This transparent strip connects the toolbar to the message.
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: widget.actions.isEmpty
                  ? const SizedBox.shrink()
                  : Material(
                      elevation: 4,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.actions,
                      ),
                    ),
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _scheduleHide(),
        child: widget.child,
      ),
    );
  }
}
