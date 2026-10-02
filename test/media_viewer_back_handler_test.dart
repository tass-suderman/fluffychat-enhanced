// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/widgets/media_viewer_back_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final location in ['/rooms/chat', '/rooms/chat/search', '/profile']) {
    testWidgets('Back dismisses viewer before $location navigation', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          ShellRoute(
            builder: (context, state, child) => child,
            routes: [
              GoRoute(
                path: '/rooms',
                builder: (context, state) =>
                    const Scaffold(body: Text('Rooms')),
                routes: [
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => const _OpenViewer(),
                    routes: [
                      GoRoute(
                        path: 'search',
                        builder: (context, state) => const _OpenViewer(),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) => const _OpenViewer(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open viewer'));
      await tester.pumpAndSettle();
      expect(find.text('Viewer'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Viewer'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, location);
      expect(find.text('Open viewer'), findsOneWidget);
      if (location != '/profile') {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          location == '/rooms/chat' ? '/rooms' : '/rooms/chat',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Back closes an overlay before the viewer and handles edge Back',
    (tester) async {
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const _OpenViewer())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open viewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Overlay'), findsNothing);
      expect(find.text('Viewer'), findsOneWidget);
      // Flutter falls back to normal Back when no predictive transition claims
      // the committed Android edge gesture (as with a dialog viewer).
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('commitBackGesture'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text('Viewer'), findsNothing);
      expect(find.text('Open viewer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Plain Navigator retains normal dialog Back behavior', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _OpenViewer()));
    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Viewer'), findsNothing);
    expect(find.text('Open viewer'), findsOneWidget);
  });
}

class _OpenViewer extends StatelessWidget {
  const _OpenViewer();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => MediaViewerBackHandler(
          child: Scaffold(
            body: Column(
              children: [
                const Text('Viewer'),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('Overlay')),
                  ),
                  child: const Text('Share'),
                ),
              ],
            ),
          ),
        ),
      ),
      child: const Text('Open viewer'),
    ),
  );
}
