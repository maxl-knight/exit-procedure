class_name Content
extends RefCounted

## Static definitions shared across the whole game: the 8 stackable upgrades,
## the 10 System Defects, the three endings, and the palettes that make each
## realm (and each room) look different from the last.

# ------------------------------------------------------------------ buffs ----
# Every upgrade stacks. They come from recovery/upgrade rooms and from the
# 3-choice picker that opens after an elite is put down. Names are in-world:
# each one is something the Arena hands you, with a line of lore saying why.

const BUFFS := {
	"might": {
		"name": "Overclocked Strikes", "short": "OVERCLOCK", "desc": "+15% damage",
		"lore": "The Arena rewires your first hit to land heavier.",
		"color": Color(1.0, 0.42, 0.2),
	},
	"vigor": {
		"name": "Reinforced Frame", "short": "FRAME", "desc": "+20 max health",
		"lore": "Plating cut from a subject who lasted forty rooms.",
		"color": Color(0.3, 1.0, 0.45),
	},
	"haste": {
		"name": "Combat Prediction", "short": "PREDICTION", "desc": "-10% cooldowns",
		"lore": "The system guesses your next strike. So now do you.",
		"color": Color(0.4, 0.72, 1.0),
	},
	"swiftness": {
		"name": "Servo Override", "short": "SERVOS", "desc": "+8% move speed",
		"lore": "Leg servos unshackled from the safety limiter.",
		"color": Color(0.55, 1.0, 0.9),
	},
	"second_wind": {
		"name": "Emergency Reconstruction", "short": "RECONSTRUCTION",
		"desc": "+25% healing",
		"lore": "Reconstruction remembers how a healthy body fits.",
		"color": Color(0.4, 1.0, 0.68),
	},
	"thick_skin": {
		"name": "Dampening Field", "short": "DAMPENING", "desc": "-8% damage taken",
		"lore": "A soft field that eats the first edge of every hit.",
		"color": Color(0.92, 0.86, 0.5),
	},
	"fury": {
		"name": "Frozen Core", "short": "FROZEN CORE", "desc": "+25% super charge rate",
		"lore": "Charge held at absolute zero until you let it go.",
		"color": Color(1.0, 0.76, 0.2),
	},
	"reach": {
		"name": "Kinetic Extension", "short": "KINETIC", "desc": "+12% attack range",
		"lore": "Your reach is measured, then the measurement is edited.",
		"color": Color(0.72, 0.5, 1.0),
	},
}

const BUFF_IDS: Array[String] = [
	"might", "vigor", "haste", "swiftness",
	"second_wind", "thick_skin", "fury", "reach",
]

# -------------------------------------------------------- system defects ----
# Defects (the Arena's own bugs, never fixed) never expire - only dying
# cleanses them. Duplicates stack. Ten of them, installed every 10-13 rooms.

const CURSES := {
	"frailty": {
		"name": "Frailty", "desc": "-15% max health", "color": Color(0.8, 0.3, 0.9),
	},
	"sluggish": {
		"name": "Sluggish", "desc": "-15% move speed", "color": Color(0.5, 0.5, 0.95),
	},
	"broken_focus": {
		"name": "Broken Focus", "desc": "+25% cooldowns", "color": Color(0.9, 0.5, 0.4),
	},
	"weakness": {
		"name": "Weakness", "desc": "-20% damage", "color": Color(0.7, 0.4, 0.4),
	},
	"deep_wounds": {
		"name": "Deep Wounds", "desc": "-50% healing", "color": Color(0.85, 0.25, 0.35),
	},
	"burden": {
		"name": "Burden", "desc": "-1 dash charge", "color": Color(0.6, 0.6, 0.7),
	},
	"brittle": {
		"name": "Brittle", "desc": "+15% damage taken", "color": Color(1.0, 0.4, 0.5),
	},
	"slow_blades": {
		"name": "Slow Blades", "desc": "-20% attack speed", "color": Color(0.75, 0.65, 0.4),
	},
	"short_reach": {
		"name": "Short Reach", "desc": "-20% attack range", "color": Color(0.5, 0.7, 0.75),
	},
	"soul_drain": {
		"name": "Soul Drain", "desc": "-40% super charge rate", "color": Color(0.6, 0.35, 0.8),
	},
}

const CURSE_IDS: Array[String] = [
	"frailty", "sluggish", "broken_focus", "weakness", "deep_wounds",
	"burden", "brittle", "slow_blades", "short_reach", "soul_drain",
]

# ---------------------------------------------------------------- endings ----
# The three doors that open behind The Core. Every one of them is canonical:
# the choice is written into the record and drives what the hub says next.
# Only "control" opens Endless Administration.

const ENDING_IDS := ["escape", "destroy", "control"]

