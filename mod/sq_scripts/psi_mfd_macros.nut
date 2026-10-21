// psi_mfd_macros: macro keys (found in user.bnd) and the macro files the MFD writes.
//
// A macro key is bound once, outside the game, to a file in the save folder:
//   bind g "run user:/psi_macros\MacroG.cmd"
// The MFD rewrites that file. Scripts can only write under "user:/\sq_cache\", which is the save folder root,
// and reading back with run needs "user:/psi_macros\...". Both were tested in game (DEVELOPMENT.md).

const PSI_MFD_ROOT = "user:/\\sq_cache\\";
const PSI_MFD_FOLDER = "psi_macros";
const PSI_MFD_RUN_PREFIX = "user:/psi_macros\\";
// A macro key with no macro yet runs a file holding this line plus the key: harmless, and it shows in the
// console when pressed (echo prints nothing there).
const PSI_MFD_PLACEHOLDER = "set psi_mfd_no_macro_yet ";
const PSI_MFD_GAP_MS = 500;       // the psi amp's refire limit (psi_autocast's PSI_REFIRE_MS)

// Finishing weapon switches, as psi_autocast chain steps. "" is no switch.
ND.psiMfdFinishes <- ["", "last", "weapon:Wrench", "weapon:Pistol", "weapon:Shotgun", "weapon:Assault_Rifle",
	"weapon:Laser_Pistol", "weapon:EMP_Rifle", "weapon:Laser_Rapier", "weapon:Grenade_Launcher",
	"weapon:Stasis_Field_Generator", "weapon:Fusion_Cannon", "weapon:Crystal_Shard", "weapon:Viral_Proliferator",
	"weapon:Annelid_Launcher"];

ND.psiMfdWaits <- [500, 750, 1000, 1500, 2000];
ND.psiMfdDrawTimes <- [600, 800, 1000, 1200];

// Small text helpers of the MFD's own, so it keeps working (and can say what's missing) without psi_autocast.
// "a,b, c" -> ["a", "b", "c"], skipping empty entries.
function PsiMfdSplitList(text) {
	local items = [];
	local current = "";
	foreach (ch in text) {
		local c = ch.tochar();
		if (c == "," || c == " " || c == "\t") {
			if (current.len() > 0)
				items.push(current);
			current = "";
		}
		else
			current += c;
	}
	if (current.len() > 0)
		items.push(current);
	return items;
}

function PsiMfdIsDigits(text) {
	if (text.len() == 0)
		return false;
	foreach (ch in text) {
		if (ch < '0' || ch > '9')
			return false;
	}
	return true;
}

// "Assault_Rifle" -> "Assault Rifle".
function PsiMfdUnderscoresToSpaces(text) {
	local result = "";
	foreach (ch in text)
		result += ch == '_' ? " " : ch.tochar();
	return result;
}

// Global calls run with the caller's "this", so "file" inside a method would find a member of that name
// first: always call the I/O library as ::file.
function PsiMfdReadFile(path) {
	local input = ::file(path, "rb");  // binary: readn on a text-mode file trips a KEX assert (wrap_fileio.cpp)
	local text = "";
	while (!input.eos())
		text += input.readn('c').tochar();
	input.close();
	return text;
}

function PsiMfdWriteFile(path, text) {
	local output = ::file(path, "w");
	foreach (c in text)
		output.writen(c, 'c');
	output.close();
}

// The MFD's own settings, in the save folder so they hold for every save: one "name value" line each.
const PSI_MFD_SETTINGS = "psi_mfd_settings.txt";
ND.psiMfdWormSkinSwap <- null;   // null until read

// Whether every psi_autocast macro wears the worm skin while it runs (psi_mfd_armor.nut). Off until the player
// ticks it: swapping armor is a trick each player chooses for themselves (author's decision 2026-10-21).
function PsiMfdWormSkinSwapOn() {
	if (ND.psiMfdWormSkinSwap == null) {
		ND.psiMfdWormSkinSwap = false;
		try {
			ND.psiMfdWormSkinSwap = PsiMfdReadFile(PSI_MFD_ROOT + PSI_MFD_FOLDER + "\\" + PSI_MFD_SETTINGS).find("worm_skin_swap 1") != null;
		}
		catch (e) {}   // no settings file yet: off
	}
	return ND.psiMfdWormSkinSwap;
}

