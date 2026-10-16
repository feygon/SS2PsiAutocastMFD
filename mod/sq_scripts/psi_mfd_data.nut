// psi_mfd_data: the discipline table the MFD shows, computed from the running gamesys (SCP or not).
// Sources and their checks are in DEVELOPMENT.md ("Psi power data").

// Internal archetype name for each discipline number (P$SymName in shockscp.gam, checked in game 2026-10-16).
ND.psiMfdPowers <- {
	[1] = "Low Grav", [2] = "Still Hand", [3] = "PsiPull", [4] = "Quickness", [5] = "Cyber", [6] = "Cryokinesis", [7] = "Codebreaker",
	[9] = "Stability", [10] = "Berserk", [11] = "Rad Shield", [12] = "PsiHeal", [13] = "Might", [14] = "PsiImage", [15] = "Immolate",
	[17] = "Fabricate", [18] = "ElectroPsi", [19] = "AntiPsi", [20] = "Toxin Shield", [21] = "Radar", [22] = "Pyrokinesis", [23] = "Terror",
	[25] = "Inviso", [26] = "Seekersense", [27] = "Electro Dampen", [28] = "Vitality", [29] = "Alchemy", [30] = "CyberHack", [31] = "Psi Sword",
	[33] = "Major Heal", [34] = "SomaDrain", [35] = "Teleport", [36] = "PsiCharm", [37] = "ForceWall", [38] = "PsiMines", [39] = "PsiShield",
};

const PSI_MFD_MAX_PSI = 8;     // highest PSI; Cryo and Pyro have no projectile past PSI 8
const PSI_MFD_OVERLOAD_PSI = 2; // an overload casts as if PSI were 2 higher

function PsiMfdPlayerPsi() {
	local psi = ShockGame.GetStat("Player", eStats.kStatPsi);
	return psi < 1 ? 1 : (psi > PSI_MFD_MAX_PSI ? PSI_MFD_MAX_PSI : psi);
}

// 90 -> "1m30s", 240 -> "4m", 45 -> "45s".
function PsiMfdTime(seconds) {
	if (seconds == null)
		return "-";
	seconds = seconds.tointeger();
	if (seconds < 60)
		return seconds + "s";
	local rest = seconds % 60;
	return (seconds / 60) + "m" + (rest ? rest + "s" : "");
}

// 2.0 -> "2", 0.5 -> "0.5".
function PsiMfdNumber(value) {
	value = value.tofloat();
	return value == value.tointeger() ? value.tointeger().tostring() : format("%.1f", value);
}

function PsiMfdData(obj, n) {
	return Property.Get(obj, "PsiPower", "Data " + n).tofloat();
}

// Timed disciplines: Base Time + Add Time seconds per PSI.
function PsiMfdShieldTime(obj, psi) {
	if (!Property.Possessed(obj, "PsiShield"))
		return null;
	return Property.Get(obj, "PsiShield", "Base Time") + Property.Get(obj, "PsiShield", "Add Time") * psi;
}

function PsiMfdStimIntensity(obj) {
	foreach (l in Link.GetAll("arSrcDesc", obj, 0))
		return LinkTools.LinkGetData(l, "Intensity").tofloat();
	return null;
}

// Cryo and Pyro link one projectile per PSI level ("Cryo PSI 4"); the others link a single projectile.
function PsiMfdProjectileIntensity(obj, psi) {
	local single = null;
	foreach (l in Link.GetAll("Projectile", obj, 0)) {
		local projectile = sLink(l).dest;
		if (endswith(Object.GetName(projectile), " PSI " + psi))
			return PsiMfdStimIntensity(projectile);
		single = PsiMfdStimIntensity(projectile);
	}
	return single;
}

// An effect cell: a label with an optional number, e.g. PsiMfdEffect("AGI +", 2) or PsiMfdEffect("", 7, " cold dmg").
function PsiMfdEffect(before, value = null, after = "") {
	return { before = before, value = value, after = after };
}

