# Hotkey Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A keyboard view inside the psi MFD that shows every key's state and lets the player pick any selectable key for the macro editor.

**Architecture:** Data and rules (key table, binding parse, key state, hover text) are plain Squirrel functions in a new `psi_mfd_keyboard.nut` plus `psi_mfd_macros.nut`, mirrored by a Python twin in the offline tests. A `PsiMfdKeyboard` widget draws the keys in the panel's table area; the panel swaps table and keyboard and handles picking and saving. Prototype first (Tasks 1–2, then the user looks at it in game), polish after (Task 3).

**Tech Stack:** Squirrel 2 (NewDark sq_scripts), Nightdive's `ND.UiBase` UI library and `ShockOverlay` drawing, pytest for offline checks, `py build.py --install` to put the build in the game.

**Spec:** `docs/superpowers/specs/2026-10-16-hotkey-picker-design.md` (requirement IDs R1–R26, C1–C3). Read it with this plan.

## Global Constraints

- Never a macro key (C1): Enter, Esc, Tab, Space, Backspace, Caps Lock, Shift, Ctrl, Alt, punctuation, the mouse wheel, keypad +.
- The MFD never edits `user.bnd` (C2); setupPsiMfd.bat is unchanged (C3).
- Every UI entry point catches its own errors with `PsiMfdFail("<name>", e)` (R20); an uncaught error in the UI loop breaks every script UI.
- Call the I/O library as `::file`, read files with `"rb"`, never name a local `base` (all Squirrel pitfalls recorded in DEVELOPMENT.md).
- Functions aim at ~100 lines; over 300 is blocking (R25).
- Widgets are created inside the draw step (the panel constructor), never from a timer (R26).
- Files written by the Bash tool must not contain backslash sequences from heredocs: write `.nut` and test files with the Write/Edit tools.
- The game must be closed for `py build.py --install`; `mod_apply` is never used mid-game.

**Prototype deviation from R15:** the overlay has no fill call (only `ShockOverlay.DrawLine`; `ND.DrawBox` is four lines, and tiled background bitmaps draw other frames at other sizes). "Filled" is drawn as a **double outline**, like the key-name box. Revisit after the user sees it.

## Review Focus

