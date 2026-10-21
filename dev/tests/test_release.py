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
    assert sorted(kpf.namelist()) == ["modinfo.json", "sq_scripts/psi_mfd_data.nut", "sq_scripts/psi_mfd_keyboard.nut",
                                     "sq_scripts/psi_mfd_macros.nut", "sq_scripts/psi_mfd_ui.nut"]


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


@pytest.mark.parametrize("name", ["psi_mfd_data.nut", "psi_mfd_keyboard.nut", "psi_mfd_macros.nut", "psi_mfd_ui.nut"])
def test_brackets_balance(name):
    """WHY: An unbalanced bracket is a compile error that only shows in kexengine.log."""
    bare = strip_strings_and_comments(nut(name))
    for open_, close in ["()", "[]", "{}"]:
        assert bare.count(open_) == bare.count(close), f"{name}: {open_}{close} unbalanced"


def test_ui_entry_points_catch_errors():
    """WHY: An exception inside the remaster's UI loop replays the click every frame and stops every script UI."""
    ui = nut("psi_mfd_ui.nut")
    for where in ['PsiMfdFail("frame update"', 'PsiMfdFail("drawing"', 'PsiMfdFail("row click"', "PsiMfdFail(\"button '",
                  'PsiMfdFail("key box click"']:
        assert where in ui, where
    keyboard = nut("psi_mfd_keyboard.nut")
    for where in ['PsiMfdFail("keyboard click"', 'PsiMfdFail("keyboard hover"', 'PsiMfdFail("keyboard draw"']:
        assert where in keyboard, where


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


DEV_SCRIPTS = REPO / "dev" / "sq_scripts"


def call_args(code, callee):
    """The top-level arguments of every call to callee ("Property.Set") in code with strings already stripped."""
    calls = []
    for m in re.finditer(re.escape(callee) + r"\s*\(", code):
        depth, start, args, i = 1, m.end(), [], m.end()
        while depth:
            if code[i] in "([{":
                depth += 1
            elif code[i] in ")]}":
                depth -= 1
            elif code[i] == "," and depth == 1:
                args.append(code[start:i].strip())
                start = i + 1
            i += 1
        args.append(code[start:i - 1].strip())
        calls.append(args)
    return calls


def test_property_set_always_names_a_field():
    """
    WHY: Property.Set takes (object, property, field, value). A property without named fields takes "" as its
    field, as the game's own scripts write it. Leaving the field out failed in game with "expected 3 parameters
    but got 4", and the dev respec tool changed nothing (2026-10-20).
    """
    for path in sorted(SCRIPTS.glob("*.nut")) + sorted(DEV_SCRIPTS.glob("*.nut")):
        for args in call_args(strip_strings_and_comments(path.read_text(encoding="utf-8")), "Property.Set"):
            assert len(args) == 4, f"{path.name}: Property.Set({', '.join(args)})"


def test_no_script_equips_the_weapon_slot():
    """
    WHY: ShockGame.Equip(0, weapon) brought out the pistol, but afterwards the amp couldn't be equipped at all
    until the save was reloaded (psi_autocast's DEVELOPMENT.md). Weapons switch with equip_weapon instead.
    """
    for path in sorted(SCRIPTS.glob("*.nut")) + sorted(DEV_SCRIPTS.glob("*.nut")):
        for args in call_args(strip_strings_and_comments(path.read_text(encoding="utf-8")), "ShockGame.Equip"):
            assert args[0] not in ("0", "kEquipWeapon"), f"{path.name}: ShockGame.Equip({', '.join(args)})"


def test_armor_tool_takes_off_the_old_armor_first():
    """
    WHY: Equipping straight over a held item is what left the amp stuck. The armor tool must empty the armor
    slot before it puts anything in it, and only ever touch the armor slot.
    """
    calls = call_args(strip_strings_and_comments((DEV_SCRIPTS / "psi_mfd_armor.nut").read_text(encoding="utf-8")),
                      "ShockGame.Equip")
    assert calls and calls[0] == ["PSI_MFD_ARMOR_SLOT", "null"]
    assert all(args[0] == "PSI_MFD_ARMOR_SLOT" for args in calls)