// What each discipline does at a given PSI: { time = seconds or null, effect = PsiMfdEffect(...) }.
// Numbers come from the gamesys; fixed percentages with no gamesys value come from psihelp.str.
ND.psiMfdEffects <- {
	[1] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("-15% damage") }),
	[2] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("no kickback") }),
	[3] = @(o, p) ({ time = p, effect = PsiMfdEffect("pull object") }),                                   // help: 1 second per PSI
	[4] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("AGI +", PsiMfdData(o, 1)) }),
	[5] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("CYB +", PsiMfdData(o, 1)) }),
	[6] = @(o, p) ({ time = null, effect = PsiMfdEffect("", PsiMfdProjectileIntensity(o, p), " cold dmg") }),
	[7] = @(o, p) ({ time = null, effect = PsiMfdEffect("alarm -", PsiMfdData(o, 1) + PsiMfdData(o, 2) * p, "s") }),
	[9] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("no weapon wear") }),
	[10] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("melee x", p) }),             // help: factor equal to PSI
	[11] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("-80% radiation") }),
	[12] = @(o, p) ({ time = null, effect = PsiMfdEffect("+", PsiMfdData(o, 2) * p, " HP") }),
	[13] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("STR +", PsiMfdData(o, 1)) }),
	[14] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("PSI +", PsiMfdData(o, 1), ", 2x cost") }),
	[15] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("fire aura") }),
	[17] = @(o, p) ({ time = null, effect = PsiMfdEffect("", PsiMfdData(o, 1) + PsiMfdData(o, 2) * p, "% dup") }),
	[18] = @(o, p) ({ time = null, effect = PsiMfdEffect("", PsiMfdData(o, 1) * p, "% charge") }),
	[19] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("-50% energy") }),
	[20] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("-", PsiMfdData(o, 1), "% toxin") }),
	[21] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("shows creatures") }),
	[22] = @(o, p) ({ time = null, effect = PsiMfdEffect("", PsiMfdProjectileIntensity(o, p), " fire dmg") }),
	[23] = @(o, p) ({ time = PsiMfdProjectileIntensity(o, p) * p, effect = PsiMfdEffect("holds creature") }),
	[25] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("invisible") }),
	[26] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("shows items") }),
	[27] = @(o, p) ({ time = PsiMfdProjectileIntensity(o, p) * p, effect = PsiMfdEffect("holds robot") }),
	[28] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("END +", PsiMfdData(o, 1)) }),
	[29] = @(o, p) ({ time = null, effect = PsiMfdEffect("items to nanites") }),
	[30] = @(o, p) ({ time = null, effect = PsiMfdEffect("hack as ", (p + 1) / 2) }),                      // help: half PSI, rounded up
	[31] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("psi blade") }),
	[33] = @(o, p) ({ time = null, effect = PsiMfdEffect("+", PsiMfdData(o, 1) + PsiMfdData(o, 2) * p, " HP") }),
	[34] = @(o, p) ({ time = null, effect = PsiMfdEffect("drains HP") }),
	[35] = @(o, p) ({ time = null, effect = PsiMfdEffect("teleport") }),
	[36] = @(o, p) ({ time = PsiMfdProjectileIntensity(o, p) * p, effect = PsiMfdEffect("turns creature") }),
	[37] = @(o, p) ({ time = 240, effect = PsiMfdEffect("wall ", PsiMfdData(o, 1) + PsiMfdData(o, 2) * (p > PsiMfdData(o, 3) ? p - PsiMfdData(o, 3) : 0), " HP") }),
	[38] = @(o, p) ({ time = 240, effect = PsiMfdEffect("psi mine") }),                                    // help: 4 minutes
	[39] = @(o, p) ({ time = PsiMfdShieldTime(o, p), effect = PsiMfdEffect("-60% damage") }),
};

// "Psychogenic Agility\n\nIncreases ..." -> "Psychogenic Agility".
function PsiMfdName(id) {
	foreach (line in split(Data.GetString("psihelp", "Psi" + id), "\n")) {
		line = strip(line);
		if (line.len())
			return line;
	}
	return "Discipline " + id;
}

function PsiMfdEffectText(now, max) {
	if (now.value == null)
		return now.before;
	local text = now.before + PsiMfdNumber(now.value);
	if (max.value != null && max.value != now.value)
		text += " / " + PsiMfdNumber(max.value);
	return text + now.after;
}

// One table row per discipline, for the player's current PSI.
function PsiMfdBuildRows() {
	local psi = PsiMfdPlayerPsi();
	local overloadPsi = psi + PSI_MFD_OVERLOAD_PSI > PSI_MFD_MAX_PSI ? PSI_MFD_MAX_PSI : psi + PSI_MFD_OVERLOAD_PSI;
	local ids = [];
	foreach (id, name in ND.psiMfdPowers)
		ids.push(id);
	ids.sort();

	local rows = [];
	foreach (id in ids) {
		local obj = Object.Named(ND.psiMfdPowers[id]);
		local benefits = ("psiDisciplines" in ND) && (id in ND.psiDisciplines) && ND.psiDisciplines[id].benefits == 1;
		local row = {
			id = id,
			tier = id / 8 + 1,
			name = PsiMfdName(id),
			shortName = Data.GetString("psihelp", "PsiShort" + id),
			icon = Data.GetString("psihelp", "PsiIcon" + id),
			benefits = benefits,
			time = "-", effect = "?", overload = "-",
		};
		if (obj) {
			local now = ND.psiMfdEffects[id](obj, psi);
			local max = ND.psiMfdEffects[id](obj, PSI_MFD_MAX_PSI);
			row.time = now.time == null ? "-" : PsiMfdTime(now.time) + (max.time != now.time ? " / " + PsiMfdTime(max.time) : "");
			row.effect = PsiMfdEffectText(now.effect, max.effect);
			if (benefits) {
				local over = ND.psiMfdEffects[id](obj, overloadPsi);
				if (over.effect.value != null && over.effect.value != now.effect.value)
					row.overload = over.effect.before + PsiMfdNumber(over.effect.value) + over.effect.after;
				else if (over.time != null && over.time != now.time)
					row.overload = PsiMfdTime(over.time);
				else
					row.overload = "yes";
			}
		}
		else
			print("[psi_mfd] no archetype named '" + ND.psiMfdPowers[id] + "' for discipline " + id);
		rows.push(row);
	}
	return rows;
}
