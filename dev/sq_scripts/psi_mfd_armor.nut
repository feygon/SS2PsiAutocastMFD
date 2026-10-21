// psi_mfd_armor: development tool, never in a release build (build.py --dev only).
// Puts on a piece of armor from the player's inventory, taking off the armor being worn first:
//   set psi_wear_armor 6
//   summon_obj PsiMfdWearArmor
// Numbers: 1 Light Armor, 2 Medium Armor, 3 Heavy Armor, 4 Vacc Suit (the hazard suit), 5 Reflec Armor (its script
// is PoweredArmor), 6 Worm Skin.
// Remembers the armor being worn, and puts that kind back on later, after other armor went on in between:
//   summon_obj PsiMfdRememberArmor
//   summon_obj PsiMfdRestoreArmor
// The memory is a campaign quest variable, psi_mfd_saved_armor (the armor's number, 0 for none), so it's saved with
// the game and kept across loads and decks. Restoring sets it back to 0 once that armor is on.
// Wears the worm skin while psi_autocast macros run, through psi_autocast's PsiMacroStarted / PsiMacroEnded hooks
// (every cast and chain, so not C's bullets): see PsiMacroStarted below.
//
// The console's use_obj doesn't put armor on (it does nothing, or shows the worm skin's research report), so this
// calls ShockGame.Equip on the armor slot. What the game does, from the logs (DEVELOPMENT.md): Equip(slot, null)
// lets go of the old armor entirely; equipping pushes out anything else held in the slot; and AddInvObj puts
// armor into the armor slot when it's empty. So the old armor comes off first, the new one goes on, and only then
// does the old one go back into the inventory, into the cell the new one left (it works with a full inventory).

const PSI_MFD_ARMOR_SLOT = 2;   // kEquipArmor: third in the game's slot list, after kEquipWeapon and kEquipWeaponAlt
const PSI_MFD_SAVED_ARMOR = "psi_mfd_saved_armor";

ND.psiMfdArmors <- ["Light Armor", "Medium Armor", "Heavy Armor", "Vacc Suit", "Reflec Armor", "Worm Skin"];

// Takes off worn (0 when nothing is worn), puts on armor from the inventory, then puts worn back into the
// inventory. True when armor is worn at the end.
function PsiMfdSwapArmor(player, worn, armor) {
	print("[psi_armor] before: wearing " + PsiMfdDescribeHeld(player, worn) + "; putting on "
		+ PsiMfdDescribeHeld(player, armor));
	if (worn) {
		ShockGame.Equip(PSI_MFD_ARMOR_SLOT, null);
		if (ShockGame.Equipped(PSI_MFD_ARMOR_SLOT)) {
			print("[psi_armor] the armor slot didn't empty: stopped");
			return false;
		}
	}
	ShockGame.Equip(PSI_MFD_ARMOR_SLOT, armor);
	ShockGame.RecalcStats("Player");
	local now = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	print("[psi_armor] now wearing " + PsiMfdDescribeHeld(player, now));
	if (worn) {
		local added = ShockGame.AddInvObj(worn);
		print("[psi_armor] AddInvObj returned " + added + ": old armor " + PsiMfdDescribeHeld(player, worn));
		local held = PsiMfdHeldAs(player, worn);
		if (held == null)
			print("[psi_armor] you no longer hold the old armor: reload your quicksave");
		else if (held >= 1000)
			print("[psi_armor] the old armor isn't in an inventory cell: reload your quicksave");
	}
	return now == armor;
}

// Puts on armor number n (1 is ND.psiMfdArmors[0]); true when that kind of armor is worn at the end.
function PsiMfdWearArmorNumber(n) {
	local name = ND.psiMfdArmors[n - 1];
	local player = ND.g_PlayerCore.GetPlayer();
	local worn = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	if (worn && Object.InheritsFrom(worn, name)) {
		print("[psi_armor] already wearing " + name);
		return true;
	}
	local armor = PsiMfdFindArmor(player, name, worn);
	if (!armor) {
		print("[psi_armor] no " + name + " in your inventory");
		return false;
	}
	return PsiMfdSwapArmor(player, worn, armor);
}

