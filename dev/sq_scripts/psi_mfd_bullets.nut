// psi_mfd_bullets: development tool, never in a release build (build.py --dev only).
// Puts a box of armor-piercing and a box of anti-personnel bullets straight into the player's inventory, 500
// bullets each unless psi_bullets_count says otherwise:
//   set psi_bullets_count 500
//   summon_obj PsiMfdBullets
// A box's StackCount is its bullet count (objname.str: "A box of %d armor-piercing bullets"). The archetypes
// don't carry StackCount, so each new box gets it added first, as the game's own debug menu adds a property
// before setting it.

// [archetype, the bullets' name in the game's text]
ND.psiMfdBulletBoxes <- [["AP Clip", "armor-piercing"], ["HE Clip", "anti-personnel"]];

class PsiMfdBullets extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Bullets", 0.01);
	}

	function OnTimer() {
		if (message().name != "Bullets")
			return;
		local count = 500;
		if (Engine.ConfigIsDefined("psi_bullets_count")) {
			local value = int_ref();
			Engine.ConfigGetInt("psi_bullets_count", value);
			count = value.tointeger();
		}
		if (count < 1)
			print("[psi_bullets] psi_bullets_count is " + count + ": nothing given");
		else {
			foreach (box in ND.psiMfdBulletBoxes) {
				try {
					Give(box[0], box[1], count);
				}
				catch (e) {
					print("[psi_bullets] " + box[0] + " error: " + e);
				}
			}
		}
		Object.Destroy(self);
	}

	function Give(archetype, kind, count) {
		local box = Object.Create(archetype);
		Property.Add(box, "StackCount");
		Property.Set(box, "StackCount", "", count);
		local stack = Property.Get(box, "StackCount");
		local added = ShockGame.AddInvObj(box);
		print("[psi_bullets] " + kind + " bullets: " + archetype + " " + box + " with StackCount " + stack
			+ ", AddInvObj returned " + added);
	}
}

ND.Archetype("PsiMfdBullets", "ND", function(){ AddScript("PsiMfdBullets"); });
