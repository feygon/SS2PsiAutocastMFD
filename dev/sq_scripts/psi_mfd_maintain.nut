// psi_mfd_maintain: development tool, never in a release build (build.py --dev only).
// Uses one maintenance tool from the inventory on the weapon in hand:
//   summon_obj PsiMfdMaintainWeapon
// A script can't send the maintenance tool the frob it gets when dropped on a weapon, so this applies the rules of
// SCP's scpWrench, the Maintenance Tool's script with SCP on (mods\scp.kpf, sq_scripts\scpScript.nut). Nothing
// happens to a gun that's unresearched, broken, needs more Maintenance than the player's base skill, or is above
// 90% condition. Otherwise its condition rises 10% per point of skill, up to 100%, and one tool is used up (one
// from a stack, or the last one), with the tool's activate sound. The messages are SCP's own strings.

const PSI_MFD_MAINT_PER_SKILL = 10.0;    // condition % per point of Maintenance skill
const PSI_MFD_MAINT_UNUSED_ABOVE = 90;   // above this condition % the tool isn't used

// Shows SCP's message strID from misc.str (value fills its %d), or text when the string isn't there.
function PsiMfdMaintainSay(strID, text, value = "") {
	local found = Data.GetString("misc", strID, "");
	local msg = found != "" ? format(found, value) : text;
	print("[psi_maintain] " + msg);
	ShockGame.AddText(msg, "Player");
}

// The first maintenance tool the player holds; 0 if none.
function PsiMfdFindMaintenanceTool(player) {
	foreach (l in Link.GetAll(LinkTools.LinkKindNamed("Contains"), player, 0)) {
		local obj = sLink(l).dest;
		if (Object.InheritsFrom(obj, "Maintenance Tool"))
			return obj;
	}
	return 0;
}

// Uses up one of obj, as SCP's scp.Consume does: one from a stack, or obj itself when it's the last.
function PsiMfdUseUpOne(obj) {
	local count = 0;
	if (Property.Possessed(obj, "StackCount")) {
		Container.StackAdd(obj, -1);
		count = Property.Get(obj, "StackCount");
	}
	if (count == 0)
		ShockGame.DestroyInvObj(obj);
}

function PsiMfdMaintainHeldWeapon() {
	local weapon = ShockGame.Equipped(ePlayerEquip.kEquipWeapon);
	if (!weapon) {
		print("[psi_maintain] no weapon in hand");
		return;
	}
	if (!ShockGame.ValidGun(weapon)) {
		PsiMfdMaintainSay("WrenchOnNonGun", "Maintenance tools only work on guns.");
		return;
	}
	local tool = PsiMfdFindMaintenanceTool(ND.g_PlayerCore.GetPlayer());
	if (!tool) {
		print("[psi_maintain] no maintenance tool in your inventory");
		ShockGame.AddText("No maintenance tool in your inventory.", "Player");
		return;
	}
	local skill = Property.Get("Player", "BaseTechDesc", "Maintain");
	local required = Property.Get(weapon, "ReqTechDesc", "Maintain");
	if (!required)
		required = 1;
	local state = Property.Get(weapon, "ObjState");
	local hp = Property.Get(weapon, "GunState", "Condition (%)");
	if (state == eObjState.kObjStateUnresearched)
		PsiMfdMaintainSay("WrenchUnresearched", "Research this weapon first.");
	else if (state == eObjState.kObjStateBroken)
		PsiMfdMaintainSay("WrenchOnBroken", "This weapon is broken: it needs repairing, not maintenance.");
	else if (skill < required)
		PsiMfdMaintainSay("WrenchSkillReq", "This weapon needs Maintenance " + required + ".", required);
	else if (hp > PSI_MFD_MAINT_UNUSED_ABOVE)
		PsiMfdMaintainSay("WrenchUnused", "This weapon is already in good condition.");
	else if (state == eObjState.kObjStateNormal) {
		local after = hp + skill * PSI_MFD_MAINT_PER_SKILL;
		after = after > 100.0 ? 100.0 : after;
		Property.Set(weapon, "GunState", "Condition (%)", after);
		Sound.PlayEnvSchema(tool, "Event Activate", 0, 0, eEnvSoundLoc.kEnvSoundAmbient);
		PsiMfdUseUpOne(tool);
		local msg = Data.GetObjString(weapon, "objshort") + ": condition " + hp.tointeger() + "% to "
			+ Property.Get(weapon, "GunState", "Condition (%)").tointeger() + "%";
		print("[psi_maintain] " + msg + " (Maintenance " + skill + ")");
		ShockGame.AddText(msg, "Player");
	}
}

class PsiMfdMaintainWeapon extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Maintain", 0.01);
	}

	function OnTimer() {
		if (message().name != "Maintain")
			return;
		try {
			PsiMfdMaintainHeldWeapon();
		}
		catch (e) {
			print("[psi_maintain] error: " + e);
		}
		Object.Destroy(self);
	}
}

ND.Archetype("PsiMfdMaintainWeapon", "ND", function(){ AddScript("PsiMfdMaintainWeapon"); });
