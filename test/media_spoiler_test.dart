// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/image_bubble.dart';
import 'package:fluffychat/pages/chat/send_file_dialog.dart';
import 'package:fluffychat/pages/chat/utils/clipboard_image.dart';
import 'package:fluffychat/utils/media_spoiler.dart';
import 'package:fluffychat/widgets/blur_hash.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:fluffychat/widgets/spoiler_media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
    await AppSettings.showThumbnailsInTimeline.setItem(false);
  });
  late Room room;
  setUp(() {
    room = Room(
      id: '!room:example.org',
      client: Client('spoiler test', database: _UnusedDatabase()),
    );
  });

  Event image({
    String id = 'image',
    Object? flag = true,
    bool encrypted = false,
    String? reason,
  }) => Event.fromJson({
    'event_id': id,
    'type': EventTypes.Message,
    'sender': '@user:example.org',
    'origin_server_ts': 1,
    'content': {
      'msgtype': MessageTypes.Image,
      'body': 'Caption, not a spoiler filename',
      'filename': 'image.png',
      if (encrypted) 'file': {'url': 'mxc://example.org/encrypted'},
      if (!encrypted) 'url': 'mxc://example.org/image',
      mediaSpoilerKey: ?flag,
      mediaSpoilerReasonKey: ?reason,
      'info': {
        'mimetype': 'image/png',
        'xyz.amorgan.blurhash': 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      },
    },
  }, room);

  Future<void> mount(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('Upload flag works without captions and never overrides filenames', () {
    expect(mediaUploadContent('', spoiler: true), {mediaSpoilerKey: true});
    expect(mediaUploadContent(' A caption ', spoiler: true), {
      'body': 'A caption',
      mediaSpoilerKey: true,
    });
    expect(mediaUploadContent(' A caption '), {'body': 'A caption'});
    expect(mediaUploadContent(''), isNull);
  });

  testWidgets('Upload preview spoiler button toggles each image independently', (
    tester,
  ) async {
    final file = clipboardImageFile(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1sAAAAASUVORK5CYII=',
      ),
    );
    await mount(
      tester,
      Builder(
        builder: (context) => SendFileDialog(
          room: room,
          files: [file, file],
          outerContext: context,
          threadRootEventId: null,
          threadLastEventId: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final buttons = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton && widget.tooltip == 'Mark image as spoiler',
    );
    expect(buttons, findsNWidgets(2));
    await tester.tap(buttons.first);
    await tester.pump();
    expect(tester.widget<IconButton>(buttons.first).isSelected, isTrue);
    expect(tester.widget<IconButton>(buttons.last).isSelected, isFalse);
    await tester.tap(buttons.first);
    await tester.pump();
    expect(tester.widget<IconButton>(buttons.first).isSelected, isFalse);
  });

  test(
    'Only a true boolean hides media, independently of caption or encryption',
    () {
      expect(image().isMediaSpoiler, isTrue);
      expect(image(encrypted: true).isMediaSpoiler, isTrue);
      expect(image(flag: false).isMediaSpoiler, isFalse);
      expect(image(flag: null).isMediaSpoiler, isFalse);
      expect(image(flag: 'true').isMediaSpoiler, isFalse);
    },
  );

  testWidgets('First click reveals image in chat; second click opens viewer', (
    tester,
  ) async {
    var opened = 0;
    await mount(
      tester,
      ImageBubble(
        image(encrypted: true),
        width: 128,
        height: 128,
        textColor: Colors.white,
        onTap: () => opened++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MxcImage), findsNothing);
    expect(find.byType(BlurHash), findsNothing);
    expect(find.text('Caption, not a spoiler filename'), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(
      tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(SpoilerMedia),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      Colors.black,
    );
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(opened, 0);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.byType(BlurHash), findsOneWidget);
    await tester.tap(find.byType(BlurHash));
    expect(opened, 1);
    expect(find.byType(MxcImage), findsNothing);
  });

  testWidgets(
    'Viewer reveals locally and resets when another event or edit replaces it',
    (tester) async {
      Widget cover(Event event) => SpoilerMedia(
        event: event,
        width: 128,
        height: 128,
        builder: (_) => const Text('Visible media'),
      );
      await mount(tester, cover(image()));
      await tester.pumpAndSettle();
      expect(find.text('Visible media'), findsNothing);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(find.text('Visible media'), findsOneWidget);
      await mount(tester, cover(image(id: 'another')));
      expect(find.text('Visible media'), findsNothing);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      await mount(
        tester,
        cover(image(id: 'another', reason: 'Edited spoiler')),
      );
      expect(find.text('Visible media'), findsNothing);
    },
  );

  testWidgets('Normal media remains visible and reasons render as plain text', (
    tester,
  ) async {
    await mount(
      tester,
      SpoilerMedia(
        event: image(flag: false),
        builder: (_) => const Text('Ordinary media'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ordinary media'), findsOneWidget);
    await mount(
      tester,
      SpoilerMedia(
        event: image(reason: '<b>Do not spoil</b>'),
        width: 128,
        height: 128,
        builder: (_) => const Text('Secret'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('<b>Do not spoil</b>'), findsOneWidget);
    expect(find.text('Secret'), findsNothing);
  });

  test(
    'SDK replacement content retains spoiler and optional reason on deletion edits',
    () {
      final original = image();
      final replacement = Event.fromJson({
        'event_id': 'edit',
        'type': EventTypes.Message,
        'sender': original.senderId,
        'origin_server_ts': 2,
        'content': {
          'm.new_content': {
            ...original.content,
            'body': 'Deleted message (4min, 5sec)',
            mediaSpoilerReasonKey: 'Story spoiler',
          },
          'm.relates_to': {
            'rel_type': RelationshipTypes.edit,
            'event_id': original.eventId,
          },
        },
      }, room);
      final timeline = _EditTimeline({
        original.eventId: {
          RelationshipTypes.edit: {replacement},
        },
      });
      final display = original.getDisplayEvent(timeline);
      expect(display.isMediaSpoiler, isTrue);
      expect(display.mediaSpoilerReason, 'Story spoiler');
      expect(display.content['url'], 'mxc://example.org/image');
    },
  );
}

class _UnusedDatabase extends Fake implements MatrixSdkDatabase {}

class _EditTimeline extends Fake implements Timeline {
  @override
  final Map<String, Map<String, Set<Event>>> aggregatedEvents;
  _EditTimeline(this.aggregatedEvents);
}
