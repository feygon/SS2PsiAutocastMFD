// psi_mfd_ui: the psi macro MFD.  summon_obj PsiMfd  opens and closes it (bind a key to that once).
//
// A scrolling table of every discipline (icon, tier, name, duration, effect, overload bonus, each now / at PSI 8),
// and an editor for the selected key's macro. Built on the remaster's UI library (libs/ui.nut), which draws
// registered panels from its DrawHUD handler and routes clicks to whatever is under the mouse.

const PSI_MFD_MIN_WIDTH = 470;
const PSI_MFD_MAX_WIDTH = 720;
const PSI_MFD_ROW_HEIGHT = 27;   // the quick-slot icons (PICNnnQ) are 55 x 25
const PSI_MFD_TOP_BAR = 18;
const PSI_MFD_HEADER = 12;
const PSI_MFD_EDITOR = 52;       // macro label and two lines of steps
const PSI_MFD_CONTROLS = 32;     // two lines of buttons
const PSI_MFD_EDIT_HINT = "Macro: click a step to remove it, a wait to change it";

// Text colours, 0-1, matching the game's teal MFDs.
ND.psiMfdBright <- [0.6, 1.0, 0.85];
ND.psiMfdText <- [0.45, 0.85, 0.7];
ND.psiMfdDim <- [0.3, 0.6, 0.5];

// Columns: x offsets inside a row, set by PsiMfdLayoutColumns for the panel's width.
ND.psiMfdColumns <- { icon = 1, tier = 60, name = 76, time = 200, effect = 266, overload = 356, cost = 400, add = 410 };

// Icon and tier are fixed; the text columns share what's left of the row (which ends 36 short of the panel).
function PsiMfdLayoutColumns(panelWidth) {
	local c = ND.psiMfdColumns;
	local free = panelWidth - 36 - c.name - 56;
	c.time = c.name + (free * 0.31).tointeger();
	c.effect = c.time + (free * 0.17).tointeger();
	c.overload = c.effect + (free * 0.22).tointeger();
	c.cost = c.overload + (free * 0.15).tointeger();
	c.add = c.name + free + 2;
}

// Readable names for user.bnd keys.
ND.psiMfdKeyNames <- { keypad_minus = "Keypad -", keypad_plus = "Keypad +", keypad_star = "Keypad *", keypad_slash = "Keypad /",
	keypad_del = "Keypad Del", keypad_ins = "Keypad Ins", keypad_center = "Keypad 5", keypad_enter = "Keypad Enter",
	keypad_end = "Keypad 1", keypad_down = "Keypad 2", keypad_pgdn = "Keypad 3", keypad_left = "Keypad 4",
	keypad_right = "Keypad 6", keypad_home = "Keypad 7", keypad_up = "Keypad 8", keypad_pgup = "Keypad 9",
	up = "Up", down = "Down", left = "Left", right = "Right" };

function PsiMfdKeyName(key) {
	return key in ND.psiMfdKeyNames ? ND.psiMfdKeyNames[key] : key.toupper();
}

function PsiMfdColor(color) {
	ND.SetTextColor(color[0] * 255, color[1] * 255, color[2] * 255);
}

function PsiMfdLabel(x, y, text, color) {
	local label = ND.UiText(x, y);
	label.Set(text, color[0], color[1], color[2]);
	label.m_ignoreMouse = true;
	return label;
}

// Errors must never reach the remaster's UI loop: an exception there aborts its whole frame update before it
// clears the click queue, so the same click replays every frame and every script UI stops. Each MFD entry point
// catches its own errors, reports them once, and closes the MFD.
function PsiMfdFail(where, e) {
	print("[psi_mfd] error in " + where + ": " + e + " - closing the MFD");
	ND.psiMfdOpen = false;
}

// The entry after value in list, wrapping round; the first entry if value isn't in it.
function PsiMfdNextIn(list, value) {
	foreach (i, entry in list) {
		if (entry == value)
			return list[(i + 1) % list.len()];
	}
	return list[0];
}

// Shortens text with "..." until it fits in width (overlay units). Call inside the draw step.
function PsiMfdFit(text, width) {
	local w = int_ref();
	local h = int_ref();
	ShockOverlay.GetStringSize(text, w, h);
	if (w.tointeger() <= width)
		return text;
	while (text.len() > 1) {
		text = text.slice(0, -1);
		ShockOverlay.GetStringSize(text + "...", w, h);
		if (w.tointeger() <= width)
			return text + "...";
	}
	return text;
}

