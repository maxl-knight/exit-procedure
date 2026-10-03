class_name Room
extends Node3D

signal cleared(room: Room)

const WIDTH := 22.0
const LENGTH := 22.0
const HEIGHT := 5.0
const DOOR_W := 5.0
const DOOR_H := 4.0
const ENTRY_MARGIN := 3.0

## Challenge rooms appear every 3-5 rooms: either an elite trial (which pays
## out as a 3-choice upgrade) or an upgrade cache that hands over a lasting buff.
enum Challenge { NONE, ELITE_TRIAL, VAULT }

## Short titles the Arena uses when it announces an adaptive test.
const ADAPTIVE_TITLES := {
	"dash": "SIMULATION ADAPTING: PREDICTIVE HAZARDS",
	"heal": "SIMULATION ADAPTING: RECONSTRUCTION SUPPRESSED",
	"melee": "SIMULATION ADAPTING: THEY KEEP THEIR DISTANCE",
	"ranged": "SIMULATION ADAPTING: THEY CLOSE THE GAP",
}

const ADAPTIVE_DESCS := {
	"dash": "Your movement was recorded. The traps no longer wait.",
	"heal": "The Arena watched how you survive. Healing is halved in here.",
	"melee": "Frontal engagement recorded. Archers will not let you close.",
	"ranged": "Ranged reliance recorded. Nothing stands at distance today.",
}

var index := 0
var enemies: Array = []
## Non-"" for the two story room types: "recovery" (light fight, no traps,
## pays reconstruction on clear) and "memory" (the Arena shows a fragment).
var kind := ""
var is_cleared := false
var challenge: int = Challenge.NONE
## Behaviour the Arena is testing here: "dash" / "heal" / "melee" / "ranged",
## or "" for an ordinary room. Announced on entry, rewarded on clear.
var adaptive := ""
var is_boss_room := false
var had_elite := false
var palette := {}

var _player: Node3D
var _barrier: StaticBody3D
var _barrier_mesh: MeshInstance3D
var _back_barrier: StaticBody3D
var _back_mesh: MeshInstance3D
var _back_sealed := false
var _door_light_mat: StandardMaterial3D
var _taken_spots: Array = []


static func enemy_color(t: int, elite: int) -> Color:
	var base: Color
	match t:
		Enemy.Type.FAST:
			base = Color.from_hsv(0.36, 0.7, 0.85)
		Enemy.Type.BIG:
			base = Color.from_hsv(0.76, 0.5, 0.8)
		Enemy.Type.ARCHER:
			base = Color.from_hsv(0.13, 0.65, 0.9)
		_:
			base = Color.from_hsv(0.04, 0.55, 0.75)
	if elite != Enemy.Elite.NONE:
		return Color(Enemy.ELITE_DATA[elite]["color"]).lerp(base, 0.3)
	return base


func build(room_index: int, player: Node3D, cfg: Dictionary = {}) -> void:
	index = room_index
	_player = player
	challenge = int(cfg.get("challenge", Challenge.NONE))
	adaptive = str(cfg.get("adaptive", ""))
	is_boss_room = bool(cfg.get("boss", false))
	palette = Content.room_palette(GameManager.realm_of_room(index),
		index * 7919 + 13)

	_build_shell()
	_build_door()
	_build_back_barrier()
	_build_decor()
	if Engine.is_editor_hint():
		return
	if not is_boss_room:
		_spawn_traps()
	_spawn_enemies()


func challenge_name() -> String:
	match challenge:
		Challenge.ELITE_TRIAL:
			return "ELITE TRIAL"
		Challenge.VAULT:
			return "REWARD VAULT"
	return ""


func adaptive_title() -> String:
	return str(ADAPTIVE_TITLES.get(adaptive, ""))


func adaptive_desc() -> String:
	return str(ADAPTIVE_DESCS.get(adaptive, ""))


# -------------------------------------------------------------- geometry ----

