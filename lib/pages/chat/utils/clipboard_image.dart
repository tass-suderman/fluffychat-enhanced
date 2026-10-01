// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:mime/mime.dart';

XFile clipboardImageFile(Uint8List bytes) {
  final mimeType = lookupMimeType('', headerBytes: bytes) ?? 'image/png';
  final extension = extensionFromMime(mimeType) ?? 'png';
  return XFile.fromData(
    bytes,
    name: 'clipboard.$extension',
    // Native XFile ignores name and derives it from path, even for memory data.
    path: 'clipboard.$extension',
    mimeType: mimeType,
    length: bytes.length,
  );
}
