# psi_autocast_mfd: an in-game psi macro MFD for System Shock 2: 25th Anniversary Remaster

**TLDR:** Press one key and an MFD opens over the game: every discipline with its duration, effect, overload value and cyber module cost, a keyboard that shows what every key does, and an editor that builds [psi_autocast](https://github.com/feygon/SS2PsiAutocast) macros and saves them to keys. **A restart is the most you'll ever have to do: no manual edits, if you don't want them.** Requires psi_autocast 1.2 or later.

**Step-by-step setup for both mods, and a troubleshooting table:** [SETUP_GUIDE.md](https://github.com/feygon/SS2PsiAutocast/blob/main/SETUP_GUIDE.md).

## What it shows

A scrolling table of all 35 disciplines, each with its icon, tier and name, and:

- **Duration** at your current PSI and at PSI 8.
- **Effect** at your current PSI and at PSI 8: damage, healing, stat bonus, chance or recharge.
- **Overload:** what an overload gives you, for the disciplines that benefit from one.
- **Cyber Mods:** "bought", or the cost, including every tier unlock still needed to reach it. Costs follow your difficulty.

The numbers are read from the running game, so they follow SCP if you use it. T1–T5 jump to a tier.

## Building a macro

1. Pick a key: with the `<` `>` arrows, or click **Keys** (or the key name) to choose from a keyboard.
2. Click a discipline, or its **+Overload** / **+Quick** button, to add a cast.
3. Add psi hypos, click a wait to change it, and choose a **Finish** weapon switch.
4. **Save**, close the MFD, and press the key.

## The keyboard

**Keys** swaps the table for a keyboard. Hover a key to see what it does; click one to pick it.

| Look | Meaning |
|---|---|
| Bright teal | A macro key. Double outline: it has a saved macro (or runs a psi_autocast script) |
| Teal | Free: no binding yet |
| Grey | Set by the game in Options > Controls |
| Blue-grey | Used by these mods: the MFD's open key, keypad + (psi_autocast's cancel) |
| Dim | Never used for macros: Enter, Esc, Tab, Space, Backspace, Shift, Ctrl, Alt, `` ` `` `-` `=` |

Marks: `=` the key's job is also on another key; red `!` it has a saved macro but is still set to something else; `?` its macro file has no steps.

Letters, digits, F-keys, the navigation keys, keypad numbers, arrows and `, . / ; ' [ ] \` can all hold macros.

## Keys: a restart is the most you'll ever have to do

- **First load:** if no key opens the MFD, it binds keypad * (or the next free key), and keypad + to psi_autocast's cancel if that's free, then tells you to restart the game once.
- **Saving on a free key** binds it for you: `Saved. Restart the game for O to run this macro.`
- **Saving on a key the game uses:** clear it in Options > Controls first, then Save again and restart. The MFD never takes a key away from the game's own controls.
- **Saving on a macro key** works on the next keypress.

The game reads key bindings only when it starts, which is why a new key needs one restart. Before the MFD changes `user.bnd`, it backs it up as `user.bnd.mfd_backup`.

**If you'd rather set keys up yourself, you still can:**

- `setupPsiMfd.bat` from the [GitHub release](https://github.com/feygon/SS2PsiAutocastMFD/releases/latest) binds every free key at once, with the game closed. It also gives G and J psi_autocast's two starter casts, as macros you can edit, and asks (y/n) whether the mouse wheel should scroll the MFD.
- Or add lines to `user.bnd` (in `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\`) with the game closed:

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

## Install

1. Install and enable psi_autocast 1.2 or later.
2. Extract this zip into the **game folder**, the one with `SystemShock2Remastered.exe`. It adds `mods\psi_autocast_mfd.kpf`.
3. Choose **New Game → Mods**, add **psi_autocast_mfd** (keep psi_autocast), **Apply** and start. Once the first level loads, load your own save, then make a regular save.
4. Restart the game when it asks, then press keypad * (or the key the message names) to open the MFD.

**In a new game, wait until you're through training before using the MFD:** macros don't take before then.

## What it writes

- **Macros:** small text files in `Saved Games\Nightdive Studios\System Shock 2 Remastered\psi_macros\`, one per key, in the format psi_autocast's Macro Builder writes.
- **Key bindings:** `user.bnd`, only when you save on a free key or on the first load without an open key, backed up first as `user.bnd.mfd_backup`.

It doesn't touch the game folder.

## Uninstall

1. With the game closed, remove the `user.bnd` lines that run `summon_obj PsiMfd` or `psi_macros` files, or rebind those keys in Options > Controls.
2. Delete `mods\psi_autocast_mfd.kpf`, and the `psi_macros` folder in your save folder if you no longer want the macros.

## License

MIT. See `LICENSE`. Source and developer notes: https://github.com/feygon/SS2PsiAutocastMFD
