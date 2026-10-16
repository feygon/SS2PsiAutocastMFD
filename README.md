# psi_autocast_mfd: an in-game psi macro MFD for System Shock 2: 25th Anniversary Remaster

**TLDR:** Press one key and an MFD opens over the game: every discipline with its duration, effect, overload value and cyber module cost, plus an editor that builds [psi_autocast](https://github.com/feygon/SS2PsiAutocast) macros and saves them to keys. Requires psi_autocast 1.2 or later.

**Step-by-step setup for both mods, and a troubleshooting table:** [SETUP_GUIDE.md](https://github.com/feygon/SS2PsiAutocast/blob/main/SETUP_GUIDE.md).

## What it shows

A scrolling table of all 35 disciplines, each with its icon, tier and name, and:

- **Duration** at your current PSI and at PSI 8.
- **Effect** at your current PSI and at PSI 8: damage, healing, stat bonus, chance or recharge.
- **Overload:** what an overload gives you, for the disciplines that benefit from one.
- **Cyber Mods:** "bought", or the cost, including every tier unlock still needed to reach it. Costs follow your difficulty.

The numbers are read from the running game, so they follow SCP if you use it.

## Building a macro

1. Pick a **macro key** at the top or bottom of the MFD.
2. Click a discipline, or its **+Overload** / **+Quick** button, to add a cast.
3. Add psi hypos, click a wait to change it, and choose a **Finish** weapon switch.
4. **Save**, close the MFD, and press the key.

T1–T5 jump to a tier.

## Install

1. Install and enable psi_autocast 1.2 or later.
2. Extract this zip into the **game folder**, the one with `SystemShock2Remastered.exe`. It adds `mods\psi_autocast_mfd.kpf`.
3. Choose **New Game → Mods**, add **psi_autocast_mfd** (keep psi_autocast), **Apply** and start. Once the first level loads, load your own save, then make a regular save.

## Set up the keys

Scripts can't bind keys while the game runs, so this happens once, with the game closed, in:
`%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\user.bnd`

Back it up first. Either run `setupPsiMfd.bat` from the GitHub repo (`extras/`), which binds free keys for you (and asks, key by key, about non-default keys whose command is also on another key), or add the lines yourself:

```
bind keypad_star "summon_obj PsiMfd"
bind keypad_minus "run user:/psi_macros\MacroKPMinus.cmd"
bind keypad_del "run user:/psi_macros\MacroKPDel.cmd"
```

- **The first line** opens and closes the MFD.
- **Each other line** is a macro key. Add one per key you want, changing the key and the file name together. The MFD finds these lines and offers those keys.

Optional: the mouse wheel scrolls the table when the mouse is over the open MFD, and switches weapons everywhere else. The setup script asks about this (y/n); by hand, replace the two `mouse_wheel` lines with:

```
bind mouse_wheel_up "summon_obj PsiMfdWheelUp"
bind mouse_wheel_down "summon_obj PsiMfdWheelDown"
```

In a save without psi_autocast_mfd enabled, the wheel then doesn't switch weapons. To undo, put back `bind mouse_wheel_up "cycle_weapon 1"` and `bind mouse_wheel_down "cycle_weapon -1"`.

## What it writes

Each macro is a small text file in `Saved Games\Nightdive Studios\System Shock 2 Remastered\psi_macros\`, one per key, in the format psi_autocast's Macro Builder writes. The MFD reads `user.bnd` and never changes it, and it doesn't touch the game folder.

## Uninstall

1. Remove the lines you added to `user.bnd`, with the game closed.
2. Delete `mods\psi_autocast_mfd.kpf`, and the `psi_macros` folder in your save folder if you no longer want the macros.

## License

MIT. See `LICENSE`. Source and developer notes: https://github.com/feygon/SS2PsiAutocastMFD
