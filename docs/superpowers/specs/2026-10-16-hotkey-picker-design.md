# Hotkey picker: design

**TLDR:** A **Keys** button in the psi MFD swaps the discipline table for a keyboard. Each key shows its state (macro key, free, game-bound, mod key, never usable) and marks (`=` redundant, red `!` conflict, `?` broken macro file). Clicking a usable key selects it for the macro editor. Macros saved to free or game-bound keys go to `Macro_<key>.cmd`, and the status line says what to do outside the game to make the key run it. The MFD never edits `user.bnd`.

Date: 2026-10-16. Mod: psi_autocast_mfd (this repo), after release 1.1.

## Purpose

The picker has three jobs, equally weighted (user, 2026-10-16):

- **Faster picking.** With 12 or more macro keys, cycling with `<` `>` is slow; the keyboard jumps straight to a key and shows which keys have macros.
- **Planning free keys.** See what's free and what's game-bound, and put macros on keys that aren't bound yet.
- **Seeing the layout.** One view of what every key does now.

**Success:** a player can open the keyboard, see every key's state at a glance, pick any usable key, save a macro to it, and be told exactly what (if anything) to do outside the game for that key to run it.

## Facts this design rests on (verified in game, 2026-10-16)

- A script can't bind or unbind a game key: the console's `bind` is the KEX engine's, and `unbindkey t` is accepted but T keeps its Dark binding (DEVELOPMENT.md, probe table).
- Clearing a key in the game's Controls menu works, and leaving the menu rewrites `user.bnd` at once without that key's line, keeping every other line (cleared O from "Change Weapon Setting": `bind o` gone, macro keys, wheel, MFD and cancel lines kept).
- setupPsiMfd.bat binds every free candidate key to `run user:/psi_macros\Macro_<key>.cmd` without asking (tested offline, 37 tests).
- The MFD reads `user.bnd` each time it opens (`PsiMfdPanel.Refresh` calls `PsiMfdMacroKeys`).
- Key names: every key the picker lets you choose appears in the author's `user.bnd` as rewritten by the game (`a`–`z`, `0`–`9`, `f1`–`f12`, `ins` `del` `home` `end` `pgup` `pgdn`, `up` `down` `left` `right`, `keypad_*`), which proves the game accepts them. Names of never-usable keys (Enter, Tab, Caps Lock, …) are only labels and are never written anywhere.

## Constraints (user decisions)