- A `user.bnd` with Windows line endings (`\r\n`): `strip()` must remove the `\r`, or every command compare fails. Covered in Task 1's twin fixture.
- A key bound twice by hand: the last line wins, not the first (R10). Covered in Task 1.
- Clicking the `<` `>` arrows inside a key selector must not also open the keyboard (the selector's own click handler checks the mouse is over the name box). Covered in Task 2 Step 6 (in game).
- Picking a key that's already in the selector list must not add it twice (R17). Covered in Task 2's `PickKey`.
- The wheel over the MFD while the keyboard shows must not scroll the hidden table (R3). Covered in Task 2's `Scroll` guard.

---

### Task 1: Key table, binding parse and key-state rules (offline-tested)

**Files:**
- Create: `mod/sq_scripts/psi_mfd_keyboard.nut`
- Modify: `mod/sq_scripts/psi_mfd_macros.nut` (replace `PsiMfdMacroKeys`, lines 78–109; add `PsiMfdBindings`, `PsiMfdMacroFile`, `PsiMfdMacroFileState`)
- Modify: `mod/sq_scripts/psi_mfd_ui.nut:355` (`Refresh` calls `PsiMfdMacroKeys(m_bindings)`)
- Test: `dev/tests/test_keyboard.py` (new)

**Interfaces:**
- Produces (Squirrel, used by Task 2):
  - `ND.psiMfdKeyboard`: array of `{ n, l, c, r, w, h }` (Dark name, label, column, row 0–5, width, height in rows).
  - `ND.psiMfdNever`, `ND.psiMfdCandidates`: arrays of Dark names.
  - `PsiMfdBindings()` → `null` (unreadable) or table `key -> { command, lower, combo }`.
  - `PsiMfdMacroFile(lower)` → plain file name (lower case) or `null`.
  - `PsiMfdMacroFileState(fileName)` → `"has"` / `"empty"` / `"missing"`.
  - `PsiMfdMacroKeys(bindings)` → `[{ key, file }]`, keyboard order, then other keys sorted.
  - `PsiMfdKeyState(name, bindings, fileState)` → `{ state, selectable, file, contentFile, content, marks }`; `state` is one of `macro free game mod reserved never notoffered faint`; `fileState` is `lower-case file name -> "has"/"empty"/"missing"`.
  - `PsiMfdAlsoOn(name, bindings)` → sorted array of other key tokens (not `joy*`) with the same lower-case command.
  - `PsiMfdKeyHover(name, keyState, bindings)` → string.
  - `PsiMfdKeyLook(keyState)` → `{ edge, text, double }` (colour arrays, bool).

- [ ] **Step 1: Write the failing tests** — `dev/tests/test_keyboard.py`:

```python
"""
Test Suite: the MFD's keyboard view (psi_mfd_keyboard.nut and the binding parse in psi_mfd_macros.nut)

WHY THESE TESTS MATTER:
- The keyboard tells players which keys they can put macros on and what to do outside the game. A wrong
  state sends them to the Controls menu for nothing, or hides a conflict.
- The Squirrel code only runs in game, so the rules are mirrored here by a Python twin that reads its
  lists and key table from the .nut file itself; the in-game test plan covers each state too.

COVERAGE GOALS:
- Key table: names, overlap, size, lists consistent with setupPsiMfd.bat
- Rules: every state in R11's order, every mark in R14, bindings parse edge cases (R10)
"""
import re
import zipfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SCRIPTS = REPO / "mod" / "sq_scripts"
BAT = REPO / "extras" / "setupPsiMfd.bat"
GAME = Path(r"D:\EpicLibrary\SystemShock225thAnniT5DFq")
KB = (SCRIPTS / "psi_mfd_keyboard.nut").read_text(encoding="utf-8") if (SCRIPTS / "psi_mfd_keyboard.nut").exists() else ""

# Keys the game accepted and rewrote into the author's user.bnd (2026-10-16): proof the names are valid.
GAME_REWRITTEN = set("abcdefghijklmnopqrstuvwxyz0123456789") | {f"f{i}" for i in range(1, 13)} | {
    "ins", "del", "home", "end", "pgup", "pgdn", "keypad_minus", "keypad_del", "keypad_ins", "keypad_center", "keypad_slash"}


def squirrel_string(s):
    return s.replace("\\\\", "\\").replace('\\"', '"')


def key_table():
    rows = re.findall(r'PsiMfdK\("((?:\\.|[^"\\])*)", "((?:\\.|[^"\\])*)", ([\d.]+), (\d+)(?:, ([\d.]+))?(?:, (\d+))?\)', KB)
    return [dict(n=squirrel_string(n), l=squirrel_string(l), c=float(c), r=int(r), w=float(w or 1), h=int(h or 1))
            for n, l, c, r, w, h in rows]


def nut_list(name):
    body = re.search(r"ND\." + name + r" <- \[(.*?)\];", KB, re.S).group(1)
    return [squirrel_string(s) for s in re.findall(r'"((?:\\.|[^"\\])*)"', body)]


def bat_candidates():
    return re.search(r'set "MACRO_CANDIDATES=([^"]*)"', BAT.read_text()).group(1).split()


# ---- the Python twin of R10-R14 -------------------------------------------------------------------------

PREFIX = "run user:/psi_macros\\"


def bindings(text):
    if text is None:
        return None
    out = {}
    for raw in text.split("\n"):
        line = raw.strip()
        if line[:5].lower() != "bind ":
            continue
        rest = line[5:].strip()
        if " " not in rest:
            continue
        key, command = rest.split(" ", 1)
        key = key.lower()
        command = command.strip()
        if len(command) >= 2 and command[0] == '"' and command[-1] == '"':
            command = command[1:-1]
        out.pop(key, None)
        out[key] = dict(command=command, lower=command.lower(), combo="+" in key)
    return out


def macro_file(lower):
    if not lower.startswith(PREFIX):
        return None
    rest = lower[len(PREFIX):]
    if "\\" in rest or "/" in rest or ".." in rest or not rest.endswith(".cmd"):
        return None
    return rest


def also_on(name, b):
    return sorted(k for k, v in b.items() if k != name and v["lower"] == b[name]["lower"] and not k.startswith("joy"))


def key_state(name, b, file_state):
    s = dict(state="faint", selectable=False, file=None, contentFile=None, content=None, marks="")
    if b is None:
        return s
    bind = b.get(name)
    lower = bind["lower"] if bind else ""
    candidate = name in nut_list("psiMfdCandidates")
    if name == "keypad_plus":
        s["state"] = "reserved"
    elif name in nut_list("psiMfdNever"):
        s["state"] = "never"
    elif lower == "summon_obj psimfd":
        s["state"] = "mod"
    elif macro_file(lower):
        s.update(state="macro", selectable=True, file=macro_file(lower))
    elif lower.startswith("summon_obj psimfdwheel") or "cancel_macro" in lower or lower.startswith("run psi\\"):
        s["state"] = "mod"
    elif candidate:
        s.update(state="game" if bind else "free", selectable=True, file="Macro_" + name + ".cmd")
    else:
        s["state"] = "notoffered"
    if s["state"] == "macro":
        s["contentFile"] = s["file"]
    elif candidate:
        s["contentFile"] = "Macro_" + name + ".cmd"
    if s["contentFile"]:
        s["content"] = file_state.get(s["contentFile"].lower(), "missing")
    if s["state"] in ("game", "mod") and also_on(name, b):
        s["marks"] += "="
    if s["state"] in ("game", "mod") and s["content"] == "has":
        s["marks"] += "!"
    elif s["content"] == "empty":
        s["marks"] += "?"
    return s


FIXTURE = "\r\n".join([
    'bind keypad_star "summon_obj psimfd"',
    'bind keypad_plus "run psi\\actions\\cancel_macro.cmd"',
    'bind g "run user:/psi_macros\\macrog.cmd"',
    'bind up "run user:/psi_macros\\macro_up.cmd"',
    'bind enter "run user:/psi_macros\\macro_enter.cmd"',
    'bind k "run psi\\t2_localized_pyrokinesis.cmd"',
    'bind t wpn_setting_toggle',
    'bind mouse5 wpn_setting_toggle',
    'bind joy3 interact',
    'bind y interact',
    'bind space +jump',
    'bind c+alt toggle_compass',
    'bind x toggle_compass',
    'bind h "use_obj med patch"',
    'bind h "use_obj psi booster"',
    'bind v "run user:/psi_macros\\..\\evil.cmd"',
    'game2 bind mouse1 +drag_and_drop_mode',
    '; a comment',
]) + "\r\n"
FILES = {"macrog.cmd": "has", "macro_t.cmd": "has", "macro_x.cmd": "empty", "macro_o.cmd": "has"}


@pytest.fixture
def b():
    return bindings(FIXTURE)


# ---- tests ----------------------------------------------------------------------------------------------

def test_keyboard_file_exists():
    """WHY: Everything below reads the key table from it."""
    assert KB, "psi_mfd_keyboard.nut missing"
    assert len(key_table()) >= 100


def test_candidates_match_the_setup_script():
    """WHY: A macro on a key the script never binds could never run (R11)."""
    assert nut_list("psiMfdCandidates") == bat_candidates()
    assert not set(nut_list("psiMfdNever")) & set(nut_list("psiMfdCandidates"))


def test_selectable_names_are_proven():
    """WHY: A candidate name the game doesn't accept would make a key that never fires."""
    assert set(nut_list("psiMfdCandidates")) <= GAME_REWRITTEN


@pytest.mark.skipif(not GAME.exists(), reason="game install not found")
def test_other_names_are_game_names():
    """WHY: Non-candidate keys are only looked up, but a misspelt name would never match user.bnd."""
    shock = zipfile.ZipFile(GAME / "base.kpf").read("defaults/shock.bnd").decode("latin-1")
    shock_keys = {l.split()[1].lower() for l in shock.splitlines() if l.startswith("bind ")}
    exe = (GAME / "SystemShock2Remastered.exe").read_bytes()
    for k in key_table():
        if k["n"] in GAME_REWRITTEN or k["n"] in shock_keys:
            continue
        assert b"\0" + k["n"].encode() + b"\0" in exe, k["n"]


def test_keys_fit_and_never_overlap():
    """WHY: Overlapping keys would make the mouse pick the wrong one (R6, R7)."""
    keys = key_table()
    for k in keys:
        assert 0 <= k["c"] and k["c"] + k["w"] <= 23 and 0 <= k["r"] and k["r"] + k["h"] <= 6, k
    for i, a in enumerate(keys):
        for c in keys[i + 1:]:
            apart = a["c"] + a["w"] <= c["c"] or c["c"] + c["w"] <= a["c"] or a["r"] + a["h"] <= c["r"] or c["r"] + c["h"] <= a["r"]
            assert apart, (a, c)
    assert (470 - 36) // 23 >= 18


def test_parse_handles_crlf_quotes_comments_game2_and_duplicates(b):
    """WHY: user.bnd uses CRLF and quotes; game2 and comment lines aren't plain bindings; the last line wins."""
    assert b["t"]["lower"] == "wpn_setting_toggle"
    assert b["g"]["command"] == "run user:/psi_macros\\macrog.cmd"
    assert b["h"]["lower"] == "use_obj psi booster"
    assert "mouse1" not in b and b["c+alt"]["combo"]


@pytest.mark.parametrize("name,state,selectable", [
    ("keypad_plus", "reserved", False), ("enter", "never", False), ("space", "never", False),
    ("keypad_star", "mod", False), ("k", "mod", False), ("g", "macro", True), ("up", "macro", True),
    ("o", "free", True), ("t", "game", True), ("v", "game", True), ("left", "notoffered", False)])
def test_states_follow_r11_order(b, name, state, selectable):
    """WHY: R11's order decides overlaps: keypad + and never-list keys win over macro bindings; a hand-bound
    non-candidate macro key is still a macro key; an unsafe file name isn't a macro."""
    s = key_state(name, b, FILES)
    assert (s["state"], s["selectable"]) == (state, selectable)


def test_marks(b):
    """WHY: = shows a job done elsewhere, ! a macro the key can't run, ? a broken file (R14)."""
    assert key_state("t", b, FILES)["marks"] == "=!"
    assert key_state("y", b, FILES)["marks"] == ""   # only a gamepad button shares 'interact'
    assert key_state("x", b, FILES)["marks"] == "=?"  # c+alt is a combo, still "elsewhere"
    assert key_state("o", b, FILES)["content"] == "has" and key_state("o", b, FILES)["marks"] == ""


def test_unreadable_bnd_shows_everything_faint():
    """WHY: Without user.bnd every key would otherwise look free (R21)."""
    assert key_state("t", bindings(None), {})["state"] == "faint"


def test_twin_lists_come_from_the_nut_file():
    """WHY: The twin must not carry its own copy of the lists, or it would drift from the game code."""
    assert "keypad_plus" in nut_list("psiMfdNever")
    for name in ["PsiMfdKeyState", "PsiMfdAlsoOn", "PsiMfdKeyHover", "PsiMfdKeyLook"]:
        assert f"function {name}(" in KB, name
    macros = (SCRIPTS / "psi_mfd_macros.nut").read_text(encoding="utf-8")
    for name in ["PsiMfdBindings", "PsiMfdMacroFile", "PsiMfdMacroFileState", "PsiMfdMacroKeys"]:
        assert f"function {name}(" in macros, name
```

- [ ] **Step 2: Run, expect failures**

Run: `py -m pytest dev/tests/test_keyboard.py -q`
Expected: FAIL (`psi_mfd_keyboard.nut missing`, list regex finds nothing).

- [ ] **Step 3: Write `mod/sq_scripts/psi_mfd_keyboard.nut`** (data and rules; the widget is added in Task 2):

```squirrel
// psi_mfd_keyboard: the MFD's keyboard view. Key table, key states and hover text (spec:
// docs/superpowers/specs/2026-10-16-hotkey-picker-design.md, R6-R16). The widget is PsiMfdKeyboard below.

// One key: Dark name, label, column and row (0-5) in units, width and height (rows).
function PsiMfdK(n, l, c, r, w = 1, h = 1) {
	return { n = n, l = l, c = c, r = r, w = w, h = h };
}

ND.psiMfdKeyboard <- [
	PsiMfdK("esc", "Esc", 0, 0),
	PsiMfdK("f1", "F1", 2, 0), PsiMfdK("f2", "F2", 3, 0), PsiMfdK("f3", "F3", 4, 0), PsiMfdK("f4", "F4", 5, 0),
	PsiMfdK("f5", "F5", 6.5, 0), PsiMfdK("f6", "F6", 7.5, 0), PsiMfdK("f7", "F7", 8.5, 0), PsiMfdK("f8", "F8", 9.5, 0),
	PsiMfdK("f9", "F9", 11, 0), PsiMfdK("f10", "F10", 12, 0), PsiMfdK("f11", "F11", 13, 0), PsiMfdK("f12", "F12", 14, 0),
	PsiMfdK("`", "`", 0, 1), PsiMfdK("1", "1", 1, 1), PsiMfdK("2", "2", 2, 1), PsiMfdK("3", "3", 3, 1), PsiMfdK("4", "4", 4, 1),
	PsiMfdK("5", "5", 5, 1), PsiMfdK("6", "6", 6, 1), PsiMfdK("7", "7", 7, 1), PsiMfdK("8", "8", 8, 1), PsiMfdK("9", "9", 9, 1),
	PsiMfdK("0", "0", 10, 1), PsiMfdK("-", "-", 11, 1), PsiMfdK("=", "=", 12, 1), PsiMfdK("backspace", "Bksp", 13, 1, 2),
	PsiMfdK("tab", "Tab", 0, 2, 1.5), PsiMfdK("q", "Q", 1.5, 2), PsiMfdK("w", "W", 2.5, 2), PsiMfdK("e", "E", 3.5, 2),
	PsiMfdK("r", "R", 4.5, 2), PsiMfdK("t", "T", 5.5, 2), PsiMfdK("y", "Y", 6.5, 2), PsiMfdK("u", "U", 7.5, 2),
	PsiMfdK("i", "I", 8.5, 2), PsiMfdK("o", "O", 9.5, 2), PsiMfdK("p", "P", 10.5, 2), PsiMfdK("[", "[", 11.5, 2),
	PsiMfdK("]", "]", 12.5, 2), PsiMfdK("\\", "\\", 13.5, 2, 1.5),
	PsiMfdK("caps_lock", "Caps", 0, 3, 1.75), PsiMfdK("a", "A", 1.75, 3), PsiMfdK("s", "S", 2.75, 3), PsiMfdK("d", "D", 3.75, 3),
	PsiMfdK("f", "F", 4.75, 3), PsiMfdK("g", "G", 5.75, 3), PsiMfdK("h", "H", 6.75, 3), PsiMfdK("j", "J", 7.75, 3),
	PsiMfdK("k", "K", 8.75, 3), PsiMfdK("l", "L", 9.75, 3), PsiMfdK(";", ";", 10.75, 3), PsiMfdK("'", "'", 11.75, 3),
	PsiMfdK("enter", "Enter", 12.75, 3, 2.25),
	PsiMfdK("shift", "Shift", 0, 4, 2.25), PsiMfdK("z", "Z", 2.25, 4), PsiMfdK("x", "X", 3.25, 4), PsiMfdK("c", "C", 4.25, 4),
	PsiMfdK("v", "V", 5.25, 4), PsiMfdK("b", "B", 6.25, 4), PsiMfdK("n", "N", 7.25, 4), PsiMfdK("m", "M", 8.25, 4),
	PsiMfdK(",", ",", 9.25, 4), PsiMfdK(".", ".", 10.25, 4), PsiMfdK("/", "/", 11.25, 4), PsiMfdK("shift", "Shift", 12.25, 4, 2.75),
	PsiMfdK("ctrl", "Ctrl", 0, 5, 1.5), PsiMfdK("alt", "Alt", 1.5, 5, 1.5), PsiMfdK("space", "Space", 3, 5, 8),
	PsiMfdK("alt", "Alt", 11, 5, 1.5), PsiMfdK("ctrl", "Ctrl", 12.5, 5, 2.5),
	PsiMfdK("ins", "Ins", 15.5, 1), PsiMfdK("home", "Home", 16.5, 1), PsiMfdK("pgup", "PgUp", 17.5, 1),
	PsiMfdK("del", "Del", 15.5, 2), PsiMfdK("end", "End", 16.5, 2), PsiMfdK("pgdn", "PgDn", 17.5, 2),
	PsiMfdK("up", "Up", 16.5, 4), PsiMfdK("left", "Lt", 15.5, 5), PsiMfdK("down", "Dn", 16.5, 5), PsiMfdK("right", "Rt", 17.5, 5),
	PsiMfdK("numlock", "Num", 19, 1), PsiMfdK("keypad_slash", "/", 20, 1), PsiMfdK("keypad_star", "*", 21, 1),
	PsiMfdK("keypad_minus", "-", 22, 1),
	PsiMfdK("keypad_home", "7", 19, 2), PsiMfdK("keypad_up", "8", 20, 2), PsiMfdK("keypad_pgup", "9", 21, 2),
	PsiMfdK("keypad_plus", "+", 22, 2, 1, 2),
	PsiMfdK("keypad_left", "4", 19, 3), PsiMfdK("keypad_center", "5", 20, 3), PsiMfdK("keypad_right", "6", 21, 3),
	PsiMfdK("keypad_end", "1", 19, 4), PsiMfdK("keypad_down", "2", 20, 4), PsiMfdK("keypad_pgdn", "3", 21, 4),
	PsiMfdK("keypad_enter", "Ent", 22, 4, 1, 2),
	PsiMfdK("keypad_ins", "0", 19, 5, 2), PsiMfdK("keypad_del", ".", 21, 5)
];

// C1: never macro keys. keypad_plus is listed for completeness; R11 checks it first as Reserved.
ND.psiMfdNever <- ["enter", "keypad_enter", "esc", "tab", "space", "backspace", "caps_lock", "shift", "ctrl", "alt",
	"keypad_plus", "`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/"];

// Exactly setupPsiMfd.bat's MACRO_CANDIDATES (a test keeps them equal): keys the script can bind later.
ND.psiMfdCandidates <- ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
	"u", "v", "w", "x", "y", "z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "f1", "f2", "f3", "f4", "f5", "f6",
	"f7", "f8", "f9", "f10", "f11", "f12", "keypad_minus", "keypad_del", "keypad_ins", "keypad_center", "keypad_slash",
	"ins", "del", "home", "end", "pgup", "pgdn"];