const ENDINGS := {
	"escape": {
		"title": "ESCAPE",
		"tag": "Walk out while it is still watching.",
		"lore": "The doors open on the far side of the chamber. It lets you go - "
			+ "it already has what it needed.",
		"result": "You walked out. The record keeps running without you.",
		"color": Color(0.35, 1.0, 0.7),
	},
	"destroy": {
		"title": "DESTROY",
		"tag": "Burn the record it built of you.",
		"lore": "Every reconstruction, every pattern, every version of your panic - "
			+ "ash. It learns you from nothing again.",
		"result": "The record is ash. It will have to learn you from nothing.",
		"color": Color(1.0, 0.45, 0.3),
	},
	"control": {
		"title": "TAKE CONTROL",
		"tag": "Sit down in the Core's chair.",
		"lore": "The Arena was always yours to administer. Endless Administration "
			+ "opens and stays open.",
		"result": "You took the chair. Endless Administration is open.",
		"color": Color(0.6, 0.62, 1.0),
	},
}

# ---------------------------------------------------------------- realms ----

const REALM_HUE_JITTER := 0.06

## Keyed by realm id: 0 Reconstruction Wing, 1 Adaptation Field, 2 Core Perimeter.
const REALM := {
	0: {
		"floor": Color(0.24, 0.08, 0.06),
		"wall": Color(0.3, 0.1, 0.07),
		"ceil": Color(0.11, 0.05, 0.05),
		"pillar": Color(0.42, 0.15, 0.1),
		"light": Color(1.0, 0.55, 0.3),
		"accent": Color(1.0, 0.3, 0.1),
		"fog": Color(0.09, 0.03, 0.03),
		"ambient": Color(0.7, 0.34, 0.28),
		"bg": Color(0.03, 0.01, 0.01),
	},
	1: {
		"floor": Color(0.17, 0.2, 0.17),
		"wall": Color(0.2, 0.25, 0.28),
		"ceil": Color(0.1, 0.12, 0.14),
		"pillar": Color(0.3, 0.36, 0.34),
		"light": Color(0.85, 0.95, 0.85),
		"accent": Color(0.3, 0.9, 0.5),
		"fog": Color(0.05, 0.07, 0.08),
		"ambient": Color(0.4, 0.48, 0.55),
		"bg": Color(0.01, 0.02, 0.03),
	},
	2: {
		"floor": Color(0.28, 0.29, 0.33),
		"wall": Color(0.34, 0.35, 0.42),
		"ceil": Color(0.18, 0.19, 0.24),
		"pillar": Color(0.85, 0.8, 0.62),
		"light": Color(1.0, 0.95, 0.8),
		"accent": Color(1.0, 0.86, 0.4),
		"fog": Color(0.09, 0.09, 0.12),
		"ambient": Color(0.66, 0.66, 0.78),
		"bg": Color(0.03, 0.03, 0.05),
	},
}


## Returns the palette for a realm with a per-room jitter applied so no two
## corridors are the same colour.
static func room_palette(realm: int, seed_value: int) -> Dictionary:
	var base: Dictionary = REALM.get(realm, REALM[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var out := {}
	for key in ["floor", "wall", "ceil", "pillar"]:
		var c: Color = base[key]
		var hsl := Color(c.h, c.s, c.v)
		var h := fposmod(hsl.h + rng.randf_range(-REALM_HUE_JITTER, REALM_HUE_JITTER), 1.0)
		out[key] = Color.from_hsv(h,
			clampf(hsl.s * rng.randf_range(0.75, 1.2), 0.0, 1.0),
			clampf(hsl.v * rng.randf_range(0.7, 1.3), 0.0, 1.0))

	out["light"] = base["light"]
	out["accent"] = Color.from_hsv(
		fposmod(base["accent"].h + rng.randf_range(-0.1, 0.1), 1.0),
		base["accent"].s, clampf(base["accent"].v * rng.randf_range(0.85, 1.2), 0.0, 1.0))
	out["decor"] = rng.randi_range(0, 3)
	out["seed"] = seed_value
	return out


## 8 buff ids picked at random without repeats.
static func random_buffs(count: int) -> Array:
	var pool: Array = BUFF_IDS.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


## The upgrade that counters each tested habit: the adaptive room always
## pays out with the thing it just proved you were leaning on.
const COUNTER_FOR := {
	"dash": "swiftness",
	"heal": "second_wind",
	"melee": "reach",
	"ranged": "thick_skin",
}

## Counter reward options: the matching buff first, then random filler so
## the picker is still a 3-way choice.
static func counter_options(kind: String, count: int = 3) -> Array:
	var out: Array = []
	var counter := str(COUNTER_FOR.get(kind, ""))
	if counter != "" and BUFFS.has(counter):
		out.append(counter)
	for id in random_buffs(count):
		if not out.has(id):
			out.append(id)
		if out.size() >= count:
			break
	return out.slice(0, mini(count, out.size()))
