# psi_autocast_mfd in-game test plan

**TLDR:** The offline tests (`py -m pytest dev/tests -v`) check files, data and the setup script. This plan covers what only the game can show. Run it with the release build installed (`py build.py --install`, no `--dev`), psi_autocast and psi_autocast_mfd enabled, and the mouse cursor key (Tab) working. Run `condump` at the end and check for `[psi_mfd] error` lines.

## Setup

- Bindings in `user.bnd`: an open key (keypad *), at least two macro keys, keypad + as cancel.
- Have Projected Cryokinesis learned, a few psi points, and at least one psi hypo.

## Opening and closing

| # | Do | Expect |
|---|---|---|
| 1 | Press the open key during play | The MFD opens with the mouse cursor up |
| 2 | Press the open key again | The MFD closes; the cursor stays up |
| 3 | Open the MFD, press Tab (back to shooting) | The MFD closes |
| 4 | Then open another MFD (inventory, Tab again) | The psi MFD does **not** come back |
| 5 | Open the MFD, edit a macro without saving, press Tab | It closes; reopening shows the saved version ("Loaded") |
| 6 | Open the MFD with the cursor already up | It opens and stays open |

## Table

| # | Do | Expect |
|---|---|---|
| 7 | Look at tier 1 | Icons, tier, name, short name, duration now / max, effect now / max, overload, Cyber Mods |
| 8 | T1 to T5 | Each jumps to that tier |
| 9 | Up and Dn | One row each; stops at the top and bottom |
| 10 | With the wheel lines set up: mouse wheel over the open MFD | Scrolls the table; up scrolls up |
| 11 | Mouse wheel off the MFD (cursor up), and in normal play | Switches weapons, both directions |
| 11a | Quit and restart; check user.bnd | Both `mouse_wheel` lines are still there (lower-cased) |
| 12 | Cyber Mods column | "bought" for owned disciplines; costs include every tier still to unlock |
| 13 | +Overload | Only on disciplines that benefit from overloading |

## Macros

| # | Do | Expect |
|---|---|---|
| 14 | Pick a macro key at the top; check the bottom selector | Both show the same key |
| 15 | Add two casts, a hypo, a Finish weapon; Save | Status "Saved for <key>"; a file appears in `Saved Games\...\psi_macros\` |
| 16 | Close the MFD, press that key | The macro runs to `chain: done` in the console |
| 17 | Edit key A, switch to key B and back, without saving | Key A's edits are still there ("Not saved yet") |
| 18 | Click a step; click a wait | The step is removed; the wait cycles 500 / 750 / 1000 / 1500 / 2000 |
| 19 | Clear, then Save | "Add at least one step first." |
| 20 | Press keypad + while a macro runs | The macro stops (psi_autocast's cancel) |

## Failure handling

| # | Do | Expect |
|---|---|---|
| 21 | Disable psi_autocast, keep the MFD | Console: "psi_autocast isn't loaded"; the MFD still opens |
| 22 | After any test above, run `condump` | No `[psi_mfd] error` and no `AN ERROR HAS OCCURED` lines from psi_mfd files |

## Keyboard (hotkey picker, 1.2)

Spec: `docs/superpowers/specs/2026-10-16-hotkey-picker-design.md`. Setup, with the game closed:

1. Back up `user.bnd` and the `psi_macros` folder.
2. Copy `dev/tests/fixtures/keyboard_user.bnd` over `user.bnd`, and `dev/tests/fixtures/keyboard_macros/*` into `psi_macros`. The fixture is the game's default bindings plus one key per state and mark (see the comments at its end).
3. Start the game; open Options > Controls and leave it, so the game rewrites `user.bnd`; check the fixture's lines are still there (lower-cased).
4. After testing, quit and copy the backups back.

| # | Do | Expect |
|---|---|---|
| K1 | Click Keys; click Table; click a key-name box (not its arrows) | Keyboard / table / keyboard |
| K2 | Look at the keys | G, F1, F2, keypad / bright (G, F1, F2 double outline); Y teal double outline; unbound keys such as ; and , teal; T, X, K, H grey; keypad * and + blue-grey; Enter, Shift, ` - = dim; Num dim |
| K3 | Hover T, Y, K, keypad +, Space, and empty space | `T: wpn_setting_toggle (also on o); has a macro: clear T in Controls, run setupPsiMfd.bat`; `Y: free, has a macro: ...`; `K: run psi\t2_localized_pyrokinesis.cmd`; `Keypad +: reserved for psi_autocast cancel`; `Space: +jump; never used for macros`; the legend |
| K4 | Marks | T `=` and red `!`; X `=` and `?`; keys with movement duplicates `=` |
| K5 | Pick G, Y and T in turn | Each loads in the editor; Y and T appear in the selector |
| K6 | Save a macro on Y, then on T | Label line: `Y isn't bound yet: quit and run setupPsiMfd.bat.` / `T is a game key: clear it in Options > Controls, quit, run setupPsiMfd.bat.` |
| K7 | Click Enter, Num, keypad * | Nothing happens |
| K8 | With the keyboard open: `<` `>`; T1; wheel over the MFD | Highlight frame moves / table at tier 1 / nothing scrolls |
| K9 | Tab with the keyboard open, then reopen the MFD | Closed; reopens on the table |
| K11 | Open Keys | No noticeable delay (subjective) |
| K12 | `condump` | No `[psi_mfd] error` |
| K13 | With `keyboard_nomacro_user.bnd`: open the MFD, then pick a free key from Keys | Label line `No macro keys bound: click Keys to pick one`; selector `no keys`, then the picked key |
| K14 | Disable psi_autocast for the save; open Keys | Keyboard works; K is still a grey game key |
| K15 | Edit F1's macro without saving; switch to F2 | F2 shows the same unsaved edits |
| K16 | After K6, pick another key | Label line back to `Macro: click a step...` |
| K17 | On the smallest window available, save on keypad 5 as a game key | The K6 text fits or is cut cleanly |

## Results

Record the date, build and outcome in DEVELOPMENT.md under "MFD test results".