def test_armor_tool_puts_the_new_armor_on_before_adding_the_old_back():
    """
    WHY: With the armor slot empty, the old armor came back in the slot (Contains 1002) after AddInvObj
    (2026-10-21), so the swap stopped. With the new armor already in the slot, the old one has to go to a cell.
    """
    code = strip_strings_and_comments((DEV_SCRIPTS / "psi_mfd_armor.nut").read_text(encoding="utf-8"))
    wear_new = code.find("ShockGame.Equip(PSI_MFD_ARMOR_SLOT, armor)")
    add_old = code.find("ShockGame.AddInvObj(worn)")
    assert wear_new != -1 and add_old != -1 and wear_new < add_old


def test_remembered_armor_is_a_campaign_quest_variable():
    """
    WHY: The remembered armor has to survive saving, loading and changing decks between "remember" and
    "restore". Campaign quest variables are saved with the game and kept across levels (the game's achievement
    code keeps its counters that way).
    """
    code = strip_strings_and_comments((DEV_SCRIPTS / "psi_mfd_armor.nut").read_text(encoding="utf-8"))
    calls = [args for args in call_args(code, "Quest.Set") if args[0] == "PSI_MFD_SAVED_ARMOR"]
    assert len(calls) >= 2
    assert all(len(args) == 3 and args[2] == "eQuestDataType.kQuestDataCampaign" for args in calls)


@needs_main
def test_dev_armor_tool_defines_the_hooks_psi_autocast_calls():
    """WHY: psi_autocast calls its macro hooks by name; a misspelt name here would silently never run."""
    called = set(re.findall(r'PsiMacroHook\("(\w+)", self\)', (MAIN / "mod/sq_scripts/psi_autocast.nut").read_text(encoding="utf-8")))
    assert called == {"PsiMacroStarted", "PsiMacroEnded"}
    armor = (DEV_SCRIPTS / "psi_mfd_armor.nut").read_text(encoding="utf-8")
    for name in called:
        assert re.search(r"^function " + name + r"\(\w+\) \{", armor, re.M), name


def test_armor_goes_back_after_a_delay_not_at_the_release():
    """
    WHY: Debug.Command only queues console commands, so when a cast's end hook runs, its "fire_weapon 0" hasn't
    happened yet: swapping armor at that moment would take the worm skin off before the power goes off.
    """
    armor = strip_strings_and_comments((DEV_SCRIPTS / "psi_mfd_armor.nut").read_text(encoding="utf-8"))
    ended = armor.split("function PsiMacroEnded(")[1].split("\nfunction ")[0]
    assert "Object.Create(" in ended
    assert "ShockGame.Equip" not in ended and "PsiMfdSwapArmor(" not in ended
    assert re.search(r'class PsiMfdArmorBack extends SqRootScript \{\s*function OnBeginScript\(\) \{\s*SetOneShotTimer\("", 0\.5\);', armor)


def test_restoring_consumes_the_memory_only_once_that_armor_is_on():
    """WHY: If the remembered armor isn't in the inventory, the memory stays, to restore after picking it up."""
    code = strip_strings_and_comments((DEV_SCRIPTS / "psi_mfd_armor.nut").read_text(encoding="utf-8"))
    restore = code.split("class PsiMfdRestoreArmor")[1].split("\nclass ")[0]
    assert re.search(r"if \(PsiMfdWearArmorNumber\(\w+\)\)\s*Quest\.Set\(PSI_MFD_SAVED_ARMOR, 0,", restore)


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
def test_dev_bullet_boxes_exist(kpf, member):
    """WHY: The dev bullet tool creates its boxes by archetype name; a wrong name gives nothing."""
    data, table = gam_chunks(kpf, member)
    names = set()
    for obj, value in gam_records(data, table, "P$SymName"):
        n = struct.unpack_from("<I", value, 0)[0]
        names.add(value[4:4 + n].split(b"\0")[0].decode("latin-1"))
    boxes = re.findall(r'\["([^"]+)", "[^"]+"\]', (DEV_SCRIPTS / "psi_mfd_bullets.nut").read_text(encoding="utf-8"))
    assert boxes == ["AP Clip", "HE Clip"]
    for box in boxes:
        assert box in names, f"{member}: no archetype {box!r}"