// A boxed button, styled like the game's MFD buttons. Clicking calls owner.<method>(argument).
// textFunc, if given, is called on owner each frame for the label.
class PsiMfdButton extends ND.UiBase {
	m_text = "";
	m_textFunc = null;
	m_owner = null;
	m_method = null;
	m_argument = null;

	constructor(text, x, y, owner, method, argument = null, textFunc = null) {
		base.constructor(x, y, 10, 11);
		m_text = text;
		m_owner = owner;
		m_method = method;
		m_argument = argument;
		m_textFunc = textFunc;
		m_uiType = "PsiMfdButton";
		Label();
	}

	// Current label, resizing the button to fit it.
	function Label() {
		local text = m_textFunc ? m_textFunc.call(m_owner) : m_text;
		local w = int_ref();
		local h = int_ref();
		ShockOverlay.GetStringSize(text, w, h);
		SetSize(w.tointeger() + 7, 11);
		return text;
	}

	function DrawAt(x, y) {
		if (!m_active)
			return null;
		local text = Label();
		local hovered = base.DrawAt(x, y);
		local left = x + m_x;
		local top = y + m_y;
		local edge = m_hovered ? ND.psiMfdBright : ND.psiMfdDim;
		ND.DrawBox(left, top, left + m_width, top + m_height, edge[0], edge[1], edge[2]);
		PsiMfdColor(m_hovered ? ND.psiMfdBright : ND.psiMfdText);
		ShockOverlay.DrawString(text, left + 4, top + 1);
		return hovered;
	}

	function OnLeftClick(message) {
		try {
			m_owner[m_method](m_argument);
		}
		catch (e) {
			PsiMfdFail("button '" + m_text + "'", e);
		}
	}
}

// The macro key selector: < [ Keypad - ] >, with the key name in a bright box. The panel has one at the top
// and one at the bottom; both change the same selection.
const PSI_MFD_KEY_BOX = 96;

class PsiMfdKeySelector extends ND.UiBase {
	m_panel = null;

	constructor(panel, x, y) {
		base.constructor(x, y, PSI_MFD_KEY_BOX + 30, 13);
		m_panel = panel;
		m_uiType = "PsiMfdKeySelector";
		AddChild(PsiMfdButton("<", 0, 1, panel, "PreviousKey"));
		AddChild(PsiMfdButton(">", PSI_MFD_KEY_BOX + 18, 1, panel, "NextKey"));
	}

	function DrawAt(x, y) {
		if (!m_active)
			return null;
		local hovered = base.DrawAt(x, y);
		local left = x + m_x + 14;
		local top = y + m_y;
		local b = ND.psiMfdBright;
		ND.DrawBox(left, top, left + PSI_MFD_KEY_BOX, top + m_height, b[0], b[1], b[2]);
		ND.DrawBox(left + 1, top + 1, left + PSI_MFD_KEY_BOX - 1, top + m_height - 1, b[0], b[1], b[2]);
		local text = m_panel.KeyText();
		local w = int_ref();
		local h = int_ref();
		ShockOverlay.GetStringSize(text, w, h);
		PsiMfdColor(b);
		ShockOverlay.DrawString(text, left + (PSI_MFD_KEY_BOX - w.tointeger()) / 2, top + 2);
		return hovered;
	}

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
}

// One table row. The panel sets m_row to the discipline it shows (it changes as the table scrolls).
class PsiMfdRow extends ND.UiBase {
	m_panel = null;
	m_row = null;
	m_addOverload = null;

	constructor(panel, y, width) {
		base.constructor(6, y, width, PSI_MFD_ROW_HEIGHT - 2);
		m_panel = panel;
		m_uiType = "PsiMfdRow";
		AddChild(m_addOverload = PsiMfdButton("+Overload", ND.psiMfdColumns.add, 1, this, "Add", "o"));
		AddChild(PsiMfdButton("+Quick", ND.psiMfdColumns.add, 13, this, "Add", "q"));
	}

	function Add(mode) {
		if (m_row)
			m_panel.AddCast(m_row.id, mode);
	}

	// Clicking the row itself adds a conditional overload cast, which quickfires disciplines that don't benefit.
	function OnLeftClick(message) {
		try {
			Add("o");
		}
		catch (e) {
			PsiMfdFail("row click", e);
		}
	}

