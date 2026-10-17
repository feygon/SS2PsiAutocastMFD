# Developer notes: psi_autocast_mfd

**TLDR:** An in-game MFD for building psi_autocast macros is feasible. The capability probe (2026-10-16, `dev/sq_scripts/psi_mfd_probe.nut`) showed that a script can draw a clickable panel with a text box, write files into the save folder and its subfolders (through `user:/\sq_cache\`), and that a key file can run those files. A script can't bind keys during play, so keys are bound once to fixed key files (MacroG, MacroJ, …) whose contents the MFD rewrites.

## Probe results (2026-10-16, Epic, game 1.3.4984, psi_autocast 1.2 loaded)

| Test | Result |
|---|---|
| `modinfo.json` `"requirements": ["psi_autocast"]` | Accepted without complaint; both mods load. Whether it's enforced is untested |
| Script writes with `file(path, "w")` | Only `user:/\sq_cache\<name>` (Nightdive's own form in `libs/helpers.nut`) works, and it lands in the save folder root (`%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\`), not in an `sq_cache` folder. So `sq_cache` appears to be the one writable location, mapped onto that root. Fail with "cannot open file": `user:/<name>`, `psi\…`, `psi/…`, `./psi/…`, a bare name, and (round 2) every form writing into an existing subfolder: `user:/\psi_macros\…`, `user:/psi_macros\…`, `user:/psi_macros/…`, `user:/\psi_macros/…`, `user:psi_macros\…`. Round 3: **subfolders work through `sq_cache`**: `user:/\sq_cache\psi_macros\<name>` and `user:/\sq_cache\psi_macros/<name>` land in `psi_macros`, and `user:/\sq_cache\psi_newdir\<name>` creates the missing folder. `user:/sq_cache/…` (no backslash after `user:/`) and plain `user:/\<name>` fail |
| Running a file in a save-folder subfolder | Works with `run user:/psi_macros\<name>`, `run user:/psi_macros/<name>` and `run user:psi_macros\<name>`; not with `run user:/\psi_macros\<name>` |
| Running a save-folder file | `run user:/<name>`, `run user:/\<name>` and `run user:<name>` work. `exec` and absolute paths don't |
| Game commands through a `run` file (2026-10-17) | One-shot commands work: `,` bound to `run user:/psi_macros\macro_comma.cmd` containing `wpn_setting_toggle` toggled the weapon setting normally. Hold commands don't: O bound the same way to a file containing `+walkfast` did nothing (no walking, not stuck). So keys with one-shot commands can be routed through per-key files; `+` (hold) keys must keep their direct binding |
| Does loading a save reread `user.bnd`? (2026-10-17) | No. With the game running, F12 was pointed at a file that echoes a message; after a quicksave and quickload F12 did nothing new and the message never appeared in the console. Bindings are read once, at startup; a binding written mid-game only takes effect after a restart |
| Unbinding a key in the game's Controls menu (2026-10-16) | Works and saves at once: clearing O from "Change Weapon Setting" and leaving the menu rewrote `user.bnd` (16:06:56) without `bind o`; every other line stayed (macro keys, wheel, MFD, cancel, the 14 `game2` lines). Leaving that menu is a time the game writes `user.bnd`; quitting the game at 14:17 didn't write it |
| Unbinding a key from the console (2026-10-16) | Not possible: `unbindkey t` is accepted silently, and T still ran its Dark binding (`wpn_setting_toggle`) afterwards. So the MFD can't free a game-bound key; only an edit to `user.bnd` with the game closed can |
| Binding a key from a script or console | Not possible for gameplay keys. The console's `bind` is the KEX engine's: it rejects Dark key names (`"keypad_plus" isn't a valid key`), accepts KEX names (`kp_plus`, `kp_divide`, `kp_mul`), but a KEX binding doesn't fire; the Dark binding in `user.bnd` keeps running. `bind` lines inside a `run` file fail the same way, silently |
| Panel drawn on the remaster's UI library | Works: `ND.UiBase` panel with `ND.UiButton` and `ND.UiEditableField`, registered with `ND.g_PlayerCore.InternalMessage("RegisterRootUi", panel)` and shown with `SetActive` |
| `Debug.Command("toggle_mouse")` | Brings up the mouse cursor |
| Clicks | Each button click registered |
| Text box | Click starts editing; Enter returns the typed text (`'bla bla'`) |
| Keyboard | The panel receives every key while hovered, including console typing; keys aren't swallowed unless a text box is being edited |
| A save-folder macro using the mod's parts | Works. `run user:/psi_test_parts.cmd` (a copy of `T1_Projected_Cryokinesis_Quickfire.cmd`) ran the nested `run psi\lib\…` parts from the game folder and cast. `run user:/psi_test_chain.cmd` (`arm,6q,w500,last`, `summon_obj PsiChain`) drew the amp from the pistol, cast, and switched back to the pistol |

## MFD test results (2026-10-16, v0.2 dev builds)

- **Layout (final for v0.2):** key selector at the top and bottom, `+Overload` (only for disciplines that benefit) and `+Quick` per row, boxed buttons, panel sized to the window.

- **End to end:** built a macro for Keypad - in the MFD and saved it; it wrote `psi_macros\macrokpminus.cmd` (`arm,4o,w500,5o,w500,6q,w500,6q,w500,6q,w500,weapon:Wrench`), and Keypad - ran all 12 steps.
- **Reading `user.bnd`** through `user:/\sq_cache\user.bnd` works; the MFD found Keypad - and Keypad Del.
- **Fixed on the way:** reading with `file(path, "r")` + `readn` tripped a KEX assert (`!file->m_bTextMode`, wrap_fileio.cpp): read with `"rb"`. A class member named `file` hid the global `file()` inside methods (global calls run with the caller's `this`): call `::file`. Bitmaps tiled at a size other than their own (`HRMSUCC`, `HRMRES0`) drew other frames ("SUCCESS!"): rows now draw lines, not bitmaps. A local named `base` (a Squirrel keyword) failed the whole file at load ("expected 'IDENTIFIER'", logged only in `kexengine.log`, line and column given).
- **An exception inside the remaster's UI loop breaks every script UI:** it aborts `PlayerCore.OnFrameUpdate` before the click queue is cleared, so the click replays and errors every frame; keybound summons stop working too. Every MFD entry point (button and row clicks, panel drawing, the frame handler) now catches its own errors, prints `[psi_mfd] error in ...` once, and closes the MFD.

## Keyboard view (hotkey picker) prototype, 2026-10-16

- **Built and looked at in game** (spec `docs/superpowers/specs/2026-10-16-hotkey-picker-design.md`, plan `docs/superpowers/plans/2026-10-16-hotkey-picker.md`). The layout fits the table area; labels fit at the author's canvas once clipped without "..." (Home showed as "Ho...").
- **No fill call:** the overlay draws lines only (`ND.DrawBox` is four `ShockOverlay.DrawLine`s; background bitmaps tile and draw other frames at other sizes), so "has a macro" is a double outline.
- **Colours:** the MFD background (TRAIT) measures about RGB 0.02 / 0.29 / 0.24. Greys darker than that were unreadable; key colours are now all lighter (a test enforces luminance >= 0.45).
- **Consts are resolved when a file compiles.** A const from a file that compiles later is looked up at runtime and fails; `psi_mfd_keyboard.nut` has its own `PSI_MFD_KEY_INFO` (a test checks every file).
- **Prefix bug found in game:** macro keys showed as game keys because `PSI_MFD_RUN_PREFIX` has no `run `. The Python twin now builds its prefix from the `.nut` const.
- **Key names proven** by the game keeping them when it rewrote `user.bnd` (19:06), with macros on `;` and `/` running to `chain: done`: `, . / ; ]`, plus keypad numbers and arrows (the game's own defaults). `'`, `[` and `\` were already proven: the author's game-written `user.bnd` binds them (chat, detox patch, worm launcher). `;` is a comment character at line start in `.bnd` files but works as a key name after `bind`.
- **User decisions (2026-10-16):** keypad numbers, arrows and `, . / ; ' [ ] \` can hold macros, and setupPsiMfd.bat binds them when free like any key (punctuation by word: `Macro_comma.cmd`); keys running psi_autocast scripts are ordinary game keys, not reserved.
- **Batch:** `for /f` skips lines starting with `;` unless `eol=` is set; findstr reads `\` in a `/c:` string as an escape, so the backslash key is searched as `\\`.
- **Not yet tried in game:** saving on a game key and the red `!` (TEST_PLAN K6, K4), the narrow-window fit (K17).

## Mouse wheel (2026-10-16)

- **Scripts never see the wheel.** With an overlay handler logging every `HandleKey` while the mouse was over the MFD, wheel turns produced no key events and kept switching weapons (the wheel is a `user.bnd` binding, `bind mouse_wheel_up "cycle_weapon 1"`, not a key event).
- **`game2 bind` lines apply in cursor mode.** `game2 bind mouse_wheel_up "summon_obj PsiMfdWheelUp"` (and `_down`) made the wheel scroll the MFD while the cursor was up; normal play keeps the plain binding. `PsiMfdWheel` switches weapons itself (`cycle_weapon ±1`) when the mouse isn't over the MFD, so cursor-mode wheel behaviour is otherwise unchanged. Tested 2026-10-16: off the MFD the wheel still switched weapons.
- **But the game drops them (2026-10-16):** when it next rewrote user.bnd (14:14), it kept its own 14 `game2` lines and every plain binding we added, and dropped both `game2` wheel lines. Until then they had never been rewritten (still in their original mixed case), which is why the first test worked. So `game2` wheel bindings don't persist; the docs no longer suggest them.
- **Fix: plain bindings (2026-10-16, tested in game).** `bind mouse_wheel_up "summon_obj PsiMfdWheelUp"` / `_down` survive the game's rewrite (it rewrote user.bnd at the 15:21 startup and kept both, lower-cased). Over the open MFD the wheel scrolled the table the expected way; off the MFD and in normal play it switched weapons both ways; condump clean. setupPsiMfd.bat asks y/n while both wheel lines are missing or default. Cost: in a save without this mod the summon has no archetype, so the wheel doesn't switch weapons.
- **When the game rewrites user.bnd:** at some startups, not all (2026-10-16: 18 s after the 14:14:28 start; earlier startups that day left it alone). It keeps every plain binding and only its own `game2` lines.

## Overlay numbers for `open_mfd`

`open_mfd <n>` opens an overlay by number (`bind m "open_mfd 26"` is the map). The numbers, printed from the script constants in game (2026-10-16): BuyPsi 38, BuyStats 35, BuyTech 36, BuyWeapon 37, BuyTraits 20, Psi 11, Map 26, Security 33, Elevator 46. The order of the `kOverlay…` names in the exe is not the numbering.

## Engine facts learned

- **Overlay API:** NewDark's `IShockOverlayHandler` (Squirrel). Nightdive's `libs/player.nut` registers one handler and forwards `DrawHUD`, mouse and key events to `ND.g_PlayerCore`; `libs/ui_handler.nut` draws registered root panels each frame and routes hover, clicks and text input. Our panel plugs into that instead of registering its own handler.
- **Build UI inside the draw step:** constructing widgets from a timer logged "ShockOverlay::GetStringSize called outside of IShockOverlayHandler::DrawHUD". Create panels from an `OnFrameUpdate` handler (called from `DrawHUD`).
- **Key names:** `user.bnd` uses Dark names (`keypad_plus`, `keypad_home` for keypad 7, `keypad_up` for 8, `keypad_pgup` for 9). The console uses KEX names (`kp_plus`, `kp_7`).
- **Free keys on the author's machine** (2026-10-16): only `keypad_star`, `keypad_slash`, `keypad_minus`, `keypad_center`, `keypad_del`, `keypad_ins`. Every letter and F-key is bound. So setupPsiMfd.bat also offers (y/n) bound keys it can take without losing anything: not in the game's defaults, and the command is on another keyboard or mouse binding.
- **Default bindings:** `base.kpf` → `defaults/shock.bnd` (the game's own defaults; `defaults/default.bnd` has only the console key). setupPsiMfd.bat copies its plain keyboard and mouse keys into `DEFAULT_KEYS`; a test checks the copy against the game file.
- **Never `open(path, "wb").write(build())`** for user.bnd: `open` truncates before `build()` runs, so an exception leaves an empty file. Build the bytes first (it happened once, 2026-10-16; restored from the backup).

## Psi power data (for the MFD's cells)

`summon_obj PsiProbeData` (dev probe) reads every discipline from the running gamesys; the raw output from 2026-10-16 (SCP beta 6, PSI 4) is in `dev/data/psi_power_data.txt`.

- **Where it lives:** each discipline is an archetype with a short internal name (`Cryokinesis`, `Quickness` for Psychogenic Agility, `Low Grav` for Psycho-Reflective Screen, …). Its `PsiPower` property has `Power` (the discipline number), `Type`, `Start Cost` and `Data 1`–`Data 4`. Timed disciplines also have `PsiShield`: `Base Time` + `Add Time` seconds per PSI.
- **Read it at runtime, not from the help text:** `psihelp.str` text can be out of date. Cyber-Affinity's help says "2 minutes + 1 minute per PSI"; the data is 60 s + 30 s per PSI.
- **Projectile damage:** Cryokinesis and Projected Pyrokinesis fire one projectile archetype per PSI level (`Projectile` links to `Cryo PSI 1` … `Cryo PSI 8`), each with an `arSrcDesc` link whose `Intensity` is the damage: Cryo 3 + PSI (cold), Pyro 5 + 2 × PSI (incendiary). There's no PSI 9 or 10 projectile, so damage stops at PSI 8.
- **Projectiles whose intensity is a duration:** Hypnogenesis (`StunStim` 20), Electron Suppression (`ElectroDampen` 3) and Imposed Neural Restructuring (`CharmStim` 10) have `Data 1` = 1, and the help text gives "20 / 3 / 10 seconds per PSI".
- **`psihelp.str`** also has `PsiIcon<n>` (the icon file for discipline n, e.g. `PsiIcon3:"picn04"`), `PsiShort<n>` (a short name) and `Psi<n>` (name, effect, and a stated formula). Read with `Data.GetString("psihelp", key)`.
- **Overload:** `P$PsiOverDe` / `P$PsiOver2D` are empty in both `shock2.gam` and `shockscp.gam`, so the overload effect is engine code. The MFD shows the overload bonus as the value at PSI + 2, capped at 8 (the cap is verified only for projectile damage).
- **Cyber module costs:** `PSICOST` (gamesys parameter table, not readable from scripts, so copied into `psi_mfd_data.nut`): by discipline number, tier headers 10 / 20 / 30 / 50 / 75 to unlock, disciplines 3 / 5 / 8 / 12 / 20; the table stops at 33 and its last value covers the rest of tier 5. `DIFFPARAM`'s first six values are the cost multiplier by difficulty (0.85 Easy, 1 Normal, 1.4 Hard, 1.8 Impossible). The game rounds down in single precision, so Hard 5 × 1.4 = 6 and Impossible 20 × 1.8 = 35; the MFD's integer maths matches all 20 discipline costs in the wiki's table (https://shodan.fandom.com/wiki/Psionic_Disciplines). Tier unlock costs on Easy, Hard and Impossible follow the same rule but aren't checked against anything.
- **Bought or not:** read from `PsiPowerDesc` / `PsiPower2Desc` as bit sets, tier headers included, the way psi_autocast does. Verified 2026-10-16: "bought" matched the disciplines the player owns.
- **Still unknown:** the meaning of some data values (Neuro-Reflex Dampening 0.5 / 0.1, Adrenaline 0.13 / 1, Soma Transference 10 / 5 / 5, Neural Decontamination 5); Localized Pyrokinesis and External Psionic Detonation damage (no stim on the power or projectile).

## Design that follows

- **Fixed key files**, shipped in the game's `psi` folder and bound once in `user.bnd` (by a starter script or by hand): `psi\macros\MacroG.cmd` contains `run user:/psi_macros\psi_macro_g.cmd`.
- **The MFD writes** `psi_macros\psi_macro_<key>.cmd` in the save folder, with `file("user:/\\sq_cache\\psi_macros\\psi_macro_<key>.cmd", "w")` (the folder is created on the first write), read back by `run user:/psi_macros\psi_macro_<key>.cmd`: the same chain lines the Macro Builder produces (`set psi_chain …`, `summon_obj PsiChain`).
- **Keys pressed before a macro exists** run a missing file; check what `run` does with a missing file (likely a console error, nothing else).
