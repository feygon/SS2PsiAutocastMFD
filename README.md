# psi_autocast_mfd: an in-game psi macro MFD for System Shock 2: 25th Anniversary Remaster

**TLDR:** Press one key and an MFD opens over the game: every discipline with its duration, effect, overload value and cyber module cost, and an editor that builds [psi_autocast](https://github.com/feygon/SS2PsiAutocast) macros and saves them to keys. **A restart is the most you'll ever have to do: no manual edits, if you don't want them.** Requires psi_autocast 1.2 or later.

**Step-by-step setup for both mods, and a troubleshooting table:** [SETUP_GUIDE.md](https://github.com/feygon/SS2PsiAutocast/blob/main/SETUP_GUIDE.md).

## What it shows

A scrolling table of all 35 disciplines, each with its icon, tier and name, and:

- **Duration** at your current PSI and at PSI 8.
- **Effect** at your current PSI and at PSI 8: damage, healing, stat bonus, chance or recharge.
- **Overload:** what an overload gives you, for the disciplines that benefit from one.
- **Cyber Mods:** "bought", or the cost, including every tier unlock still needed to reach it. Costs follow your difficulty.

The numbers are read from the running game, so they follow SCP if you use it.

## Building a macro

1. Pick a key, or click **Keys** to choose one from a keyboard that shows what every key does.
2. Click disciplines to add casts; add psi hypos, waits and a finishing weapon switch.
3. **Save**, close the MFD, and press the key.

Saving on a key that isn't a macro key yet binds it for you; the MFD tells you when that needs a restart. Keys the game uses stay with the game's Controls menu.

## Install

1. Install and enable psi_autocast 1.2 or later.
2. Extract this zip into the **game folder**, the one with `SystemShock2Remastered.exe`. It adds `mods\psi_autocast_mfd.kpf`.
3. Choose **New Game → Mods**, add **psi_autocast_mfd** (keep psi_autocast), **Apply** and start. Once the first level loads, load your own save, then make a regular save.
4. On that first load the MFD binds keypad * to open it. Restart the game once when it tells you to, then press keypad *.

**In a new game, wait until you're through training before using the MFD:** macros don't take before then.

## Setting keys up yourself (optional)

- **`setupPsiMfd.bat`**, from the [GitHub release](https://github.com/feygon/SS2PsiAutocastMFD/releases/latest), sets up many keys at once with the game closed. It also gives G and J psi_autocast's two starter casts as macros you can edit, and asks (y/n) about letting the mouse wheel scroll the MFD.
- **By hand:** with the game closed, add lines to `user.bnd` (in `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\`):

```
bind keypad_star "summon_obj PsiMfd"
bind keypad_minus "run user:/psi_macros\Macro_keypad_minus.cmd"
```

Optional: the mouse wheel scrolls the table when the cursor is over the open MFD, and switches weapons everywhere else. Replace the two `mouse_wheel` lines with:

```
bind mouse_wheel_up "summon_obj PsiMfdWheelUp"
bind mouse_wheel_down "summon_obj PsiMfdWheelDown"
```

In a save without psi_autocast_mfd enabled, the wheel then doesn't switch weapons. To undo, put back `bind mouse_wheel_up "cycle_weapon 1"` and `bind mouse_wheel_down "cycle_weapon -1"`.

## What it writes

Macros go in `Saved Games\Nightdive Studios\System Shock 2 Remastered\psi_macros\`, one small text file per key. Key bindings go in `user.bnd`, backed up first as `user.bnd.mfd_backup`. It doesn't touch the game folder.

## Uninstall

1. With the game closed, remove the `user.bnd` lines that run `summon_obj PsiMfd` or `psi_macros` files, or rebind those keys in Options > Controls.
2. Delete `mods\psi_autocast_mfd.kpf`, and the `psi_macros` folder in your save folder if you no longer want the macros.

## Changes and license

What changed in each version: [releases](https://github.com/feygon/SS2PsiAutocastMFD/releases). MIT licensed; see `LICENSE`. Source and developer notes: https://github.com/feygon/SS2PsiAutocastMFD
