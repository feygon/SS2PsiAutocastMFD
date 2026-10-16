"""
Test Suite: psi_autocast_mfd release (offline)

WHY THESE TESTS MATTER:
- Squirrel can't be run outside the game, and a single compile error in one .nut file stops that whole file
  loading (this happened with a local named "base"). Static checks catch the mistakes we've already made.
- The MFD reads the game's own data and art by name: an archetype or bitmap name that doesn't exist shows "?"
  or a blank, silently.
- It writes macros that psi_autocast runs: every step it can write must be one psi_autocast understands.
- setupPsiMfd.bat edits the player's user.bnd: it must never overwrite a binding the player made, and never
  pick keys the user ruled out (Enter, modifiers, punctuation, the wheel, keypad + for anything but cancel).

COVERAGE GOALS:
- Release zip: contents, no dev code, version.
- Static Squirrel checks: keywords as names, file() shadowing, bracket balance, dev output.
- Game data: archetype names, icons and bitmaps exist; cost tables match the gamesys and the wiki.
- Cross-mod: weapon switches and chain steps exist in psi_autocast.
- setupPsiMfd.bat on fixture user.bnd files.

Game behaviour (drawing, clicks, saving, the wheel, closing) can only be checked in game: see dev/tests/TEST_PLAN.md.
Run:  py -m pytest dev/tests -v
"""
import io
import json
import re
import struct
import subprocess
import zipfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SCRIPTS = REPO / "mod" / "sq_scripts"
MAIN = REPO.parent / "SS2PsiAutocast"           # psi_autocast's repo, for cross-mod checks
GAME = Path(r"D:\EpicLibrary\SystemShock225thAnniT5DFq")

needs_game = pytest.mark.skipif(not GAME.exists(), reason="game install not found")
needs_main = pytest.mark.skipif(not MAIN.exists(), reason="psi_autocast repo not found")


def nut(name):
    return (SCRIPTS / name).read_text(encoding="utf-8")


def all_nut():
    return {p.name: p.read_text(encoding="utf-8") for p in sorted(SCRIPTS.glob("*.nut"))}


def strip_strings_and_comments(code):
    code = re.sub(r"//[^\n]*", "", code)
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
    code = re.sub(r'"(?:\\.|[^"\\])*"', '""', code)
    return re.sub(r"'(?:\\.|[^'\\])'", "''", code)


# ---- release ------------------------------------------------------------------------------------------

def release_zip():
    version = json.loads((REPO / "mod/modinfo.json").read_text())["version"]
    path = REPO / "dist" / f"psi_autocast_mfd_v{version}.zip"
    if not path.exists():
        pytest.skip(f"{path.name} not built (py build.py --package)")
    return zipfile.ZipFile(path)


def test_release_zip_contents():
    """WHY: Players extract the zip into the game folder; it must hold the mod and docs only, no executables or dev tools."""
    z = release_zip()
    assert sorted(z.namelist()) == ["mods/psi_autocast_mfd.kpf", "psi/psi_autocast_mfd_LICENSE", "psi/psi_autocast_mfd_README.md"]
    kpf = zipfile.ZipFile(io.BytesIO(z.read("mods/psi_autocast_mfd.kpf")))
    assert sorted(kpf.namelist()) == ["modinfo.json", "sq_scripts/psi_mfd_data.nut", "sq_scripts/psi_mfd_macros.nut", "sq_scripts/psi_mfd_ui.nut"]


def test_release_kpf_has_no_dev_output():
    """WHY: The dev probe and the overlay-number printout must never reach players."""
    kpf = zipfile.ZipFile(io.BytesIO(release_zip().read("mods/psi_autocast_mfd.kpf")))
    for name in kpf.namelist():
        text = kpf.read(name).decode("utf-8")
        assert "PsiProbe" not in text and "Dev: overlay numbers" not in text, name


def test_modinfo_requires_psi_autocast():
    """WHY: The MFD only writes macros; psi_autocast runs them. The mod list should say so."""
    info = json.loads((REPO / "mod/modinfo.json").read_text())
    assert info["requirements"] == ["psi_autocast"]
    assert info["title"] == "psi_autocast_mfd"


# ---- static Squirrel checks ---------------------------------------------------------------------------

KEYWORDS = {"base", "break", "case", "catch", "class", "clone", "constructor", "continue", "const", "default",
            "delete", "else", "enum", "extends", "for", "foreach", "function", "if", "in", "instanceof", "local",
            "null", "resume", "return", "static", "switch", "this", "throw", "try", "typeof", "while", "yield"}