@needs_game
@pytest.mark.parametrize("kpf,member", gamesys_files())
def test_dev_armor_archetypes_exist(kpf, member):
    """WHY: The armor tool finds armor by archetype name; a wrong name says "no ... in your inventory"."""
    data, table = gam_chunks(kpf, member)
    names = set()
    for obj, value in gam_records(data, table, "P$SymName"):
        n = struct.unpack_from("<I", value, 0)[0]
        names.add(value[4:4 + n].split(b"\0")[0].decode("latin-1"))
    listed = (DEV_SCRIPTS / "psi_mfd_armor.nut").read_text(encoding="utf-8").split("ND.psiMfdArmors <- [")[1].split("]")[0]
    armors = re.findall(r'"([^"]+)"', listed)
    assert armors == ["Light Armor", "Medium Armor", "Heavy Armor", "Vacc Suit", "Reflec Armor", "Worm Skin"]
    for armor in armors:
        assert armor in names, f"{member}: no archetype {armor!r}"


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
    """WHY: A "weapon:<Name>" step runs psi\\actions\\Switch_To_<Name>.txt from psi_autocast; a missing file does nothing."""
    finishes = re.findall(r'"weapon:([A-Za-z_]+)"', nut("psi_mfd_macros.nut"))
    assert finishes
    for name in finishes:
        assert (MAIN / "psi" / "actions" / f"Switch_To_{name}.txt").exists(), name


@needs_main
def test_chain_steps_are_ones_psi_autocast_understands():
    """WHY: Every step the MFD writes (arm, <id>o, <id>q, w<ms>, hypo, last, weapon:) must be parsed by PsiChain."""
    chain = (MAIN / "mod" / "sq_scripts" / "psi_autocast.nut").read_text(encoding="utf-8")
    for token in ['"arm"', '"hypo"', '"last"', '"weapon:', '== "w"', '"o"', '"q"']:
        assert token in chain, token


@needs_main
def test_overload_flags_match_psi_autocast():
    """
    WHY: The MFD's Overload column and +Overload buttons use its own copy of the flags, so they show without
    psi_autocast; psi_autocast decides at cast time from its copy. If the two drift, the MFD shows one thing
    and the cast does another.
    """
    data = (MAIN / "mod" / "sq_scripts" / "psi_autocast_disciplines.nut").read_text()
    autocast = {int(i) for i, b in re.findall(r'ND\.psiDisciplines\[(\d+)\] <- \{ name = "[^"]+", benefits = (\d) \}', data) if b == "1"}
    block = nut("psi_mfd_data.nut").split("ND.psiMfdBenefits <- {")[1].split("};")[0]
    mfd = {int(i) for i in re.findall(r"\[(\d+)\] = true", block)}
    assert mfd == autocast


@needs_main
def test_disciplines_match_psi_autocast():
    """WHY: The MFD's discipline numbers must be psi_autocast's; a mismatch casts the wrong discipline."""
    data = (MAIN / "mod" / "sq_scripts" / "psi_autocast_disciplines.nut").read_text()
    ids = {int(i) for i in re.findall(r"ND\.psiDisciplines\[(\d+)\]", data)}
    assert ids == set(mfd_powers())


# ---- setupPsiMfd.bat ----------------------------------------------------------------------------------

BAT = REPO / "extras" / "setupPsiMfd.bat"
NEVER = ["enter", "keypad_enter", "esc", "tab", "space", "bs", "backspace", "`", "-", "=", "mouse_wheel_up", "mouse_wheel_down"]


def run_bat(folder, answers=""):
    """Runs the script against a fixture folder, passed as its argument so it never looks at the real one.
    answers: one line per y/n question, in order; the final newline answers the closing pause.
    Fed from a file: from a pipe, the first set /p swallows the whole buffer and later questions get nothing."""
    answer_file = folder / "answers.txt"
    answer_file.write_text(answers + "\n")
    with answer_file.open() as stdin:
        return subprocess.run(["cmd", "/c", str(BAT), str(folder)], stdin=stdin, capture_output=True, text=True).stdout


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
    assert 'bind keypad_plus "run psi\\actions\\cancel_macro.txt"' in new
    macro_keys = [l.split()[1] for l in new if "psi_macros" in l]
    assert macro_keys[:3] == ["a", "b", "c"], "letters come first"
    assert "g" not in macro_keys and "j" not in macro_keys
    assert len(macro_keys) == 24 + 10 + 12 + 5 + 6 + 12 + 8
    assert (tmp_path / "user.bnd.before_mfd_1").exists()
    assert "Done." in out