func _build_shell() -> void:
	var floor_mat := Util.make_material(palette["floor"], 0.85, 0.05)
	var wall_mat := Util.make_material(palette["wall"], 0.9, 0.02)
	var ceil_mat := Util.make_material(palette["ceil"], 0.9, 0.02)

	Util.add_static_box(self, Vector3(WIDTH, 0.5, LENGTH), Vector3(0, -0.25, 0),
		floor_mat, Combat.LAYER_WORLD)
	Util.add_static_box(self, Vector3(WIDTH, 0.4, LENGTH), Vector3(0, HEIGHT + 0.2, 0),
		ceil_mat, Combat.LAYER_WORLD)

	Util.add_static_box(self, Vector3(0.5, HEIGHT, LENGTH),
		Vector3(-WIDTH / 2.0 - 0.25, HEIGHT / 2.0, 0), wall_mat, Combat.LAYER_WORLD)
	Util.add_static_box(self, Vector3(0.5, HEIGHT, LENGTH),
		Vector3(WIDTH / 2.0 + 0.25, HEIGHT / 2.0, 0), wall_mat, Combat.LAYER_WORLD)

	# The very first room is closed off behind the player.
	if index == 0:
		Util.add_static_box(self, Vector3(WIDTH, HEIGHT, 0.5),
			Vector3(0, HEIGHT / 2.0, LENGTH / 2.0 + 0.25), wall_mat, Combat.LAYER_WORLD)

	# Exit wall (with doorway) - this also serves as the next room's entry wall.
	var seg_w := (WIDTH - DOOR_W) / 2.0
	var z := -LENGTH / 2.0 - 0.25
	Util.add_static_box(self, Vector3(seg_w, HEIGHT, 0.5),
		Vector3(-(DOOR_W / 2.0 + seg_w / 2.0), HEIGHT / 2.0, z), wall_mat, Combat.LAYER_WORLD)
	Util.add_static_box(self, Vector3(seg_w, HEIGHT, 0.5),
		Vector3(DOOR_W / 2.0 + seg_w / 2.0, HEIGHT / 2.0, z), wall_mat, Combat.LAYER_WORLD)
	Util.add_static_box(self, Vector3(DOOR_W, HEIGHT - DOOR_H, 0.5),
		Vector3(0, DOOR_H + (HEIGHT - DOOR_H) / 2.0, z), wall_mat, Combat.LAYER_WORLD)


func _barrier_material() -> StandardMaterial3D:
	var m := Util.make_material(Color(1.0, 0.15, 0.1, 0.55), 0.2, 0.0,
		Color(1.0, 0.15, 0.1), 2.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	return m


func _build_door() -> void:
	_door_light_mat = Util.make_material(Color(0.1, 0.1, 0.12), 0.4, 0.3,
		Color(1.0, 0.15, 0.1), 2.0)
	Util.add_box(self, Vector3(DOOR_W + 0.4, 0.16, 0.6),
		Vector3(0, DOOR_H + 0.1, -LENGTH / 2.0), _door_light_mat)

	_barrier = _make_barrier(_barrier_material())
	_barrier.position = Vector3(0, 0, -LENGTH / 2.0)
	add_child(_barrier)
	_barrier_mesh = _barrier.get_node("Mesh") as MeshInstance3D


## Every room beyond the first gets a shutter behind the entry doorway. It
## slams shut the moment you step in, so you can never walk back.
func _build_back_barrier() -> void:
	if index == 0:
		return
	_back_barrier = _make_barrier(_barrier_material())
	_back_barrier.position = Vector3(0, 0, LENGTH / 2.0)
	add_child(_back_barrier)
	_back_mesh = _back_barrier.get_node("Mesh") as MeshInstance3D
	_back_mesh.visible = false
	_back_barrier.collision_layer = 0
	_set_shape_disabled(_back_barrier, true)


func _make_barrier(mat: StandardMaterial3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Combat.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_W, DOOR_H, 0.35)
	cs.shape = shape
	cs.position = Vector3(0, DOOR_H / 2.0, 0)
	body.add_child(cs)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(DOOR_W, DOOR_H, 0.35)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0, DOOR_H / 2.0, 0)
	body.add_child(mi)
	return body


