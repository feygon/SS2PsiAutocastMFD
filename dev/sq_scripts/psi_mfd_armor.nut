// psi_mfd_armor: development tool, never in a release build (build.py --dev only).
// Puts on a piece of armor from the player's inventory, taking off the armor being worn first:
//   set psi_wear_armor 6
//   summon_obj PsiMfdWearArmor
// Numbers: 1 Light Armor, 2 Medium Armor, 3 Heavy Armor, 4 Vacc Suit (the hazard suit), 5 Reflec Armor (its script
// is PoweredArmor), 6 Worm Skin.
// The console's use_obj doesn't put armor on (it does nothing, or shows the worm skin's research report), so this
// calls ShockGame.Equip on the armor slot. ShockGame.Equip(0, weapon) straight over a held weapon left the old one
// unequippable until a reload, so the worn armor always comes off first: Equip(slot, null), as the game's cutscene
// code clears the weapon slot, then RemoveFromContainer. The new armor goes on, and only then does the old one go
// back into the inventory with AddInvObj (added while the slot was empty, it came back in the slot). Every step is
// logged; the log says to reload the quicksave if the old armor didn't reach an inventory cell.

const PSI_MFD_ARMOR_SLOT = 2;   // kEquipArmor: third in the game's slot list, after kEquipWeapon and kEquipWeaponAlt

ND.psiMfdArmors <- ["Light Armor", "Medium Armor", "Heavy Armor", "Vacc Suit", "Reflec Armor", "Worm Skin"];

class PsiMfdWearArmor extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("WearArmor", 0.01);
	}

	function OnTimer() {
		if (message().name != "WearArmor")
			return;
		try {
			Wear();
		}
		catch (e) {
			print("[psi_armor] error: " + e);
		}
		Object.Destroy(self);
	}

	function Wear() {
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
		local name = ND.psiMfdArmors[n - 1];
		local player = ND.g_PlayerCore.GetPlayer();
		local worn = ShockGame.Equipped(PSI_MFD_ARMOR_SLOT);
		if (worn && Object.InheritsFrom(worn, name)) {
			print("[psi_armor] already wearing " + name);
			return;
		}
		local armor = Find(player, name, worn);
		if (!armor) {
			print("[psi_armor] no " + name + " in your inventory");
			return;
		}
		print("[psi_armor] before: wearing " + Describe(player, worn) + "; putting on " + Describe(player, armor));
		if (worn) {
			ShockGame.Equip(PSI_MFD_ARMOR_SLOT, null);
			if (ShockGame.Equipped(PSI_MFD_ARMOR_SLOT)) {
				print("[psi_armor] the armor slot didn't empty: stopped");
				return;
			}
			print("[psi_armor] slot emptied: old armor " + Describe(player, worn));
			try {
				ShockGame.RemoveFromContainer(worn, player);
			}
			catch (e) {
				print("[psi_armor] RemoveFromContainer failed: " + e);
			}
			print("[psi_armor] let go: old armor " + Describe(player, worn));
		}
		ShockGame.Equip(PSI_MFD_ARMOR_SLOT, armor);
		ShockGame.RecalcStats("Player");
		print("[psi_armor] now wearing " + Describe(player, ShockGame.Equipped(PSI_MFD_ARMOR_SLOT))
			+ (worn ? "; old armor " + Describe(player, worn) : ""));
		if (worn) {
			// Only now, with the new armor in the slot: emptying the slot, letting go and AddInvObj left the old
			// armor at Contains 1002 again (2026-10-21, with plenty of room), and the swap stopped.
			local added = ShockGame.AddInvObj(worn);
			print("[psi_armor] AddInvObj returned " + added + ": old armor " + Describe(player, worn));
			local held = HeldAs(player, worn);
			if (held == null)
				print("[psi_armor] you no longer hold the old armor: reload your quicksave");
			else if (held >= 1000)
				print("[psi_armor] the old armor isn't in an inventory cell: reload your quicksave");
		}
	}

	// The first armor of this kind the player holds, other than the one being worn; 0 if none.
	function Find(player, name, worn) {
		foreach (l in Link.GetAll(LinkTools.LinkKindNamed("Contains"), player, 0)) {
			local obj = LinkDest(l);
			if (obj != worn && Object.InheritsFrom(obj, name))
				return obj;
		}
		return 0;
	}

	// How the player holds obj: the Contains link's value, an inventory cell (11, 13) or 1000 + the slot when worn
	// (1002 for armor); null when the player doesn't hold it.
	function HeldAs(player, obj) {
		foreach (l in Link.GetAll(LinkTools.LinkKindNamed("Contains"), player, obj))
			return LinkTools.LinkGetData(l, "ordinal");
		return null;
	}

	// For the log: "Worm Skin 147 (Contains 13)", the object and how the player holds it. Never throws, so a log
	// line can't stop a swap halfway.
	function Describe(player, obj) {
		if (!obj)
			return "nothing";
		local text = "" + obj;
		try {
			text = ND.GetArchetypeName(obj) + " " + obj;
			local held = HeldAs(player, obj);
			text += held == null ? " (not held)" : " (Contains " + held + ")";
		}
		catch (e) {
			text += " (" + e + ")";
		}
		return text;
	}
}

ND.Archetype("PsiMfdWearArmor", "ND", function(){ AddScript("PsiMfdWearArmor"); });