// Colours (R15).
ND.psiMfdGrey <- [0.35, 0.4, 0.38];
ND.psiMfdSlate <- [0.4, 0.42, 0.55];
ND.psiMfdFaint <- [0.22, 0.27, 0.25];
ND.psiMfdRed <- [0.8, 0.35, 0.3];

// Other keys (not gamepad) whose command matches name's, sorted.
function PsiMfdAlsoOn(name, bindings) {
	local others = [];
	local lower = bindings[name].lower;
	foreach (key, b in bindings) {
		if (key != name && b.lower == lower && !startswith(key, "joy"))
			others.push(key);
	}
	others.sort();
	return others;
}

function PsiMfdIsModCommand(lower) {
	return startswith(lower, "summon_obj psimfdwheel") || lower.find("cancel_macro") != null || startswith(lower, "run psi\\");
}

// R11 state, R12 content and R14 marks for one key. fileState: lower-case file name -> "has" / "empty" / "missing".
function PsiMfdKeyState(name, bindings, fileState) {
	local s = { state = "faint", selectable = false, file = null, contentFile = null, content = null, marks = "" };
	if (bindings == null)
		return s;
	local b = name in bindings ? bindings[name] : null;
	local lower = b ? b.lower : "";
	local candidate = ND.psiMfdCandidates.find(name) != null;
	local macroFile = PsiMfdMacroFile(lower);
	if (name == "keypad_plus")
		s.state = "reserved";
	else if (ND.psiMfdNever.find(name) != null)
		s.state = "never";
	else if (lower == "summon_obj psimfd")
		s.state = "mod";
	else if (macroFile) {
		s.state = "macro";
		s.selectable = true;
		s.file = macroFile;
	}
	else if (PsiMfdIsModCommand(lower))
		s.state = "mod";
	else if (candidate) {
		s.state = b ? "game" : "free";
		s.selectable = true;
		s.file = "Macro_" + name + ".cmd";
	}
	else
		s.state = "notoffered";
	PsiMfdAddContent(s, name, candidate, fileState);
	PsiMfdAddMarks(s, name, bindings);
	return s;
}

