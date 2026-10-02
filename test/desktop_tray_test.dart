// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/desktop_tray.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DesktopTray tray;
  late List<MethodCall> windowCalls;
  late List<MethodCall> trayCalls;
  var hostAvailable = true;
  var menuFails = false;
  const windowChannel = MethodChannel('window_manager');
  const trayChannel = MethodChannel('tray_manager');

  setUp(() {
    windowCalls = [];
    trayCalls = [];
    hostAvailable = true;
    menuFails = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      windowCalls.add(call);
      return call.method == 'isMinimized' ? false : null;
    });
    messenger.setMockMethodCallHandler(trayChannel, (call) async {
      trayCalls.add(call);
      if (menuFails && call.method == 'setContextMenu') {
        throw PlatformException(code: 'failed');
      }
      return null;
    });
    tray = DesktopTray(hasTrayHost: () async => hostAvailable);
  });

  tearDown(() {
    tray.dispose();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockMethodCallHandler(trayChannel, null);
  });

  Future<bool> configure(bool enabled) => tray.configure(
    enabled: enabled,
    showLabel: 'Show',
    exitLabel: 'Exit',
    tooltip: 'FluffyChat',
  );

  test('Close hides, Show restores, and Exit destroys the window', () async {
    expect(await configure(true), isTrue);
    expect(
      trayCalls.map((c) => c.method),
      containsAllInOrder(['setIcon', 'setContextMenu']),
    );
    expect(windowCalls.last.method, 'setPreventClose');
    expect((windowCalls.last.arguments as Map)['isPreventClose'], isTrue);
    tray.onWindowClose();
    await Future<void>.delayed(Duration.zero);
    expect(windowCalls.last.method, 'hide');
    await tray.show();
    expect(
      windowCalls.map((c) => c.method),
      containsAllInOrder(['show', 'focus']),
    );
    await tray.exit();
    expect(trayCalls.last.method, 'destroy');
    expect(windowCalls.last.method, 'destroy');
    final count = windowCalls.length;
    tray.onWindowClose();
    await Future<void>.delayed(Duration.zero);
    expect(windowCalls.length, count);
  });

  test('Disabling restores the window and removes close prevention', () async {
    await configure(true);
    await configure(false);
    expect(trayCalls.last.method, 'destroy');
    expect(
      windowCalls.lastWhere((c) => c.method == 'setPreventClose').arguments,
      {'isPreventClose': false},
    );
    final count = windowCalls.length;
    tray.onWindowClose();
    await Future<void>.delayed(Duration.zero);
    expect(windowCalls.length, count);
  });

  test(
    'A missing host or failed menu never enables close interception',
    () async {
      hostAvailable = false;
      expect(await configure(true), isFalse);
      expect(
        windowCalls
            .where((c) => c.method == 'setPreventClose')
            .every((c) => (c.arguments as Map)['isPreventClose'] == false),
        isTrue,
      );
      hostAvailable = true;
      menuFails = true;
      expect(await configure(true), isFalse);
      expect(
        windowCalls
            .where((c) => c.method == 'setPreventClose')
            .every((c) => (c.arguments as Map)['isPreventClose'] == false),
        isTrue,
      );
    },
  );

  test('Tray host disappearing leaves the window reachable', () async {
    await configure(true);
    hostAvailable = false;
    tray.onWindowClose();
    await Future<void>.delayed(Duration.zero);
    expect(windowCalls.map((c) => c.method), isNot(contains('hide')));
    expect(windowCalls.map((c) => c.method), contains('show'));
  });

  test(
    'Rapid preference changes finish with the last requested state',
    () async {
      await Future.wait([configure(true), configure(false), configure(true)]);
      expect((windowCalls.last.arguments as Map)['isPreventClose'], isTrue);
      expect(trayCalls.last.method, 'setContextMenu');
    },
  );
}
