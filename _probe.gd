extends Node

## Round A probe: Arena memory, voice lines, adaptive rooms, death screen.
## Instantiates game.tscn as a child so tree.current_scene stays this probe.

var fails := 0
var total := 0
var heard: Array = []
var game: Node

var _save_existed := false
var _save_bytes := PackedByteArray()


func check(cond: bool, label: String) -> void:
	total += 1
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)


## The probe rewrites save.cfg - snapshot it first, put it back at the end so
## a real player's unlocks and story are untouched.
func _backup_save() -> void:
	var f := FileAccess.open(GameManager.SAVE_PATH, FileAccess.READ)
	if f != null:
		_save_existed = true
		_save_bytes = f.get_buffer(f.get_length())


func _restore_save() -> void:
	if _save_existed:
		var f := FileAccess.open(GameManager.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_save_bytes)
	elif FileAccess.file_exists(GameManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_PATH))


func _ready() -> void:
	_backup_save()
	GameManager.start_run(GameManager.Difficulty.NORMAL, 0)
	ArenaMemory.voice.connect(func(t): heard.append(t))

	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	_test_run_counters()
	_test_voice_lines()
	_test_flagged_behavior()
	_test_death_cause()
	_test_adaptive_schedule()
	_test_trap_haste()
	_test_spawn_composition()
	_test_config_propagation()
	_test_heal_suppression()
	_test_adaptive_entry()
	_test_voice_bar()
	_test_save_merge()
	await _test_death_screen()

	_restore_save()
	print("PROBE RESULT: %d/%d passed, %d failed" % [total - fails, total, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ tests ---

func _test_run_counters() -> void:
	check(ArenaMemory.runs >= 1, "start_run counts the run")
	check(int(ArenaMemory.char_runs.get(0, 0)) >= 1, "start_run counts the character")
	check(ArenaMemory.dashes == 0 and ArenaMemory.heals == 0,
		"start_run resets run counters")
	check(ArenaMemory.death_cause == ArenaMemory.CAUSE_UNKNOWN,
		"fresh run has no death cause")


func _test_voice_lines() -> void:
	heard.clear()
	ArenaMemory.note_heal()
	ArenaMemory.note_heal()
	check(heard.size() == 1 and str(heard[0]).contains("Reconstruction inputs"),
		"first heal speaks exactly once")
	check(ArenaMemory.heals == 2, "both heals counted")

	heard.clear()
	for i in 9:
		ArenaMemory.note_dash()
	check(heard.is_empty(), "nine dashes stay silent")
	ArenaMemory.note_dash()
	check(heard.size() == 1 and str(heard[0]).contains("Movement pattern"),
		"tenth dash speaks")

	heard.clear()
	ArenaMemory.speak("dash_rhythm")
	check(heard.is_empty(), "repeat speak of same line is suppressed")

	heard.clear()
	ArenaMemory.note_super_held()
	check(heard.size() == 1 and str(heard[0]).contains("Power retained"),
		"hoarded super speaks")
	heard.clear()
	ArenaMemory.speak("super_hoard")
	check(heard.is_empty(), "super line fires once per run")

	heard.clear()
	ArenaMemory.speak("adapt")
	check(heard.size() == 1 and str(heard[0]).contains("Simulation adapting"),
		"adaptation warning speaks")
	heard.clear()
	ArenaMemory.speak("adapt")
	check(heard.is_empty(), "adaptation warning is once per run")


func _test_flagged_behavior() -> void:
	ArenaMemory.heals = 0
	ArenaMemory.dashes = 0
	ArenaMemory.bolt_attacks = 0
	ArenaMemory.melee_attacks = 0
	check(ArenaMemory.flagged_behavior() == "", "no data means no flag")

	ArenaMemory.heals = 2
	check(ArenaMemory.flagged_behavior() == "heal", "heal habit wins priority")
	ArenaMemory.heals = 0

	ArenaMemory.dashes = 10
	check(ArenaMemory.flagged_behavior() == "dash", "dash habit flagged")
	ArenaMemory.dashes = 0

	ArenaMemory.bolt_attacks = 6
	ArenaMemory.melee_attacks = 1
	check(ArenaMemory.flagged_behavior() == "ranged", "bolt habit flagged")
	ArenaMemory.bolt_attacks = 0
	ArenaMemory.melee_attacks = 0

	ArenaMemory.melee_attacks = 12
	check(ArenaMemory.flagged_behavior() == "melee", "melee habit flagged")
	ArenaMemory.melee_attacks = 0


func _test_death_cause() -> void:
	var p: Player = game.player
	p.last_hit_source = "unknown"
	var dealt := p.apply_hit(3.0, Vector3.RIGHT, 0.0, ArenaMemory.CAUSE_TRAP)
	check(dealt > 0.0, "tagged hit lands")
	check(p.last_hit_source == "trap", "trap source recorded")
	var dmg_before := ArenaMemory.damage_taken
	p.apply_hit(3.0, Vector3.RIGHT, 0.0, ArenaMemory.CAUSE_RANGED)
	check(p.last_hit_source == "ranged", "ranged source overwrites")
	check(ArenaMemory.damage_taken > dmg_before, "damage taken accumulated")
	# death_line() reads whatever note_death() filed - that is the only path
	# the death screen uses.
	ArenaMemory.note_death(ArenaMemory.CAUSE_RANGED)
	check(ArenaMemory.death_line().contains("static positioning"),
		"death line follows filed cause")


func _test_adaptive_schedule() -> void:
	ArenaMemory.heals = 0
	ArenaMemory.dashes = 0
	ArenaMemory.bolt_attacks = 0
	ArenaMemory.melee_attacks = 0
	var rm: RoomManager = game.room_manager
	var slots := 0
	var conflicts := 0
	for i in 70:
		var kind := rm.adaptive_for(i)
		if kind == "":
			continue
		slots += 1
		if rm.challenge_for(i) != Room.Challenge.NONE \
				or rm.is_curse_room(i) or GameManager.is_boss_room(i):
			conflicts += 1
	check(slots >= 4, "schedule finds at least 4 test slots in 70 rooms (%d)" % slots)
	check(conflicts == 0, "no test slot collides with challenge/curse/boss")
	# The first slot lands on the 4th-6th room (1-based), so no test before
	# room index 3.
	var first_slot := -1
	for i in 70:
		if rm.adaptive_for(i) != "":
			first_slot = i
			break
	check(first_slot >= 3 and first_slot <= 5,
		"first test lands on room 4-6 (index %d)" % first_slot)


func _test_trap_haste() -> void:
	var trap := SpikeTrap.new()
	trap.haste = 1.6
	add_child(trap)
	check(is_equal_approx(trap.timer, SpikeTrap.SAFE_TIME / 1.6),
		"trap starts on a shortened cycle")
	trap._enter(SpikeTrap.Phase.WARN, 0.75)
	check(is_equal_approx(trap.timer, 0.75 / 1.6), "_enter divides by haste")
	trap.haste = 1.0
	trap._enter(SpikeTrap.Phase.ACTIVE, 1.4)
	check(is_equal_approx(trap.timer, 1.4), "normal rooms keep normal timing")
	trap.queue_free()


func _test_spawn_composition() -> void:
	var r := Room.new()
	r.adaptive = "melee"
	var archers := 0
	for i in 100:
		if r._pick_adaptive_type() == Enemy.Type.ARCHER:
			archers += 1
	check(archers >= 50, "melee test floods with archers (%d/100)" % archers)

	r.adaptive = "ranged"
	var runners := 0
	for i in 100:
		if r._pick_adaptive_type() == Enemy.Type.FAST:
			runners += 1
	check(runners >= 50, "ranged test floods with runners (%d/100)" % runners)

	r.adaptive = "heal"
	var others := 0
	for i in 100:
		if r._pick_adaptive_type() != Enemy.Type.BIG:
			others += 1
	check(others >= 40, "heal test stays mixed (%d/100 non-brutes)" % others)

	r.adaptive = ""
	r.index = 2
	check(r._pick_adaptive_type() is int, "ordinary rooms still pick a type")
	r.free()


func _test_config_propagation() -> void:
	var rm: RoomManager = game.room_manager
	var found := ""
	var slot := -1
	for i in 70:
		found = rm.adaptive_for(i)
		if found != "" and rm.challenge_for(i) == Room.Challenge.NONE \
				and not rm.is_curse_room(i):
			slot = i
			break
	check(slot > 0, "found an adaptive slot (%d)" % slot)
	if slot > 0:
		var cfg: Dictionary = rm._config_for(slot)
		check(str(cfg.get("adaptive", "")) == found,
			"config carries the test kind")
	var challenge_slot := -1
	for i in 70:
		if rm.challenge_for(i) != Room.Challenge.NONE:
			challenge_slot = i
			break
	check(challenge_slot > 0, "found a challenge room")
	if challenge_slot > 0:
		var cfg2: Dictionary = rm._config_for(challenge_slot)
		check(not cfg2.has("adaptive"), "challenge rooms never double up")


func _test_heal_suppression() -> void:
	var p: Player = game.player
	p.arena_heal_mult = 1.0
	var normal := p.heal_amount_now()
	p.arena_heal_mult = 0.5
	check(is_equal_approx(p.heal_amount_now(), normal * 0.5),
		"adaptive heal test halves reconstruction")
	p.arena_heal_mult = 1.0
	check(is_equal_approx(p.heal_amount_now(), normal), "suppression lifts cleanly")


func _test_adaptive_entry() -> void:
	var p: Player = game.player
	var r := Room.new()
	r.index = 3
	r.adaptive = "heal"
	check(r.adaptive_title().contains("RECONSTRUCTION SUPPRESSED"),
		"heal test has a title")
	check(r.adaptive_desc() != "", "heal test explains itself")
	game._enter_adaptive(r)
	check(is_equal_approx(p.arena_heal_mult, 0.5), "entry switches suppression on")
	check(game.hud._banner.visible and game.hud._banner.text.contains("SUPPRESSED"),
		"banner announces the test")

	# Walking into an ordinary room must lift it again.
	game._on_room_entered(0)
	check(is_equal_approx(p.arena_heal_mult, 1.0), "next room lifts suppression")
	r.free()


func _test_voice_bar() -> void:
	var hud: HUD = game.hud
	hud.show_voice("ARENA: probe line")
	check(hud._voice.visible, "voice bar shows")
	check(hud._voice.text == "ARENA: probe line", "voice bar carries the text")
	check(hud._voice.visible_characters == 0, "typewriter starts empty")
	hud.clear_bars()
	check(not hud._voice.visible, "clear_bars hides the voice bar")


func _test_save_merge() -> void:
	# [unlock] written by GameManager must survive an ArenaMemory save.
	var cfg := ConfigFile.new()
	cfg.load(GameManager.SAVE_PATH)
	cfg.set_value("unlock", "hell", true)
	cfg.save(GameManager.SAVE_PATH)

	ArenaMemory.runs += 1
	ArenaMemory._save()

	var cfg2 := ConfigFile.new()
	check(cfg2.load(GameManager.SAVE_PATH) == OK, "save file still parses")
	check(bool(cfg2.get_value("unlock", "hell", false)), "[unlock] survived a story save")
	check(cfg2.has_section("story"), "[story] present after save")

	var cfg3 := ConfigFile.new()
	cfg3.load(GameManager.SAVE_PATH)
	cfg3.set_value("unlock", "hell", false)
	cfg3.save(GameManager.SAVE_PATH)

	# Round-trip the story numbers through a real load.
	ArenaMemory._load()
	check(ArenaMemory.runs >= 2, "story state round-trips through disk (%d)" % ArenaMemory.runs)


func _test_death_screen() -> void:
	# Establish a repeating pattern so the threshold line is exercised.
	var cause := ArenaMemory.CAUSE_TRAP
	ArenaMemory.deaths_by_cause[cause] = 2
	ArenaMemory.note_death(cause)
	check(ArenaMemory.pattern_repeats(), "third death to one cause repeats the pattern")

	var p: Player = game.player
	p.apply_hit(99999.0, Vector3.RIGHT, 0.0, cause)
	await get_tree().process_frame
	await get_tree().process_frame

	check(p.dead, "player died from the tagged hit")
	var over: GameOverScreen = game.game_over
	check(over.visible, "death screen shows")
	check(get_tree().paused, "death pauses the tree")
	check(ArenaMemory.death_cause == cause, "memory files the cause of death")
	check(over._arena_line.text.contains("hazard cycles"),
		"death screen speaks the cause line")
	check(over._learned.text.contains("MOVEMENT"), "death screen shows observations")
	check(over._pattern.visible, "repeating-pattern line is visible")
	# The killing blow files one more death, so the counter is now 4.
	check(over._pattern.text.contains(
		"%d logged failures" % ArenaMemory.deaths_by_cause[cause]),
		"pattern count matches the story layer")
	check(not game.hud._voice.visible, "voice bar cleared on death")
	check(not game.hud._ability_root.visible, "ability row cleared on death")
	check(ArenaMemory.deaths >= 1, "death persisted to the story layer")
