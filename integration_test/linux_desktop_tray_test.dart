// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:fluffychat/utils/desktop_tray.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native close interception hides and restores a live window', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('App remains running'))),
    );
    // The virtual display has no panel. Check native window behavior without
    // requiring one; real tray-host availability is covered separately.
    final tray = DesktopTray(hasTrayHost: () async => true);
    addTearDown(tray.dispose);
    expect(
      await tray.configure(
        enabled: true,
        showLabel: 'Show',
        exitLabel: 'Exit',
        tooltip: 'Test',
      ),
      isTrue,
    );
    expect(await windowManager.isPreventClose(), isTrue);
    await windowManager.close();
    // Do not request a Flutter frame while the native window is hidden.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await windowManager.isVisible(), isFalse);
    expect(find.text('App remains running'), findsOneWidget);
    await tray.show();
    expect(await windowManager.isVisible(), isTrue);
    expect(
      await tray.configure(
        enabled: false,
        showLabel: 'Show',
        exitLabel: 'Exit',
        tooltip: 'Test',
      ),
      isTrue,
    );
    expect(await windowManager.isPreventClose(), isFalse);
  }, skip: !PlatformInfos.isLinux);
}