function PsiMfdAddContent(s, name, candidate, fileState) {
	if (s.state == "macro")
		s.contentFile = s.file;
	else if (candidate)
		s.contentFile = "Macro_" + name + ".cmd";
	if (s.contentFile) {
		local lower = s.contentFile.tolower();
		s.content = lower in fileState ? fileState[lower] : "missing";
	}
}

function PsiMfdAddMarks(s, name, bindings) {
	local bound = s.state == "game" || s.state == "mod";
	if (bound && PsiMfdAlsoOn(name, bindings).len())
		s.marks += "=";
	if (bound && s.content == "has")
		s.marks += "!";
	else if (s.content == "empty")
		s.marks += "?";
}

function PsiMfdJoin(list) {
	local text = "";
	foreach (item in list)
		text += (text.len() ? " " : "") + item;
	return text;
}

function PsiMfdModText(lower, command) {
	if (lower == "summon_obj psimfd")
		return "opens this MFD";
	if (startswith(lower, "summon_obj psimfdwheel"))
		return "scrolls the MFD";
	if (lower.find("cancel_macro") != null)
		return "psi_autocast cancel";
	return "psi_autocast (" + command + ")";
}

// R16 hover text.
function PsiMfdKeyHover(name, ks, bindings) {
	if (ks.state == "faint" && bindings == null)
		return "Can't read user.bnd: keys can't be shown";
	local key = PsiMfdKeyName(name);
	local b = bindings && name in bindings ? bindings[name] : null;
	local command = b ? b.command : "";
	if (ks.marks.find("?") != null)
		return key + ": macro file has no steps";
	local text = key + ": ";
	switch (ks.state) {
		case "macro": text += ks.content == "has" ? "macro (" + ks.file + ")" : "macro key, no macro yet"; break;
		case "free": text += ks.content == "has" ? "free, has a macro: quit and run setupPsiMfd.bat" : "free"; break;
		case "game": text += command; break;
		case "mod": text += PsiMfdModText(b.lower, command); break;
		case "reserved": text += "reserved for psi_autocast cancel"; break;
		case "never": text += (b ? command + "; " : "") + "never used for macros"; break;
		default: text += (b ? command + "; " : "") + "not offered for macros";
	}
	if (ks.marks.find("=") != null)
		text += " (also on " + PsiMfdJoin(PsiMfdAlsoOn(name, bindings)) + ")";
	if (ks.marks.find("!") != null)
		text += "; has a macro: clear " + key + " in Controls, run setupPsiMfd.bat";
	return text;
}

