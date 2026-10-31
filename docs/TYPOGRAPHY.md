# Pebble typography

## Visual direction

Pebble uses two complementary typefaces. **Plus Jakarta Sans** is the default
interface font for lists, navigation, buttons, addresses, receipts and form
fields. **Fraunces** is reserved for the expressive, watercolor-inspired page
and section headings.

| Element | Typeface | Weight | Guidance |
| --- | --- | --- | --- |
| Page titles | Fraunces | SemiBold (600–700) | 23–31 logical px; avoid all-caps |
| Watercolor section titles | Fraunces Italic | SemiBold (600) | 21 logical px |
| Transaction rows and labels | Plus Jakarta Sans | Medium/Bold | 12–15 logical px |
| Monetary values | Plus Jakarta Sans | ExtraBold (800) | Tabular figures (OpenType `tnum`) |
| Body and forms | Plus Jakarta Sans | Regular/Medium | 13–16 logical px |
| Buttons | Plus Jakarta Sans | Bold | 14–17 logical px |

The families are defined in `lib/core/pebble_typography.dart` and the app theme
in `lib/core/design.dart`. Text styles that need equal-width digits use
`PebbleTypography.tabularFigures`.

## Offline packaging

Run the normal repository setup:

```bash
bash scripts/bootstrap.sh
```

The bootstrap runs `scripts/fetch_fonts.py` to obtain **four official,
SIL-OFL-licensed variable-font TTFs**, verify their pinned Git object checksums,
and place them under `assets/fonts/`. Flutter then bundles the fonts into
Android, iOS and Linux packages. **No runtime Google Fonts download is needed.**

The TTF files are intentionally not duplicated in Git history. A network
connection is required once during setup, just as it is for `flutter pub get`.
Repeated bootstrap runs reuse local copies after checksum validation.

Upstream: `google/fonts`, directories `ofl/plusjakartasans` and
`ofl/fraunces`. Full licenses are preserved in
`third_party/fonts/OFL-PlusJakartaSans.txt` and
`third_party/fonts/OFL-Fraunces.txt`.

## Accessibility

The app continues to respect Flutter's system text-scale setting. Decorative
Fraunces is never used for amounts, validation messages or multi-line data.
Amounts use tabular figures for better alignment and accessibility.
