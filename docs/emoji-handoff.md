# Emoji rendering investigation handoff

Status: parked experiment, not a confirmed fix for the user's Linux rendering
issue. The user reports that the visible monochrome problem persisted. Keep
this experiment off main until the actual failing UI and font path are known.

Branch: `experiment/linux-emoji-rendering`. Created from main at `5e2506b83`.
This branch contains only the emoji experiment, not the concurrent system tray,
read receipts, avatar settings or image-viewer Back work.

## What was tried

Native Linux message HTML text spans and the composer explicitly style complete
emoji grapheme clusters with installed Noto Color Emoji. Explicit VS15 clusters
use DejaVu Sans. Other platforms retain existing behavior. Text is never
rewritten. See `docs/linux-emoji-rendering.md` for implementation details,
font comparisons, commands and runtime limitations.

Changes are in `lib/utils/emoji_text.dart`, `lib/pages/chat/chat.dart`,
`lib/pages/chat/events/html_message.dart` and `lib/pages/chat/input_bar.dart`.
The direct characters dependency and associated documentation belong to this
experiment. No bundled font or system fontconfig change was introduced.

## Evidence and validation

Flutter 3.47.4 Linux-engine tests in an isolated X11 display showed fallback
alone insufficient with a primary font containing monochrome emoji glyphs.
Explicit emoji-font spans produced colored pixels for the tested message and
composer samples. This does not explain the user's continuing problem and does
not validate every emoji-bearing UI (reaction pills, pickers, room lists etc.).
The user will return with screenshots to identify the actual failing surface.

After branch extraction, all 25 tests in `test/emoji_text_test.dart` passed and
`flutter analyze --no-pub` reported no issues. The native emoji integration test
was retained separately; it passed before extraction, but was not rerun on this
branch. The unrelated native tray test stays on main.

## Resume here

1. Obtain screenshots, failing UI location, exact build/commit and launch path;
   verify the executable is the newly built fork, not the AUR installation.
2. Trace that surface's actual text style and renderer. Do not assume this
   message/composer experiment covers it.
3. Verify Flutter's runtime font resolution independently of browser/fontconfig
   evidence. Check whether installed fonts are available in that launch context.
4. Compare this branch with main, reproduce the user's case, then decide whether
   to discard, revise or selectively reapply the experiment.
5. Preserve VS15, whole sequences, copying, selection, links and original text.

## Toolchain

Use `$HOME/.local/share/fluffychat-flutter-sdk/bin/flutter` (3.47.4), not the old
/tmp SDK. Run `flutter pub get` in a fresh worktree, then analyze and focused
checks. Generated localization Dart files are ignored. Native integration-test
instructions are in `docs/linux-emoji-rendering.md`; do not change fontconfig.

No branch was pushed. User handles publication later. No signing keys belong
in this branch. Main's unrelated working changes must not be reverted.