def test_bat_never_uses_ruled_out_keys(tmp_path):
    """WHY: Enter, modifiers, punctuation and the wheel were ruled out; keypad + is only ever cancel."""
    (tmp_path / "user.bnd").write_bytes(("; empty\r\n").encode())
    run_bat(tmp_path)
    keys = [l.split()[1] for l in lines(tmp_path) if l.startswith("bind ") or l.startswith("game2 ")]
    assert not [k for k in keys if k in NEVER or "+" in k.replace("keypad_plus", "")]
    assert not [l for l in lines(tmp_path) if "wheel" in l.lower()]
    assert [l for l in lines(tmp_path) if "keypad_plus" in l] == ['bind keypad_plus "run psi\\actions\\cancel_macro.txt"']


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


OFFER_FIXTURE = [
    'bind o wpn_setting_toggle', 'bind t wpn_setting_toggle',  # t: not a default key, command also on o -> offered
    'bind y "use_obj psi booster"',                             # only binding of its command -> never offered
    'bind b cycle_ammo', 'bind f cycle_ammo',                   # f is a default key -> never offered
    'bind joy3 interact', 'bind g interact',                    # only a gamepad button shares it -> never offered
    'bind i foo', 'bind v foo',                                 # only other offered keys share it -> never offered
    'bind k "run user:/psi_macros\\Macro_k.cmd"',               # already a macro key
]


def write_fixture(folder):
    (folder / "user.bnd").write_bytes(("\r\n".join(OFFER_FIXTURE) + "\r\n").encode())


def test_bat_default_keys_match_the_game():
    """WHY: Default keys are never offered for replacing; the script's list must be the game's own defaults."""
    if not GAME.exists():
        pytest.skip("game install not found")
    shock = zipfile.ZipFile(GAME / "base.kpf").read("defaults/shock.bnd").decode("latin-1")
    game = {l.split()[1].lower() for l in shock.splitlines() if l.startswith("bind ") and "+" not in l.split()[1]
            and not l.split()[1].lower().startswith("joy")}
    listed = re.search(r'set "DEFAULT_KEYS=([^"]*)"', BAT.read_text()).group(1).split()
    assert set(listed) == game


def test_bat_offers_only_keys_whose_command_is_bound_elsewhere(tmp_path):
    """WHY: Answering y must never take a default key or leave a command with no key."""
    write_fixture(tmp_path)
    out = run_bat(tmp_path, "n\n")
    asked = re.findall(r"Use (\S+) as a macro key\?", out)
    assert asked == ["t"]
    assert "also on o" in out


def test_bat_y_replaces_the_binding(tmp_path):
    """WHY: A replaced key must lose its old line (two bindings for one key would be ambiguous) and keep the rest."""
    write_fixture(tmp_path)
    run_bat(tmp_path, "y\n")
    after = lines(tmp_path)
    assert 'bind t "run user:/psi_macros\\Macro_t.cmd"' in after
    assert 'bind t wpn_setting_toggle' not in after
    assert [l for l in after if l.startswith("bind t ")] == ['bind t "run user:/psi_macros\\Macro_t.cmd"']
    for line in OFFER_FIXTURE:
        if not line.startswith("bind t "):
            assert line in after


WHEEL_UP = 'bind mouse_wheel_up "summon_obj PsiMfdWheelUp"'
WHEEL_DOWN = 'bind mouse_wheel_down "summon_obj PsiMfdWheelDown"'


def test_bat_wheel_y_replaces_the_default_wheel_lines(tmp_path):
    """WHY: The wheel scrolls the MFD only through plain bindings (the game drops added game2 lines); the
    default weapon-switching lines must be replaced, not duplicated."""
    (tmp_path / "user.bnd").write_bytes(b'bind mouse_wheel_up "cycle_weapon 1"\r\nbind mouse_wheel_down "cycle_weapon -1"\r\n')
    out = run_bat(tmp_path, "y\n")
    wheel = [l for l in lines(tmp_path) if "mouse_wheel" in l]
    assert wheel == [WHEEL_UP, WHEEL_DOWN]
    assert "Mouse wheel: scrolls the MFD." in out


def test_bat_wheel_y_binds_a_missing_wheel(tmp_path):
    """WHY: A wheel with no binding at all (the author's wheel-down) gets both lines."""
    (tmp_path / "user.bnd").write_bytes(b'bind mouse_wheel_up "cycle_weapon 1"\r\n')
    run_bat(tmp_path, "y\n")
    assert [l for l in lines(tmp_path) if "mouse_wheel" in l] == [WHEEL_UP, WHEEL_DOWN]


