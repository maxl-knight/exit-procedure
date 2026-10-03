extends Node

## Autoload that owns the whole run: difficulty, realm progression, the score
## multiplier and the Hell unlock.

signal stats_changed

const SAVE_PATH := "user://save.cfg"

## Rooms per realm, and the room index of the Creator's arena.
const REALM_LENGTH := 20
const GAME_END_ROOM := REALM_LENGTH * 3

enum Difficulty { EASY, NORMAL, HARD, HELL }
enum CharacterType { BRAWLER, SWORDSMAN, ICE_MAGE }
enum Realm { HELL, EARTH, HEAVEN }

const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard", "Hell"]
const CHARACTER_NAMES := ["Brawler", "Swordsman", "Ice Mage"]
const REALM_NAMES := ["HELL", "EARTH", "HEAVEN"]

const DIFFICULTY_SETTINGS := {
	Difficulty.EASY: {
		"enemy_bonus": -1, "hp_mult": 0.7, "dmg_mult": 0.6, "speed_mult": 0.9,
		"hp_bonus": 50.0, "cooldown_mult": 0.8, "score_mult": 1.0,
		"desc": "+50 health and 20% shorter cooldowns. A relaxed warm-up.",
	},
	Difficulty.NORMAL: {
		"enemy_bonus": 0, "hp_mult": 1.0, "dmg_mult": 1.0, "speed_mult": 1.0,
		"hp_bonus": 0.0, "cooldown_mult": 1.0, "score_mult": 1.0,
		"desc": "The intended experience. Balanced fights.",
	},
	Difficulty.HARD: {
		"enemy_bonus": 2, "hp_mult": 1.9, "dmg_mult": 1.4, "speed_mult": 1.15,
		"hp_bonus": -20.0, "cooldown_mult": 1.3, "score_mult": 1.7,
		"desc": "Tougher enemies, 30% longer cooldowns, -20 health.",
	},
	Difficulty.HELL: {
		"enemy_bonus": 5, "hp_mult": 2.6, "dmg_mult": 1.9, "speed_mult": 1.3,
		"hp_bonus": -50.0, "cooldown_mult": 1.4, "score_mult": 3.5,
		"desc": "40% longer cooldowns, -50 health, 3.5x score.",
	},
}

const PAR_TIME := 26.0

var difficulty: int = Difficulty.NORMAL
var character: int = CharacterType.BRAWLER
var kills := 0
var rooms_cleared := 0
var score_points := 0.0
var hell_unlocked := false
var announce_unlock := false
var game_beaten := false
var endless := false

## Live inputs for the score multiplier - reset whenever a room starts.
var room_damage := 0.0
var room_time := 0.0


func _ready() -> void:
	_setup_input()
	_load_unlock()


func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("ability_1", KEY_Q)
	_add_key_action("ability_2", KEY_SHIFT)
	_add_key_action("ability_3", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)


func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func start_run(d: int, c: int) -> void:
	difficulty = d
	character = c
	kills = 0
	rooms_cleared = 0
	score_points = 0.0
	announce_unlock = false
	game_beaten = false
	endless = false
	reset_room_stats()
	ArenaMemory.start_run(c)
	stats_changed.emit()


func reset_room_stats() -> void:
	room_damage = 0.0
	room_time = 0.0


# ----------------------------------------------------------- difficulty -----

func settings() -> Dictionary:
	return DIFFICULTY_SETTINGS[difficulty]


func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]


func character_name() -> String:
	return CHARACTER_NAMES[character]


func hp_bonus() -> float:
	return float(settings()["hp_bonus"])


func cooldown_mult() -> float:
	return float(settings()["cooldown_mult"])


func base_score_mult() -> float:
	return float(settings()["score_mult"])


# ------------------------------------------------------------- realms -------

func is_boss_room(index: int) -> bool:
	return index > 0 and index % GAME_END_ROOM == 0


func realm_of_room(index: int) -> int:
	if is_boss_room(index):
		return Realm.HEAVEN
	return int(floor(float(index) / float(REALM_LENGTH))) % 3


func realm_name(index: int) -> String:
	return REALM_NAMES[realm_of_room(index)]


# ---------------------------------------------------------------- score -----

## Damage taken and speed inside the current room both push this around.
func multiplier() -> float:
	var max_hp := maxf(100.0 + hp_bonus(), 10.0)
	var dmg_factor := 1.0 + 2.0 * clampf(1.0 - room_damage / max_hp, 0.0, 1.0)
	var speed_factor := 1.0 + 1.5 * clampf((PAR_TIME - room_time) / PAR_TIME, 0.0, 1.0)
	return clampf(base_score_mult() * dmg_factor * speed_factor, 0.5, 15.0)


func add_kill() -> void:
	kills += 1
	score_points += 100.0 * multiplier()
	stats_changed.emit()


func add_room() -> void:
	rooms_cleared += 1
	score_points += 250.0 * multiplier()
	stats_changed.emit()


func score() -> int:
	return maxi(0, int(round(score_points)))


## Called the moment the Creator falls. Only a Hard clear opens Hell.
func beat_game() -> bool:
	game_beaten = true
	var unlocked := false
	if difficulty == Difficulty.HARD and not hell_unlocked:
		hell_unlocked = true
		announce_unlock = true
		_save_unlock()
		unlocked = true
	stats_changed.emit()
	return unlocked


# ----------------------------------------------------------------- save -----

func _load_unlock() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		hell_unlocked = bool(cfg.get_value("unlock", "hell",
			bool(cfg.get_value("unlock", "secret", false))))


func _save_unlock() -> void:
	var cfg := ConfigFile.new()
	# Load first: ArenaMemory stores the story in this same file.
	cfg.load(SAVE_PATH)
	cfg.set_value("unlock", "hell", hell_unlocked)
	cfg.save(SAVE_PATH)
