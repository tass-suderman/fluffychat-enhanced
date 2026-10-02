// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'platform_infos.dart';

/// Owns the native tray independently of routes and keeps the existing app,
/// sync connections and notifications alive while its window is hidden.
class DesktopTray with WindowListener, TrayListener {
  static final instance = DesktopTray();

  final Future<bool> Function() _hasTrayHost;
  Future<void> _pending = Future.value();
  bool _initialized = false;
  bool _enabled = false;
  bool _exiting = false;

  DesktopTray({Future<bool> Function()? hasTrayHost})
    : _hasTrayHost = hasTrayHost ?? _checkTrayHost;

  static Future<bool> _checkTrayHost() async {
    if (!PlatformInfos.isLinux) return true;
    final bus = DBusClient.session();
    try {
      return await bus.nameHasOwner('org.kde.StatusNotifierWatcher');
    } finally {
      await bus.close();
    }
  }

  Future<void> initialize() async {
    if (_initialized || !PlatformInfos.isDesktop) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initialized = true;
  }

  /// Serializes startup, locale changes and setting changes. Never intercept
  /// close before both the tray icon and its menu have been created successfully.
  Future<bool> configure({
    required bool enabled,
    required String showLabel,
    required String exitLabel,
    required String tooltip,
  }) {
    final result = Completer<bool>();
    _pending = _pending.then((_) async {
      try {
        await initialize();
        if (!_initialized || _exiting) {
          result.complete(false);
          return;
        }
        if (!enabled) {
          await _disable();
        } else {
          if (!await _hasTrayHost()) {
            throw StateError('No system tray host is available');
          }
          if (!_enabled) {
            await trayManager.setIcon(
              PlatformInfos.isWindows
                  ? 'assets/logo/mini/tray_icon.ico'
                  : 'assets/logo/mini/logo_mini.png',
            );
          }
          await trayManager.setContextMenu(
            Menu(
              items: [
                MenuItem(key: 'show', label: showLabel),
                MenuItem.separator(),
                MenuItem(key: 'exit', label: exitLabel),
              ],
            ),
          );
          if (!PlatformInfos.isLinux) await trayManager.setToolTip(tooltip);
          await windowManager.setPreventClose(true);
          _enabled = true;
        }
        result.complete(true);
      } catch (error, stack) {
        Logs().w('Unable to configure system tray', error, stack);
        // Leave the app reachable and normally closable if a plugin fails.
        try {
          await _disable();
          await trayManager.destroy();
        } catch (error, stack) {
          Logs().w('Unable to clean up system tray', error, stack);
        }
        result.complete(false);
      }
    });
    return result.future;
  }

  Future<void> _disable() async {
    final wasEnabled = _enabled;
    _enabled = false;
    await windowManager.setPreventClose(false);
    if (wasEnabled) {
      await show();
      await trayManager.destroy();
    }
  }

  Future<void> show() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> exit() async {
    if (_exiting) return;
    _exiting = true;
    _enabled = false;
    // Destroy bypasses close prevention. A failed tray cleanup must not make
    // Exit behave like another request to hide the window.
    try {
      await trayManager.destroy();
    } finally {
      await windowManager.destroy();
    }
  }

  Future<void> _handleClose() async {
    if (!_enabled || _exiting) return;
    try {
      if (await _hasTrayHost()) {
        if (_enabled && !_exiting) await windowManager.hide();
      } else {
        await _disable();
      }
    } catch (error, stack) {
      Logs().w('Unable to hide window to system tray', error, stack);
      await _disable();
    }
  }

  @override
  void onWindowClose() => unawaited(_handleClose());

  @override
  void onTrayIconMouseDown() => unawaited(show());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') unawaited(show());
    if (menuItem.key == 'exit') unawaited(exit());
  }

  void dispose() {
    if (!_initialized) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _initialized = false;
  }
}

Future<void> updateDesktopTray(BuildContext context) async {
  final l10n = L10n.of(context);
  final enabled = AppSettings.closeToTray.value;
  final success = await DesktopTray.instance.configure(
    enabled: enabled,
    showLabel: l10n.trayShowWindow,
    exitLabel: l10n.trayExit,
    tooltip: AppSettings.applicationName.value,
  );
  if (success || !enabled) return;
  await AppSettings.closeToTray.setItem(false);
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(l10n.trayUnavailable)));
}

/// Initializes the persisted preference and refreshes native menu translations.
class DesktopTrayLifecycle extends StatefulWidget {
  final Widget child;
  const DesktopTrayLifecycle({required this.child, super.key});

  @override
  State<DesktopTrayLifecycle> createState() => _DesktopTrayLifecycleState();
}

class _DesktopTrayLifecycleState extends State<DesktopTrayLifecycle> {
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!PlatformInfos.isDesktop) return;
    final locale = Localizations.localeOf(context);
    if (locale == _locale) return;
    _locale = locale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(updateDesktopTray(context));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
