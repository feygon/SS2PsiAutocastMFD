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
    "ins", "del", "home", "end", "pgup", "pgdn", "keypad_minus", "keypad_del", "keypad_ins", "keypad_center", "keypad_slash",
    # also in the author's game-rewritten user.bnd, as the game's own default bindings:
    "keypad_home", "keypad_up", "keypad_pgup", "keypad_left", "keypad_right", "keypad_end", "keypad_down", "keypad_pgdn", "up", "down", "left", "right"}


def squirrel_string(s):
    return s.replace("\\\\", "\\").replace('\\"', '"')


def key_table():
    rows = re.findall(r'PsiMfdK\("((?:\\.|[^"\\])*)", "((?:\\.|[^"\\])*)", ([\d.]+), (\d+)(?:, ([\d.]+))?(?:, (\d+))?\)', KB)
    return [dict(n=squirrel_string(n), l=squirrel_string(l), c=float(c), r=int(r), w=float(w or 1), h=int(h or 1))
            for n, l, c, r, w, h in rows]


def nut_list(name):
    found = re.search(r"ND\." + name + r" <- \[(.*?)\];", KB, re.S)
    assert found, f"ND.{name} not found in psi_mfd_keyboard.nut"
    return [squirrel_string(s) for s in re.findall(r'"((?:\\.|[^"\\])*)"', found.group(1))]


def file_words():
    found = re.search(r"ND\.psiMfdFileWords <- \{(.*?)\};", KB, re.S)
    assert found, "ND.psiMfdFileWords not found"
    return {squirrel_string(k): w for k, w in re.findall(r'\["((?:\\.|[^"\\])*)"\] = "(\w+)"', found.group(1))}


def macro_name(name):
    return "Macro_" + file_words().get(name, name) + ".cmd"


def bat_candidates():
    """The script's list with its punctuation words turned back into key names."""
    words = {w: k for k, w in file_words().items()}
    return [words.get(c, c) for c in re.search(r'set "MACRO_CANDIDATES=([^"]*)"', BAT.read_text()).group(1).split()]


# ---- the Python twin of R10-R14 -------------------------------------------------------------------------

MACROS = (SCRIPTS / "psi_mfd_macros.nut").read_text(encoding="utf-8")
# The twin builds its prefix the way the .nut does, from the .nut's own constant, so a mismatch fails here.
RUN_PREFIX = squirrel_string(re.search(r'const PSI_MFD_RUN_PREFIX = "((?:\\.|[^"\\])*)"', MACROS).group(1))
PREFIX = ("run " if '"run " + PSI_MFD_RUN_PREFIX' in MACROS else "") + RUN_PREFIX


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
    elif lower.startswith("summon_obj psimfdwheel") or "cancel_macro" in lower:
        s["state"] = "mod"
    elif candidate:
        s.update(state="game" if bind else "free", selectable=True, file=macro_name(name))
    else:
        s["state"] = "notoffered"
    if s["state"] == "macro":
        s["contentFile"] = s["file"]
    elif candidate:
        s["contentFile"] = macro_name(name)
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
    assert len(key_table()) == 98  # R7: 71 main, 10 navigation, 17 keypad


def test_candidates_match_the_setup_script():
    """WHY: A macro on a key the script never binds could never run (R11)."""
    assert nut_list("psiMfdCandidates") == bat_candidates()
    assert not set(nut_list("psiMfdNever")) & set(nut_list("psiMfdCandidates"))


# Punctuation bound by setupPsiMfd.bat and kept by the game when it rewrote user.bnd (2026-10-16, 19:06); macros on
# ; and / ran to "chain: done". Proven, like the rest.
PENDING_PROOF = set()


def test_selectable_names_are_proven():
    """WHY: A candidate name the game doesn't accept would make a key that never fires."""
    assert set(nut_list("psiMfdCandidates")) <= GAME_REWRITTEN | {"'", "[", "\\"} | PENDING_PROOF