## Called by the room manager as soon as the player crosses into this room.
func seal_back() -> void:
	if index == 0 or _back_barrier == null or _back_sealed:
		return
	_back_sealed = true
	_back_barrier.collision_layer = Combat.LAYER_WORLD
	call_deferred("_enable_shape", _back_barrier)
	_back_mesh.visible = true
	FX.burst(get_tree().current_scene, to_global(Vector3(0, 1.5, LENGTH / 2.0)),
		Color(1.0, 0.2, 0.1), 22, 0.12, 0.5, 5.0)
	_back_mesh.scale = Vector3(1.0, 0.05, 1.0)
	var tw := create_tween()
	tw.tween_property(_back_mesh, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_back_sealed() -> bool:
	return _back_sealed


func back_solid() -> bool:
	if _back_barrier == null:
		return index == 0
	return _back_barrier.collision_layer == Combat.LAYER_WORLD


func _enable_shape(body: StaticBody3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	_set_shape_disabled(body, false)


func _set_shape_disabled(body: StaticBody3D, disabled: bool) -> void:
	for child in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", disabled)


func _build_decor() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, HEIGHT - 0.7, 0)
	light.omni_range = randf_range(15.0, 19.0)
	light.light_energy = randf_range(1.3, 1.9)
	light.light_color = palette["light"]
	light.shadow_enabled = false
	add_child(light)

	var pillar_mat := Util.make_material(palette["pillar"], 0.75, 0.1)
	var accent_mat := Util.make_material(palette["accent"], 0.4, 0.2,
		palette["accent"], 2.2)

	# Four different furniture layouts so back-to-back rooms never read the same.
	match int(palette["decor"]):
		0:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					Util.add_box(self, Vector3(1.0, HEIGHT, 1.0),
						Vector3(sx * (WIDTH / 2.0 - 0.75), HEIGHT / 2.0,
							sz * (LENGTH / 2.0 - 0.75)), pillar_mat, 0.05)
		1:
			# Glowing floor trim instead of pillars - keeps the arena open.
			for sx in [-1.0, 1.0]:
				Util.add_box(self, Vector3(0.18, 0.06, LENGTH - 3.0),
					Vector3(sx * (WIDTH / 2.0 - 1.1), 0.03, 0), accent_mat, 0.0)
				Util.add_box(self, Vector3(0.14, 1.4, LENGTH - 3.0),
					Vector3(sx * (WIDTH / 2.0 - 0.4), HEIGHT - 1.0, 0), pillar_mat, 0.04)
		2:
			for sx in [-1.0, 1.0]:
				Util.add_box(self, Vector3(1.2, HEIGHT, 1.2),
					Vector3(sx * (WIDTH / 2.0 - 1.0), HEIGHT / 2.0, -3.5),
					pillar_mat, 0.05)
				Util.add_box(self, Vector3(1.2, HEIGHT, 1.2),
					Vector3(sx * (WIDTH / 2.0 - 1.0), HEIGHT / 2.0, 3.5),
					pillar_mat, 0.05)
		_:
			for sx in [-1.0, 1.0]:
				Util.add_box(self, Vector3(0.8, HEIGHT, 0.8),
					Vector3(sx * (WIDTH / 2.0 - 0.7), HEIGHT / 2.0,
						LENGTH / 2.0 - 0.7), pillar_mat, 0.05)
			Util.add_box(self, Vector3(WIDTH - 2.0, 0.3, 0.8),
				Vector3(0, HEIGHT - 0.4, -2.5), pillar_mat, 0.04)
			Util.add_box(self, Vector3(WIDTH - 2.0, 0.3, 0.8),
				Vector3(0, HEIGHT - 0.4, 2.5), pillar_mat, 0.04)

	if challenge != Challenge.NONE:
		_build_challenge_marker()
	elif adaptive != "":
		_build_adaptive_marker()


## A cyan ring + cool beacon: the adaptive test reads as "the system is
## watching this one" rather than the gold/violet of a reward challenge.
func _build_adaptive_marker() -> void:
	var col := Color(0.35, 0.85, 1.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.0
	torus.outer_radius = 3.3
	ring.mesh = torus
	ring.material_override = Util.make_material(col, 0.3, 0.0, col, 3.0)
	ring.position = Vector3(0, 0.08, 0)
	ring.rotation.x = PI / 2.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0, 2.2, 0)
	beacon.omni_range = 13.0
	beacon.light_color = col
	beacon.light_energy = 1.4
	beacon.shadow_enabled = false
	add_child(beacon)


## A floor ring + banner light so a challenge room is obvious at a glance.
func _build_challenge_marker() -> void:
	var gold := challenge == Challenge.VAULT
	var col := Color(1.0, 0.85, 0.3) if gold else Color(0.9, 0.25, 0.95)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.0
	torus.outer_radius = 3.35
	ring.mesh = torus
	var m := Util.make_material(col, 0.3, 0.0, col, 3.0)
	ring.material_override = m
	ring.position = Vector3(0, 0.08, 0)
	ring.rotation.x = PI / 2.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0, 2.2, 0)
	beacon.omni_range = 14.0
	beacon.light_color = col
	beacon.light_energy = 1.6
	beacon.shadow_enabled = false
	add_child(beacon)