	function DrawAt(x, y) {
		if (!m_active || !m_row)
			return null;
		local left = x + m_x;
		local top = y + m_y;
		local c = ND.psiMfdColumns;
		ShockOverlay.DrawBitmap(ND.GetBitmap(m_row.icon), left + c.icon, top);
		if (m_hovered)
			ND.DrawBox(left, top, left + m_width, top + m_height, ND.psiMfdBright[0], ND.psiMfdBright[1], ND.psiMfdBright[2]);
		else {
			PsiMfdColor(ND.psiMfdDim);
			ShockOverlay.DrawLine(left, top + m_height + 1, left + m_width, top + m_height + 1);
		}

		PsiMfdColor(ND.psiMfdBright);
		ShockOverlay.DrawString("T" + m_row.tier, left + c.tier, top + 2);
		ShockOverlay.DrawString(m_row.name, left + c.name, top + 2);
		PsiMfdColor(ND.psiMfdText);
		ShockOverlay.DrawString(m_row.time, left + c.time, top + 2);
		ShockOverlay.DrawString(m_row.effect, left + c.effect, top + 2);
		PsiMfdColor(m_row.benefits ? ND.psiMfdBright : ND.psiMfdDim);
		ShockOverlay.DrawString(m_row.overload, left + c.overload, top + 2);
		PsiMfdColor(m_row.cost == "bought" ? ND.psiMfdDim : ND.psiMfdText);
		ShockOverlay.DrawString(m_row.cost, left + c.cost, top + 2);
		PsiMfdColor(ND.psiMfdDim);
		ShockOverlay.DrawString(m_row.shortName, left + c.name, top + 13);

		m_addOverload.SetActive(m_row.benefits);
		return base.DrawAt(x, y);
	}
}

class PsiMfdPanel extends ND.UiBase {
	m_rows = null;        // table data, from PsiMfdBuildRows()
	m_rowUis = null;
	m_visibleRows = 0;
	m_scroll = 0;
	m_keys = null;        // from PsiMfdMacroKeys()
	m_bindings = null;    // from PsiMfdBindings(), read each time the MFD opens
	m_keyIndex = 0;
	m_macro = null;
	m_macros = null;       // key -> PsiMfdMacro, kept while the MFD is open so switching keys keeps edits
	m_steps = null;       // container for the step buttons
	m_status = null;
	m_placeX = 0;
	m_placeY = 0;
	m_keyboard = null;
	m_keyboardShown = false;
	m_tableWidgets = null;  // header labels, rows, Up, Dn: hidden while the keyboard shows
	m_tableHeight = 0;
	m_editLabel = null;

