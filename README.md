# SelectiveLoot

*[Version française](README.fr.md)*

Addon for **World of Warcraft: Forever**: loot corpses as usual, and the addon picks up everything **except** the items you chose to ignore.

## Features

- **Loot filter**: everything is looted (gold, items, currencies) except the items on your ignore list. Quest items are always looted.
- **One list per character**: each character has their own ignore list. Settings are shared across the account.
- **Shift+click** a corpse to loot everything, ignored items included.
- **Key binding**: hover over an item (bags, loot, bank…) and press your key to ignore it, or to loot it again.
- **Tooltips**:
  - ignored item: red line "Ignored when looting" (nothing is added to other items);
  - corpse already looted: green line "Looted", with the number of ignored items left on it;
  - corpse not looted yet: yellow line "Not looted yet".
- **Loot display**: the loot window is replaced by an on-screen list of what you pick up, styled like the items of the loot window (icon in its item slot, name on the parchment plate, quality color). Lines fade in and out, and ignored items left behind are shown too (grayed out, red cross). Size, display time, number of lines and plate opacity can be adjusted. To move it: drag the preview while the options are open, or hold **Ctrl** and drag it in game.
- **Options in the game menu** (Options > AddOns > SelectiveLoot, or `/sl`):
  - status of the filter, of the game's auto loot and of the key binding, with a button to fix each one;
  - set the key binding right from the panel, with a warning if the key is already used;
  - ignore list: add by ID, link or drag and drop, with a "Remove" button on each line;
  - language: automatic (game language), English or French.

Colors everywhere: **green** = all good, **yellow** = to do, **red** = problem or ignored item, **gray** = detail.

## Installation

1. Download the addon from CurseForge, or this repository (**Code > Download ZIP**).
2. Copy the `SelectiveLoot` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
3. In game, type `/sl`: if the game's auto loot is on, click **Fix** (the filter needs it off), then choose your key binding.

Don't copy the `tests` folder into the game.

## Commands

| Command | Effect |
|---|---|
| `/sl` | Opens the options |
| `/sl add <link or ID>` | Ignores an item |
| `/sl del <link or ID>` | Stops ignoring it |
| `/sl on` / `/sl off` | Turns the filter on or off |
| `/sl move` | Unlocks / locks the loot display |
| `/sl debug` | Prints a loot trace in the chat, for bug reports |

## Known limits

- The corpse sparkle is handled by the game, not by the addon. In WoW Forever it stops as soon as a corpse has been looted, even if ignored items are still on it: the "Looted" tooltip line tells you how many are left.
- The loot window may flash for a split second before closing when only ignored items are left.
- If the game hides corpse identities from addons, the "Looted" / "Not looted yet" lines don't appear. The filter keeps working.

## Translations

English and French are included. Texts are in [`SelectiveLoot/Locales.lua`](SelectiveLoot/Locales.lua): to add a language, copy the `enUS` table, translate it, and add the language to `ns.LANGUAGES`.

## Tests

`tests/!SelectiveLootSandbox` simulates loot, corpses, a bag, the Options menu and key bindings to test the addon in [wow-addons-sandbox](https://github.com/srrmke/wow-addons-sandbox) without launching the game. Screenshots are in `tests/captures`.

## License

[MIT](LICENSE): you can use, modify and share the addon freely, as long as you keep the copyright notice.
