// SPDX-FileCopyrightText: 2026 Contributors to FluffyChat
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

const mediaSpoilerKey = 'page.codeberg.everypizza.msc4193.spoiler';
const mediaSpoilerReasonKey = '$mediaSpoilerKey.reason';

extension MediaSpoiler on Event {
  bool get isMediaSpoiler => content[mediaSpoilerKey] == true;
  String? get mediaSpoilerReason =>
      content.tryGet<String>(mediaSpoilerReasonKey);
}

Map<String, dynamic>? mediaUploadContent(
  String caption, {
  bool spoiler = false,
}) {
  final body = caption.trim();
  if (body.isEmpty && !spoiler) return null;
  return {
    if (body.isNotEmpty) 'body': body,
    if (spoiler) mediaSpoilerKey: true,
  };
}