// Saves the worm skin swap choice; returns null, or the reason it couldn't.
function PsiMfdSetWormSkinSwap(on) {
	try {
		PsiMfdWriteFile(PSI_MFD_ROOT + PSI_MFD_FOLDER + "\\" + PSI_MFD_SETTINGS, "worm_skin_swap " + (on ? 1 : 0) + "\r\n");
	}
	catch (e) {
		return "Couldn't save the setting";
	}
	ND.psiMfdWormSkinSwap = on;
	return null;
}

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

// Players never edit user.bnd by hand: the MFD writes it. The game reads it only at startup, so a binding written
// here works after the next restart; leaving the Controls menu before then rewrites the file from the game's memory.
ND.psiMfdBndBackedUp <- false;

// text with every plain binding of key removed and "bind <key> <command>" appended; everything else is kept.
function PsiMfdRebind(text, key, command) {
	local out = "";
	local prefix = "bind " + key + " ";
	foreach (raw in split(text, "\n")) {
		local line = strip(raw);
		if (line != "" && !startswith(line.tolower(), prefix))
			out += line + "\r\n";
	}
	return out + prefix + command + "\r\n";
}

// Binds key to command in user.bnd, backing the file up to user.bnd.mfd_backup the first time per session.
// Returns null, or the reason it couldn't.
function PsiMfdBindKey(key, command) {
	local text = PsiMfdReadBnd();
	if (text == null)
		return "Couldn't read user.bnd";
	try {
		if (!ND.psiMfdBndBackedUp) {
			PsiMfdWriteFile(PSI_MFD_ROOT + "user.bnd.mfd_backup", text);
			ND.psiMfdBndBackedUp = true;
		}
		PsiMfdWriteFile(PSI_MFD_ROOT + "user.bnd", PsiMfdRebind(text, key, command));
	}
	catch (e) {
		return "Couldn't write user.bnd";
	}
	return null;
}

// Binds several keys in one write: pairs is [[key, command], ...]. Same backup as PsiMfdBindKey. Returns null, or
// the reason it couldn't.
function PsiMfdBindKeys(pairs) {
	local text = PsiMfdReadBnd();
	if (text == null)
		return "Couldn't read user.bnd";
	try {
		if (!ND.psiMfdBndBackedUp) {
			PsiMfdWriteFile(PSI_MFD_ROOT + "user.bnd.mfd_backup", text);
			ND.psiMfdBndBackedUp = true;
		}
		local updated = text;
		foreach (pair in pairs)
			updated = PsiMfdRebind(updated, pair[0], pair[1]);
		PsiMfdWriteFile(PSI_MFD_ROOT + "user.bnd", updated);
	}
	catch (e) {
		return "Couldn't write user.bnd";
	}
	return null;
}

// The macro file a lower-case command runs, if it's "run user:/psi_macros\<plain name>.cmd"; else null.
function PsiMfdMacroFile(lower) {
	local prefix = "run " + PSI_MFD_RUN_PREFIX.tolower();
	if (!startswith(lower, prefix))
		return null;
	local rest = lower.slice(prefix.len());
	if (rest.find("\\") != null || rest.find("/") != null || rest.find("..") != null || !(endswith(rest, ".cmd") || endswith(rest, ".txt")))
		return null;
	return rest;
}