def test_no_keyword_used_as_a_name():
    """WHY: "local base = ..." failed the whole data file at load ("expected 'IDENTIFIER'"), blanking the MFD."""
    for name, code in all_nut().items():
        bare = strip_strings_and_comments(code)
        for m in re.finditer(r"\b(?:local|const)\s+([A-Za-z_]\w*)", bare):
            assert m.group(1) not in KEYWORDS, f"{name}: {m.group(0)}"
        for m in re.finditer(r"\bfunction\s+\w+\s*\(([^)]*)\)", bare):
            for param in m.group(1).split(","):
                param = param.split("=")[0].strip()
                assert param not in KEYWORDS, f"{name}: parameter {param}"


def test_io_calls_are_global():
    """WHY: Global calls run with the caller's "this"; a member named "file" shadowed file() and saving failed."""
    for name, code in all_nut().items():
        bare = strip_strings_and_comments(code)
        assert not re.search(r"(?<![:\w.])file\s*\(", bare), f"{name}: call ::file(...), not file(...)"


@pytest.mark.parametrize("name", ["psi_mfd_data.nut", "psi_mfd_macros.nut", "psi_mfd_ui.nut"])
def test_brackets_balance(name):
    """WHY: An unbalanced bracket is a compile error that only shows in kexengine.log."""
    bare = strip_strings_and_comments(nut(name))
    for open_, close in ["()", "[]", "{}"]:
        assert bare.count(open_) == bare.count(close), f"{name}: {open_}{close} unbalanced"


def test_ui_entry_points_catch_errors():
    """WHY: An exception inside the remaster's UI loop replays the click every frame and stops every script UI."""
    ui = nut("psi_mfd_ui.nut")
    for where in ['PsiMfdFail("frame update"', 'PsiMfdFail("drawing"', 'PsiMfdFail("row click"', "PsiMfdFail(\"button '"]:
        assert where in ui, where


def test_mfd_defines_every_psi_function_it_calls():
    """
    WHY: Calling psi_autocast's helpers (PsiSplitList and others) made the MFD fail, and close, whenever
    psi_autocast wasn't loaded. The MFD should open on its own and say what's missing.
    """
    code = "\n".join(strip_strings_and_comments(c) for c in all_nut().values())
    defined = set(re.findall(r"\b(?:function|class)\s+(Psi\w+)", code))
    called = set(re.findall(r"(?<![\w.:])(Psi[A-Z]\w*)\s*\(", code))
    assert called - defined == set()


def test_files_are_read_in_binary_mode():
    """WHY: readn on a text-mode file trips a KEX assert (wrap_fileio.cpp) and stops the game."""
    macros = nut("psi_mfd_macros.nut")
    assert '::file(path, "rb")' in macros
    assert not re.search(r'::file\([^)]*"r"\)', macros)


# ---- game data ----------------------------------------------------------------------------------------

def gam_chunks(kpf, member):
    data = zipfile.ZipFile(kpf).read(member)
    toc = struct.unpack_from("<I", data, 0)[0]
    table = {}
    for i in range(struct.unpack_from("<I", data, toc)[0]):
        name, off, size = struct.unpack_from("<12sII", data, toc + 4 + i * 20)
        table[name.split(b"\0")[0].decode("latin-1")] = (off, size)
    return data, table


def gam_records(data, table, chunk):
    off, size = table[chunk]
    pos, out = off + 24, []
    while pos + 8 <= off + size:
        obj, length = struct.unpack_from("<iI", data, pos)
        out.append((obj, data[pos + 8:pos + 8 + length]))
        pos += 8 + length
    return out


def gamesys_files():
    return [(GAME / "mods/scp.kpf", "shockscp.gam"), (GAME / "sshock2.kpf", "data/shock2.gam")]


def mfd_powers():
    return {int(i): name for i, name in re.findall(r'\[(\d+)\] = "([^"]+)"', nut("psi_mfd_data.nut").split("ND.psiMfdPowers <- {")[1].split("};")[0])}


@needs_game
@pytest.mark.parametrize("kpf,member", gamesys_files())
def test_power_archetypes_exist(kpf, member):
    """
    WHY: Each row's numbers come from Object.Named(<internal name>). A wrong name shows "?" for that row.
    Checked against both gamesys files, SCP and base, so it works with SCP off too.
    """
    data, table = gam_chunks(kpf, member)
    names = {}
    for obj, value in gam_records(data, table, "P$SymName"):
        n = struct.unpack_from("<I", value, 0)[0]
        names[value[4:4 + n].split(b"\0")[0].decode("latin-1")] = obj
    power_of = {obj: struct.unpack_from("<i", value, 0)[0] for obj, value in gam_records(data, table, "P$PsiPower")}
    for power, name in mfd_powers().items():
        assert name in names, f"{member}: no archetype {name!r}"
        assert power_of.get(names[name]) == power, f"{member}: {name!r} is discipline {power_of.get(names[name])}, not {power}"


