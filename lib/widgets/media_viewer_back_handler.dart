// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

/// Gives a modal media viewer priority over the underlying chat router.
class MediaViewerBackHandler extends StatelessWidget {
  final Widget child;

  const MediaViewerBackHandler({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    if (Router.maybeOf(context)?.backButtonDispatcher == null) return child;
    return BackButtonListener(
      onBackButtonPressed: () async {
        // A share dialog above the viewer must receive Back first.
        if (ModalRoute.of(context)?.isCurrent != true) return false;
        return Navigator.of(context).maybePop();
      },
      child: child,
    );
  }
}