# ------------------------------------------------------------- spawning -----

func _spawn_traps() -> void:
	var count := clampi(1 + index / 3, 1, 5)
	if GameManager.difficulty >= GameManager.Difficulty.HARD:
		count += 1
	# The dash test: reflexive movement gets punished with a faster cycle.
	var haste := 1.6 if adaptive == "dash" else 1.0
	if adaptive == "dash":
		count = mini(count + 1, 6)
	var trap_dmg := 12.0 * float(GameManager.settings()["dmg_mult"])
	for i in count:
		var spot := _find_spot(2.6, Vector3(0, 0, LENGTH / 2.0 - 3.0), 5.0, 3.5)
		var trap := SpikeTrap.new()
		trap.damage = trap_dmg
		trap.haste = haste
		trap.position = spot
		add_child(trap)


## Mix of enemy types, unlocked gradually so the first rooms stay readable.
func _pick_type() -> int:
	var roll := randf()
	if index >= 3 and roll < 0.16:
		return Enemy.Type.BIG
	if index >= 2 and roll < 0.40:
		return Enemy.Type.ARCHER
	if index >= 1 and roll < 0.66:
		return Enemy.Type.FAST
	return Enemy.Type.GRUNT


## Adaptive rooms counter the behavior they are testing: the melee test
## fills the room with archers (they refuse to let you close), the ranged
## test floods it with runners (nothing stays at distance).
func _pick_adaptive_type() -> int:
	match adaptive:
		"melee":
			return Enemy.Type.ARCHER if randf() < 0.7 else Enemy.Type.GRUNT
		"ranged":
			return Enemy.Type.FAST if randf() < 0.7 else Enemy.Type.BIG
		"heal":
			# High single hits make every heal decision expensive.
			return Enemy.Type.BIG if randf() < 0.45 else _pick_type()
	return _pick_type()