@pytest.mark.skipif(not GAME.exists(), reason="game install not found")
def test_other_names_are_game_names():
    """WHY: Non-candidate keys are only looked up, but a misspelt name would never match user.bnd."""
    shock = zipfile.ZipFile(GAME / "base.kpf").read("defaults/shock.bnd").decode("latin-1")
    shock_keys = {l.split()[1].lower() for l in shock.splitlines() if l.startswith("bind ")}
    exe = (GAME / "SystemShock2Remastered.exe").read_bytes()
    assert key_table()
    for k in key_table():
        if k["n"] in GAME_REWRITTEN or k["n"] in shock_keys:
            continue
        assert b"\0" + k["n"].encode() + b"\0" in exe, k["n"]


def test_keys_fit_and_never_overlap():
    """WHY: Overlapping keys would make the mouse pick the wrong one (R6, R7)."""
    keys = key_table()
    assert keys
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
    ("keypad_star", "mod", False), ("k", "game", True), ("g", "macro", True), ("up", "macro", True),
    ("o", "free", True), ("t", "game", True), ("v", "game", True), ("numlock", "notoffered", False), ("left", "free", True)])
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


def test_consts_come_from_the_same_or_an_earlier_file():
    """WHY: Squirrel resolves const names when a file compiles; a const from a file that compiles later is
    looked up at runtime, isn't found, and the error stops the MFD. Files are assumed to compile by name."""
    defined = {}
    for path in sorted(SCRIPTS.glob("*.nut")):
        code = re.sub(r"//[^\n]*", "", path.read_text(encoding="utf-8"))
        own = set(re.findall(r"^const (PSI_MFD_\w+)", code, re.M))
        visible = own | {c for c, f in defined.items()}
        for used in set(re.findall(r"\bPSI_MFD_\w+", code)):
            assert used in visible, f"{path.name} uses {used}, defined in a later file or nowhere"
        for c in own:
            defined[c] = path.name


def test_key_colours_stand_out_from_the_background():
    """WHY: The MFD background (TRAIT) measures about RGB 0.02/0.29/0.24 in game (luminance ~0.23); key outlines
    and labels darker than ~0.45 were reported as unreadable (2026-10-16)."""
    for name in ["psiMfdGrey", "psiMfdSlate", "psiMfdFaint"]:
        r, g, b_ = (float(v) for v in re.search(r"ND\." + name + r" <- \[([^\]]*)\]", KB).group(1).split(","))
        assert 0.2126 * r + 0.7152 * g + 0.0722 * b_ >= 0.45, name


NUMPAD_AND_ARROWS = ["keypad_home", "keypad_up", "keypad_pgup", "keypad_left", "keypad_right", "keypad_end",
                     "keypad_down", "keypad_pgdn", "up", "down", "left", "right"]


def test_keypad_numbers_and_arrows_are_offered():
    """WHY: User decision 2026-10-16: most players move with WASD + mouse, so keypad numbers and arrows are worth
    offering. They're default bindings, so they show as game keys until cleared in the Controls menu."""
    assert all(k in nut_list("psiMfdCandidates") for k in NUMPAD_AND_ARROWS)


PUNCTUATION = [",", ".", "/", ";", "'", "[", "]", "\\"]


def test_punctuation_keys_are_offered_with_file_safe_names():
    """WHY: User decision 2026-10-16: , . / ; ' [ ] \\ can hold macros. / and \\ can't be in a file name, so every
    punctuation key's macro file uses a word (Macro_comma.cmd), the same word the setup script uses."""
    for k in PUNCTUATION:
        assert k in nut_list("psiMfdCandidates") and k not in nut_list("psiMfdNever"), k
        assert re.fullmatch(r"Macro_[a-z]+\.cmd", macro_name(k)), k
    assert not {"`", "-", "="} & set(nut_list("psiMfdCandidates"))


def test_psi_autocast_keys_are_ordinary_game_keys(b):
    """WHY: User decision 2026-10-16: a key running a psi_autocast script isn't reserved; it's a game key."""
    s = key_state("k", b, {})
    assert (s["state"], s["selectable"], s["file"]) == ("game", True, "Macro_k.cmd")
