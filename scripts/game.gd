extends Node3D

## Game scene root: builds the world, the player, the UI and owns the run state.

enum State { PLAYING, PAUSED, CHOOSING, VICTORY, OVER }

const MENU_SCENE := "res://scenes/main_menu.tscn"

const REALM_BANNER := {
	0: Color(1.0, 0.4, 0.25),
	1: Color(0.4, 1.0, 0.6),
	2: Color(1.0, 0.92, 0.6),
}

var state: int = State.PLAYING

var player: Player
var camera_rig: CameraRig
var room_manager: RoomManager
var hud: HUD
var pause_menu: PauseMenu
var game_over: GameOverScreen
var choice: ChoiceScreen
var victory: VictoryScreen

var boss: TheCreator
var _env: Environment
var _sun: DirectionalLight3D
var _realm := -1
var _boss_started := false


func _ready() -> void:
	_build_environment()

	player = Player.new()
	player.character_type = GameManager.character
	player.position = Vector3(0, 0.2, 6)
	add_child(player)

	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.set_target(player)
	player.camera = camera_rig

	room_manager = RoomManager.new()
	room_manager.player = player
	add_child(room_manager)
	room_manager.room_entered.connect(_on_room_entered)
	room_manager.room_cleared.connect(_on_room_cleared)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	hud = HUD.new()
	hud.setup(player)
	ui.add_child(hud)

	pause_menu = PauseMenu.new()
	pause_menu.game = self
	ui.add_child(pause_menu)

	game_over = GameOverScreen.new()
	game_over.game = self
	ui.add_child(game_over)

	choice = ChoiceScreen.new()
	choice.chosen.connect(_on_choice_made)
	ui.add_child(choice)

	victory = VictoryScreen.new()
	victory.descend.connect(_on_descend)
	victory.to_menu.connect(go_menu)
	ui.add_child(victory)

	player.died.connect(_on_player_died)
	ArenaMemory.voice.connect(_on_arena_voice)

	_realm = GameManager.realm_of_room(0)
	_apply_realm(_realm)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_banner("Last Ascend", Color(1.0, 0.85, 0.4), 2.2)


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.008, 0.01, 0.018)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.36, 0.4, 0.55)
	_env.ambient_light_energy = 0.65
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.15
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.15
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.05, 0.06, 0.1)
	_env.fog_light_energy = 0.6
	_env.fog_density = 0.012
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, -35, 0)
	_sun.light_color = Color(1.0, 0.96, 0.88)
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 70.0
	add_child(_sun)


func _apply_realm(realm: int) -> void:
	if not Content.REALM.has(realm):
		return
	var p: Dictionary = Content.REALM[realm]
	var sun_colors := [Color(1.0, 0.6, 0.45), Color(0.9, 1.0, 0.95), Color(1.0, 0.97, 0.85)]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_env, "fog_light_color", p["fog"], 1.4)
	tw.tween_property(_env, "ambient_light_color", p["ambient"], 1.4)
	tw.tween_property(_env, "background_color", p["bg"], 1.4)
	tw.tween_property(_sun, "light_color", sun_colors[clampi(realm, 0, 2)], 1.4)


func _process(delta: float) -> void:
	if state == State.PLAYING:
		GameManager.room_time += delta
	if hud != null and room_manager != null:
		hud.set_enemies_left(room_manager.enemies_in(room_manager.current_index))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


# --------------------------------------------------------------- events -----

func _on_room_entered(index: int) -> void:
	GameManager.reset_room_stats()
	player.arena_heal_mult = 1.0
	hud.current_room = index

	var realm := GameManager.realm_of_room(index)
	var realm_changed := realm != _realm
	if realm_changed:
		_realm = realm
		_apply_realm(realm)

	if GameManager.is_boss_room(index) and not _boss_started:
		_spawn_boss(index)

	if state != State.PLAYING:
		return

	# A curse is the loudest thing that can happen to you - say it plainly.
	if room_manager.is_curse_room(index):
		var id := player.apply_random_curse()
		var data: Dictionary = Content.CURSES.get(id, {})
		var curse_name := str(data.get("name", id)).to_upper()
		var desc := str(data.get("desc", ""))
		hud.show_banner("YOU HAVE BEEN CURSED BY A DEBUFF\n%s  -  %s" % [curse_name, desc],
			Color(0.9, 0.3, 0.9), 5.0)
		return

	var room := room_manager.room_at(index)
	if room != null and room.is_boss_room:
		hud.show_banner("THE THRONE OF HEAVEN", Color(1.0, 0.9, 0.5), 3.0)
		return
	if room != null and room.challenge != Room.Challenge.NONE:
		hud.show_banner(room.challenge_name(),
			Color(1.0, 0.3, 0.95) if room.challenge == Room.Challenge.ELITE_TRIAL
			else Color(1.0, 0.85, 0.3), 2.4)
		return
	if room != null and room.adaptive != "":
		_enter_adaptive(room)
		return
	if realm_changed:
		hud.show_banner("ENTERING  %s" % GameManager.REALM_NAMES[realm],
			REALM_BANNER.get(realm, Color.WHITE), 2.6)
		return

	hud.show_banner("Room %d   -   %s" % [index + 1, GameManager.realm_name(index)],
		Color(0.6, 0.85, 1.0), 1.6)