func _spawn_enemies() -> void:
	if is_boss_room:
		return
	var settings := GameManager.settings()
	var count := maxi(1, 1 + floori(index * 0.8) + int(settings["enemy_bonus"]))
	match challenge:
		Challenge.ELITE_TRIAL:
			count = maxi(3, count - 1)
		Challenge.VAULT:
			count = maxi(1, count - 2)

	for i in count:
		var t := _pick_adaptive_type() if adaptive != "" else _pick_type()
		var elite := Enemy.Elite.NONE

		if challenge == Challenge.ELITE_TRIAL and i == 0:
			elite = Enemy.ELITE_KINDS[randi() % Enemy.ELITE_KINDS.size()]
			had_elite = true
		elif index >= 5 and randf() < 0.05:
			# Rare wandering elite keeps ordinary rooms exciting.
			elite = Enemy.ELITE_KINDS[randi() % Enemy.ELITE_KINDS.size()]
			had_elite = true

		if elite == Enemy.Elite.HEXMASTER:
			t = Enemy.Type.ARCHER
		elif elite == Enemy.Elite.JUGGERNAUT:
			t = Enemy.Type.BIG

		var data: Dictionary = Enemy.TYPE_DATA[t]
		var scale_v := float(data["scale"]) * (1.35 if elite != Enemy.Elite.NONE else 1.0)
		var spot := _find_spot(3.2 * scale_v,
			Vector3(0, 0, LENGTH / 2.0 - 3.0), 7.5, 2.0 * scale_v)

		var cfg := EnemyFactory.room_cfg(t, elite, index,
			1.2 if challenge == Challenge.ELITE_TRIAL else 1.0)
		# `spot` is room-local, EnemyFactory.spawn() expects world space.
		var enemy := EnemyFactory.spawn(self, _player,
			to_global(spot + Vector3(0, 0.8 * scale_v, 0)), cfg)
		enemies.append(enemy)
		enemy.died.connect(_on_enemy_died)


## Picks a local XZ position with margins, away from `away_from` and other spawns.
func _find_spot(margin: float, away_from: Vector3, min_dist: float,
		min_between: float) -> Vector3:
	var limit_x := WIDTH / 2.0 - margin
	var limit_z := LENGTH / 2.0 - margin
	var best := Vector3.ZERO
	var best_score := -1.0
	for attempt in 24:
		var p := Vector3(randf_range(-limit_x, limit_x), 0.0, randf_range(-limit_z, limit_z))
		var d_away := Vector2(p.x - away_from.x, p.z - away_from.z).length()
		if d_away < min_dist:
			continue
		var too_close := false
		for other in _taken_spots:
			if Vector2(p.x - other.x, p.z - other.z).length() < min_between:
				too_close = true
				break
		if too_close:
			continue
		_taken_spots.append(p)
		return p
	# Fallback: just take the furthest point we sampled.
	for attempt in 24:
		var p := Vector3(randf_range(-limit_x, limit_x), 0.0, randf_range(-limit_z, limit_z))
		var d := Vector2(p.x - away_from.x, p.z - away_from.z).length()
		if d > best_score:
			best_score = d
			best = p
	_taken_spots.append(best)
	return best


# -------------------------------------------------------------- cleared -----

func _on_enemy_died(enemy: Enemy) -> void:
	enemies.erase(enemy)
	if enemies.is_empty() and not is_cleared:
		_mark_cleared()


func _mark_cleared() -> void:
	is_cleared = true
	_open_barrier()
	cleared.emit(self)


func _open_barrier() -> void:
	_door_light_mat.emission = Color(0.2, 1.0, 0.45)
	_door_light_mat.emission_energy_multiplier = 3.0
	if _barrier != null:
		_barrier.collision_layer = 0
		call_deferred("_disable_barrier_collision")
	var tw := create_tween()
	tw.tween_property(_barrier_mesh, "position:y", -1.2, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_barrier_mesh, "scale", Vector3(1.0, 0.3, 1.0), 0.35)
	tw.tween_callback(_hide_barrier)


func _disable_barrier_collision() -> void:
	if _barrier != null and is_instance_valid(_barrier) and _barrier.collision_layer == 0:
		_set_shape_disabled(_barrier, true)


func _hide_barrier() -> void:
	if _barrier != null and is_instance_valid(_barrier):
		_barrier.visible = false