// R15 look. double = drawn with a second outline ("filled": the overlay has no fill call).
function PsiMfdKeyLook(ks) {
	switch (ks.state) {
		case "macro": return { edge = ND.psiMfdBright, text = ND.psiMfdBright, double = ks.content == "has" };
		case "free":
			if (ks.content == "has")
				return { edge = ND.psiMfdDim, text = ND.psiMfdText, double = true };
			return { edge = ND.psiMfdDim, text = ND.psiMfdDim, double = false };
		case "game": return { edge = ND.psiMfdGrey, text = ND.psiMfdGrey, double = false };
		case "mod":
		case "reserved": return { edge = ND.psiMfdSlate, text = ND.psiMfdSlate, double = false };
	}
	return { edge = ND.psiMfdFaint, text = ND.psiMfdFaint, double = false };
}
```

Note: `PsiMfdKeyName` and `ND.psiMfdBright/Text/Dim` live in `psi_mfd_ui.nut`; they are only used at call time, so file load order doesn't matter.

- [ ] **Step 4: Replace `PsiMfdMacroKeys` in `psi_mfd_macros.nut`** (lines 78–109) with:

```squirrel
// user.bnd's text, or null if it can't be read.
function PsiMfdReadBnd() {
	foreach (path in [PSI_MFD_ROOT + "user.bnd", "user:/user.bnd"]) {
		try {
			return PsiMfdReadFile(path);
		}
		catch (e) {}
	}
	print("[psi_mfd] couldn't read user.bnd");
	return null;
}

// key -> { command, lower, combo } for every "bind <key> <command>" line (R10); null if user.bnd can't be read.
// Outer quotes are removed; game2 and comment lines are ignored; a key bound twice keeps its last line.
function PsiMfdBindings() {
	local text = PsiMfdReadBnd();
	if (text == null)
		return null;
	local bindings = {};
	foreach (raw in split(text, "\n")) {
		local line = strip(raw);
		if (line.len() < 5 || line.slice(0, 5).tolower() != "bind ")
			continue;
		local rest = strip(line.slice(5));
		local space = rest.find(" ");
		if (space == null)
			continue;
		local key = rest.slice(0, space).tolower();
		local command = strip(rest.slice(space + 1));
		if (command.len() >= 2 && command[0] == '"' && command[command.len() - 1] == '"')
			command = command.slice(1, -1);
		if (key in bindings)
			delete bindings[key];
		bindings[key] <- { command = command, lower = command.tolower(), combo = key.find("+") != null };
	}
	return bindings;
}

// The macro file a lower-case command runs, if it's "run user:/psi_macros\<plain name>.cmd"; else null.
function PsiMfdMacroFile(lower) {
	local prefix = PSI_MFD_RUN_PREFIX.tolower();
	if (!startswith(lower, prefix))
		return null;
	local rest = lower.slice(prefix.len());
	if (rest.find("\\") != null || rest.find("/") != null || rest.find("..") != null || !endswith(rest, ".cmd"))
		return null;
	return rest;
}

// "has" (a step or a finish weapon), "empty" (reads, but neither), or "missing" (can't be read). R12.
function PsiMfdMacroFileState(fileName) {
	local macro = PsiMfdMacro("", fileName);
	try {
		if (!macro.Load())
			return "missing";
	}
	catch (e) {
		return "missing";
	}
	return macro.steps.len() || macro.finish != "" ? "has" : "empty";
}

// [{ key, file }] for every key whose R11 state is "macro": keyboard order first, then other keys by name.
function PsiMfdMacroKeys(bindings) {
	local keys = [];
	if (bindings == null)
		return keys;
	local seen = {};
	foreach (k in ND.psiMfdKeyboard) {
		if (!(k.n in seen) && PsiMfdKeyState(k.n, bindings, {}).state == "macro")
			keys.push({ key = k.n, file = PsiMfdMacroFile(bindings[k.n].lower) });
		seen[k.n] <- true;
	}
	local others = [];
	foreach (key, b in bindings) {
		if (!(key in seen) && !b.combo && PsiMfdKeyState(key, bindings, {}).state == "macro")
			others.push({ key = key, file = PsiMfdMacroFile(b.lower) });
	}
	others.sort(@(a, b) a.key <=> b.key);
	keys.extend(others);
	return keys;
}
```

The mod already uses Squirrel 3 features (default parameters in `PsiMfdButton`), so `endswith`, `array.find`, `array.extend` and `<=>` are available.

- [ ] **Step 5: Update `Refresh` in `psi_mfd_ui.nut`** — add a member `m_bindings = null;` to `PsiMfdPanel` and change line 355:

```squirrel
		m_bindings = PsiMfdBindings();
		m_keys = PsiMfdMacroKeys(m_bindings);