func _on_room_cleared(index: int) -> void:
	if state != State.PLAYING:
		return
	ArenaMemory.note_room(GameManager.rooms_cleared)
	var room := room_manager.room_at(index)
	if room == null or room.is_boss_room:
		return

	if room.challenge == Room.Challenge.VAULT:
		var picked: Array = Content.random_buffs(2)
		var title := ""
		for id in picked:
			player.apply_buff(str(id))
			var d: Dictionary = Content.BUFFS.get(str(id), {})
			if title != "":
				title += "   +   "
			title += str(d.get("name", id))
		hud.show_banner("REWARD VAULT\n%s" % title.to_upper(),
			Color(1.0, 0.85, 0.3), 3.2)
		return

	if room.had_elite:
		_open_choice("ELITE DEFEATED", "Pick one upgrade  -  all eight stack",
			Content.random_buffs(3))
		return

	if room.adaptive != "":
		ArenaMemory.note_adaptive(room.adaptive)
		if room.adaptive == "heal":
			# The Arena concedes the point: reconstruction works again.
			player.health.heal(player.max_health_now() * 0.3)
		_open_choice("SIMULATION CLEARED", "Your habit cost you - take a reward",
			Content.random_buffs(3))
		return

	hud.show_banner("Room %d cleared" % (index + 1), Color(0.4, 1.0, 0.55), 1.7)


## Announce the test, switch on its modifiers, and let the Arena say why.
func _enter_adaptive(room: Room) -> void:
	player.arena_heal_mult = 0.5 if room.adaptive == "heal" else 1.0
	hud.show_banner("%s\n%s" % [room.adaptive_title(), room.adaptive_desc()],
		Color(0.35, 0.85, 1.0), 4.0)
	ArenaMemory.speak("adapt")


func _open_choice(title: String, detail: String, options: Array) -> void:
	if state != State.PLAYING or options.is_empty():
		return
	state = State.CHOOSING
	choice.open(title, detail, options, player.buffs)


func _on_choice_made(id: String) -> void:
	player.apply_buff(id)
	if state == State.CHOOSING:
		state = State.PLAYING
	var data: Dictionary = Content.BUFFS.get(id, {})
	hud.show_banner("%s  x%d" % [str(data.get("name", id)).to_upper(),
		player.buff_stacks(id)], data.get("color", Color.WHITE), 2.0)


func _on_player_died() -> void:
	if state == State.OVER:
		return
	state = State.OVER
	ArenaMemory.note_death(player.last_hit_source)
	# Show the death screen first - nothing else may get in its way.
	game_over.show_stats()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	hud.clear_bars()


# ------------------------------------------------------------------ boss ----

func _spawn_boss(index: int) -> void:
	var room := room_manager.room_at(index)
	if room == null or boss != null:
		return
	_boss_started = true
	boss = TheCreator.new()
	boss.target = player
	room.add_child(boss)
	boss.position = Vector3(0, 0.1, -5.5)
	boss.died.connect(_on_boss_died)
	hud.watch_boss(boss)
	get_tree().create_timer(0.3).timeout.connect(func():
		if hud != null:
			hud.show_banner("THE CREATOR", Color(1.0, 0.9, 0.5), 3.0))


func _on_boss_died() -> void:
	hud.clear_boss()
	boss = null
	GameManager.add_room()
	GameManager.beat_game()
	ArenaMemory.note_boss()
	state = State.VICTORY
	victory.show_stats()


## The Arena talking: relay its reaction to the HUD subtitle bar.
func _on_arena_voice(text: String) -> void:
	if hud != null:
		hud.show_voice(text)


func _on_descend() -> void:
	GameManager.endless = true
	state = State.PLAYING
	_boss_started = false
	room_manager.descend()
	hud.show_banner("YOU FALL FROM HEAVEN INTO HELL", Color(1.0, 0.3, 0.2), 3.4)


# -------------------------------------------------------------- control -----

func toggle_pause() -> void:
	if state == State.OVER or state == State.VICTORY or state == State.CHOOSING:
		return
	if state == State.PLAYING:
		state = State.PAUSED
		pause_menu.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		state = State.PLAYING
		pause_menu.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false


func restart() -> void:
	get_tree().paused = false
	GameManager.start_run(GameManager.difficulty, GameManager.character)
	get_tree().reload_current_scene()


func go_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)
