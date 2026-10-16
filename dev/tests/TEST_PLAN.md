# psi_autocast_mfd in-game test plan

**TLDR:** The offline tests (`py -m pytest dev/tests -v`) check files, data and the setup script. This plan covers what only the game can show. Run it with the release build installed (`py build.py --install`, no `--dev`), psi_autocast and psi_autocast_mfd enabled, and the mouse cursor key (Tab) working. Run `condump` at the end and check for `[psi_mfd] error` lines.

## Setup

- Bindings in `user.bnd`: an open key (keypad *), at least two macro keys, keypad + as cancel, and the two optional `game2` wheel lines.
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
| 10 | Mouse wheel over the MFD | Scrolls the table; doesn't switch weapons |
| 11 | Mouse wheel away from the MFD, cursor up | Switches weapons |
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

## Results

Record the date, build and outcome in DEVELOPMENT.md under "MFD test results".
