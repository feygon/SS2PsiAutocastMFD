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
    if "\\" in rest or "/" in rest or ".." in rest or not rest.endswith((".cmd", ".txt")):
        return None
    return rest


def also_on(name, b):
    return sorted(k for k, v in b.items() if k != name and v["lower"] == b[name]["lower"] and not k.startswith("joy"))


def nut_string(name):
    """A string ND slot from psi_mfd_keyboard.nut, so the twin never carries its own copy."""
    return re.search(r'ND\.' + name + r' <- "([^"]+)";', KB).group(1)


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
    elif lower.startswith("summon_obj psimfdwheel") or "cancel_macro" in lower or lower == nut_string("psiMfdMaintainCommand").lower():
        s["state"] = "mod"
    elif name == nut_string("psiMfdMaintainKey") and not bind:
        s["state"] = "reserved"
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
    if s["state"] in ("game", "mod") and s["content"] in ("has", "script"):
        s["marks"] += "!"
    elif s["content"] == "empty":
        s["marks"] += "?"
    return s


FIXTURE = "\r\n".join([
    'bind keypad_star "summon_obj psimfd"',
    'bind keypad_plus "run psi\\actions\\cancel_macro.txt"',
    'bind g "run user:/psi_macros\\macrog.cmd"',
    'bind up "run user:/psi_macros\\macro_up.cmd"',
    'bind enter "run user:/psi_macros\\macro_enter.cmd"',
    'bind l "run psi\\t2_localized_pyrokinesis.cmd"',
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
    assert set(nut_list("psiMfdCandidates")) <= GAME_REWRITTEN | {"'", "[", "\\", ",", ".", "/", ";", "]"} | PENDING_PROOF


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
    ("keypad_star", "mod", False), ("k", "reserved", False), ("l", "game", True), ("g", "macro", True), ("up", "macro", True),
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
    s = key_state("l", b, {})
    assert (s["state"], s["selectable"], s["file"]) == ("game", True, "Macro_l.cmd")


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
    start = ui.index("class PsiMfdPanel")
    constructor = ui[start:ui.index("function DrawAt", start)]
    assert "PsiMfdKeyboard(" in constructor


def test_texts_fit_in_90_characters():
    """WHY: R16/R19: the info and label lines hold about 90 characters at the narrowest panel."""
    legend = re.search(r'"(Bright: macro[^"]*)"', KB).group(1)
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    assert len(legend) <= 90
    longest = max((display_name(k) for k in nut_list("psiMfdCandidates")), key=len)
    # The save messages: "Saved. " + name + rest, built in PsiMfdPanel.Save.
    messages = ["Saved. " + longest + rest for rest in re.findall(r'"Saved\. " \+ name \+ "([^"]*)"', ui)]
    assert len(messages) == 2  # game key; key that works after the next start
    for message in messages:
        assert len(message) <= 90, message


def display_name(name):
    """The twin of PsiMfdKeyName: ND.psiMfdKeyNames, else the key upper-cased."""
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    body = re.search(r"ND\.psiMfdKeyNames <- \{(.*?)\};", ui, re.S).group(1)
    names = dict(re.findall(r'(\w+) = "([^"]*)"', body))
    return names.get(name, name.upper())


def test_every_candidate_has_a_readable_name():
    """WHY: The selector, hover line and save message show this name; KEYPAD_HOME tells a player nothing."""
    for k in nut_list("psiMfdCandidates"):
        assert "_" not in display_name(k) and len(display_name(k)) <= 10, (k, display_name(k))


def test_in_game_fixture_covers_every_state_and_mark():
    """WHY: The in-game keyboard test (TEST_PLAN K2-K4) relies on this fixture showing every state and mark;
    the Python twin can drift from the Squirrel code, so the game has to see each one too."""
    fixtures = Path(__file__).resolve().parent / "fixtures"
    b = bindings((fixtures / "keyboard_user.bnd").read_text(encoding="latin-1"))
    files = {}
    for p in (fixtures / "keyboard_macros").iterdir():
        text = p.read_text()
        files[p.name.lower()] = "has" if re.search(r"set psi_chain \S", text) else "empty"
    seen_states, seen_marks = set(), set()
    for k in key_table():
        s = key_state(k["n"], b, files)
        seen_states.add(s["state"] + ("+" if s["content"] == "has" and s["state"] in ("macro", "free") else ""))
        seen_marks |= set(s["marks"])
    assert {"macro+", "macro", "free+", "free", "game", "mod", "reserved", "never", "notoffered"} <= seen_states
    assert set("=!?") <= seen_marks


def rebind(text, key, command):
    """The twin of PsiMfdRebind: drop every plain binding of key, keep everything else, append the new line."""
    out = [line.strip() for line in text.split("\n") if line.strip() and not line.strip().lower().startswith("bind " + key + " ")]
    return "\r\n".join(out + ["bind " + key + " " + command]) + "\r\n"


def test_rebind_replaces_only_that_key():
    """WHY: The MFD writes user.bnd itself now (players never edit it by hand); it must change one key and
    keep every other line, including combos like f1+shift and game2 lines."""
    before = 'bind o wpn_setting_toggle\r\nbind o+alt foo\r\nbind ox bar\r\ngame2 bind o x\r\nbind O "old"\r\n'
    after = rebind(before, "o", '"run user:/psi_macros\\Macro_o.cmd"').split("\r\n")
    assert after[-2] == 'bind o "run user:/psi_macros\\Macro_o.cmd"'
    assert "bind o wpn_setting_toggle" not in after and 'bind O "old"' not in after
    assert "bind o+alt foo" in after and "bind ox bar" in after and "game2 bind o x" in after
    macros = (SCRIPTS / "psi_mfd_macros.nut").read_text(encoding="utf-8")
    for name in ["PsiMfdRebind", "PsiMfdBindKey"]:
        assert f"function {name}(" in macros, name


STARTER = {"g": "run psi\\t1_projected_cryokinesis.txt", "j": "run psi\\chains\\starter_localized_pyrokinesis.txt"}


def keys_to_bind(b, take_k=False):
    """The twin of PsiMfdKeysToBind: {key: command} the MFD binds on load (only keys with no binding, and the
    maintenance key when take_k: a macro key whose file has no macro yet)."""
    add = {}
    def free(k):
        return k not in b and k not in add
    if not any(not v["combo"] and v["lower"] == "summon_obj psimfd" for v in b.values()):
        for k in ["keypad_star", "keypad_slash"] + nut_list("psiMfdCandidates"):
            if free(k):
                add[k] = '"summon_obj PsiMfd"'
                break
    if free("keypad_plus"):
        add["keypad_plus"] = '"run psi\\actions\\cancel_macro.txt"'
    if take_k or free(nut_string("psiMfdMaintainKey")):
        add[nut_string("psiMfdMaintainKey")] = '"' + nut_string("psiMfdMaintainCommand") + '"'
    for k in ["g", "j"] + nut_list("psiMfdCandidates"):
        if free(k):
            add[k] = '"run user:/psi_macros\\' + macro_name(k) + '"'
    return add


def test_every_free_key_is_bound_on_load():
    """WHY: Binding a key only when a macro was saved on it cost one restart per key (user, 2026-10-19: "I'm having
    to restart too much"). On load the MFD binds every free key at once - open key if none, keypad + cancel, G and J
    with the starter casts, every other free candidate as a macro key - so after one restart any non-grey key takes
    a macro on the next keypress. Bound keys (game keys, combos, an existing open key) are never touched."""
    fresh = bindings('bind w +walkfast\r\nbind t wpn_setting_toggle\r\nbind c+alt toggle_compass\r\n')
    add = keys_to_bind(fresh)
    assert add["keypad_star"] == '"summon_obj PsiMfd"'
    assert add["keypad_plus"] == '"run psi\\actions\\cancel_macro.txt"'
    assert add["g"] == '"run user:/psi_macros\\Macro_g.cmd"' and add[","] == '"run user:/psi_macros\\Macro_comma.cmd"'
    assert "w" not in add and "t" not in add and "c" in add
    assert len(add) == 3 + len(nut_list("psiMfdCandidates")) - 2   # all candidates but w and t, plus open, cancel, K
    set_up = bindings('bind keypad_star "summon_obj PsiMfd"\r\nbind g "mine"\r\n')
    again = keys_to_bind(set_up)
    assert "keypad_slash" in again and again["keypad_slash"] != '"summon_obj PsiMfd"', "no second open key"
    assert "g" not in again
    next_load = dict(fresh)
    next_load.update(bindings("\r\n".join(f"bind {k} {v}" for k, v in add.items())))
    assert keys_to_bind(next_load) == {}, "nothing left on the next load"
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    for name in ["PsiMfdKeysToBind", "PsiMfdEnsureKeys"]:
        assert f"function {name}(" in ui, name
    assert 'PsiMfdFail("binding keys"' in ui
    macros = (SCRIPTS / "psi_mfd_macros.nut").read_text(encoding="utf-8")
    assert "function PsiMfdBindKeys(" in macros
    for key, line in STARTER.items():
        assert line.replace("\\", "\\\\") in ui, key


def test_k_is_the_maintenance_key():
    """WHY: K uses a maintenance tool on the weapon in hand by default, so it isn't a macro key (author's decision
    2026-10-21). It's bound on load when free, or when it's a macro key with no macro yet; a K holding a real macro,
    or set to anything else, is never touched (no keys taken from the player)."""
    assert nut_string("psiMfdMaintainKey") == "k" and nut_string("psiMfdMaintainCommand") == "summon_obj PsiMfdMaintainWeapon"
    assert "k" not in nut_list("psiMfdCandidates")
    maintain = '"summon_obj PsiMfdMaintainWeapon"'
    assert keys_to_bind(bindings('bind w +walkfast\r\n'))["k"] == maintain
    empty_macro = bindings('bind k "run user:/psi_macros\\macro_k.cmd"\r\n')
    assert keys_to_bind(empty_macro, take_k=True)["k"] == maintain
    assert "k" not in keys_to_bind(empty_macro), "a K macro key with a macro is left alone"
    assert "k" not in keys_to_bind(bindings('bind k +lean_left\r\n'))
    assert key_state("k", bindings('bind k "summon_obj PsiMfdMaintainWeapon"\r\n'), {})["state"] == "mod"
    assert key_state("k", bindings('bind w +walkfast\r\n'), {})["state"] == "reserved"
    assert key_state("k", empty_macro, {"macro_k.cmd": "has"})["state"] == "macro"
    assert "uses a maintenance tool on the weapon in hand" in KB and "reserved for the maintenance tool" in KB
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    assert re.search(r'PsiMfdMacroFileState\(\w+\) == "missing"', ui), "takes K over only when its file has no macro"


def file_state(text):
    """The twin of PsiMfdMacroFileState for a file's text: has / script / empty."""
    chain = re.search(r"^set psi_chain (\S+)", text, re.M)
    if chain and [tok for tok in chain.group(1).split(",") if tok != "arm" and not re.fullmatch(r"w\d+", tok)]:
        return "has"
    return "script" if re.search(r"^run psi\\", text, re.M | re.I) else "empty"


def test_a_file_running_a_psi_script_is_working_content(b):
    """WHY: The starter scripts bind G and J to Macro_g.cmd / Macro_j.cmd holding one line, run psi\\<script>.
    That key works; the MFD must show it as filled, not as an empty file (?), and a game key with such a file
    is a conflict (!) like one with a macro."""
    assert file_state("run psi\\t1_projected_cryokinesis.txt\n") == "script"
    assert file_state("set psi_chain arm,6o\nsummon_obj PsiChain\n") == "has"
    assert file_state("summon_obj PsiChain\n") == "empty"
    g = key_state("g", b, {"macrog.cmd": "script"})
    assert (g["state"], g["content"], g["marks"]) == ("macro", "script", "")
    t = key_state("t", b, {"macro_t.cmd": "script"})
    assert "!" in t["marks"]
    macros = (SCRIPTS / "psi_mfd_macros.nut").read_text(encoding="utf-8")
    assert '"script"' in macros and "script = " in macros
    for name in ["PsiMfdAddMarks", "PsiMfdKeyLook", "PsiMfdKeyHover"]:
        body = KB[KB.index(f"function {name}("):]
        assert '"script"' in body[:body.index("\n}\n")], name


def test_extend_is_never_used_for_its_value():
    """WHY: Squirrel's array.extend() changes the array and returns null; using its result ("foreach (k in
    a.extend(b))") failed the first run in game with "cannot iterate null" (2026-10-17)."""
    for path in SCRIPTS.glob("*.nut"):
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("//")[0]
            if ".extend(" in code:
                assert re.fullmatch(r"\s*[\w.]+\.extend\([^;]*\);\s*", code), f"{path.name}:{n}: {line.strip()}"


def function_body(code, name):
    start = code.index(f"function {name}(")
    return code[start:code.index("\n\t}\n", start)]


def test_script_note_goes_away_once_the_macro_changes():
    """WHY: In game (2026-10-17) "Runs psi\\T1_Projected_Cryokinesis.cmd: a macro saved here replaces it" stayed after
    a step was added and saved, though the key then ran the new macro. Editing resets the label; saving forgets the
    script the file used to run."""
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    assert "SetEditLabel(PSI_MFD_EDIT_HINT)" in function_body(ui, "Changed")
    assert 'm_macro.script = ""' in function_body(ui, "Save")


def test_macro_files_may_be_txt_or_cmd():
    """WHY: psi_autocast 1.4 uses .txt key files; a macro key bound to a .txt file in psi_macros must count as a
    macro key just like the MFD's own .cmd files."""
    assert macro_file("run user:/psi_macros\\macro_q.txt") == "macro_q.txt"
    assert macro_file("run user:/psi_macros\\macro_q.cmd") == "macro_q.cmd"
    macros = (SCRIPTS / "psi_mfd_macros.nut").read_text(encoding="utf-8")
    assert '(endswith(rest, ".cmd") || endswith(rest, ".txt"))' in macros


PLACEHOLDER = "set psi_mfd_no_macro_yet "


def test_placeholder_files_mean_no_macro_yet():
    """WHY: Every macro key gets a file (user, 2026-10-19). A key with no macro yet holds one harmless line,
    "set psi_mfd_no_macro_yet <key>", which shows in the console when pressed (echo prints nothing). The MFD must
    treat it as "no macro yet" - no ? mark, and the editor starts a new macro - not as a broken file."""
    macros = (SCRIPTS / "psi_mfd_macros.nut").read_text(encoding="utf-8")
    ui = (SCRIPTS / "psi_mfd_ui.nut").read_text(encoding="utf-8")
    assert f'"{PLACEHOLDER}"' in macros
    body = macros[macros.index("function PsiMfdMacroFileState("):]
    assert "placeholder" in body[:body.index("\n}\n")]
    assert "m_macro.placeholder" in ui and "PsiMfdPlaceholder(" in ui
    bat = BAT.read_bytes().decode("latin-1")
    assert "set psi_mfd_no_macro_yet" in bat
