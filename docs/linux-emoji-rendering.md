# Linux emoji rendering

The fork styles emoji only on native Linux. Android, iOS, macOS, Windows and
web keep their existing font behavior. No message text, variation selectors,
editing values or sent content are rewritten, and system fontconfig is untouched.

## Flutter findings

A temporary minimal app tested the actual Flutter 3.47.4 Linux engine in a
virtual display, using installed fonts rather than browser rendering or the
widget-test Ahem font. Raster color-pixel checks compared a primary font,
`fontFamilyFallback: ['Noto Color Emoji']`, and an explicit emoji font:

- Roboto already rendered most tested emoji in color, but rendered `1️⃣`
  without color, even with the fallback.
- DejaVu Sans rendered `😎`, `😂`, `☺`, `♥` and `☎` monochrome with the fallback.
  Adding VS16 did not reliably override its glyphs in Flutter.
- Explicit Noto Color Emoji rendered these glyphs and complete keycaps in color.
- Roboto/emoji fallback also rendered tested VS15 sequences in color. Explicit
  DejaVu Sans is therefore used for VS15 text presentation.

The installed Noto Color Emoji and DejaVu Sans resolved successfully through
Flutter's Linux font manager. An app-bundled font was unnecessary on this machine.
Other Linux installations must provide those fonts (`noto-fonts-emoji` and
`ttf-dejavu` on Arch). Merely matching a font through `fc-match` is not considered
proof of Flutter's rendering behavior.

## Implementation

`lib/utils/emoji_text.dart` iterates Flutter's extended grapheme clusters and
reuses the existing emoji picker's Unicode emoji classifier. It excludes plain
digits, `#` and `*` unless part of a keycap. Entire clusters receive the emoji
font, including selectors, skin tones, ZWJ sequences, flags and tag sequences.
Explicit VS15 clusters receive a text font. Adjacent runs with identical styles
are combined to avoid a span per ordinary character.

The HTML message renderer retains formatting, custom-emote/mention widget spans
and link handlers. The composer controller uses the same styling, preserving
selection offsets and composing ranges. A composing range that intersects a
cluster underlines that whole cluster without splitting its font run.

## Validation

Unit/widget coverage checks cluster preservation, VS15, ordinary typography,
link hit testing, formatted-message selection/copying, composer copying and
IME ranges. Existing autocomplete tests cover arrow/Enter behavior.

The native Linux integration test captures **HtmlMessage** and **InputBar**
with DejaVu Sans as their primary font and measures raster color pixels for:

```
😎 😂 🥳 ✨
☺ ☺️ ♥ ♥️ ☎ ☎️
👍🏽 👩‍💻 🏳️‍🌈 🇨🇦 1️⃣
😎 + VS15, 😂 + VS15, ☺ + VS15, ♥ + VS15, ☎ + VS15
```

Run with the persistent SDK and a virtual X11 display:

```sh
xvfb-run -a dbus-run-session -- env GDK_BACKEND=x11 \
  "$HOME/.local/share/fluffychat-flutter-sdk/bin/flutter" test --no-pub \
  integration_test/linux_emoji_rendering_test.dart -d linux
```

Wayland, other desktops/font versions and other platforms were not runtime-tested.
The user's reported rendering issue remains unresolved; this branch preserves
the experiment for further investigation.
