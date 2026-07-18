# wi_symbol_fallback.ttf

Source: DejaVu Sans 2.37 (dejavu-fonts.github.io, release
version_2_37), subset via fonttools to eight symbol codepoints
(U+25CF U+25CB U+2713 U+00B7 U+2014 U+2192 U+25C6 U+25C7).

License: Bitstream Vera + public-domain additions (see
dejavu-fonts-LICENSE.txt beside this file). Redistribution permitted
with license text -- PUBLIC TIER, ships in the open repo, no bundle
gating.

Purpose (GH#169): the default theme font lacks these glyphs; desktop
borrows them from system fonts, the web export cannot and rendered
tofu (AP pips, move pips, journal checkmarks). Appended as a global
font fallback at boot (src/world/main.gd).
