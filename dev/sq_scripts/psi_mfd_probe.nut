// psi_mfd_probe: developer-only capability probe for psi_autocast_mfd. Not part of release builds.
//
// Tests, each summoned from the console. Results print as "[psi_probe]" lines (console and kexengine.log).
//   summon_obj PsiProbeFiles    write a small .cmd file to several candidate paths and read each back
//   summon_obj PsiProbeMfd      open or close a test panel (it brings up the mouse cursor)
//   summon_obj PsiProbeData     print every discipline's power data, duration and projectile damage
// Results so far are in DEVELOPMENT.md. Binding keys from a script was tested and isn't possible.

function PsiProbeLog(text) {
	print("[psi_probe] " + text);
}

// The game's own helpers (libs/helpers.nut) write with file() under "user:/"; the other paths are guesses.
// Each written file sets psi_probe_ran_<label> when run.
// Round 1 (2026-10-16): only "user:/\\sq_cache\\<name>" could be written, and it landed in the save folder root. Round 2: every form writing into psi_macros (an existing subfolder) failed.
// Round 3: sq_cache seems to be the one writable location, mapped onto the save folder root, so go through it.
ND.psiProbeFiles <- [
	["x1", "user:/\\sq_cache\\psi_macros\\psi_probe_x1.cmd"],   // existing subfolder, backslash
	["x2", "user:/\\sq_cache\\psi_macros/psi_probe_x2.cmd"],    // existing subfolder, forward slash
	["x3", "user:/\\sq_cache\\psi_newdir\\psi_probe_x3.cmd"],   // subfolder that doesn't exist
	["x4", "user:/sq_cache/psi_macros/psi_probe_x4.cmd"],       // all forward slashes
	["x5", "user:/\\psi_probe_x5.cmd"],                         // plain root form, never tried
	["x6", "user:/\\sq_cache\\psi_probe_x6.cmd"],               // control: the form that worked in round 1
];

function PsiProbeWrite(path, text) {
	try {
		local out = file(path, "w");
		foreach (c in text)
			out.writen(c, 'c');
		out.close();
		local back = file(path, "r");
		local size = back.len();
		back.close();
		return "written and read back, " + size + " bytes";
	}
	catch (e) {
		return "FAILED: " + e;
	}
}

class PsiProbeFiles extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Write", 0.01);
	}

	function OnTimer() {
		if (message().name != "Write")
			return;
		foreach (entry in ND.psiProbeFiles) {
			local text = "echo psi_probe file " + entry[0] + " ran\nset psi_probe_ran_" + entry[0] + " 1\n";
			PsiProbeLog("file " + entry[0] + " (" + entry[1] + "): " + PsiProbeWrite(entry[1], text));
		}
		PsiProbeLog("files done");
		Object.Destroy(self);
	}
}

// Test panel, built on the remaster's own UI library (libs/ui.nut), drawn by its UiHandler.
ND.psiProbeMfdOpen <- false;
ND.psiProbePanel <- null;

class PsiProbePanel extends ND.UiBase {
	m_status = null;
	m_field = null;
	m_clicks = 0;

	constructor() {
		local width = 260;
		local height = 110;
		base.constructor((ND.GetCanvasSize().x / 2) - width / 2, (ND.GetCanvasSize().y / 2) - height / 2, width, height);
		SetName("PsiProbePanel");
		SetBackground("ND-bg_base");
		AddChild(ND.UiText(8, 8).Set("psi_autocast MFD probe", 0.8, 0.8, 0.8));

		m_status = ND.UiText(8, 24);
		m_status.Set("clicks: 0", 0.7, 0.7, 0.7);
		AddChild(m_status);

		AddChild(ND.UiButton("Click me", 8, 42, this, function() {
			m_clicks++;
			m_status.Set("clicks: " + m_clicks, 0.6, 0.9, 0.6);
			PsiProbeLog("panel button clicked, " + m_clicks);
		}));
		AddChild(ND.UiButton("Close", 200, 42, this, function() {
			ND.psiProbeMfdOpen = false;
			PsiProbeLog("panel closed");
		}));

		m_field = ND.UiEditableField("string");
		m_field.Set("");
		m_field.SetPos(8, 62);
		m_field.SetSize(160, 14);
		m_field.Subscribe("ValueChange", this);
		AddChild(m_field);
		AddChild(ND.UiText(8, 82).Set("Click the box, type, press Enter", 0.5, 0.5, 0.5));
	}

	function OnValueChange(message) {
		m_status.Set("typed: " + m_field.m_fieldValue, 0.6, 0.9, 0.6);
		PsiProbeLog("typed: '" + m_field.m_fieldValue + "'");
	}

	// The UI handler sends key events to whatever is under the mouse.
	function OnInput(message) {
		PsiProbeLog("key over panel: ch " + message.data + ", keycode " + message.data2);
	}
}

// Shows the panel only while it's open and the mouse cursor is up.
class PsiProbeMfdHandler {
	m_name = "PsiProbeMfdHandler";

