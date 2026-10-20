// psi_mfd_respec: development tool, never in a release build (build.py --dev only).
// Unlearns one discipline and refunds its cyber modules:
//   set psi_respec_power 17
//   summon_obj PsiMfdRespec
// Clears the discipline's bit in PsiPowerDesc / PsiPower2Desc (the learned-disciplines bit sets the MFD reads),
// written as the game's own debug menu writes them, and gives back the discipline's own cost on this difficulty
// (PsiMfdCost; tier unlocks aren't refunded) with add_pool, the game's cheat command, so "enable_cheats 1" must
// be on (that disables achievements). Nothing is refunded unless the bit really cleared.

class PsiMfdRespec extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Respec", 0.01);
	}

	function OnTimer() {
		if (message().name != "Respec")
			return;
		try {
			Respec();
		}
		catch (e) {
			print("[psi_respec] error: " + e);
		}
		Object.Destroy(self);
	}

	function Respec() {
		if (!Engine.ConfigIsDefined("psi_respec_power")) {
			print("[psi_respec] set psi_respec_power <discipline number> first");
			return;
		}
		local value = int_ref();
		Engine.ConfigGetInt("psi_respec_power", value);
		local power = value.tointeger();
		if (power < 1 || power > 39 || power % 8 == 0) {
			print("[psi_respec] " + power + " isn't a discipline number");
			return;
		}
		local prop = power < 32 ? "PsiPowerDesc" : "PsiPower2Desc";
		local bit = 1 << (power % 32);
		local bits = Property.Get("Player", prop);
		if (typeof bits != "integer") {
			print("[psi_respec] couldn't read " + prop);
			return;
		}
		if (!(bits & bit)) {
			print("[psi_respec] " + PsiMfdName(power) + " isn't learned");
			return;
		}
		Property.Set("Player", prop, "", bits & ~bit);
		local after = Property.Get("Player", prop);
		if (after != (bits & ~bit)) {
			print("[psi_respec] " + prop + " is still " + after + " after writing " + (bits & ~bit) + ": nothing refunded");
			return;
		}
		local refund = PsiMfdCost(power);
		local pool = Property.Get("Player", "ExP");
		Debug.Command("add_pool", refund);
		print("[psi_respec] unlearned " + PsiMfdName(power) + " (" + prop + " " + bits + " -> " + after + "); add_pool "
			+ refund + " (player ExP " + pool + " -> " + Property.Get("Player", "ExP") + ")");
	}
}

ND.Archetype("PsiMfdRespec", "ND", function(){ AddScript("PsiMfdRespec"); });