	// Sized to the window: between the inventory bar and the bottom HUD, centred between the side MFDs.
	constructor() {
		local canvas = ND.GetCanvasSize();
		local top = (canvas.y * 0.24).tointeger();
		local height = (canvas.y * 0.64).tointeger();
		local width = (canvas.x * 0.74).tointeger();
		width = width < PSI_MFD_MIN_WIDTH ? PSI_MFD_MIN_WIDTH : (width > PSI_MFD_MAX_WIDTH ? PSI_MFD_MAX_WIDTH : width);
		PsiMfdLayoutColumns(width);
		base.constructor(((canvas.x - width) / 2).tointeger(), top, width, height);
		SetName("PsiMfdPanel");
		SetBackground("TRAIT");
		m_uiType = "PsiMfdPanel";

		local fixed = PSI_MFD_TOP_BAR + PSI_MFD_HEADER + PSI_MFD_EDITOR + PSI_MFD_CONTROLS + 8;
		m_visibleRows = ((height - fixed) / PSI_MFD_ROW_HEIGHT).tointeger();
		if (m_visibleRows < 2)
			m_visibleRows = 2;

		// Top bar
		AddChild(PsiMfdLabel(6, 4, "PSI MACROS", ND.psiMfdBright));
		AddChild(PsiMfdLabel(80, 4, "Macro key:", ND.psiMfdText));
		AddChild(PsiMfdKeySelector(this, 130, 2));
		AddChild(PsiMfdButton("", 260, 4, this, "ToggleKeyboard", null, @() m_keyboardShown ? "Table" : "Keys"));
		for (local tier = 1; tier <= 5; tier++)
			AddChild(PsiMfdButton("T" + tier, width - 200 + tier * 24, 4, this, "ScrollToTier", tier));
		AddChild(PsiMfdButton("Close", width - 40, 4, this, "Close"));

		// Column headings
		local c = ND.psiMfdColumns;
		local headY = PSI_MFD_TOP_BAR + 1;
		m_tableWidgets = [];
		foreach (heading in [[c.name, "Discipline"], [c.time, "Duration"], [c.effect, "Effect"], [c.overload, "Overload"], [c.cost, "Cyber Mods"]])
			m_tableWidgets.push(PsiMfdLabel(6 + heading[0], headY, heading[1], ND.psiMfdDim));
		foreach (widget in m_tableWidgets)
			AddChild(widget);

		// Table
		local tableY = PSI_MFD_TOP_BAR + PSI_MFD_HEADER + 2;
		m_rowUis = [];
		for (local i = 0; i < m_visibleRows; i++) {
			local row = PsiMfdRow(this, tableY + i * PSI_MFD_ROW_HEIGHT, width - 36);
			m_rowUis.push(row);
			m_tableWidgets.push(row);
			AddChild(row);
		}
		local up = PsiMfdButton("Up", width - 26, tableY, this, "Scroll", -1);
		local down = PsiMfdButton("Dn", width - 26, tableY + m_visibleRows * PSI_MFD_ROW_HEIGHT - 12, this, "Scroll", 1);
		m_tableWidgets.push(up);
		m_tableWidgets.push(down);
		AddChild(up);
		AddChild(down);

		// Keyboard view (R2, R6): same place as the table, hidden until Keys is clicked.
		m_tableHeight = PSI_MFD_HEADER + 2 + m_visibleRows * PSI_MFD_ROW_HEIGHT;
		AddChild(m_keyboard = PsiMfdKeyboard(this, 6, PSI_MFD_TOP_BAR, width - 12, m_tableHeight, width));
		m_keyboard.SetActive(false);

		// Macro editor
		local editY = tableY + m_visibleRows * PSI_MFD_ROW_HEIGHT + 4;
		AddChild(m_editLabel = PsiMfdLabel(6, editY, PSI_MFD_EDIT_HINT, ND.psiMfdDim));
		AddChild(m_steps = ND.UiBase(6, editY + 12, width - 12, 36));

		// Controls
		local controlsY = height - PSI_MFD_CONTROLS + 2;
		AddChild(PsiMfdButton("", 6, controlsY, this, "ToggleArm", null, @() "Draw amp: " + (m_macro && m_macro.arm ? "on" : "off")));
		AddChild(PsiMfdButton("", 80, controlsY, this, "CycleDraw", null, @() "Amp wait: " + (m_macro ? m_macro.drawMs : 800) + "ms"));
		AddChild(PsiMfdButton("Add hypo", 172, controlsY, this, "AddHypo"));
		AddChild(PsiMfdButton("", 232, controlsY, this, "CycleFinish", null, @() "Finish: " + FinishText()));
		// For every macro, not the one shown: so it sits apart, at the right end of the row.
		local w = int_ref();
		local h = int_ref();
		ShockOverlay.GetStringSize("Worm skin swap: off", w, h);
		AddChild(PsiMfdButton("", width - 13 - w.tointeger(), controlsY, this, "ToggleWormSkin", null,
			@() "Worm skin swap: " + (PsiMfdWormSkinSwapOn() ? "on" : "off")));
		AddChild(PsiMfdButton("", 6, controlsY + 13, this, "ToggleAutoHypo", null, @() "Auto psi hypo: " + (m_macro && m_macro.autoHypo ? "on" : "off")));
		AddChild(PsiMfdKeySelector(this, width - 214, controlsY + 12));
		AddChild(PsiMfdButton("Clear", width - 76, controlsY + 13, this, "Clear"));
		AddChild(PsiMfdButton("Save", width - 36, controlsY + 13, this, "Save"));
		AddChild(m_status = PsiMfdLabel(110, controlsY + 14, "", ND.psiMfdText));
	}

	function DrawAt(x, y) {
		try {
			return DrawPanel(x, y);
		}
		catch (e) {
			PsiMfdFail("drawing", e);
			m_active = false;
			return null;
		}
	}

	function DrawPanel(x, y) {
		local hovered = base.DrawAt(x, y);
		if (!m_active)
			return hovered;
		local left = x + m_x;
		local top = y + m_y;
		local b = ND.psiMfdBright;
		ND.DrawBox(left, top, left + m_width, top + m_height, b[0], b[1], b[2]);
		local d = ND.psiMfdDim;
		ND.DrawBox(left, top, left + m_width, top + PSI_MFD_TOP_BAR - 2, d[0], d[1], d[2]);
		return hovered;
	}

	function IsUnderMouse() {
		local mouse = ND.g_PlayerCore.m_mouse;
		return m_active && mouse.x >= m_screenX && mouse.x < m_screenX + m_width && mouse.y >= m_screenY && mouse.y < m_screenY + m_height;
	}