- Never a macro key: Enter, Esc, Tab, Space, Backspace, modifier keys (Shift, Ctrl, Alt), punctuation, the mouse wheel, and keypad + (reserved for psi_autocast's cancel, whatever it is bound to).
- The MFD doesn't edit `user.bnd`. To free a game key, the player clears it in the game's Controls menu.
- setupPsiMfd.bat keeps its current rules (it does not offer default keys even when a macro file exists for them).

## What the player sees

### Opening and closing

- A **Keys** button sits next to each key selector (top bar and bottom controls). It swaps the discipline table area (header, rows, Up/Dn) for the keyboard. The macro editor and the controls below stay.
- Clicking a selectable key, or **Keys** again, swaps back to the table.
- Tab, the open key, or leaving cursor mode closes the whole MFD as now. Reopening always shows the table.

### Layout

A US keyboard drawn in the table area, 23 units wide:

| Block | Units | Rows |
|---|---|---|
| Main | 15 | F-row (Esc, F1–F12), digits row (`` ` `` 1–0 - = Backspace), Q row (Tab Q–P [ ] \), A row (Caps A–L ; ' Enter), Z row (Shift Z–M , . / Shift), bottom row (Ctrl Alt Space Alt Ctrl) |
| Gap | 0.5 | |
| Navigation | 3 | Ins Home PgUp / Del End PgDn on rows 2–3; Up on row 5; Left Down Right on row 6 |
| Gap | 0.5 | |
| Keypad | 4 | rows 2–6: Num / * - ; 7 8 9 + ; 4 5 6 ; 1 2 3 Enter ; 0 . |

- One unit = (panel width − 36) / 23 px, floored; key height = table area height / 6, floored, but at least 14 px. At the 720 px maximum a unit is 29 px; at the author's 1080-line canvas the table area holds 8 rows (216 px), so keys are 36 px tall. If 6 rows of 14 px don't fit the table area (only on very small canvases, not tested), the keyboard is drawn over the macro editor's first line rather than clipped.
- Labels are short (`PgUp`, `KP 7` shown as `7` inside the keypad block, `-`, `F11`) and pass through `PsiMfdFit` so they never overflow a key.
- The key selected in the editor has a highlight frame.

### Key states

| State | Rule | Look | Click |
|---|---|---|---|
| Macro key, has a macro | bound to a `psi_macros` file whose macro has steps | bright, filled | selects |
| Macro key, empty | bound to a `psi_macros` file with no macro (missing file) | bright outline | selects |
| Free | no plain binding, and a candidate key | dim outline | selects |
| Game-bound | bound to anything else, and a candidate key | greyed | selects |
| Mod key | runs `summon_obj PsiMfd…` (open key, wheel), `cancel_macro`, or a psi_autocast script (`run psi\…`, not a `psi_macros` file) | greyed, second tint | none |
| Never usable | in the never list (Constraints) | faint | none |

"Candidate key" = exactly setupPsiMfd.bat's `MACRO_CANDIDATES` list (letters, digits, F1–F12, keypad - Del Ins 5 /, Ins Del Home End PgUp PgDn), because a macro on any other key could never be bound by the script. Every other key (arrows, keypad 1–4 and 6–9, Num Lock, …) is not selectable: shown faint, or greyed if bound, with its binding on hover plus "not offered for macros".

### Marks

| Mark | Rule |
|---|---|
| `=` (corner) | the key is game-bound or a mod key, and its command is also on another keyboard or mouse binding (any other plain or combo `bind` line; gamepad `joy*` lines don't count) — the setup script's rule |
| red `!` | conflict: a macro with steps exists in `Macro_<key>.cmd`, but the key is bound to something other than that file (game-bound or mod key) |
| `?` | the key's macro file exists but loads no steps (no `set psi_chain` line, or the chain parses to nothing) |

A free key with a macro is a normal waiting state: filled, no `!`.

### Hover

The status line shows the key and what it does, for example:

- `O: free` / `O: free, has a macro: run setupPsiMfd.bat to bind it`
- `T: wpn_setting_toggle (also on mouse5)`
- `T: wpn_setting_toggle; has a saved macro: clear T in Options > Controls, then run setupPsiMfd.bat`
- `Keypad +: psi_autocast cancel`
- `Enter: never used for macros`
- `X: macro file has no steps`

### Picking and saving

- Picking a key makes it the editor's key, swaps back to the table, and loads its macro (status `Loaded`, `New macro`, or `Not saved yet` if edited earlier this session). Unsaved edits on the previous key stay in memory, as with `<` `>` now.
- `<` `>` still cycle only through bound macro keys (the keypad + and wheel rules don't change). A picked free or game-bound key is added to the selector's list until the MFD closes.
- Saving writes the file named in the key's binding if it is a macro key, else `psi_macros\Macro_<key>.cmd`. Status after saving:
  - macro key: `Saved for <key>` (as now)
  - free key: `Saved. <key> isn't bound yet: quit and run setupPsiMfd.bat to bind it to this macro.`
  - game-bound key: `Saved. <key> is a game key: clear it in Options > Controls, then quit and run setupPsiMfd.bat to bind it to this macro.`

## Data

One parse of `user.bnd` per MFD open, replacing `PsiMfdMacroKeys` as the source for both the selector and the keyboard:

```
key -> { command, macroFile (or null), modKind (null | "open" | "wheel" | "cancel" | "discipline"), alsoOn: [other keys] }
```

- Lines: `bind <key> <command>`, case-insensitive. The game writes one line per key; if a hand-edited file has two lines for a key, the picker uses the last one.
- `alsoOn`: other keys (plain or combo, not `joy*`) with the same command, compared case-insensitively.

Macro state is computed when the keyboard opens (not every frame): for each key with a macro file (its binding's file, or `Macro_<key>.cmd` for free and game-bound candidate keys), load it with `PsiMfdMacro.Load` and count steps. About 60 small reads.

## Units

| Unit | File | Does |
|---|---|---|
| Key table | new `psi_mfd_keyboard.nut` | fixed list: Dark name, label, block, row, column, width in units; the never list; the candidate list |
| Binding parse | `psi_mfd_macros.nut` | `PsiMfdBindings()` → the map above; `PsiMfdMacroKeys()` becomes a filter over it |
| Key state | `psi_mfd_keyboard.nut` | `PsiMfdKeyState(name, bindings)` → state, marks, hover text |
| Keyboard view | `psi_mfd_keyboard.nut` | `PsiMfdKeyboard extends ND.UiBase`: draws keys, handles hover and click, calls back into the panel |
| Panel | `psi_mfd_ui.nut` | Keys buttons, swap table/keyboard, picked keys in the selector, save status text |

## Errors

- Every new click, hover and draw entry point catches its own errors through `PsiMfdFail`: prints `[psi_mfd] error in …` once and closes the MFD (an uncaught error in the UI loop breaks every script UI — DEVELOPMENT.md).
- A macro file that can't be read counts as missing; one that reads but has no steps gets `?`.
- Without psi_autocast the keyboard works the same; discipline keys are still detected from their `run psi\…` lines.

## Testing

Offline (`dev/tests/test_release.py`):

- Every selectable key name in the key table appears in the game's `shock.bnd` or in the author's game-rewritten `user.bnd` key set recorded in the test (skips if the game isn't installed).
- The key table's candidate list equals setupPsiMfd.bat's `MACRO_CANDIDATES`, and no never-list key is a candidate.
- Layout: no two keys overlap; all keys fit 23 units × 6 rows; at 470 px wide every key is at least 18 px wide.
- Classification: a Python twin of the binding parse and state rules, checked against the `.nut` lists, over fixture `user.bnd` files covering every state and mark.
- Code safety checks extended to the new file (no keywords as names, `::file`, binary reads, error guards).

In game (`dev/tests/TEST_PLAN.md`, new rows): Keys opens and closes the keyboard; states and marks on the author's `user.bnd` (T `=`, O free, C I X V Ins Home End macro keys, keypad * and + mod keys); pick each kind of key; save to a free key and to a game key (status text, then red `!` on the game key after reopening the keyboard); Tab closes everything; condump clean.

## Out of scope

- Editing `user.bnd` from the MFD.
- Changing setupPsiMfd.bat.
- Non-US keyboard layouts.
- Gamepad bindings.