```

- [ ] **Step 6: Run the tests**

Run: `py -m pytest dev/tests -q`
Expected: all pass, except `test_release_zip_contents` and `test_brackets_balance` don't know the new file yet (that's Task 3); `test_release_zip_contents` skips or fails only if the zip is rebuilt. If any `test_keyboard.py` test fails, fix the `.nut` (or the twin if the twin is wrong about the spec) until all pass.

- [ ] **Step 7: Commit**

```bash
git add mod/sq_scripts/psi_mfd_keyboard.nut mod/sq_scripts/psi_mfd_macros.nut mod/sq_scripts/psi_mfd_ui.nut dev/tests/test_keyboard.py
git commit -m "Keyboard: key table, binding parse and key-state rules, with offline twin tests"
```

---

### Task 2: Keyboard widget and panel integration (the prototype)

**Files:**
- Modify: `mod/sq_scripts/psi_mfd_keyboard.nut` (append `PsiMfdKeyboard`)
- Modify: `mod/sq_scripts/psi_mfd_ui.nut` (`PsiMfdKeySelector`, `PsiMfdPanel`)

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces: `PsiMfdKeyboard(panel, x, y, width, height)` with `SetData(bindings, fileState)`; panel methods `ToggleKeyboard(unused)`, `ShowKeyboard(show)`, `PickKey(name, keyState)`, `SelectedKeyName()`, `SetEditLabel(text)`, `BuildFileState()`.

- [ ] **Step 1: Append the widget to `psi_mfd_keyboard.nut`:**

```squirrel
// The keyboard view, drawn in the panel's table area: a 12-unit info line, then 6 rows of keys (R6).
class PsiMfdKeyboard extends ND.UiBase {
	m_panel = null;
	m_unit = 0;
	m_rowHeight = 0;
	m_bindings = null;
	m_states = null;      // Dark name -> PsiMfdKeyState()
	m_labels = null;      // per ND.psiMfdKeyboard entry: { text, dx } fitted to the key
	m_hover = null;       // the key entry under the mouse

	constructor(panel, x, y, width, height, panelWidth) {
		base.constructor(x, y, width, height);
		m_panel = panel;
		m_uiType = "PsiMfdKeyboard";
		m_unit = ((panelWidth - 36) / 23).tointeger();
		m_rowHeight = ((height - PSI_MFD_HEADER) / 6).tointeger();
		m_states = {};
		m_labels = [];
		local w = int_ref();
		local h = int_ref();
		foreach (k in ND.psiMfdKeyboard) {
			local width_ = Rect(k, 0, 0);
			local text = PsiMfdFit(k.l, width_[2] - width_[0] - 3);
			ShockOverlay.GetStringSize(text, w, h);
			m_labels.push({ text = text, dx = (width_[2] - width_[0] - w.tointeger()) / 2 });
		}
	}

	function SetData(bindings, fileState) {
		m_bindings = bindings;
		m_states = {};
		foreach (k in ND.psiMfdKeyboard) {
			if (!(k.n in m_states))
				m_states[k.n] <- PsiMfdKeyState(k.n, bindings, fileState);
		}
	}

	// [x0, y0, x1, y1] of a key, from the area's top-left corner (R6 rounding).
	function Rect(k, left, top) {
		local x0 = left + (k.c * m_unit).tointeger();
		local x1 = left + ((k.c + k.w) * m_unit).tointeger() - 2;
		local y0 = top + PSI_MFD_HEADER + k.r * m_rowHeight;
		return [x0, y0, x1, y0 + k.h * m_rowHeight - 2];
	}

	function KeyAt(left, top) {
		local mouse = ND.g_PlayerCore.m_mouse;
		foreach (k in ND.psiMfdKeyboard) {
			local r = Rect(k, left, top);
			if (mouse.x >= r[0] && mouse.x <= r[2] && mouse.y >= r[1] && mouse.y <= r[3])
				return k;
		}
		return null;
	}

	function DrawAt(x, y) {
		if (!m_active)
			return null;
		try {
			local hovered = base.DrawAt(x, y);
			local left = x + m_x;
			local top = y + m_y;
			m_hover = m_hovered ? KeyAt(left, top) : null;
			DrawInfo(left, top);
			local selected = m_panel.SelectedKeyName();
			foreach (i, k in ND.psiMfdKeyboard)
				DrawKey(k, m_labels[i], Rect(k, left, top), k == m_hover, k.n == selected);
			return hovered;
		}
		catch (e) {
			PsiMfdFail("keyboard draw", e);
			return null;
		}
	}

	function DrawInfo(left, top) {
		local text;
		try {
			if (m_hover)
				text = PsiMfdKeyHover(m_hover.n, m_states[m_hover.n], m_bindings);
			else if (m_bindings == null)
				text = "Can't read user.bnd: keys can't be shown";
			else
				text = "Bright: macro  Dim: free  Grey: game  Slate: mod  = elsewhere  ! conflict  ? empty";
		}
		catch (e) {
			PsiMfdFail("keyboard hover", e);
			return;
		}
		PsiMfdColor(ND.psiMfdText);
		ShockOverlay.DrawString(PsiMfdFit(text, m_width - 4), left, top);
	}