// The first armor of this kind the player holds, other than the one being worn; 0 if none.
function PsiMfdFindArmor(player, name, worn) {
	foreach (l in Link.GetAll(LinkTools.LinkKindNamed("Contains"), player, 0)) {
		local obj = LinkDest(l);
		if (obj != worn && Object.InheritsFrom(obj, name))
			return obj;
	}
	return 0;
}

// How the player holds obj: the Contains link's value, an inventory cell (11, 13) or 1000 + the slot when worn
// (1002 for armor); null when the player doesn't hold it.
function PsiMfdHeldAs(player, obj) {
	foreach (l in Link.GetAll(LinkTools.LinkKindNamed("Contains"), player, obj))
		return LinkTools.LinkGetData(l, "ordinal");
	return null;
}

// For the log: "Worm Skin 147 (Contains 13)", the object and how the player holds it. Never throws, so a log
// line can't stop a swap halfway.
function PsiMfdDescribeHeld(player, obj) {
	if (!obj)
		return "nothing";
	local text = "" + obj;
	try {
		text = ND.GetArchetypeName(obj) + " " + obj;
		local held = PsiMfdHeldAs(player, obj);
		text += held == null ? " (not held)" : " (Contains " + held + ")";
	}
	catch (e) {
		text += " (" + e + ")";
	}
	return text;
}

// The number of the armor being worn (1 to 6), or 0 when none or a kind this tool doesn't know.
function PsiMfdWornArmorNumber() {
	local worn = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	if (worn) {
		foreach (i, name in ND.psiMfdArmors) {
			if (Object.InheritsFrom(worn, name))
				return i + 1;
		}
	}
	return 0;
}

// ---- the worm skin while macros run ------------------------------------------------------------------------
// When the first psi_autocast macro (cast or chain) starts, the worm skin goes on, unless it's already on or isn't
// in the inventory. Half a second after the last one ends, the armor worn before goes back on; with no armor worn
// before, the worm skin stays on (armor only leaves the slot when other armor takes its place). macros: the casts
// and chains running; before: the armor to put back (0 when none was worn), or null when nothing was changed.
ND.psiMfdMacroArmor <- { macros = [], before = null };

// The running macros, without except and without any that ended without saying so (a level change destroys them).
function PsiMfdRunningMacros(except) {
	local running = [];
	foreach (id in ND.psiMfdMacroArmor.macros) {
		if (id != except && Object.Exists(id))
			running.push(id);
	}
	return running;
}

function PsiMacroStarted(obj) {
	local state = ND.psiMfdMacroArmor;
	local running = PsiMfdRunningMacros(obj);
	running.push(obj);
	state.macros = running;
	if (running.len() > 1 || state.before != null)
		return;   // an earlier macro already put the worm skin on
	local player = ND.g_PlayerCore.GetPlayer();
	local worn = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	if (worn && Object.InheritsFrom(worn, "Worm Skin"))
		return;
	local skin = PsiMfdFindArmor(player, "Worm Skin", worn);
	if (!skin)
		return;
	print("[psi_armor] macro starting: putting on the worm skin");
	if (PsiMfdSwapArmor(player, worn, skin))
		state.before = worn ? worn : 0;
}

function PsiMacroEnded(obj) {
	local state = ND.psiMfdMacroArmor;
	state.macros = PsiMfdRunningMacros(obj);
	// Not at once: Debug.Command only queues console commands, so the cast's fire_weapon 0 hasn't happened yet.
	if (state.macros.len() == 0 && state.before != null)
		Object.Create("PsiMfdArmorBack");
}