	// Called each time the MFD opens: PSI and bindings may have changed.
	function Refresh() {
		m_rows = PsiMfdBuildRows();
		local c = ND.psiMfdColumns;
		foreach (row in m_rows) {
			row.icon += "Q";
			row.name = PsiMfdFit(row.name, c.time - c.name - 4);
			row.shortName = PsiMfdFit(row.shortName, c.time - c.name - 4);
			row.time = PsiMfdFit(row.time, c.effect - c.time - 4);
			row.effect = PsiMfdFit(row.effect, c.overload - c.effect - 4);
			row.overload = PsiMfdFit(row.overload, c.cost - c.overload - 4);
			row.cost = PsiMfdFit(row.cost, c.add - c.cost - 4);
		}
		m_bindings = PsiMfdBindings();
		m_keys = PsiMfdMacroKeys(m_bindings);
		m_macros = {};
		if (m_keyIndex >= m_keys.len())
			m_keyIndex = 0;
		ShowKeyboard(false);
		LoadMacro();
		Scroll(0);
		if (!m_keys.len())
			SetEditLabel("No macro keys bound: click Keys to pick one");
		if (!("psiDisciplines" in ND))
			SetStatus("psi_autocast isn't loaded: macros won't run");
	}

	function SetStatus(text) {
		m_status.Set(PsiMfdFit(text, m_width - 330), ND.psiMfdText[0], ND.psiMfdText[1], ND.psiMfdText[2]);
	}

	function KeyText() {
		return m_keys && m_keys.len() ? PsiMfdKeyName(m_keys[m_keyIndex].key) : "no keys";
	}

	function FinishText() {
		if (!m_macro || m_macro.finish == "")
			return "none";
		return m_macro.finish == "last" ? "previous weapon" : PsiMfdUnderscoresToSpaces(m_macro.finish.slice(7));
	}

