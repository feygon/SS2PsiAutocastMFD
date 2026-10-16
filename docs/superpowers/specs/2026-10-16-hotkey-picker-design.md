# Hotkey picker: design

**TLDR:** The psi MFD gets a keyboard view (open it with **Keys** or by clicking a key-name box). It replaces the discipline table and shows every key's state (macro key, free, game key, mod key, not usable) with marks (`=` also on another key, red `!` conflict, `?` broken macro file). Clicking a selectable key picks it for the macro editor. Macros on free or game keys are saved to `Macro_<key>.cmd`, and the MFD says what to do outside the game for the key to run them. The MFD never edits `user.bnd`. Target release: 1.2.

Date: 2026-10-16. Mod: psi_autocast_mfd (this repo), after release 1.1.

## Purpose

Three jobs, equally weighted (user, 2026-10-16):

- **Faster picking:** jump straight to any key instead of cycling with `<` `>`.
- **Planning free keys:** see what's free and what's game-bound; put macros on keys that aren't bound yet.
- **Seeing the layout:** one view of what every key does now.

**Success:** a player can open the keyboard, read every key's state, pick any selectable key, save a macro to it, and be told in one line what (if anything) to do outside the game for that key to run it.

## Facts this design rests on (verified, 2026-10-16)

- A script can't bind or unbind a game key: the console's `bind` is the KEX engine's, and `unbindkey t` is accepted but T keeps its Dark binding (DEVELOPMENT.md).
- Clearing a key in the game's Controls menu works and saves at once: leaving the menu rewrote `user.bnd` without that key's line and kept every other line.
- setupPsiMfd.bat binds every free key in its `MACRO_CANDIDATES` list to `run user:/psi_macros\Macro_<key>.cmd` without asking (offline tests).
- The MFD reads `user.bnd` each time it opens (`PsiMfdPanel.Refresh` → `PsiMfdMacroKeys`).
- Every `MACRO_CANDIDATES` name appears in the author's `user.bnd` as rewritten (lower-cased) by the game, which proves the game accepts it: `a`–`z`, `0`–`9`, `f1`–`f12`, `ins` `del` `home` `end` `pgup` `pgdn`, `keypad_minus` `keypad_del` `keypad_ins` `keypad_center` `keypad_slash`. The other names the keyboard uses (`enter`, `tab`, `space`, `backspace`, `esc`, `caps_lock`, `numlock`, `keypad_enter`, `shift`, `ctrl`, `alt`, the arrows, `keypad_home` … `keypad_pgdn`, `keypad_star`, `keypad_plus`, and the punctuation keys) are in the game's `shock.bnd` or its key-name table in the executable; they are only looked up in `user.bnd`, never written.
- Canvas: the author's 1920×1080 screen gives a UI canvas about 540 units high (the panel shows 8 table rows: panel height 0.64 × 540 = 345, minus 122 fixed, / 27 = 8). The table area is then 12 (header) + 216 (rows) = 228 units.

## Constraints (user decisions)