@needs_game
@pytest.mark.parametrize("kpf,member", gamesys_files())
def test_cost_tables_match_the_gamesys(kpf, member):
    """WHY: Scripts can't read PSICOST or DIFFPARAM, so the MFD carries copies; they must match the game's."""
    data, table = gam_chunks(kpf, member)
    off, size = table["PSICOST"]
    costs = list(struct.unpack_from("<34i", data, off + 24))
    off, size = table["DIFFPARAM"]
    multipliers = list(struct.unpack_from("<6f", data, off + 24))
    code = nut("psi_mfd_data.nut")
    mine = [int(x) for x in re.search(r"ND\.psiMfdCosts <- \[([^\]]+)\]", code).group(1).replace("\n", "").split(",")]
    assert mine == costs
    scaled = [int(x) for x in re.search(r"ND\.psiMfdCostMultipliers <- \[([^\]]+)\]", code).group(1).split(",")]
    for want, got in zip(multipliers, scaled):
        assert got == int(struct.unpack("<f", struct.pack("<f", want))[0] * 1000000), (want, got)


def test_costs_match_the_wiki_table():
    """
    WHY: The game rounds base x multiplier down in single precision (Hard 5 x 1.4 = 6). The wiki's table
    (https://shodan.fandom.com/wiki/Psionic_Disciplines) is the independent check, all 20 cells.
    """
    code = nut("psi_mfd_data.nut")
    scaled = [int(x) for x in re.search(r"ND\.psiMfdCostMultipliers <- \[([^\]]+)\]", code).group(1).split(",")]
    wiki = {1: [2, 4, 6, 10, 17], 2: [3, 5, 8, 12, 20], 3: [4, 6, 11, 16, 27], 4: [5, 8, 14, 21, 35]}
    for difficulty, row in wiki.items():
        assert [base * scaled[difficulty] // 1000000 for base in (3, 5, 8, 12, 20)] == row, difficulty


@needs_game
def test_bitmaps_exist_in_the_remaster_art():
    """WHY: The MFD draws the remaster's own art by name; a missing name draws nothing."""
    art = {n[len("iface/"):-len(".png")].lower() for n in zipfile.ZipFile(GAME / "mods/sshock2ee.kpf").namelist()
           if n.startswith("iface/") and n.endswith(".png")}
    code = nut("psi_mfd_ui.nut")
    used = set(re.findall(r'(?:GetBitmap|SetBackground)\("([^"]+)"\)', code))
    assert used, "no bitmap names found"
    for name in used:
        assert name.lower() in art, name
    helpstr = zipfile.ZipFile(GAME / "sshock2.kpf").read("data/res/strings/psihelp.str").decode("latin-1")
    for power in mfd_powers():
        icon = re.search(rf'^PsiIcon{power}:"([^"]+)"', helpstr, re.M).group(1)
        assert (icon + "q").lower() in art, f"discipline {power}: {icon}Q"


# ---- cross-mod ----------------------------------------------------------------------------------------

@needs_main
def test_finish_weapons_exist_in_psi_autocast():
    """WHY: A "weapon:<Name>" step runs psi\\actions\\Switch_To_<Name>.cmd from psi_autocast; a missing file does nothing."""
    finishes = re.findall(r'"weapon:([A-Za-z_]+)"', nut("psi_mfd_macros.nut"))
    assert finishes
    for name in finishes:
        assert (MAIN / "psi" / "actions" / f"Switch_To_{name}.cmd").exists(), name


@needs_main
def test_chain_steps_are_ones_psi_autocast_understands():
    """WHY: Every step the MFD writes (arm, <id>o, <id>q, w<ms>, hypo, last, weapon:) must be parsed by PsiChain."""
    chain = (MAIN / "mod" / "sq_scripts" / "psi_autocast.nut").read_text(encoding="utf-8")
    for token in ['"arm"', '"hypo"', '"last"', '"weapon:', '== "w"', '"o"', '"q"']:
        assert token in chain, token


@needs_main
def test_disciplines_match_psi_autocast():
    """WHY: The MFD's discipline numbers must be psi_autocast's; a mismatch casts the wrong discipline."""
    data = (MAIN / "mod" / "sq_scripts" / "psi_autocast_disciplines.nut").read_text()
    ids = {int(i) for i in re.findall(r"ND\.psiDisciplines\[(\d+)\]", data)}
    assert ids == set(mfd_powers())


# ---- setupPsiMfd.bat ----------------------------------------------------------------------------------

BAT = REPO / "extras" / "setupPsiMfd.bat"
NEVER = ["enter", "keypad_enter", "esc", "tab", "space", "bs", "backspace", "`", "-", "=", "[", "]", "\\", ";", "'",
         ",", ".", "/", "mouse_wheel_up", "mouse_wheel_down"]


def run_bat(folder):
    """Runs the script against a fixture folder, passed as its argument so it never looks at the real one."""
    return subprocess.run(["cmd", "/c", str(BAT), str(folder)], input="\n", capture_output=True, text=True).stdout


def lines(folder):
    return (folder / "user.bnd").read_text().splitlines()


def added(before, after):
    return [l for l in after if l not in before]


def test_bat_has_windows_line_endings():
    """WHY: cmd can misread goto labels in a batch file with LF-only line endings."""
    data = BAT.read_bytes()
    assert b"\r\n" in data and b"\n" not in data.replace(b"\r\n", b"")


def test_bat_fresh_file(tmp_path):
    """WHY: On a user.bnd with only G and J bound, it binds the open key, cancel and every other plain key."""
    before = ['bind g "x"', 'bind j "y"']
    (tmp_path / "user.bnd").write_bytes(("\r\n".join(before) + "\r\n").encode())
    out = run_bat(tmp_path)
    new = added(before, lines(tmp_path))
    assert 'bind keypad_star "summon_obj PsiMfd"' in new
    assert 'bind keypad_plus "run psi\\actions\\Cancel_Macro.cmd"' in new
    macro_keys = [l.split()[1] for l in new if "psi_macros" in l]
    assert macro_keys[:3] == ["a", "b", "c"], "letters come first"
    assert "g" not in macro_keys and "j" not in macro_keys
    assert len(macro_keys) == 24 + 10 + 12 + 5 + 6
    assert (tmp_path / "user.bnd.before_mfd_1").exists()
    assert "Done." in out


def test_bat_never_uses_ruled_out_keys(tmp_path):
    """WHY: Enter, modifiers, punctuation and the wheel were ruled out; keypad + is only ever cancel."""
    (tmp_path / "user.bnd").write_bytes(("; empty\r\n").encode())
    run_bat(tmp_path)
    keys = [l.split()[1] for l in lines(tmp_path) if l.startswith("bind ") or l.startswith("game2 ")]
    assert not [k for k in keys if k in NEVER or "+" in k.replace("keypad_plus", "")]
    assert not [l for l in lines(tmp_path) if "wheel" in l.lower()]
    assert [l for l in lines(tmp_path) if "keypad_plus" in l] == ['bind keypad_plus "run psi\\actions\\Cancel_Macro.cmd"']


def test_bat_leaves_existing_bindings_alone(tmp_path):
    """WHY: Overwriting a player's own binding would break their setup without asking."""
    before = ['bind keypad_star +zoom', 'bind keypad_plus "my thing"', 'bind keypad_minus "mine"', 'game2 bind mouse_wheel_up "x"']
    (tmp_path / "user.bnd").write_bytes(("\r\n".join(before) + "\r\n").encode())
    run_bat(tmp_path)
    after = lines(tmp_path)
    for line in before:
        assert line in after
    assert not [l for l in added(before, after) if l.split()[1] in ("keypad_star", "keypad_plus", "keypad_minus")]
    assert [l for l in added(before, after) if "summon_obj PsiMfd" in l], "an open key on another free key"


def test_bat_rerun_adds_nothing(tmp_path):
    """WHY: Running it twice must not duplicate lines or stack backups."""
    (tmp_path / "user.bnd").write_bytes(("; empty\r\n").encode())
    run_bat(tmp_path)
    before = (tmp_path / "user.bnd").read_bytes()
    assert "Nothing to add" in run_bat(tmp_path)
    assert (tmp_path / "user.bnd").read_bytes() == before
    assert not (tmp_path / "user.bnd.before_mfd_2").exists()


def test_bat_open_key_check_ignores_wheel_lines(tmp_path):
    """WHY: The wheel lines also mention PsiMfd; they mustn't be mistaken for an open key."""
    (tmp_path / "user.bnd").write_bytes(('game2 bind mouse_wheel_up "summon_obj PsiMfdWheelUp"\r\n').encode())
    run_bat(tmp_path)
    assert 'bind keypad_star "summon_obj PsiMfd"' in lines(tmp_path)


def test_bat_handles_missing_final_newline(tmp_path):
    """WHY: If the last line has no newline, a naive append glues the new binding onto it."""
    (tmp_path / "user.bnd").write_bytes(('bind k "keep"').encode())
    run_bat(tmp_path)
    assert 'bind k "keep"' in lines(tmp_path)
