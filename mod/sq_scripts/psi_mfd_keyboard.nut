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