// "has" (a step or a finish weapon), "script" (no macro, but a run psi\... line), "empty" (reads, but none of
// those), or "missing" (can't be read). R12.
function PsiMfdMacroFileState(fileName) {
	local macro = PsiMfdMacro("", fileName);
	try {
		if (!macro.Load())
			return "missing";
	}
	catch (e) {
		return "missing";
	}
	if (macro.steps.len() || macro.finish != "")
		return "has";
	if (macro.placeholder)
		return "missing";   // the placeholder line: no macro yet, not a broken file
	return macro.script != "" ? "script" : "empty";   // "script": runs a psi_autocast script (the starter keys)
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

// One key's macro: an arm flag, steps ({ kind = "cast", id, mode } or { kind = "hypo" }, each with the wait
// before it), and an optional finishing weapon switch. Saved in the format the Macro Builder writes.
class PsiMfdMacro {
	key = "";
	fileName = "";
	arm = true;
	steps = null;
	finish = "";
	autoHypo = 0;
	drawMs = 800;
	dirty = false;      // edited since the last load or save
	script = "";        // a "run psi\..." line in the file (the starter keys run psi_autocast scripts this way)
	placeholder = false; // the file is only the "no macro yet" line

	constructor(key_, file_) {
		key = key_;
		fileName = file_;
		steps = [];
	}

	function Path() {
		return PSI_MFD_ROOT + PSI_MFD_FOLDER + "\\" + fileName;
	}

	function Tokens() {
		local tokens = arm ? ["arm"] : [];
		foreach (i, step in steps) {
			if (i > 0)
				tokens.push("w" + step.wait);
			tokens.push(step.kind == "hypo" ? "hypo" : step.id + step.mode);
		}
		if (finish != "") {
			if (steps.len())
				tokens.push("w" + PSI_MFD_GAP_MS);
			tokens.push(finish);
		}
		return tokens;
	}

	function Text() {
		local chain = "";
		foreach (token in Tokens())
			chain += (chain.len() ? "," : "") + token;
		local text = "set psi_chain " + chain + "\n";
		if (arm)
			text += "set psi_draw_ms " + drawMs + "\n";
		// Always written, on or off: config values carry over from the last macro that ran.
		text += "set psi_auto_hypo " + autoHypo + "\n";
		if (autoHypo)
			text += "set psi_auto_hypo_wait_ms " + PSI_MFD_GAP_MS + "\n";
		return text + "set psi_chain_gap_ms " + PSI_MFD_GAP_MS + "\nsummon_obj PsiChain\n";
	}

	// Reads the file back, if it exists. Unknown lines are ignored.
	function Load() {
		local text;
		try {
			text = PsiMfdReadFile(Path());
		}
		catch (e) {
			return false;
		}
		arm = false;
		steps = [];
		finish = "";
		script = "";
		placeholder = false;
		local chainFound = false;
		foreach (raw in split(text, "\n")) {
			local line = strip(raw);
			if (startswith(line, "set psi_auto_hypo "))
				autoHypo = line.slice(18).tointeger() ? 1 : 0;
			else if (startswith(line, "set psi_draw_ms "))
				drawMs = line.slice(16).tointeger();
			else if (startswith(line, "set psi_chain ")) {
				chainFound = true;
				ParseChain(line.slice(14));
			}
			else if (startswith(line.tolower(), "run psi\\"))
				script = line.slice(4);
			else if (startswith(line, PSI_MFD_PLACEHOLDER))
				placeholder = true;
		}
		if (!chainFound)
			arm = true;   // no macro in the file yet: a new one starts by drawing the amp, as usual
		return true;
	}

	function ParseChain(text) {
		local wait = PSI_MFD_GAP_MS;
		foreach (token in PsiMfdSplitList(text)) {
			local mode = token.slice(-1);
			if (token == "arm")
				arm = true;
			else if (token == "hypo") {
				steps.push({ kind = "hypo", wait = wait });
				wait = PSI_MFD_GAP_MS;
			}
			else if (token == "last" || startswith(token, "weapon:"))
				finish = token;
			else if (token[0] == 'w' && PsiMfdIsDigits(token.slice(1)))
				wait = token.slice(1).tointeger();
			else if ((mode == "o" || mode == "q") && PsiMfdIsDigits(token.slice(0, -1))) {
				steps.push({ kind = "cast", id = token.slice(0, -1).tointeger(), mode = mode, wait = wait });
				wait = PSI_MFD_GAP_MS;
			}
		}
	}

	// Returns null when saved, otherwise the reason it wasn't.
	function Save() {
		if (!steps.len() && finish == "")
			return "Add at least one step first.";
		try {
			PsiMfdWriteFile(Path(), Text());
		}
		catch (e) {
			return "Couldn't write " + fileName + ": " + e;
		}
		dirty = false;
		return null;
	}
}