	// Shows the selected key's macro, reading it from disk the first time it's shown after opening.
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
				SetStatus(m_macro.Load() && !m_macro.placeholder ? "Loaded" : "New macro");
				if (m_macro.script != "" && !m_macro.steps.len() && m_macro.finish == "")
					SetEditLabel("Runs " + m_macro.script + ": a macro saved here replaces it.");
			}
		}
		RebuildSteps();
	}

	function PreviousKey(unused) {
		if (m_keys.len()) {
			m_keyIndex = (m_keyIndex + m_keys.len() - 1) % m_keys.len();
			LoadMacro();
		}
	}

	function NextKey(unused) {
		if (m_keys.len()) {
			m_keyIndex = (m_keyIndex + 1) % m_keys.len();
			LoadMacro();
		}
	}

	function Scroll(delta) {
		if (m_keyboardShown && delta != 0)
			return;
		local last = m_rows.len() - m_visibleRows;
		local next = m_scroll + delta;
		m_scroll = next < 0 ? 0 : (next > last ? last : next);
		foreach (i, row in m_rowUis)
			row.m_row = m_rows[m_scroll + i];
	}

	function ScrollToTier(tier) {
		ShowKeyboard(false);
		m_scroll = (tier - 1) * 7;
		Scroll(0);
	}

	function Close(unused) {
		ND.psiMfdOpen = false;
	}

	function Editable() {
		if (!m_macro)
			SetStatus("No macro key selected");
		return m_macro != null;
	}

	function AddCast(id, mode) {
		if (!Editable())
			return;
		m_macro.steps.push({ kind = "cast", id = id, mode = mode, wait = PSI_MFD_GAP_MS });
		Changed();
	}

	function AddHypo(unused) {
		if (!Editable())
			return;
		m_macro.steps.push({ kind = "hypo", wait = PSI_MFD_GAP_MS });
		Changed();
	}

	function RemoveStep(index) {
		m_macro.steps.remove(index);
		Changed();
	}

	function CycleWait(index) {
		local step = m_macro.steps[index];
		step.wait = PsiMfdNextIn(ND.psiMfdWaits, step.wait);
		Changed();
	}

	function CycleFinish(unused) {
		if (!Editable())
			return;
		m_macro.finish = PsiMfdNextIn(ND.psiMfdFinishes, m_macro.finish);
		Changed();
	}

	function CycleDraw(unused) {
		if (!Editable())
			return;
		m_macro.drawMs = PsiMfdNextIn(ND.psiMfdDrawTimes, m_macro.drawMs);
		Changed();
	}

	function ToggleArm(unused) {
		if (!Editable())
			return;
		m_macro.arm = !m_macro.arm;
		Changed();
	}

	// The worm skin swap: while any psi_autocast macro runs, the worm skin is worn (psi_mfd_armor.nut). Off until
	// the player ticks it; kept in psi_macros\psi_mfd_settings.txt.
	function ToggleWormSkin(unused) {
		local on = !PsiMfdWormSkinSwapOn();
		local problem = PsiMfdSetWormSkinSwap(on);
		SetStatus(problem ? problem : "All macros: worm skin swap " + (on ? "on" : "off"));
	}

	function ToggleAutoHypo(unused) {
		if (!Editable())
			return;
		m_macro.autoHypo = m_macro.autoHypo ? 0 : 1;
		Changed();
	}

	function Clear(unused) {
		if (!Editable())
			return;
		m_macro.steps = [];
		m_macro.finish = "";
		Changed();
	}

	function Save(unused) {
		if (!Editable())
			return;
		local problem = m_macro.Save();
		if (problem) {
			SetStatus(problem);
			return;
		}
		m_macro.script = "";   // the file now holds this macro, not the psi script it used to run
		local entry = m_keys[m_keyIndex];
		local name = PsiMfdKeyName(entry.key);
		SetStatus("Saved for " + name);
		local state = "state" in entry ? entry.state : "macro";
		if (state == "free") {   // a key freed in Controls since this load
			local failed = PsiMfdBindKey(entry.key, "\"run " + PSI_MFD_RUN_PREFIX + entry.file + "\"");
			if (failed)
				SetEditLabel("Saved, but " + failed + ": " + name + " isn't bound.");
			else {
				entry.state = "macro";
				ND.psiMfdPending[entry.key] <- true;
			}
		}
		if (entry.key in ND.psiMfdPending)
			SetEditLabel("Saved. " + name + " runs this macro after you next start the game.");
		else if (state == "game")
			SetEditLabel("Saved. " + name + " is set in Controls: clear it there, Save here again, then restart.");
	}

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

	function Changed() {
		m_macro.dirty = true;
		SetStatus("Not saved yet");
		SetEditLabel(PSI_MFD_EDIT_HINT);   // drops any note about what the file used to run, or the last save
		RebuildSteps();
	}

	function StepText(step) {
		if (step.kind == "hypo")
			return "Hypo";
		return Data.GetString("psihelp", "PsiShort" + step.id) + (step.mode == "o" ? " OL" : " Q");
	}

	// Lays out the macro as buttons, wrapping onto further lines.
	function RebuildSteps() {
		m_steps.m_children = [];
		m_placeX = 0;
		m_placeY = 0;
		if (!m_macro)
			return;
		if (m_macro.arm)
			Place(PsiMfdLabel(0, 0, "Draw amp >", ND.psiMfdDim));
		foreach (i, step in m_macro.steps) {
			if (i > 0)
				Place(PsiMfdButton(step.wait + "ms", 0, 0, this, "CycleWait", i));
			Place(PsiMfdButton(StepText(step), 0, 0, this, "RemoveStep", i));
		}
		if (m_macro.finish != "")
			Place(PsiMfdLabel(0, 0, "> " + FinishText(), ND.psiMfdDim));
	}

	function Place(widget) {
		if (m_placeX + widget.m_width + 10 > m_steps.m_width) {
			m_placeX = 0;
			m_placeY += 12;
		}
		widget.SetPos(m_placeX, m_placeY);
		m_steps.AddChild(widget);
		m_placeX += widget.m_width + 10;
	}
}

// Opening and closing. The panel is built inside the draw step: the UI library measures text when widgets
// are created, and the engine warns if that happens outside DrawHUD.
ND.psiMfdOpen <- false;
ND.psiMfdWasOpen <- false;
ND.psiMfdSeenCursor <- false;  // the cursor has been up since the MFD opened
ND.psiMfdOpenFor <- 0.0;       // seconds since the MFD opened
const PSI_MFD_CURSOR_WAIT = 1.0; // the open key asks for the cursor; close if it hasn't come up by then
ND.psiMfdPanel <- null;
ND.psiMfdPending <- {};        // keys bound in user.bnd this session: they work from the next start
ND.psiMfdKeysChecked <- false;

// psi_autocast's two starter casts, for G and J (the same one-line files its starterPsiPowers.bat writes).
ND.psiMfdStarter <- { g = "run psi\\t1_projected_cryokinesis.txt", j = "run psi\\chains\\starter_localized_pyrokinesis.txt" };

function PsiMfdIsFree(key, bindings, add) {
	if (key in bindings)
		return false;
	foreach (pair in add) {
		if (pair[0] == key)
			return false;
	}
	return true;
}