def test_bat_wheel_custom_binding_is_left_alone(tmp_path):
    """WHY: A player's own wheel command would be lost; the script must not even ask."""
    before = ['bind mouse_wheel_up "zoom_in"', 'bind mouse_wheel_down "cycle_weapon -1"']
    (tmp_path / "user.bnd").write_bytes(("\r\n".join(before) + "\r\n").encode())
    out = run_bat(tmp_path, "y\n")
    assert "Bind the mouse wheel" not in out
    assert [l for l in lines(tmp_path) if "mouse_wheel" in l] == before


def test_bat_wheel_rerun_does_not_ask(tmp_path):
    """WHY: Once set up, running the script again must not ask about the wheel or change it."""
    (tmp_path / "user.bnd").write_bytes(b'; empty\r\n')
    run_bat(tmp_path, "y\n")
    out = run_bat(tmp_path, "y\n")
    assert "Bind the mouse wheel" not in out and "already scrolls the MFD" in out
    assert [l for l in lines(tmp_path) if "mouse_wheel" in l] == [WHEEL_UP, WHEEL_DOWN]


def test_bat_each_question_gets_its_own_answer(tmp_path):
    """WHY: The key offer and the wheel are separate questions; n to the first must not swallow y to the second."""
    write_fixture(tmp_path)
    run_bat(tmp_path, "n\ny\n")
    after = lines(tmp_path)
    assert 'bind t wpn_setting_toggle' in after
    assert [l for l in after if "mouse_wheel" in l] == [WHEEL_UP, WHEEL_DOWN]


def test_bat_n_keeps_the_binding(tmp_path):
    """WHY: n (or no answer at all) must leave the player's binding as it was."""
    write_fixture(tmp_path)
    run_bat(tmp_path, "n\n")
    assert 'bind t wpn_setting_toggle' in lines(tmp_path)
    assert not [l for l in lines(tmp_path) if "Macro_t" in l]


def test_bat_binds_punctuation_with_word_file_names(tmp_path):
    """WHY: , ; = split a batch list and / \\ can't be file names, so the script names punctuation by words;
    the bind line must still use the real key, and a backslash must survive findstr's escaping."""
    (tmp_path / "user.bnd").write_bytes(b'bind [ "use_obj detox patch"\r\n')
    run_bat(tmp_path)
    after = lines(tmp_path)
    for key, word in [(",", "comma"), (".", "period"), ("/", "slash"), (";", "semicolon"), ("'", "apostrophe"),
                      ("]", "rbracket"), ("\\", "backslash")]:
        assert f'bind {key} "run user:/psi_macros\\Macro_{word}.cmd"' in after, key
    assert 'bind [ "use_obj detox patch"' in after
    assert not [l for l in after if "Macro_lbracket" in l], "[ was bound, so it's not free"


def test_bat_offer_replaces_a_bound_punctuation_key(tmp_path):
    """WHY: An offered punctuation key goes through the word file name and the findstr filter that removes its old
    line; ] and ; are not game defaults, and their command is also on O (a default key), so both are offered."""
    before = ["bind o wpn_setting_toggle", "bind ] wpn_setting_toggle", "bind ; wpn_setting_toggle"]
    (tmp_path / "user.bnd").write_bytes(("\r\n".join(before) + "\r\n").encode())
    out = run_bat(tmp_path, "y\ny\nn\n")
    after = lines(tmp_path)
    assert re.findall(r"Use (\S+) as a macro key\?", out) == [";", "]"]
    assert 'bind ] "run user:/psi_macros\\Macro_rbracket.cmd"' in after
    assert 'bind ; "run user:/psi_macros\\Macro_semicolon.cmd"' in after
    assert "bind ] wpn_setting_toggle" not in after and "bind ; wpn_setting_toggle" not in after
    assert "bind o wpn_setting_toggle" in after


