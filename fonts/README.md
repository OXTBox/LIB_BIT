# fonts

BitFontMaker2 fonts (JSON: one key per character code, each a list of row numbers; the
other keys are the font's name and settings).

| File | What |
|---|---|
| `KeepThoughts_bitfontmaker2.json` | the owner's "Keep Thoughts" font, 16x16: illustration characters for games, not letters (e.g. `!` is a face, `A` a maze tile). 104 characters, codes 33 and up. |

Reading one: `Bit.FromRows(rows, 16)` in `livecode/lib_bit.livecodescript` turns one character's
row list into a grid (column 1 = bit value 1). Reading the whole JSON file in one call
(BitFontMaker2 import/export) is still on the list in the main README.
