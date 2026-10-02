// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' as ui;

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/html_message.dart';
import 'package:fluffychat/pages/chat/input_bar.dart';
import 'package:fluffychat/utils/emoji_text.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Run on the real Linux engine, not flutter_tester's Ahem test font:
/// xvfb-run -a flutter test integration_test/linux_emoji_rendering_test.dart -d linux
/// Requires installed Noto Color Emoji and DejaVu Sans; changes no fontconfig.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const samples = [
    '😎',
    '😂',
    '🥳',
    '✨',
    '☺',
    '☺️',
    '♥',
    '♥️',
    '☎',
    '☎️',
    '👍🏽',
    '👩‍💻',
    '🏳️‍🌈',
    '🇨🇦',
    '1️⃣',
    '😎\uFE0E',
    '😂\uFE0E',
    '☺\uFE0E',
    '♥\uFE0E',
    '☎\uFE0E',
  ];

  testWidgets(
    'System fonts render message and composer emojis in color, except VS15',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.init(loadWebConfigFile: false);
      final room = Room(
        id: '!font-test:example.org',
        client: Client('font rendering', database: _UnusedDatabase()),
      );
      final controller = EmojiMessageEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      for (final composer in [false, true]) {
        for (final sample in samples) {
          controller.text = sample;
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: L10n.localizationsDelegates,
              supportedLocales: L10n.supportedLocales,
              // Deliberately use a font containing monochrome emoji glyphs.
              theme: ThemeData(
                fontFamily: 'DejaVu Sans',
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(fontSize: 48, color: Colors.black),
                ),
              ),
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: captureKey,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SizedBox(
                        width: 240,
                        height: 160,
                        child: composer
                            ? InputBar(
                                room: room,
                                controller: controller,
                                focusNode: focus,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                suggestionEmojis: const [],
                              )
                            : HtmlMessage(
                                html: '<b>$sample</b>',
                                room: room,
                                fontSize: 48,
                                textColor: Colors.black,
                                linkStyle: const TextStyle(color: Colors.black),
                                onOpen: (_) {},
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var coloredPixels = 0;
          for (var i = 0; i < pixels.length; i += 4) {
            if ((pixels[i] - pixels[i + 1]).abs() > 24 ||
                (pixels[i] - pixels[i + 2]).abs() > 24 ||
                (pixels[i + 1] - pixels[i + 2]).abs() > 24) {
              coloredPixels++;
            }
          }
          image.dispose();
          expect(controller.text, sample);
          expect(
            coloredPixels,
            sample.contains('\uFE0E') ? 0 : greaterThan(20),
            reason: '${composer ? 'composer' : 'message'}: $sample',
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !PlatformInfos.isLinux,
  );

}

class _UnusedDatabase extends Fake implements MatrixSdkDatabase {}