def test_bat_binds_the_starter_psi_keys(tmp_path):
    """WHY: setupPsiMfd.bat subsumes psi_autocast's starterPsiPowers.bat. G and J become ordinary MFD macro keys
    (Macro_g.cmd, Macro_j.cmd, the names the MFD uses) preloaded with the starter casts, so the MFD can edit them."""
    (tmp_path / "user.bnd").write_bytes(b"; empty\r\n")
    out = run_bat(tmp_path)
    after = lines(tmp_path)
    assert 'bind g "run user:/psi_macros\\Macro_g.cmd"' in after
    assert 'bind j "run user:/psi_macros\\Macro_j.cmd"' in after
    g = (tmp_path / "psi_macros" / "Macro_g.cmd").read_text().splitlines()
    j = (tmp_path / "psi_macros" / "Macro_j.cmd").read_text().splitlines()
    # The same files psi_autocast's starterPsiPowers.bat writes: one line running the psi script.
    assert g == ["run psi\\t1_projected_cryokinesis.txt"]
    assert j == ["run psi\\chains\\starter_localized_pyrokinesis.txt"]
    assert "Starter key: g" in out


def test_bat_keeps_an_existing_starter_macro_file(tmp_path):
    """WHY: A player's own Macro_g.cmd must never be overwritten by the starter cast."""
    (tmp_path / "user.bnd").write_bytes(b"; empty\r\n")
    (tmp_path / "psi_macros").mkdir()
    (tmp_path / "psi_macros" / "Macro_g.cmd").write_text("set psi_chain arm,3q\nsummon_obj PsiChain\n")
    run_bat(tmp_path)
    assert (tmp_path / "psi_macros" / "Macro_g.cmd").read_text().startswith("set psi_chain arm,3q")
    assert 'bind g "run user:/psi_macros\\Macro_g.cmd"' in lines(tmp_path)


def test_bat_leaves_a_bound_g_alone(tmp_path):
    """WHY: As in the starter script, a key the player already bound is never changed."""
    (tmp_path / "user.bnd").write_bytes(b'bind g "mine"\r\n')
    run_bat(tmp_path)
    assert [l for l in lines(tmp_path) if l.startswith("bind g ")] == ['bind g "mine"']


def test_bat_upgrades_the_starter_scripts_bindings(tmp_path):
    """WHY: "Subsumes": a player who ran psi_autocast's starterPsiPowers.bat and later adds the MFD runs this script
    over the top. The starter's exact G and J bindings (any case: the game lower-cases user.bnd) become the same
    casts as editable macros, without asking, since nothing the player chose is lost."""
    before = ['bind g "run psi\\T1_Projected_Cryokinesis.cmd"',
              'bind j "run psi\\chains\\starter_localized_pyrokinesis.cmd"']
    (tmp_path / "user.bnd").write_bytes(("\r\n".join(before) + "\r\n").encode())
    out = run_bat(tmp_path)
    after = lines(tmp_path)
    assert [l for l in after if l.startswith("bind g ")] == ['bind g "run user:/psi_macros\\Macro_g.cmd"']
    assert [l for l in after if l.startswith("bind j ")] == ['bind j "run user:/psi_macros\\Macro_j.cmd"']
    assert (tmp_path / "psi_macros" / "Macro_g.cmd").read_text().splitlines() == ["run psi\\t1_projected_cryokinesis.txt"]
    assert (tmp_path / "psi_macros" / "Macro_j.cmd").read_text().splitlines() == ["run psi\\chains\\starter_localized_pyrokinesis.txt"]
    assert "Starter key: g" in out and "Starter key: j" in out


def test_bat_leaves_other_psi_autocast_bindings_on_g_and_j(tmp_path):
    """WHY: Only the starter's own two lines are upgraded; another psi_autocast cast on G or J is the player's choice."""
    before = ['bind g "run psi\\t1_projected_cryokinesis_quickfire.cmd"', 'bind j "run psi\\t1_projected_cryokinesis.cmd"']
    (tmp_path / "user.bnd").write_bytes(("\r\n".join(before) + "\r\n").encode())
    run_bat(tmp_path)
    after = lines(tmp_path)
    for line in before:
        assert line in after
    assert not (tmp_path / "psi_macros" / "Macro_g.cmd").exists()


def test_bat_writes_a_placeholder_for_each_new_macro_key(tmp_path):
    """WHY: Every macro key gets a file; one with no macro yet holds the harmless placeholder line."""
    (tmp_path / "user.bnd").write_bytes(b"; empty\r\n")
    run_bat(tmp_path)
    assert (tmp_path / "psi_macros" / "Macro_a.cmd").read_text().splitlines() == ["set psi_mfd_no_macro_yet a"]
    assert (tmp_path / "psi_macros" / "Macro_comma.cmd").read_text().splitlines() == ["set psi_mfd_no_macro_yet comma"]