// The keys to bind on load, as [[key, command], ...]: an open key if none opens the MFD, keypad + for
// psi_autocast's cancel, K for the maintenance tool, G and J with psi_autocast's starter casts, and every other free
// candidate as a macro key. Only keys with no binding at all: game keys, combos and the player's own bindings are
// never touched. takeK: K is a macro key whose file has no macro yet (set up before K was the maintenance key).
function PsiMfdKeysToBind(bindings, takeK = false) {
	local add = [];
	local hasOpen = false;
	foreach (key, b in bindings) {
		if (!b.combo && b.lower == "summon_obj psimfd")
			hasOpen = true;
	}
	if (!hasOpen) {
		local choices = ["keypad_star", "keypad_slash"];
		choices.extend(ND.psiMfdCandidates);   // extend() returns null: never use its result
		foreach (key in choices) {
			if (PsiMfdIsFree(key, bindings, add)) {
				add.push([key, "\"summon_obj PsiMfd\""]);
				break;
			}
		}
	}
	if (PsiMfdIsFree("keypad_plus", bindings, add))
		add.push(["keypad_plus", "\"run psi\\actions\\cancel_macro.txt\""]);
	if (takeK || PsiMfdIsFree(ND.psiMfdMaintainKey, bindings, add))
		add.push([ND.psiMfdMaintainKey, "\"" + ND.psiMfdMaintainCommand + "\""]);
	local keys = ["g", "j"];
	keys.extend(ND.psiMfdCandidates);
	foreach (key in keys) {
		if (PsiMfdIsFree(key, bindings, add))
			add.push([key, "\"run " + PSI_MFD_RUN_PREFIX + PsiMfdMacroName(key) + "\""]);
	}
	return add;
}

// The placeholder file for a macro key with no macro yet (punctuation keys by their file word).
function PsiMfdPlaceholder(key) {
	return PSI_MFD_PLACEHOLDER + (key in ND.psiMfdFileWords ? ND.psiMfdFileWords[key] : key) + "\r\n";
}

function PsiMfdFileExists(path) {
	try {
		PsiMfdReadFile(path);
	}
	catch (e) {
		return false;
	}
	return true;
}

// Each load: binds every free key at once (one user.bnd write, backed up first), so any non-grey key takes a
// macro on the next keypress after the next start. Only a first install, with no open key yet, asks for a restart.
function PsiMfdEnsureKeys() {
	local bindings = PsiMfdBindings();
	if (bindings == null)
		return;
	// K became the maintenance key in 1.3: a K macro key set up before then is taken over only if it has no macro.
	local takeK = false;
	local k = ND.psiMfdMaintainKey in bindings ? bindings[ND.psiMfdMaintainKey] : null;
	if (k && !k.combo) {
		local kFile = PsiMfdMacroFile(k.lower);
		takeK = kFile != null && PsiMfdMacroFileState(kFile) == "missing";
	}
	local add = PsiMfdKeysToBind(bindings, takeK);
	// Every macro key gets a file: a placeholder where there's none yet (keys already bound, and new ones below).
	foreach (key in PsiMfdMacroKeys(bindings)) {
		local file = PSI_MFD_ROOT + PSI_MFD_FOLDER + "\\" + key.file;
		if (!PsiMfdFileExists(file))
			PsiMfdWriteFile(file, PsiMfdPlaceholder(key.key));
	}
	if (!add.len())
		return;
	local openKey = null;
	foreach (pair in add) {
		if (pair[1] == "\"summon_obj PsiMfd\"")
			openKey = pair[0];
		if (pair[1].find("psi_macros") != null) {
			local file = PSI_MFD_ROOT + PSI_MFD_FOLDER + "\\" + PsiMfdMacroName(pair[0]);
			if (!PsiMfdFileExists(file))
				PsiMfdWriteFile(file, pair[0] in ND.psiMfdStarter ? ND.psiMfdStarter[pair[0]] + "\r\n" : PsiMfdPlaceholder(pair[0]));
		}
	}
	local failed = PsiMfdBindKeys(add);
	if (failed) {
		print("[psi_mfd] " + failed + ": couldn't set up keys");
		return;
	}
	local macroKeys = 0;
	local maintenance = false;
	foreach (pair in add) {
		ND.psiMfdPending[pair[0]] <- true;
		if (pair[1].find("psi_macros") != null)
			macroKeys++;
		if (pair[0] == ND.psiMfdMaintainKey)
			maintenance = true;
	}
	local parts = [];
	if (maintenance)
		parts.push(PsiMfdKeyName(ND.psiMfdMaintainKey) + " uses a maintenance tool on the weapon in hand");
	if (macroKeys)
		parts.push(macroKeys + " more " + (macroKeys == 1 ? "key is" : "keys are") + " ready for macros");
	if (!parts.len())
		parts.push(add.len() + " more " + (add.len() == 1 ? "key is" : "keys are") + " set up");
	local message = openKey
		? "psi_autocast_mfd is set up: restart the game once, then press " + PsiMfdKeyName(openKey) + " to open the psi MFD"
		: "psi_autocast_mfd, from your next start: " + parts[0] + (parts.len() > 1 ? ", and " + parts[1] : "");
	print("[psi_mfd] " + message);
	try {
		ShockGame.AddText(message, "Player", 15000);
	}
	catch (e) {}
}

