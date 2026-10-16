// psi_mfd_macros: macro keys (found in user.bnd) and the macro files the MFD writes.
//
// A macro key is bound once, outside the game, to a file in the save folder:
//   bind g "run user:/psi_macros\MacroG.cmd"
// The MFD rewrites that file. Scripts can only write under "user:/\sq_cache\", which is the save folder root,
// and reading back with run needs "user:/psi_macros\...". Both were tested in game (DEVELOPMENT.md).

const PSI_MFD_ROOT = "user:/\\sq_cache\\";
const PSI_MFD_FOLDER = "psi_macros";
const PSI_MFD_RUN_PREFIX = "user:/psi_macros\\";
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

// [{ key = "g", file = "macrog.cmd" }, ...] for every binding that runs a file in psi_macros.
// The game writes user.bnd in lower case.
function PsiMfdMacroKeys() {
	local keys = [];
	local text = null;
	foreach (path in [PSI_MFD_ROOT + "user.bnd", "user:/user.bnd"]) {
		try {
			text = PsiMfdReadFile(path);
			break;
		}
		catch (e) {}
	}
	if (text == null) {
		print("[psi_mfd] couldn't read user.bnd");
		return keys;
	}
	local marker = PSI_MFD_RUN_PREFIX.tolower();
	foreach (raw in split(text, "\n")) {
		local line = strip(raw).tolower();
		if (!startswith(line, "bind "))
			continue;
		local at = line.find(marker);
		local keyEnd = line.find(" ", 5);
		if (at == null || keyEnd == null)
			continue;
		local rest = line.slice(at + marker.len());
		local fileEnd = rest.find(".cmd");
		if (fileEnd != null)
			keys.push({ key = line.slice(5, keyEnd), file = rest.slice(0, fileEnd + 4) });
	}
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
		foreach (raw in split(text, "\n")) {
			local line = strip(raw);
			if (startswith(line, "set psi_auto_hypo "))
				autoHypo = line.slice(18).tointeger() ? 1 : 0;
			else if (startswith(line, "set psi_draw_ms "))
				drawMs = line.slice(16).tointeger();
			else if (startswith(line, "set psi_chain "))
				ParseChain(line.slice(14));
		}
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
