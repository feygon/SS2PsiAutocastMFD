// psi_mfd_probe: developer-only capability probe for psi_autocast_mfd. Not part of release builds.
//
// Four tests, each summoned from the console. Results print as "[psi_probe]" lines (console and kexengine.log).
//   summon_obj PsiProbeFiles    write a small .cmd file to several candidate paths and read each back
//   run psi\Probe_Run_All.cmd   try running each written file with run and exec, then print which ran
//   summon_obj PsiProbeBind     bind keypad 7, 8 and 9 from a script, three different ways
//   summon_obj PsiProbeUnbind   remove those three test bindings again
//   summon_obj PsiProbeMfd      open or close a test panel (it brings up the mouse cursor)

function PsiProbeLog(text) {
	print("[psi_probe] " + text);
}

// The game's own helpers (libs/helpers.nut) write with file() under "user:/"; the other paths are guesses.
// Each written file sets psi_probe_ran_<label>, which PsiProbeReport checks.
ND.psiProbeFiles <- [
	["a1", "user:/psi_probe_a1.cmd"],
	["a2", "user:/psi_probe_a2.cmd"],
	["a3", "user:/psi_probe_a3.cmd"],
	["b1", "user:/\\sq_cache\\psi_probe_b1.cmd"],
	["c", "psi\\psi_probe_c.cmd"],
	["d", "psi/psi_probe_d.cmd"],
	["e", "./psi/psi_probe_e.cmd"],
	["f", "psi_probe_f.cmd"],
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
		PsiProbeLog("files done. Next: run psi\\Probe_Run_All.cmd");
		Object.Destroy(self);
	}
}

class PsiProbeReport extends SqRootScript {
	function OnBeginScript() {
		// Commands from the run file are still being applied; give them a moment.
		SetOneShotTimer("Report", 0.5);
	}

	function OnTimer() {
		if (message().name != "Report")
			return;
		foreach (entry in ND.psiProbeFiles) {
			local ran = Engine.ConfigIsDefined("psi_probe_ran_" + entry[0]);
			PsiProbeLog("RESULT file " + entry[0] + ": " + (ran ? "RAN" : "did not run"));
		}
		Object.Destroy(self);
	}
}

// Each test binding runs the cancel action, which prints "[psi_autocast] cancel: ..." when pressed.
class PsiProbeBind extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Bind", 0.01);
	}

	function OnTimer() {
		if (message().name != "Bind")
			return;
		// 7: one command string with the quoted command inside it.
		Debug.Command("bind keypad_7 \"run psi\\actions\\Cancel_Macro.cmd\"");
		// 8: command name and arguments passed separately.
		Debug.Command("bind", "keypad_8 \"run psi\\actions\\Cancel_Macro.cmd\"");
		// 9: write the bind line to a file, then run the file (multi-word arguments work in .cmd files).
		local result = PsiProbeWrite("psi\\psi_probe_bind9.cmd", "bind keypad_9 \"run psi\\actions\\Cancel_Macro.cmd\"\n");
		PsiProbeLog("bind 9 file: " + result);
		Debug.Command("run psi\\psi_probe_bind9.cmd");
		PsiProbeLog("bindings sent. Press keypad 7, 8 and 9: each one that works prints a cancel line.");
		Object.Destroy(self);
	}
}

class PsiProbeUnbind extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Unbind", 0.01);
	}

	function OnTimer() {
		if (message().name != "Unbind")
			return;
		Debug.Command("unbind keypad_7");
		Debug.Command("unbind keypad_8");
		Debug.Command("unbind keypad_9");
		PsiProbeLog("test bindings removed");
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

// Is psi_autocast loaded alongside? (Tests whether modinfo "requirements" matters.)
PsiProbeLog("loaded; psi_autocast " + (("psiDisciplines" in ND) ? "is" : "is NOT") + " loaded");

ND.Archetype("PsiProbeFiles", "ND", function(){ AddScript("PsiProbeFiles"); });
ND.Archetype("PsiProbeReport", "ND", function(){ AddScript("PsiProbeReport"); });
ND.Archetype("PsiProbeBind", "ND", function(){ AddScript("PsiProbeBind"); });
ND.Archetype("PsiProbeUnbind", "ND", function(){ AddScript("PsiProbeUnbind"); });
ND.Archetype("PsiProbeMfd", "ND", function(){ AddScript("PsiProbeMfd"); });