class PsiMfdHandler {
	m_name = "PsiMfdHandler";

	function OnFrameUpdate(deltaTime) {
		try {
			Update(deltaTime);
		}
		catch (e) {
			PsiMfdFail("frame update", e);
			if (ND.psiMfdPanel)
				ND.psiMfdPanel.SetActive(false);
			ND.psiMfdWasOpen = false;
		}
	}

	// Leaving cursor mode (back to shooting) closes the MFD, saved or not, so it doesn't reappear the next time
	// the cursor comes up for another MFD.
	function Update(deltaTime) {
		if (!ND.psiMfdKeysChecked) {
			ND.psiMfdKeysChecked = true;
			try {
				PsiMfdEnsureKeys();
			}
			catch (e) {
				PsiMfdFail("binding keys", e);
			}
		}
		if (ND.psiMfdOpen && !ND.psiMfdPanel) {
			ND.psiMfdPanel = PsiMfdPanel();
			ND.g_PlayerCore.InternalMessage("RegisterRootUi", ND.psiMfdPanel);
		}
		if (ND.psiMfdOpen && !ND.psiMfdWasOpen) {
			ND.psiMfdPanel.Refresh();
			ND.psiMfdSeenCursor = false;
			ND.psiMfdOpenFor = 0.0;
		}
		local cursor = ShockGame.MouseCursor();
		if (ND.psiMfdOpen) {
			ND.psiMfdOpenFor += deltaTime;
			if (cursor)
				ND.psiMfdSeenCursor = true;
			else if (ND.psiMfdSeenCursor || ND.psiMfdOpenFor > PSI_MFD_CURSOR_WAIT)
				ND.psiMfdOpen = false;
		}
		ND.psiMfdWasOpen = ND.psiMfdOpen;
		if (ND.psiMfdPanel)
			ND.psiMfdPanel.SetActive(ND.psiMfdOpen && cursor);
	}
}

ND.g_PlayerCore.AddHandler(PsiMfdHandler());

class PsiMfd extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Toggle", 0.01);
	}

	function OnTimer() {
		if (message().name != "Toggle")
			return;
		ND.psiMfdOpen = !ND.psiMfdOpen;
		if (ND.psiMfdOpen && !ShockGame.MouseCursor())
			Debug.Command("toggle_mouse");
		Object.Destroy(self);
	}
}

// Mouse wheel. Scripts never see the wheel (it's a binding, not a key event), so it's bound once in user.bnd:
//   bind mouse_wheel_up "summon_obj PsiMfdWheelUp"  (and _down / PsiMfdWheelDown).
// A plain binding, because the game drops added game2 lines when it rewrites user.bnd.
// Over the open MFD it scrolls the table; anywhere else it switches weapons, as the default binding does.
class PsiMfdWheel extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Wheel", 0.01);
	}

	function OnTimer() {
		if (message().name != "Wheel")
			return;
		local up = Object.InheritsFrom(self, Object.Named("PsiMfdWheelUp"));
		if (ND.psiMfdPanel && ND.psiMfdPanel.IsUnderMouse())
			ND.psiMfdPanel.Scroll(up ? -1 : 1);
		else
			Debug.Command("cycle_weapon " + (up ? 1 : -1));
		Object.Destroy(self);
	}
}

if (!("psiDisciplines" in ND))
	print("[psi_mfd] psi_autocast isn't loaded: enable it as well, or macros won't run");

ND.Archetype("PsiMfd", "ND", function(){ AddScript("PsiMfd"); });
ND.Archetype("PsiMfdWheelUp", "ND", function(){ AddScript("PsiMfdWheel"); });
ND.Archetype("PsiMfdWheelDown", "ND", function(){ AddScript("PsiMfdWheel"); });
