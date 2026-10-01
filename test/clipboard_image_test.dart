// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:fluffychat/pages/chat/utils/clipboard_image.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

void main() {
  for (final fixture in {
    'png': [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    'jpg': [0xff, 0xd8, 0xff, 0xe0],
    'gif': [0x47, 0x49, 0x46, 0x38, 0x39, 0x61],
  }.entries) {
    test(
      'Pasted ${fixture.key} preserves bytes and has an image filename',
      () async {
        final bytes = Uint8List.fromList(fixture.value);
        final xfile = clipboardImageFile(bytes);
        final file = MatrixFile(
          bytes: await xfile.readAsBytes(),
          name: xfile.name,
          mimeType: xfile.mimeType,
        ).detectFileType;
        expect(file, isA<MatrixImageFile>());
        expect(file.name, 'clipboard.${fixture.key}');
        expect(
          file.mimeType,
          fixture.key == 'jpg' ? 'image/jpeg' : 'image/${fixture.key}',
        );
        expect(file.bytes, bytes);
      },
    );
  }
}
