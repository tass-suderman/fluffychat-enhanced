// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/widgets/settings_switch_list_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Alert once defaults off and persists across settings visits', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppSettings.init(loadWebConfigFile: false);
    await store.remove(AppSettings.notificationAlertOncePerRoom.key);

    Widget settings() => const MaterialApp(
      home: Scaffold(
        body: SettingsSwitchListTile.adaptive(
          title: 'Alert only once per chat',
          setting: AppSettings.notificationAlertOncePerRoom,
        ),
      ),
    );

    await tester.pumpWidget(settings());
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(store.getBool(AppSettings.notificationAlertOncePerRoom.key), true);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(settings());
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(store.getBool(AppSettings.notificationAlertOncePerRoom.key), false);
  });
}