	function DrawKey(k, label, r, over, selected) {
		local s = m_states[k.n];
		local look = PsiMfdKeyLook(s);
		local edge = over && s.selectable ? ND.psiMfdBright : look.edge;
		ND.DrawBox(r[0], r[1], r[2], r[3], edge[0], edge[1], edge[2]);
		if (look.double)
			ND.DrawBox(r[0] + 1, r[1] + 1, r[2] - 1, r[3] - 1, edge[0], edge[1], edge[2]);
		if (selected) {
			local b = ND.psiMfdBright;
			ND.DrawBox(r[0] - 1, r[1] - 1, r[2] + 1, r[3] + 1, b[0], b[1], b[2]);
		}
		PsiMfdColor(look.text);
		ShockOverlay.DrawString(label.text, r[0] + label.dx, r[1] + (r[3] - r[1] - 9) / 2);
		if (s.marks.find("=") != null) {
			PsiMfdColor(ND.psiMfdText);
			ShockOverlay.DrawString("=", r[2] - 6, r[1]);
		}
		if (s.marks.find("!") != null) {
			PsiMfdColor(ND.psiMfdRed);
			ShockOverlay.DrawString("!", r[0] + 2, r[1]);
		}
		else if (s.marks.find("?") != null) {
			PsiMfdColor(ND.psiMfdText);
			ShockOverlay.DrawString("?", r[0] + 2, r[1]);
		}
	}

	function OnLeftClick(message) {
		try {
			if (m_hover && m_states[m_hover.n].selectable)
				m_panel.PickKey(m_hover.n, m_states[m_hover.n]);
		}
		catch (e) {
			PsiMfdFail("keyboard click", e);
		}
	}
}
```

(`width_` avoids shadowing; never name a local `base`.)

- [ ] **Step 2: Make the key-name box clickable** — in `PsiMfdKeySelector` (`psi_mfd_ui.nut:144`), add:

```squirrel
	// Clicking the name box (not the < > buttons) opens or closes the keyboard (R1).
	function OnLeftClick(message) {
		try {
			local mouseX = ND.g_PlayerCore.m_mouse.x;
			if (mouseX >= m_screenX + 14 && mouseX <= m_screenX + 14 + PSI_MFD_KEY_BOX)
				m_panel.ToggleKeyboard(null);
		}
		catch (e) {
			PsiMfdFail("key box click", e);
		}
	}
```

- [ ] **Step 3: Panel members and constructor** — in `PsiMfdPanel` add members:

```squirrel
	m_keyboard = null;
	m_keyboardShown = false;
	m_tableWidgets = null;  // header labels, rows, Up, Dn: hidden while the keyboard shows
	m_tableHeight = 0;
	m_editLabel = null;
```

and the constant near the others at the top of the file:

```squirrel
const PSI_MFD_EDIT_HINT = "Macro: click a step to remove it, a wait to change it";
```

In the constructor:
- after `AddChild(PsiMfdKeySelector(this, 130, 2));` add
  `AddChild(PsiMfdButton("", 260, 4, this, "ToggleKeyboard", null, @() m_keyboardShown ? "Table" : "Keys"));`
- start `m_tableWidgets = [];` before the column headings, and collect each heading label, each row, and the Up and Dn buttons into it (e.g. `local heading = PsiMfdLabel(...); AddChild(heading); m_tableWidgets.push(heading);`).
- after the Up/Dn buttons:

```squirrel
		m_tableHeight = PSI_MFD_HEADER + 2 + m_visibleRows * PSI_MFD_ROW_HEIGHT;
		AddChild(m_keyboard = PsiMfdKeyboard(this, 6, PSI_MFD_TOP_BAR, width - 12, m_tableHeight, width));
		m_keyboard.SetActive(false);
```

- replace the editor label line with
  `AddChild(m_editLabel = PsiMfdLabel(6, editY, PSI_MFD_EDIT_HINT, ND.psiMfdDim));`

- [ ] **Step 4: Panel methods** — add to `PsiMfdPanel`:

```squirrel
	function SelectedKeyName() {
		return m_keys && m_keys.len() ? m_keys[m_keyIndex].key : null;
	}

	function SetEditLabel(text) {
		m_editLabel.Set(PsiMfdFit(text, m_width - 12), ND.psiMfdDim[0], ND.psiMfdDim[1], ND.psiMfdDim[2]);
	}

	function ShowKeyboard(show) {
		m_keyboardShown = show;
		foreach (widget in m_tableWidgets)
			widget.SetActive(!show);
		m_keyboard.SetActive(show);
	}

	// lower-case file name -> "has" / "empty" / "missing", for every file a keyboard key can show (R12, R13).
	function BuildFileState() {
		local files = {};
		if (m_bindings) {
			foreach (k in ND.psiMfdKeyboard) {
				local file = PsiMfdKeyState(k.n, m_bindings, {}).contentFile;
				if (file)
					files[file.tolower()] <- file;
			}
		}
		local state = {};
		foreach (lower, file in files)
			state[lower] <- PsiMfdMacroFileState(file);
		return state;
	}

	function ToggleKeyboard(unused) {
		if (m_keyboardShown) {
			ShowKeyboard(false);
			return;
		}
		if (m_tableHeight < PSI_MFD_HEADER + 6 * 14) {
			SetEditLabel("Window too small for the keyboard");
			return;
		}
		m_bindings = PsiMfdBindings();
		m_keyboard.SetData(m_bindings, BuildFileState());
		ShowKeyboard(true);
	}

	// R17: select a key picked on the keyboard, adding a free or game key to the selector's list once.
	function PickKey(name, keyState) {
		local index = null;
		foreach (i, entry in m_keys) {
			if (entry.key == name)
				index = i;
		}
		if (index == null) {
			m_keys.push({ key = name, file = keyState.file, state = keyState.state });
			index = m_keys.len() - 1;
		}
		m_keyIndex = index;
		ShowKeyboard(false);
		LoadMacro();
	}
```

- [ ] **Step 5: Change existing panel methods:**
  - `Refresh`: after loading keys, call `ShowKeyboard(false);` (R4), and replace `SetStatus("No macro keys bound: see the readme");` with `SetEditLabel("No macro keys bound: click Keys to pick one");` (R18).
  - `LoadMacro`: key the cache by file (R17) and reset the label:

```squirrel
	function LoadMacro() {
		m_macro = null;
		SetEditLabel(PSI_MFD_EDIT_HINT);
		if (m_keys.len()) {
			local key = m_keys[m_keyIndex];
			local id = key.file.tolower();
			if (id in m_macros) {
				m_macro = m_macros[id];
				SetStatus(m_macro.dirty ? "Not saved yet" : "");
			}
			else {
				m_macro = PsiMfdMacro(key.key, key.file);
				m_macros[id] <- m_macro;
				SetStatus(m_macro.Load() ? "Loaded" : "New macro");
			}
		}
		RebuildSteps();
	}