- C1. Never a macro key: Enter, Esc, Tab, Space, Backspace, Caps Lock, Shift, Ctrl, Alt, punctuation, the mouse wheel, and keypad + (reserved for psi_autocast's cancel).
- C2. The MFD doesn't edit `user.bnd`. To free a game key, the player clears it in the game's Controls menu.
- C3. setupPsiMfd.bat is unchanged.

## Requirements

### Opening and closing

- R1. The top bar gets a **Keys** button (between the top key selector and T1, 34 units wide). Clicking either key-name box (top or bottom selector) also opens the keyboard. While the keyboard shows, the Keys button reads **Table**.
- R2. The keyboard replaces the table area: header, rows, Up and Dn. The macro editor and the controls below stay and keep working (step clicks, Clear, Save, Draw amp, Amp wait, Add hypo, Finish, Auto psi hypo).
- R3. Picking a key, clicking **Table**, or clicking a key-name box again shows the table again. T1–T5 show the table and jump to that tier. `<` `>` change the selected key and move the keyboard's highlight frame without leaving the keyboard. While the keyboard shows, the table's scroll is ignored (the wheel over the MFD does nothing; off the MFD it still switches weapons).
- R4. Tab, the open key, or leaving cursor mode closes the whole MFD, as now. Reopening shows the table.
- R5. If the table area is under 12 + 6 × 14 = 96 units (only on canvases smaller than the author's, not tested), the Keys button and key-name boxes don't open the keyboard; the editor label line (R19) says `Window too small for the keyboard`.

### Layout

- R6. A US keyboard, 23 units wide and 6 rows high, drawn in the table area below a 12-unit info line (R16). One unit = floor((panel width − 36) / 23); one row = floor((table area − 12) / 6). A key's left edge is floor(column × unit) and its width is floor((column + width) × unit) − left edge minus a 2-unit gap, the same for rows, so neighbouring keys never overlap and the mouse boundary is exact. At 720 wide a unit is 29; at 470 it is 18. On the author's canvas a row is 36.
- R7. Positions are a fixed table (`psi_mfd_keyboard.nut`), one entry per key: Dark name, label, column, row, width, height (in units and rows; most keys 1 × 1). The table, in columns:
  - Row 1: Esc at 0; F1–F4 at 2–5; F5–F8 at 6.5–9.5; F9–F12 at 11–14 (all width 1).
  - Row 2: `` ` `` 0, 1–9 at 1–9, 0 at 10, `-` 11, `=` 12, Backspace 13 (width 2).
  - Row 3: Tab 0 (1.5), Q–P at 1.5–10.5, `[` 11.5, `]` 12.5, `\` 13.5 (1.5).
  - Row 4: Caps 0 (1.75), A–L at 1.75–9.75, `;` 10.75, `'` 11.75, Enter 12.75 (2.25).
  - Row 5: Shift 0 (2.25), Z–M at 2.25–8.25, `,` 9.25, `.` 10.25, `/` 11.25, Shift 12.25 (2.75).
  - Row 6: Ctrl 0 (1.5), Alt 1.5 (1.5), Space 3 (8), Alt 11 (1.5), Ctrl 12.5 (2.5).
  - Navigation (columns 15.5–17.5): Ins Home PgUp on row 2, Del End PgDn on row 3, Up at 16.5 row 5, Left Down Right on row 6.
  - Keypad (columns 19–22): Num `/` `*` `-` on row 2; 7 8 9 on row 3 with `+` at 22 spanning rows 3–4; 4 5 6 on row 4; 1 2 3 on row 5 with Enter at 22 spanning rows 5–6; 0 at 19 (width 2) and `.` at 21 on row 6.
- R8. Labels are short (`Esc`, `F11`, `PgUp`, `Bksp`, `7` in the keypad, `-`) and drawn through `PsiMfdFit` so they never overflow a key. Left and right Shift, Ctrl and Alt share one Dark name, so they always show the same state.
- R9. The selected key has a highlight frame (the selector's frame colour, `ND.psiMfdBright`).

### Reading the bindings

- R10. `PsiMfdBindings()` reads `user.bnd` once per MFD open and returns, for every key token in a `bind` line: the command (outer quotes removed, case kept for display, lower-cased for comparing) and a `combo` flag (true when the key token contains `+`). Rules:
  - A line counts only if, after trimming, it starts with `bind ` (case-insensitive) and has a key and a command. `game2 bind` lines, comment lines (`;`) and blank lines are ignored.
  - A key token containing `+` (e.g. `c+alt`) is a combo: it isn't a key on the keyboard, but it counts as "another key" for R14.
  - If a key has two `bind` lines (only possible by hand), the last one is used.
  - `PsiMfdMacroKeys()` keeps returning `[{ key, file }]`, now built from `PsiMfdBindings()` and containing exactly the keys whose R11 state is Macro key (so a never-list key or `keypad_plus` bound by hand to a macro file is not in the `<` `>` list).
  - Other `run` forms that work in game (`run user:/psi_macros/<name>`, `run user:psi_macros\<name>`) are not recognised as macro keys and fall through to Game key, as `PsiMfdMacroKeys` does today. Known limitation.
- R11. Each keyboard key's state is decided by the first rule that matches, in this order:

| Step | Rule | State | Selectable | Save writes |
|---|---|---|---|---|
| 1 | `keypad_plus` | Reserved (cancel) | no | — |
| 2 | in the C1 list | Not usable | no | — |
| 3 | command is `summon_obj psimfd` | Mod key (MFD open) | no | — |
| 4 | command starts with `run user:/psi_macros\` and the rest is a plain file name (no `\`, `/` or `..`) | Macro key (any key, candidate or not) | yes | that file |
| 5 | command starts with `summon_obj psimfdwheel`, contains `cancel_macro`, or starts with `run psi\` | Mod key (wheel / cancel / psi_autocast) | no | — |
| 6 | in `MACRO_CANDIDATES`, no binding | Free | yes | `Macro_<key>.cmd` |
| 7 | in `MACRO_CANDIDATES`, bound | Game key | yes | `Macro_<key>.cmd` |
| 8 | anything else (arrows, keypad 1–4 and 6–9, Num Lock, …) | Not offered | no | — |

  Step 4 before 5 makes a hand-bound non-candidate macro key selectable, as `<` `>` already treat it. `<key>` in file names is the lower-case Dark name (`Macro_keypad_minus.cmd`), as setupPsiMfd.bat writes.

- R12. Macro content. A macro file "has a macro" when `PsiMfdMacro.Load` reads it and the result has at least one step or a finish weapon (the same test Save uses to accept a macro). It is "empty" when it exists and reads but has neither. It is "missing" when it can't be read. Files are read from disk with throw-away `PsiMfdMacro` objects (not the editor's), so unsaved edits don't change the keyboard. Which file is read per key: the bound file for a macro key; `Macro_<key>.cmd` for every other `MACRO_CANDIDATES` key (free, game key, or mod key that is a candidate).
- R13. When the keyboard opens, the panel builds a `fileState` map (key → `has` / `empty` / `missing`) for those keys, then passes `bindings` and `fileState` to the keyboard. Reading happens once per keyboard open (about 60 small files). The delay is a subjective in-game check (K11): if it is noticeable, the reads move to the MFD's open.

### Showing state

- R14. Marks:
  - `=` (top-right corner): the key is a game key or mod key, and the same command is on another keyboard or mouse key (another `bind` line, plain or combo; `joy*` lines don't count). It means "this key's job is also done elsewhere" (e.g. T and O both had `wpn_setting_toggle`). It is not the setup script's offer rule.
  - red `!` (top-left corner): conflict. `Macro_<key>.cmd` has a macro (R12) but the key is a game key or a mod key.
  - `?` (top-left corner, when no `!`): the key's macro file is empty (R12).
- R15. Looks (fill and outline colours, RGB 0–1; red kept low-intensity for the dark palette):

| State | Outline | Fill | Label |
|---|---|---|---|
| Macro key with a macro | bright `[0.6, 1.0, 0.85]` | dim teal `[0.15, 0.35, 0.3]` | bright |
| Macro key, empty or missing | bright | none | bright |
| Free with a macro (`Macro_<key>.cmd` has one) | dim `[0.3, 0.6, 0.5]` | darker teal `[0.1, 0.22, 0.2]` | text `[0.45, 0.85, 0.7]` |
| Free | dim | none | dim |
| Game key | grey `[0.35, 0.4, 0.38]` | none | grey |
| Mod key or Reserved | slate `[0.4, 0.42, 0.55]` | none | slate |
| Not usable or Not offered | faint `[0.22, 0.27, 0.25]` | none | faint |
| Mark `!` | — | — | muted red `[0.8, 0.35, 0.3]` |
| Marks `=` and `?` | — | — | text colour |

- R16. The info line (12 units, top of the keyboard area, full panel width) shows, while the mouse is over a key: the key's display name (`PsiMfdKeyName`), what it does, and any mark, aiming at 90 characters; any text longer than the line (variable parts like long commands) is cut by `PsiMfdFit` at the panel width minus 12. When the mouse isn't over a key it shows the legend: `Bright: macro  Dim: free  Grey: game  Slate: mod  = elsewhere  ! conflict  ? empty` (82 characters). Hover texts:
  - Macro key: `G: macro (macrog.cmd)` / `G: macro key, no macro yet`
  - Free: `O: free` / `O: free, has a macro: quit and run setupPsiMfd.bat`
  - Game key: `T: wpn_setting_toggle`; with `=` add ` (also on mouse5 o)`; with `!` add `; has a macro: clear T in Controls, run setupPsiMfd.bat`. Both together: `T: wpn_setting_toggle (also on o); has a macro: clear T in Controls, run setupPsiMfd.bat`.
  - Mod key: `Keypad *: opens this MFD`, `Keypad +: psi_autocast cancel`, `K: psi_autocast (run psi\t2_localized_pyrokinesis.cmd)`, `Wheel: scrolls the MFD`
  - Not usable / not offered: the binding if any, then `never used for macros` or `not offered for macros` (e.g. `Space: +jump; never used for macros`).
  - Any key with `?`: `X: macro file has no steps`.

### Picking and saving

- R17. Picking a selectable key makes it the editor's key, shows the table (R3), and loads its macro (`Loaded`, `New macro`, or `Not saved yet` if edited earlier this session), as switching keys does now. A picked free or game key is appended to the end of the selector's list until the MFD closes; a key already in the list is not added again. Two keys bound to the same file share one editor macro (keyed by the lower-cased file name, since the game lower-cases `user.bnd`), so their edits can't clash; `Saved for <key>` names the key currently selected.
- R18. With no macro keys bound, the editor label line (R19) says `No macro keys bound: click Keys to pick one` on open (the status line is too short for it), and the selector shows `no keys` until a key is picked.
- R19. After saving, the status line says `Saved for <key>` for every key (as now). For a free or game key, the macro editor's label line (full panel width, normally `Macro: click a step to remove it, a wait to change it`) also shows what to do:
  - free key: `<key> isn't bound yet: quit and run setupPsiMfd.bat.` (at most 62 characters)
  - game key: `<key> is a game key: clear it in Options > Controls, quit, run setupPsiMfd.bat.` (at most 84 characters, with the longest display names `Keypad Del` / `Keypad Ins`)
  Both are under 90 characters; at the layout's measured ~5 units per character ("Macro key:" fills the 50 units from x = 80 to 130) that is at most 450 units against 458 available at 470 wide, and the line still passes through `PsiMfdFit`. The label line returns to its usual text when another key is picked or the MFD closes. `<key>` is the display name (`PsiMfdKeyName`).

### Errors

- R20. Every new entry point catches its own errors through `PsiMfdFail`, printing `[psi_mfd] error in …` once and closing the MFD: `keyboard click`, `keyboard hover`, `keyboard draw`, and `key box click` (the key-name boxes, which have no click handler today). The Keys button is a `PsiMfdButton`, whose click is already guarded (`button '…'`).
- R21. If `user.bnd` can't be read, the keyboard still opens but every key is drawn faint and unselectable, and the info line says `Can't read user.bnd: keys can't be shown` (otherwise every key would look free). Tested offline only: the game likely recreates a missing `user.bnd` at start, so the case can't be set up reliably in game.
- R22. A macro file that can't be read counts as missing; one that reads with no content counts as empty (`?`).
- R23. Without psi_autocast the keyboard works the same; psi_autocast keys are still recognised from their `run psi\` lines.

### Code

- R24. Units (each with one job):

| Unit | File | Does |
|---|---|---|
| Key table, C1 list, candidate list | new `psi_mfd_keyboard.nut` | data only |
| `PsiMfdBindings()` | `psi_mfd_macros.nut` | R10 |
| `PsiMfdMacroFileState(path)` | `psi_mfd_macros.nut` | R12 for one file |
| `PsiMfdKeyState(name, bindings, fileState)` | `psi_mfd_keyboard.nut` | R11 + R12 + R14 → `{ state, selectable, file, content, marks }`; `content` is `has` / `empty` / `missing`, or null for keys with no file to read |
| `PsiMfdKeyHover(name, keyState, bindings)` | `psi_mfd_keyboard.nut` | R16 text, using `keyState.content` (no second read of `fileState`) |
| `PsiMfdKeyboard extends ND.UiBase` | `psi_mfd_keyboard.nut` | draws keys, finds the key under the mouse, routes clicks to the panel |
| Panel changes | `psi_mfd_ui.nut` | Keys button, view swap, picked keys, fileState, save texts |

- R25. Functions aim at about 100 lines; over 300 is blocking. Drawing one key, finding the key under the mouse, choosing a state, choosing marks and building hover text are separate functions.
- R26. The keyboard widget is created in the panel's constructor (which runs inside the draw step), never from a timer ("Build UI inside the draw step", DEVELOPMENT.md).

## Testing

Offline (`dev/tests/test_release.py`):

| Test | Covers |
|---|---|
| Selectable names are in `shock.bnd` (read from `base.kpf`) or the game-rewritten candidate set recorded in the test; every other name is in `shock.bnd` or found as a NUL-terminated string (`\0name\0`) in `SystemShock2Remastered.exe` (skips without the game) | R7, Facts |
| Candidate list = setupPsiMfd.bat's `MACRO_CANDIDATES`; no C1 key is a candidate | R11, C1 |
| No two keys overlap; all fit 23 × 6; at 470 wide every key is ≥ 18 units | R6, R7 |
| A Python twin of R10–R14 over fixture `user.bnd` files and macro files: one fixture per state, per mark, combos, `game2` lines, duplicate lines, quotes, an unsafe file name; the twin's lists are read from the `.nut` file | R10–R14 |
| `test_release_zip_contents` and `test_brackets_balance` include `psi_mfd_keyboard.nut`; `test_ui_entry_points_catch_errors` covers it and checks the four R20 names | R20, R24 |
| Existing safety checks (keywords as names, `::file`, `rb` reads) cover the new file | R24 |
| The legend and R19 texts, filled with the longest display name, are at most 90 characters | R16, R19 |
| No function in the `.nut` files is over 300 lines (a brace-counting line counter) | R25 |
| `PsiMfdKeyboard(` is constructed only inside the panel constructor (grep) | R26 |
| The twin's selector list (R10) leaves out never-list keys and `keypad_plus` bound to macro files; `user.bnd` unreadable gives all keys faint (R21) | R10, R21 |

The Python twin can drift from the Squirrel code, so every state and mark also has an in-game row.

In game (`dev/tests/TEST_PLAN.md`, new section "Keyboard"). Setup, with the game closed:
1. Back up `user.bnd` and the `psi_macros` folder.
2. Copy `dev/tests/fixtures/keyboard_user.bnd` (added with this work) over `user.bnd`, and `dev/tests/fixtures/keyboard_macros/*` into `psi_macros`. The fixture keeps the game's default movement, Tab (`toggle_mouse`), keypad * (open the MFD) and keypad + (cancel), and adds one key per state and mark, two keys sharing one macro file, and an empty macro file.
3. Start the game and check `user.bnd` still has the fixture's lines (the game may lower-case them; it drops only added `game2` lines, and the fixture has none).
4. After testing, quit and copy the backups back.

A second fixture, `keyboard_nomacro_user.bnd`, has no macro keys (K13).

| # | Do | Expect | Covers |
|---|---|---|---|
| K1 | Click Keys; click Table; click a key-name box | Keyboard / table / keyboard | R1–R3 |
| K2 | Look at every key | States and colours as R11, R15 | R11, R15 |
| K3 | Hover a key of each state, and empty space | Info line texts and legend as R16 | R16 |
| K4 | Find `=`, red `!`, `?` | On the fixture's keys for each | R14 |
| K5 | Pick a macro key, a free key, a game key | Each loads in the editor; free/game key appear in the selector | R17 |
| K6 | Save on a free key and a game key | R19 texts in the editor label line; reopen Keys: free key filled, game key red `!` | R19, R14 |
| K7 | Click a not-usable, not-offered and mod key | Nothing happens | R11 |
| K8 | `<` `>` and T1 while the keyboard shows; wheel over the MFD | Frame moves / table at tier 1 / nothing | R3 |
| K9 | Tab with the keyboard open, reopen | MFD closed; reopens on the table | R4 |
| K11 | Open Keys | No noticeable delay (subjective) | R13 |
| K12 | condump | No `[psi_mfd] error` | R20 |
| K13 | With `keyboard_nomacro_user.bnd`: open the MFD, pick a free key from Keys | Label line `No macro keys bound…`; selector `no keys`, then the picked key | R18 |
| K14 | Disable psi_autocast for the save; open Keys | Keyboard works; psi_autocast keys still slate | R23 |
| K15 | Edit the macro on one of the two keys sharing a file; switch to the other key | It shows the same unsaved edits | R17 |
| K16 | After K6's save, pick another key | Label line back to `Macro: click a step…` | R19 |
| K17 | On the smallest canvas available (a small window), save on `Keypad Del` as a game key | The R19 text fits or is cut cleanly, never overflowing | R19, R8 |

Label fit at 470 wide (R8) depends on the game's font, so it's only checked in game on a canvas that gives the minimum width, if one is available; otherwise it stays unverified and is recorded as such in DEVELOPMENT.md.

## Out of scope

- Editing `user.bnd` from the MFD; changing setupPsiMfd.bat.
- Non-US keyboard layouts; gamepad bindings.
- README, Nexus description and changelog updates happen at release (1.2), after the in-game test.