	function OnFrameUpdate(deltaTime) {
		if (ND.psiProbePanel)
			ND.psiProbePanel.SetActive(ND.psiProbeMfdOpen && ShockGame.MouseCursor());
	}
}

ND.g_PlayerCore.AddHandler(PsiProbeMfdHandler());

class PsiProbeMfd extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Toggle", 0.01);
	}

	function OnTimer() {
		if (message().name != "Toggle")
			return;
		if (!ND.psiProbePanel) {
			ND.psiProbePanel = PsiProbePanel();
			ND.g_PlayerCore.InternalMessage("RegisterRootUi", ND.psiProbePanel);
		}
		ND.psiProbeMfdOpen = !ND.psiProbeMfdOpen;
		if (ND.psiProbeMfdOpen && !ShockGame.MouseCursor())
			Debug.Command("toggle_mouse");
		PsiProbeLog("panel " + (ND.psiProbeMfdOpen ? "opened" : "closed") + ", mouse cursor " + ShockGame.MouseCursor());
		Object.Destroy(self);
	}
}

// Psi power data, read from the running gamesys (SCP or not), for the MFD's duration and damage cells.
// Internal archetype names per discipline number, from P$SymName in shockscp.gam (2026-10-16).
ND.psiProbePowerObjects <- {
	[1] = "Low Grav", [2] = "Still Hand", [3] = "PsiPull", [4] = "Quickness", [5] = "Cyber", [6] = "Cryokinesis", [7] = "Codebreaker",
	[9] = "Stability", [10] = "Berserk", [11] = "Rad Shield", [12] = "PsiHeal", [13] = "Might", [14] = "PsiImage", [15] = "Immolate",
	[17] = "Fabricate", [18] = "ElectroPsi", [19] = "AntiPsi", [20] = "Toxin Shield", [21] = "Radar", [22] = "Pyrokinesis", [23] = "Terror",
	[25] = "Inviso", [26] = "Seekersense", [27] = "Electro Dampen", [28] = "Vitality", [29] = "Alchemy", [30] = "CyberHack", [31] = "Psi Sword",
	[33] = "Major Heal", [34] = "SomaDrain", [35] = "Teleport", [36] = "PsiCharm", [37] = "ForceWall", [38] = "PsiMines", [39] = "PsiShield",
};

function PsiProbeStims(obj) {
	local text = "";
	foreach (l in Link.GetAll("arSrcDesc", obj, 0)) {
		local link = sLink(l);
		text += (text.len() ? ", " : "") + Object.GetName(link.dest) + " " + LinkTools.LinkGetData(l, "Intensity");
	}
	return text.len() ? text : "none";
}

class PsiProbeData extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Dump", 0.01);
	}

	function OnTimer() {
		if (message().name != "Dump")
			return;
		PsiProbeLog("DATA player PSI " + ShockGame.GetStat("Player", eStats.kStatPsi));
		local ids = [];
		foreach (id, name in ND.psiProbePowerObjects)
			ids.push(id);
		ids.sort();
		foreach (id in ids) {
			local name = ND.psiProbePowerObjects[id];
			local obj = Object.Named(name);
			if (!obj) {
				PsiProbeLog("DATA " + id + " " + name + ": NOT FOUND");
				continue;
			}
			local line = "DATA " + id + " " + name + ":";
			if (Property.Possessed(obj, "PsiPower"))
				line += " power " + Property.Get(obj, "PsiPower", "Power") + ", type " + Property.Get(obj, "PsiPower", "Type")
					+ ", cost " + Property.Get(obj, "PsiPower", "Start Cost")
					+ ", data " + Property.Get(obj, "PsiPower", "Data 1") + " / " + Property.Get(obj, "PsiPower", "Data 2")
					+ " / " + Property.Get(obj, "PsiPower", "Data 3") + " / " + Property.Get(obj, "PsiPower", "Data 4");
			if (Property.Possessed(obj, "PsiShield"))
				line += "; time " + Property.Get(obj, "PsiShield", "Base Time") + " + " + Property.Get(obj, "PsiShield", "Add Time")
					+ " per PSI, int " + Property.Get(obj, "PsiShield", "Base Int");
			line += "; own stims " + PsiProbeStims(obj);
			PsiProbeLog(line);
			foreach (l in Link.GetAll("Projectile", obj, 0)) {
				local proj = sLink(l).dest;
				PsiProbeLog("DATA   " + id + " projectile " + Object.GetName(proj) + ": " + PsiProbeStims(proj));
			}
		}
		PsiProbeLog("DATA done");
		Object.Destroy(self);
	}
}

// Is psi_autocast loaded alongside? (Tests whether modinfo "requirements" matters.)
PsiProbeLog("loaded; psi_autocast " + (("psiDisciplines" in ND) ? "is" : "is NOT") + " loaded");

ND.Archetype("PsiProbeFiles", "ND", function(){ AddScript("PsiProbeFiles"); });
ND.Archetype("PsiProbeData", "ND", function(){ AddScript("PsiProbeData"); });
ND.Archetype("PsiProbeMfd", "ND", function(){ AddScript("PsiProbeMfd"); });