// Puts the armor worn before the macros back on, unless another macro has started since.
function PsiMfdPutBackArmor() {
	local state = ND.psiMfdMacroArmor;
	state.macros = PsiMfdRunningMacros(0);
	if (state.macros.len() > 0 || state.before == null)
		return;
	local before = state.before;
	state.before = null;
	if (!before) {
		print("[psi_armor] macros done: no armor was worn before them, so the worm skin stays on");
		return;
	}
	local player = ND.g_PlayerCore.GetPlayer();
	local worn = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	if (worn == before)
		return;
	local held = PsiMfdHeldAs(player, before);
	if (held == null || held >= 1000) {
		print("[psi_armor] macros done: the armor worn before isn't in your inventory: " + PsiMfdDescribeHeld(player, before));
		return;
	}
	print("[psi_armor] macros done: putting the armor worn before back on");
	PsiMfdSwapArmor(player, worn, before);
}

class PsiMfdArmorBack extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("ArmorBack", 0.5);
	}

	function OnTimer() {
		if (message().name != "ArmorBack")
			return;
		try {
			PsiMfdPutBackArmor();
		}
		catch (e) {
			print("[psi_armor] error: " + e);
		}
		Object.Destroy(self);
	}
}

// ---- console tools -----------------------------------------------------------------------------------------

// Runs once, just after it's summoned, then removes itself. Each tool below defines Run().
class PsiMfdArmorTool extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("ArmorTool", 0.01);
	}

	function OnTimer() {
		if (message().name != "ArmorTool")
			return;
		try {
			Run();
		}
		catch (e) {
			print("[psi_armor] error: " + e);
		}
		Object.Destroy(self);
	}
}

class PsiMfdWearArmor extends PsiMfdArmorTool {
	function Run() {
		local count = ND.psiMfdArmors.len();
		if (!Engine.ConfigIsDefined("psi_wear_armor")) {
			print("[psi_armor] set psi_wear_armor <1-" + count + "> first");
			return;
		}
		local value = int_ref();
		Engine.ConfigGetInt("psi_wear_armor", value);
		local n = value.tointeger();
		if (n < 1 || n > count) {
			print("[psi_armor] psi_wear_armor is " + n + ": use 1-" + count);
			return;
		}
		PsiMfdWearArmorNumber(n);
	}
}

class PsiMfdRememberArmor extends PsiMfdArmorTool {
	function Run() {
		local n = PsiMfdWornArmorNumber();
		Quest.Set(PSI_MFD_SAVED_ARMOR, n, eQuestDataType.kQuestDataCampaign);
		if (n)
			print("[psi_armor] remembered " + ND.psiMfdArmors[n - 1]);
		else
			print("[psi_armor] not wearing armor this tool knows: nothing remembered");
	}
}

class PsiMfdRestoreArmor extends PsiMfdArmorTool {
	function Run() {
		local n = Quest.Exists(PSI_MFD_SAVED_ARMOR) ? Quest.Get(PSI_MFD_SAVED_ARMOR) : 0;
		if (n < 1 || n > ND.psiMfdArmors.len()) {
			print("[psi_armor] no armor remembered");
			return;
		}
		print("[psi_armor] restoring " + ND.psiMfdArmors[n - 1]);
		if (PsiMfdWearArmorNumber(n))
			Quest.Set(PSI_MFD_SAVED_ARMOR, 0, eQuestDataType.kQuestDataCampaign);
	}
}

ND.Archetype("PsiMfdArmorBack", "ND", function(){ AddScript("PsiMfdArmorBack"); });
ND.Archetype("PsiMfdWearArmor", "ND", function(){ AddScript("PsiMfdWearArmor"); });
ND.Archetype("PsiMfdRememberArmor", "ND", function(){ AddScript("PsiMfdRememberArmor"); });
ND.Archetype("PsiMfdRestoreArmor", "ND", function(){ AddScript("PsiMfdRestoreArmor"); });
