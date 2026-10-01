// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/pages/chat/events/message_hover_actions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final alignLeft in [false, true]) {
    testWidgets(
      '${alignLeft ? 'Left' : 'Right'} toolbar stays above the message and permits clicks',
      (tester) async {
        var replies = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: MessageHoverActions(
                    alignLeft: alignLeft,
                    actions: [
                      IconButton(
                        tooltip: 'Reply',
                        onPressed: () => replies++,
                        icon: const Icon(Icons.reply),
                      ),
                    ],
                    child: const SizedBox(
                      height: 100,
                      child: Center(child: Text('Message')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final before = tester.getRect(find.text('Message'));
        expect(find.byTooltip('Reply'), findsNothing);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.text('Message')));
        await tester.pump();
        expect(find.byTooltip('Reply'), findsOneWidget);
        expect(tester.getRect(find.text('Message')), before);
        final messageRect = tester.getRect(find.byType(MessageHoverActions));
        final actionRect = tester.getRect(find.byTooltip('Reply'));
        final toolbarRect = tester.getRect(
          find
              .ancestor(
                of: find.byTooltip('Reply'),
                matching: find.byType(Positioned),
              )
              .first,
        );
        expect(actionRect.bottom, lessThanOrEqualTo(messageRect.top));
        expect(
          alignLeft ? toolbarRect.left : toolbarRect.right,
          alignLeft ? messageRect.left + 8 : messageRect.right - 8,
        );
        await mouse.moveTo(Offset(actionRect.center.dx, messageRect.top - 2));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byTooltip('Reply'), findsOneWidget);
        await mouse.moveTo(tester.getCenter(find.byTooltip('Reply')));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byTooltip('Reply'), findsOneWidget);
        await tester.tap(find.byTooltip('Reply'));
        expect(replies, 1);
        await mouse.moveTo(Offset.zero);
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byTooltip('Reply'), findsNothing);
        await mouse.removePointer();
      },
    );
  }
}
