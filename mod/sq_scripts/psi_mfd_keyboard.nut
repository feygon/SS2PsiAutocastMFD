// psi_mfd_keyboard: the MFD's keyboard view. Key table, key states and hover text (spec:
// docs/superpowers/specs/2026-10-16-hotkey-picker-design.md, R6-R16). The widget is PsiMfdKeyboard below.

// The info line above the keys. Its own const: consts are resolved when a file compiles, and this file may
// compile before psi_mfd_ui.nut (where PSI_MFD_HEADER, also 12, lives).
const PSI_MFD_KEY_INFO = 12;

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
// , . / ; ' [ ] \ can hold macros (user decision 2026-10-16); ` - = stay out.
ND.psiMfdNever <- ["enter", "keypad_enter", "esc", "tab", "space", "backspace", "caps_lock", "shift", "ctrl", "alt",
	"keypad_plus", "`", "-", "="];

// Exactly setupPsiMfd.bat's MACRO_CANDIDATES (a test keeps them equal): keys the script can bind later.
ND.psiMfdCandidates <- ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
	"u", "v", "w", "x", "y", "z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "f1", "f2", "f3", "f4", "f5", "f6",
	"f7", "f8", "f9", "f10", "f11", "f12", "keypad_minus", "keypad_del", "keypad_ins", "keypad_center", "keypad_slash",
	"ins", "del", "home", "end", "pgup", "pgdn",
	"keypad_home", "keypad_up", "keypad_pgup", "keypad_left", "keypad_right", "keypad_end", "keypad_down", "keypad_pgdn", "up", "down", "left", "right",
	",", ".", "/", ";", "'", "[", "]", "\\"];

// Punctuation keys' macro files use a word (/ and \ can't be in a file name); setupPsiMfd.bat uses the same words.
ND.psiMfdFileWords <- { [","] = "comma", ["."] = "period", ["/"] = "slash", [";"] = "semicolon", ["'"] = "apostrophe",
	["["] = "lbracket", ["]"] = "rbracket", ["\\"] = "backslash" };

// The macro file a free or game key gets: Macro_<key>.cmd, or Macro_<word>.cmd for punctuation.
function PsiMfdMacroName(name) {
	return "Macro_" + (name in ND.psiMfdFileWords ? ND.psiMfdFileWords[name] : name) + ".cmd";
}

// Colours (R15).
// All well above the MFD background (about 0.02 / 0.29 / 0.24), which made darker greys unreadable.
ND.psiMfdGrey <- [0.62, 0.68, 0.65];
ND.psiMfdSlate <- [0.66, 0.7, 0.92];
ND.psiMfdFaint <- [0.42, 0.5, 0.47];
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

// Keys these mods need (the wheel, psi_autocast's cancel). Keys running other psi_autocast scripts are ordinary
// game keys (user decision 2026-10-16).
function PsiMfdIsModCommand(lower) {
	return startswith(lower, "summon_obj psimfdwheel") || lower.find("cancel_macro") != null;
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
		s.file = PsiMfdMacroName(name);
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
		s.contentFile = PsiMfdMacroName(name);
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
				return { edge = ND.psiMfdText, text = ND.psiMfdText, double = true };
			return { edge = ND.psiMfdText, text = ND.psiMfdText, double = false };
		case "game": return { edge = ND.psiMfdGrey, text = ND.psiMfdGrey, double = false };
		case "mod":
		case "reserved": return { edge = ND.psiMfdSlate, text = ND.psiMfdSlate, double = false };
	}
	return { edge = ND.psiMfdFaint, text = ND.psiMfdFaint, double = false };
}

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
		m_rowHeight = ((height - PSI_MFD_KEY_INFO) / 6).tointeger();
		m_states = {};
		m_labels = [];
		local w = int_ref();
		local h = int_ref();
		foreach (k in ND.psiMfdKeyboard) {
			local r = Rect(k, 0, 0);
			local text = k.l;
			ShockOverlay.GetStringSize(text, w, h);
			while (text.len() > 1 && w.tointeger() > r[2] - r[0] - 2) {  // clip, no "...": keys are narrow
				text = text.slice(0, -1);
				ShockOverlay.GetStringSize(text, w, h);
			}
			m_labels.push({ text = text, dx = (r[2] - r[0] - w.tointeger()) / 2 });
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
		local y0 = top + PSI_MFD_KEY_INFO + k.r * m_rowHeight;
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
