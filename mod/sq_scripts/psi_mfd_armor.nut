// psi_mfd_armor: the worm skin swap. With "Worm skin swap" on in the MFD, every psi_autocast macro (cast or chain)
// wears the worm skin while it runs, through psi_autocast's PsiMacroStarted / PsiMacroEnded hooks. When the first
// macro starts, the worm skin goes on, unless it's already on or isn't in the inventory. Half a second after the last
// one ends, the armor worn before goes back on; with no armor worn before, the worm skin stays on (armor only leaves
// the slot when other armor takes its place). After a discipline cast onto an item you click (Molecular Duplication,
// Electron Cascade, Molecular Transmutation), the armor waits for that click: see PsiMfdArmorBack.
//
// What the game does when a script changes armor, from the logs (DEVELOPMENT.md): Equip(slot, null) lets go of the
// old armor entirely; equipping pushes out anything else held in the slot; and AddInvObj puts armor into the armor
// slot when it's empty. So the old armor comes off first, the new one goes on, and only then does the old one go back
// into the inventory, into the cell the new one left (it works with a full inventory).

const PSI_MFD_ARMOR_SLOT = 2;   // kEquipArmor: third in the game's slot list, after kEquipWeapon and kEquipWeaponAlt

// Takes off worn (0 when nothing is worn), puts on armor from the inventory, then puts worn back into the
// inventory. True when armor is worn at the end.
function PsiMfdSwapArmor(player, worn, armor) {
	if (worn) {
		ShockGame.Equip(PSI_MFD_ARMOR_SLOT, null);
		if (ShockGame.Equipped(PSI_MFD_ARMOR_SLOT)) {
			print("[psi_mfd] worm skin swap: the armor slot didn't empty, so nothing changed");
			return false;
		}
	}
	ShockGame.Equip(PSI_MFD_ARMOR_SLOT, armor);
	ShockGame.RecalcStats("Player");
	local now = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	if (worn) {
		ShockGame.AddInvObj(worn);
		local held = PsiMfdHeldAs(player, worn);
		if (held == null || held >= 1000)
			print("[psi_mfd] worm skin swap: the armor taken off isn't in an inventory cell: " + PsiMfdDescribeHeld(player, worn));
	}
	print("[psi_mfd] worm skin swap: " + PsiMfdDescribeHeld(player, worn) + " -> " + PsiMfdDescribeHeld(player, now));
	return now == armor;
}

// The first armor of this kind the player holds, other than the one being worn; 0 if none. sLink, not LinkDest:
// LinkDest belongs to script objects, and psi_autocast's hooks call this from outside one.
function PsiMfdFindArmor(player, name, worn) {
	foreach (l in Link.GetAll(LinkTools.LinkKindNamed("Contains"), player, 0)) {
		local obj = sLink(l).dest;
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

// macros: the casts and chains running; before: the armor to put back (0 when none was worn), or null when nothing
// was changed; targeting: a target discipline was cast; released: the last psi_autocast release count seen.
ND.psiMfdMacroArmor <- { macros = [], before = null, targeting = false, released = null };

// Disciplines cast first and then clicked onto an item (PsiPower Type 4 in the gamesys): 17 Molecular Duplication,
// 18 Electron Cascade, 29 Molecular Transmutation.
ND.psiMfdTargetPowers <- [17, 18, 29];
const PSI_MFD_TARGET_WAIT_MS = 10000;   // how long to wait for the cursor to come up for that click

// What the player holds, as text: each held object and its stack count, sorted. It changes when the item clicked
// after a target discipline is used up or copied (Molecular Transmutation's item turns into nanites).
function PsiMfdInventoryPrint(player) {
	local held = [];
	foreach (l in Link.GetAll(LinkTools.LinkKindNamed("Contains"), player, 0)) {
		local obj = sLink(l).dest;
		local stack = Property.Get(obj, "StackCount");
		held.push(obj + ":" + (stack == null ? "-" : stack));
	}
	held.sort();
	local text = "";
	foreach (item in held)
		text += item + ",";
	return text;
}

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
	if (!PsiMfdWormSkinSwapOn())
		return;   // the player hasn't chosen the swap
	state.targeting = false;
	local player = ND.g_PlayerCore.GetPlayer();
	local worn = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	if (worn && Object.InheritsFrom(worn, "Worm Skin"))
		return;
	local skin = PsiMfdFindArmor(player, "Worm Skin", worn);
	if (!skin)
		return;
	if (PsiMfdSwapArmor(player, worn, skin))
		state.before = worn ? worn : 0;
}

function PsiMacroEnded(obj) {
	local state = ND.psiMfdMacroArmor;
	state.macros = PsiMfdRunningMacros(obj);
	// A cast that just released a target discipline: the armor waits for its click.
	if (("psiCastsReleased" in ND) && ND.psiCastsReleased != state.released) {
		state.released = ND.psiCastsReleased;
		if (("psiLastReleasedPower" in ND) && ND.psiMfdTargetPowers.find(ND.psiLastReleasedPower) != null)
			state.targeting = true;
	}
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
	state.targeting = false;
	if (!before)
		return;   // no armor was worn before: the worm skin stays on
	local player = ND.g_PlayerCore.GetPlayer();
	local worn = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
	if (worn == before)
		return;
	local held = PsiMfdHeldAs(player, before);
	if (held == null || held >= 1000) {
		print("[psi_mfd] worm skin swap: the armor worn before isn't in your inventory any more: " + PsiMfdDescribeHeld(player, before));
		return;
	}
	PsiMfdSwapArmor(player, worn, before);
}

// Puts the armor worn before back on, half a second after the last macro ended. After a target discipline, it waits
// for the click: until the inventory changes (the clicked item used up or copied), or, when it doesn't (Electron
// Cascade only recharges), until the cursor is down, waiting up to PSI_MFD_TARGET_WAIT_MS for it to come up.
class PsiMfdArmorBack extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("ArmorBack", 0.5);
		SetData("WaitedMs", 500);
		SetData("SawCursor", 0);
	}

	function OnTimer() {
		if (message().name != "ArmorBack")
			return;
		if (ND.psiMfdMacroArmor.targeting && PsiMfdRunningMacros(0).len() == 0) {
			local waited = GetData("WaitedMs");
			local inventory = PsiMfdInventoryPrint(ND.g_PlayerCore.GetPlayer());
			if (waited == 500)
				SetData("Inventory", inventory);
			local clicked = inventory != GetData("Inventory");
			local cursor = ShockGame.MouseCursor();
			if (cursor)
				SetData("SawCursor", 1);
			if (!clicked && (cursor || (!GetData("SawCursor") && waited < PSI_MFD_TARGET_WAIT_MS))) {
				SetData("WaitedMs", waited + 250);
				SetOneShotTimer("ArmorBack", 0.25);
				return;
			}
		}
		try {
			PsiMfdPutBackArmor();
		}
		catch (e) {
			print("[psi_mfd] worm skin swap error: " + e);
		}
		Object.Destroy(self);
	}
}

ND.Archetype("PsiMfdArmorBack", "ND", function(){ AddScript("PsiMfdArmorBack"); });