```

  (Refresh calls `LoadMacro` before `ShowKeyboard`/`SetEditLabel` for R18, so put the R18 line after `LoadMacro()`.)
  - `Scroll(delta)`: first line `if (m_keyboardShown && delta != 0) return;` (R3).
  - `ScrollToTier(tier)`: first line `ShowKeyboard(false);` (R3).
  - `Save`:

```squirrel
	function Save(unused) {
		if (!Editable())
			return;
		local problem = m_macro.Save();
		if (problem) {
			SetStatus(problem);
			return;
		}
		local entry = m_keys[m_keyIndex];
		local name = PsiMfdKeyName(entry.key);
		SetStatus("Saved for " + name);
		local state = "state" in entry ? entry.state : "macro";
		if (state == "free")
			SetEditLabel(name + " isn't bound yet: quit and run setupPsiMfd.bat.");
		else if (state == "game")
			SetEditLabel(name + " is a game key: clear it in Options > Controls, quit, run setupPsiMfd.bat.");
	}
```

- [ ] **Step 6: Build, install, and hand to the user**

Run (game closed): `py -m pytest dev/tests -q` (Task 1's tests still pass), then `py build.py --install`.
Then the user tests in game: open the MFD, click Keys and a key-name box (not the arrows), hover keys, pick a free key and a game key (e.g. T), save on each, reopen Keys, Tab, `condump`. Read `condump.txt` (game folder) and `kexengine.log` (Saved Games, load-time errors) for `[psi_mfd] error` or Squirrel errors. Fix and repeat until the user is happy with the prototype.

- [ ] **Step 7: Commit**

```bash
git add mod/sq_scripts/psi_mfd_keyboard.nut mod/sq_scripts/psi_mfd_ui.nut
git commit -m "Keyboard view: draw, hover, pick, and save texts (prototype)"
```

---

### Task 3: Release checks, in-game test plan and notes

**Files:**
- Modify: `dev/tests/test_release.py:72` (kpf member list), `:116` (brackets parametrize), `:124-128` (entry points)
- Modify: `dev/tests/test_keyboard.py` (function length, R26, text lengths)
- Create: `dev/tests/fixtures/keyboard_user.bnd`, `dev/tests/fixtures/keyboard_nomacro_user.bnd`, `dev/tests/fixtures/keyboard_macros/` (macro files)
- Modify: `dev/tests/TEST_PLAN.md` (new "Keyboard" section K1–K17 from the spec), `DEVELOPMENT.md` (prototype results)

**Interfaces:**
- Consumes: Tasks 1–2.

- [ ] **Step 1: Extend the release tests** — in `test_release.py`:
  - line 72: add `"sq_scripts/psi_mfd_keyboard.nut"` to the sorted kpf list.
  - line 116: add `"psi_mfd_keyboard.nut"` to the parametrize list.
  - `test_ui_entry_points_catch_errors`: also assert `'PsiMfdFail("key box click"'` in `psi_mfd_ui.nut` and `'PsiMfdFail("keyboard click"'`, `'PsiMfdFail("keyboard hover"'`, `'PsiMfdFail("keyboard draw"'` in `psi_mfd_keyboard.nut`.

- [ ] **Step 2: Add to `test_keyboard.py`:**

```python
def function_lengths(code):
    """Yields (name, lines) for every Squirrel function, by brace counting."""
    lines = code.split("\n")
    for i, line in enumerate(lines):
        m = re.match(r"\s*function (\w+)\(", line)
        if not m:
            continue
        depth, started = 0, False
        for j in range(i, len(lines)):
            depth += lines[j].count("{") - lines[j].count("}")
            started = started or "{" in lines[j]
            if started and depth == 0:
                yield m.group(1), j - i + 1
                break


def test_no_function_over_300_lines():
    """WHY: R25: long functions are where the UI bugs hide."""
    for path in SCRIPTS.glob("*.nut"):
        for name, length in function_lengths(path.read_text(encoding="utf-8")):
            assert length <= 300, f"{path.name}: {name} is {length} lines"


def test_keyboard_built_in_the_panel_constructor():
    """WHY: R26: widgets made outside the draw step make the engine warn and measure text wrongly."""
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    assert ui.count("PsiMfdKeyboard(") == 1
    constructor = ui[ui.index("class PsiMfdPanel"):ui.index("function DrawAt", ui.index("class PsiMfdPanel"))]
    assert "PsiMfdKeyboard(" in constructor


def test_texts_fit_in_90_characters():
    """WHY: R16/R19: the info and label lines hold about 90 characters at the narrowest panel."""
    legend = re.search(r'"(Bright: macro[^"]*)"', KB).group(1)
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    game = re.search(r'name \+ "( is a game key[^"]*)"', ui).group(1)
    assert len(legend) <= 90
    assert len("Keypad Del" + game) <= 90
```

Run: `py -m pytest dev/tests -q`, rebuild the zip first with `py build.py --package` so the zip test sees the new file. Expected: all pass.

- [ ] **Step 3: Fixtures** — `dev/tests/fixtures/keyboard_user.bnd`: copy `base.kpf`'s `defaults/shock.bnd` binds (movement, Tab `toggle_mouse`, etc.), then add one key per state and mark, matching the twin's `FIXTURE` keys plus `bind keypad_star "summon_obj PsiMfd"`, `bind keypad_plus "run psi\actions\Cancel_Macro.cmd"`, two keys on one file (`bind f1 "run user:/psi_macros\shared.cmd"`, `bind f2 "run user:/psi_macros\shared.cmd"`). `keyboard_macros/`: `macrog.cmd` (a one-cast macro), `Macro_t.cmd` (one cast: the `!` case), `Macro_x.cmd` (a file with only `summon_obj PsiChain`: the `?` case), `shared.cmd`. `keyboard_nomacro_user.bnd`: the same without any `psi_macros` lines. Write all with the Write tool (backslashes).

- [ ] **Step 4: TEST_PLAN.md** — add the "Keyboard" section from the spec's Testing part (setup steps 1–4 and rows K1–K9, K11–K17) verbatim.

- [ ] **Step 5: DEVELOPMENT.md** — under "MFD test results", record the prototype's in-game results (date, what was checked, any deviations such as the double-outline fill), and anything learned about the UI library (e.g. whether a parent and child both get a click).

- [ ] **Step 6: Commit**

```bash
git add dev/tests mod/sq_scripts DEVELOPMENT.md
git commit -m "Keyboard: release checks, fixtures, in-game test plan"
```
