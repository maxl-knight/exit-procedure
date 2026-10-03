class_name Player
extends CharacterBody3D

signal died
signal health_changed(current: float, max_health: float)
signal damaged_received(amount: float)
signal buff_added(id: String, stacks: int)
signal curse_added(id: String, total: int)

const CHAR_BRAWLER := 0
const CHAR_SWORDSMAN := 1
const CHAR_ICE_MAGE := 2

const DATA := {
	CHAR_BRAWLER: {
		"name": "Brawler",
		"color": Color(0.2, 0.55, 1.0),
		"accent": Color(0.04, 0.1, 0.3),
		"speed": 7.0,
		"max_health": 100.0,
		"damage": 14.0,
		"range": 2.5,
		"attack_cd": 0.42,
		"unique_name": "Super Punch",
		"dash_charges": 3,
		"desc": "Fast punches and 3 dashes. Super Punch detonates everything nearby.",
	},
	CHAR_SWORDSMAN: {
		"name": "Swordsman",
		"color": Color(1.0, 0.55, 0.12),
		"accent": Color(0.35, 0.12, 0.02),
		"speed": 6.4,
		"max_health": 90.0,
		"damage": 24.0,
		"range": 3.7,
		"attack_cd": 0.72,
		"unique_name": "Whirlwind",
		"dash_charges": 1,
		"desc": "Longer, harder sword swings and Whirlwind, but only 1 dash.",
	},
	CHAR_ICE_MAGE: {
		"name": "Ice Mage",
		"color": Color(0.55, 0.85, 1.0),
		"accent": Color(0.06, 0.2, 0.5),
		"speed": 6.6,
		"max_health": 85.0,
		"damage": 15.0,
		"range": 13.0,
		"attack_cd": 0.5,
		"unique_name": "Ice Shards",
		"dash_charges": 2,
		"desc": "Frost bolts from range. Super spawns 6 orbiting shards that chill "
			+ "enemies 35% - at 200% it launches 10 that hunt the nearest foe.",
	},
}

const DASH_SPEED := 23.0
const DASH_TIME := 0.22
const DASH_RECHARGE := 4.0
const HEAL_AMOUNT := 45.0
const HEAL_DURATION := 1.4
const HEAL_CD_MAX := 14.0

## The super bar climbs to 200%. 100% fires normally, 200% is the boosted hit.
const SUPER_MAX := 200.0
const SUPER_READY := 100.0
const SUPER_RADIUS := 3.6
const SUPER_RADIUS_SWORD := 4.3
const SUPER_DAMAGE := 55.0
const SUPER_DAMAGE_SWORD := 51.0
const SUPER_PER_DEALT := 1.0
const SUPER_PER_TAKEN := 2.0
const DESPERATION_HEALTH_PCT := 0.25
const DESPERATION_TIME := 10.0

## Ice Mage super: orbiting shards at 100%, homing shards at 200%.
const ICE_SHARD_COUNT := 6
const ICE_MEGA_SHARD_COUNT := 10
const ICE_SHARD_DAMAGE := 12.0
const ICE_SEEK_DAMAGE := 18.0
const ICE_SHARD_SLOW := 0.65
const ICE_SHARD_SLOW_TIME := 3.0
const ICE_ORBIT_TIME := 6.0
const ICE_SEEK_TIME := 7.0
const ICE_BOLT_SPEED := 32.0

const HIT_COLOR := Color(1.0, 0.72, 0.25)

var character_type: int = 0
var stats: Dictionary = {}

var health: Health
var camera: CameraRig

## Stacking run upgrades (8 kinds) and the curses that never wear off (10 kinds).
var buffs: Dictionary = {}
var curses: Array[String] = []

var super_charge := SUPER_MAX
var dash_charges_max := 3
var dash_charges := 3
var dash_recharging := false
var dash_recharge_t := 0.0
var heal_cd := 0.0

var ability_names: Array[String] = ["Super Punch", "Dash", "Heal"]
var ability_keys: Array[String] = ["Q", "Shift", "E"]

var invulnerable := false
var dead := false

## What most recently hurt us ("melee" / "ranged" / "trap" / "clone") - the
## Arena files its memory by cause of death.
var last_hit_source := "unknown"

## Adaptive-room suppression: halves healing while the Arena tests the fact
## that you lean on reconstruction.
var arena_heal_mult := 1.0

## True once the bar has been rebuilt to 190%+ after a spend - used to catch
## "holds the super forever" as a tracked play style.
var _super_held_announced := false

## 1.5x damage window granted by a desperation super.
var damage_bonus_mult := 1.0
var damage_bonus_time := 0.0

var visual: Node3D
var _arm_pivot: Node3D
var _body_mat: StandardMaterial3D
var _collision: CollisionShape3D
var _swing_tween: Tween

var attack_timer := 0.0
var attack_face_time := 0.0
var dash_time := 0.0
var dash_dir := Vector3.ZERO
var heal_time := 0.0
var heal_fx_accum := 0.0
var hit_flash := 0.0
var _trail_accum := 0.0


func _ready() -> void:
	stats = DATA[character_type]
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD

	_collision = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	_collision.shape = capsule
	_collision.position = Vector3(0, 0.9, 0)
	add_child(_collision)

	health = Health.new()
	health.setup(max_health_now())
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.healed.connect(_on_healed)
	health.died.connect(_on_died)

	ability_names[0] = stats["unique_name"]
	dash_charges_max = dash_max_now()
	dash_charges = dash_charges_max
	# Runs start with a full bar, so "held to 190%" only means something
	# after the first spend.
	_super_held_announced = super_charge >= 190.0

	_build_visual()


# ----------------------------------------------------------- derived stats ---

func buff_stacks(id: String) -> int:
	return int(buffs.get(id, 0))


func curse_count(id: String) -> int:
	var n := 0
	for c in curses:
		if c == id:
			n += 1
	return n


func max_health_now() -> float:
	var v := float(stats["max_health"]) + GameManager.hp_bonus()
	v += 20.0 * buff_stacks("vigor")
	v *= pow(0.85, curse_count("frailty"))
	return maxf(10.0, v)


func recalc_max_health() -> void:
	var new_max := max_health_now()
	var delta := new_max - health.max_health
	health.max_health = new_max
	if delta > 0.0:
		health.health = minf(new_max, health.health + delta)
	else:
		health.health = minf(health.health, new_max)
	health_changed.emit(health.health, health.max_health)


## Difficulty cooldowns * Haste * Broken Focus.
func cooldown_mult_now() -> float:
	var v := GameManager.cooldown_mult()
	v *= pow(0.9, buff_stacks("haste"))
	v *= pow(1.25, curse_count("broken_focus"))
	return maxf(0.2, v)


func attack_cooldown_now() -> float:
	return float(stats["attack_cd"]) * cooldown_mult_now() \
		* pow(1.25, curse_count("slow_blades"))


func damage_now() -> float:
	var v := float(stats["damage"])
	v *= 1.0 + 0.15 * buff_stacks("might")
	v *= pow(0.8, curse_count("weakness"))
	v *= damage_bonus_mult
	return maxf(1.0, v)


func move_speed_now() -> float:
	var v := float(stats["speed"])
	v *= 1.0 + 0.08 * buff_stacks("swiftness")
	v *= pow(0.85, curse_count("sluggish"))
	return maxf(1.5, v)


func attack_range_now() -> float:
	var v := float(stats["range"])
	v *= 1.0 + 0.12 * buff_stacks("reach")
	v *= pow(0.8, curse_count("short_reach"))
	return maxf(1.0, v)


func heal_amount_now() -> float:
	var v := HEAL_AMOUNT * (1.0 + 0.25 * buff_stacks("second_wind"))
	v *= pow(0.5, curse_count("deep_wounds"))
	v *= arena_heal_mult
	return v


func damage_taken_mult_now() -> float:
	var v := 1.0 + 0.15 * curse_count("brittle")
	v *= pow(0.92, buff_stacks("thick_skin"))
	return v


func charge_rate_now() -> float:
	return (1.0 + 0.25 * buff_stacks("fury")) * pow(0.6, curse_count("soul_drain"))


func dash_max_now() -> int:
	return maxi(1, int(stats["dash_charges"]) - curse_count("burden"))


func super_base_damage() -> float:
	match character_type:
		CHAR_SWORDSMAN:
			return SUPER_DAMAGE_SWORD
		CHAR_ICE_MAGE:
			return SUPER_DAMAGE * 0.9
	return SUPER_DAMAGE


func super_base_radius() -> float:
	return SUPER_RADIUS if character_type == CHAR_BRAWLER else SUPER_RADIUS_SWORD


# ---------------------------------------------------------------- upgrades ---

func apply_buff(id: String) -> bool:
	if not Content.BUFFS.has(id):
		return false
	buffs[id] = buff_stacks(id) + 1
	if id == "vigor":
		recalc_max_health()
	buff_added.emit(id, buff_stacks(id))
	return true


func apply_curse(id: String) -> bool:
	if not Content.CURSES.has(id):
		return false
	curses.append(id)
	recalc_max_health()
	dash_charges_max = dash_max_now()
	dash_charges = mini(dash_charges, dash_charges_max)
	curse_added.emit(id, curse_count(id))
	return true


## Picks a curse the player does not have yet when there is one left,
## applies it, and returns its id so the caller can announce it.
func apply_random_curse(rng_seed: int = -1) -> String:
	var owned := {}
	for c in curses:
		owned[c] = true
	var fresh: Array = []
	for id in Content.CURSE_IDS:
		if not owned.has(id):
			fresh.append(id)
	var pool: Array = fresh if not fresh.is_empty() else Content.CURSE_IDS.duplicate()
	var id: String
	if rng_seed >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = rng_seed
		id = str(pool[rng.randi_range(0, pool.size() - 1)])
	else:
		id = str(pool[randi() % pool.size()])
	apply_curse(id)
	return id


# ------------------------------------------------------------------ input ----

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		try_attack()


func _physics_process(delta: float) -> void:
	if dead:
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	attack_face_time = maxf(0.0, attack_face_time - delta)
	heal_cd = maxf(0.0, heal_cd - delta)

	if damage_bonus_time > 0.0:
		damage_bonus_time -= delta
		if damage_bonus_time <= 0.0:
			damage_bonus_time = 0.0
			damage_bonus_mult = 1.0

	if dash_recharging:
		dash_recharge_t -= delta
		if dash_recharge_t <= 0.0:
			dash_recharging = false
			dash_recharge_t = 0.0
			dash_charges = dash_charges_max

	_handle_abilities()
	_handle_movement(delta)
	_handle_heal(delta)
	animate_hit_flash(delta)
	move_and_slide()


func _process(delta: float) -> void:
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		var base: Color = stats["color"]
		var t := hit_flash / 0.18
		_body_mat.albedo_color = base.lerp(Color.WHITE, t)


func _handle_movement(delta: float) -> void:
	var dir := _input_direction()

	if dash_time > 0.0:
		dash_time -= delta
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		_trail_accum += delta
		if _trail_accum >= 0.05:
			_trail_accum = 0.0
			FX.burst(get_tree().current_scene, global_position + Vector3(0, 0.9, 0),
				Color(0.55, 0.8, 1.0), 8, 0.09, 0.35, 2.5)
		if dash_time <= 0.0:
			invulnerable = false
	else:
		var target := dir * move_speed_now()
		var accel := 18.0
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if is_on_floor():
		velocity.y = -0.6
	else:
		velocity.y -= 26.0 * delta

	var face := dir
	if attack_face_time > 0.0 and camera != null:
		face = camera.get_flat_forward()
	if face.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 12.0 * delta)


func _handle_abilities() -> void:
	if Input.is_action_just_pressed("ability_1"):
		_use_unique()
	elif Input.is_action_just_pressed("ability_2"):
		_use_dash()
	elif Input.is_action_just_pressed("ability_3"):
		_use_heal()


func _handle_heal(delta: float) -> void:
	if heal_time <= 0.0:
		return
	heal_time -= delta
	health.heal(heal_amount_now() * delta / HEAL_DURATION)
	heal_fx_accum += delta
	if heal_fx_accum >= 0.22:
		heal_fx_accum = 0.0
		FX.burst(get_tree().current_scene, global_position + Vector3(0, 1.4, 0),
			Color(0.35, 1.0, 0.5), 8, 0.09, 0.5, 2.2)
	if heal_time <= 0.0:
		heal_time = 0.0


# --------------------------------------------------------------- combat ----

func try_attack() -> void:
	if dead or attack_timer > 0.0:
		return
	attack_timer = attack_cooldown_now()
	attack_face_time = 0.3
	ArenaMemory.note_attack("bolt" if character_type == CHAR_ICE_MAGE else "melee")
	var reach := attack_range_now()
	var fwd := _attack_forward()
	# Soft lock: lean the attack toward whatever is closest to the crosshair.
	var cone := 45.0 if character_type != CHAR_ICE_MAGE else 26.0
	fwd = Combat.aim_assist(self, global_position + Vector3(0, 1.0, 0), fwd, reach, cone)
	rotation.y = atan2(-fwd.x, -fwd.z)
	_swing()
	if character_type == CHAR_ICE_MAGE:
		_fire_bolt(fwd)
		return
	var center := global_position + Vector3(0, 1.0, 0) + fwd * (reach * 0.55)
	var dealt := Combat.damage_sphere(self, center, reach * 0.6, damage_now(),
		fwd, 7.0, HIT_COLOR)
	_charge_super(dealt)


## Frost bolt: straight-line skillshot that stops on the first wall or body.
func _fire_bolt(dir: Vector3) -> void:
	var root := _scene_root()
	if root == null:
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length_squared() > 0.001 else Vector3(0, 0, -1)
	var bolt := IceBolt.new()
	bolt.setup(d, damage_now(), attack_range_now(), self)
	root.add_child(bolt)
	bolt.global_position = global_position + Vector3(0, 1.25, 0) + d * 0.75
	FX.burst(root, bolt.global_position, Color(0.6, 0.9, 1.0), 10, 0.1, 0.3, 3.0)


func charge_super(amount: float) -> void:
	_charge_super(amount)


func _scene_root() -> Node:
	var tree := get_tree()
	if tree == null:
		return get_parent()
	return tree.current_scene if tree.current_scene != null else get_parent()


func can_use_unique() -> bool:
	return not dead and super_charge >= SUPER_READY - 0.01


func _use_unique() -> void:
	if not can_use_unique():
		return
	ArenaMemory.note_super()
	_super_held_announced = false
	var at_max := super_charge >= SUPER_MAX - 0.5
	var desperate := at_max and health.health <= health.max_health * DESPERATION_HEALTH_PCT
	super_charge = 0.0
	attack_face_time = 0.45

	if desperate:
		_desperation_strike()
	elif at_max:
		if character_type == CHAR_ICE_MAGE:
			_spawn_shards(ICE_MEGA_SHARD_COUNT, true)
		else:
			_mega_strike()
	elif character_type == CHAR_ICE_MAGE:
		_spawn_shards(ICE_SHARD_COUNT, false)
	elif character_type == CHAR_SWORDSMAN:
		_whirlwind()
	else:
		_super_punch()


## 100%: six shards circle you and chill anything they touch.
## 200%: ten shards launch themselves at the nearest enemies.
func _spawn_shards(count: int, homing: bool) -> void:
	var root := _scene_root()
	if root == null:
		return
	_spin_visual()
	var field := IceShards.new()
	field.setup(self, count, homing)
	root.add_child(field)
	var radius := 6.5 if homing else 4.5
	FX.ring(root, global_position + Vector3(0, 0.3, 0),
		Color(0.45, 0.85, 1.0), radius, 0.55)
	FX.burst(root, global_position + Vector3(0, 1.1, 0),
		Color(0.7, 0.95, 1.0), 60 if homing else 34, 0.14, 0.7, 9.0)
	if camera != null:
		camera.shake(0.6 if homing else 0.35)


## 100% - the original super.
func _super_punch() -> void:
	var fwd := Combat.aim_assist(self, global_position + Vector3(0, 1.0, 0),
		_attack_forward(), super_base_radius() + 2.0, 40.0)
	rotation.y = atan2(-fwd.x, -fwd.z)
	_swing()
	var center := global_position + Vector3(0, 0.9, 0) + fwd * 2.0
	var scene := get_tree().current_scene
	FX.ring(scene, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.7, 0.2), 4.0, 0.5)
	FX.burst(scene, center, Color(1.0, 0.78, 0.3), 55, 0.17, 0.7, 11.0)
	Combat.damage_sphere(self, center, super_base_radius(), super_base_damage(), fwd,
		17.0, Color(1.0, 0.82, 0.35))
	if camera != null:
		camera.shake(0.4)


func _whirlwind() -> void:
	_spin_visual()
	for i in 3:
		var timer := get_tree().create_timer(0.17 * i)
		timer.timeout.connect(_whirlwind_tick)
	if camera != null:
		camera.shake(0.25)


func _whirlwind_tick() -> void:
	if dead or not is_instance_valid(self):
		return
	var center := global_position + Vector3(0, 0.9, 0)
	var scene := get_tree().current_scene
	FX.ring(scene, global_position + Vector3(0, 0.2, 0), Color(1.0, 0.9, 0.4), 3.4, 0.4)
	Combat.damage_sphere(self, center, super_base_radius(), 17.0, Vector3.ZERO, 6.0,
		Color(1.0, 0.92, 0.45))
	if camera != null:
		camera.shake(0.18)


## 200% - twice the damage across three times the reach.
func _mega_strike() -> void:
	var fwd := Combat.aim_assist(self, global_position + Vector3(0, 1.0, 0),
		_attack_forward(), super_base_radius() * 2.0, 45.0)
	rotation.y = atan2(-fwd.x, -fwd.z)
	_swing()
	var center := global_position + Vector3(0, 0.9, 0) + fwd * 3.0
	var radius := super_base_radius() * 3.0
	var scene := get_tree().current_scene
	FX.ring(scene, global_position + Vector3(0, 0.3, 0), Color(0.3, 0.75, 1.0), 7.0, 0.6)
	FX.ring(scene, global_position + Vector3(0, 0.3, 0), Color(1.0, 1.0, 1.0), 4.0, 0.35)
	FX.burst(scene, center, Color(0.5, 0.85, 1.0), 90, 0.2, 0.8, 16.0)
	Combat.damage_sphere(self, center, radius, super_base_damage() * 2.0, fwd, 24.0,
		Color(0.55, 0.9, 1.0))
	if camera != null:
		camera.shake(0.7)


## 200% at <=25% health - 5x damage in every direction, a knockback blast and
## 1.5x damage for the next 10 seconds.
func _desperation_strike() -> void:
	var center := global_position + Vector3(0, 0.9, 0)
	var radius := minf(super_base_radius() * 3.4, 12.5)
	var scene := get_tree().current_scene
	_spin_visual()
	FX.ring(scene, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.2, 0.15), 9.0, 0.7)
	FX.ring(scene, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.3), 6.0, 0.5)
	FX.burst(scene, center, Color(1.0, 0.35, 0.2), 140, 0.24, 0.9, 22.0)
	Combat.damage_sphere(self, center, radius, super_base_damage() * 5.0, Vector3.ZERO,
		34.0, Color(1.0, 0.45, 0.25))
	damage_bonus_mult = 1.5
	damage_bonus_time = DESPERATION_TIME
	if character_type == CHAR_ICE_MAGE:
		# The frost version of the desperation blast keeps the 200% payload.
		_spawn_shards(ICE_MEGA_SHARD_COUNT, true)
	if camera != null:
		camera.shake(1.0)


func _charge_super(amount: float) -> void:
	if amount <= 0.0:
		return
	super_charge = minf(SUPER_MAX, super_charge + amount * charge_rate_now())
	if not _super_held_announced and super_charge >= 190.0:
		_super_held_announced = true
		ArenaMemory.note_super_held()


func can_dash() -> bool:
	return not dead and dash_time <= 0.0 and not dash_recharging and dash_charges > 0


func _use_dash() -> void:
	if not can_dash():
		return
	ArenaMemory.note_dash()
	dash_charges -= 1
	if dash_charges <= 0:
		dash_charges = 0
		dash_recharging = true
		dash_recharge_t = DASH_RECHARGE * cooldown_mult_now()
	dash_time = DASH_TIME
	invulnerable = true
	_trail_accum = 0.0
	var dir := _input_direction()
	if dir.length_squared() < 0.01:
		dir = _attack_forward()
	dash_dir = dir.normalized()
	dash_dir.y = 0.0
	FX.burst(get_tree().current_scene, global_position + Vector3(0, 0.5, 0),
		Color(0.55, 0.8, 1.0), 18, 0.1, 0.4, 4.5)


func _use_heal() -> void:
	if dead or heal_cd > 0.0 or heal_time > 0.0:
		return
	if health.health >= health.max_health:
		return
	ArenaMemory.note_heal()
	heal_cd = HEAL_CD_MAX * cooldown_mult_now()
	heal_time = HEAL_DURATION
	heal_fx_accum = 0.0


## Damage from traps / enemies / projectiles. Returns the damage actually taken.
## `source` tags the hit so the Arena can file its memory by cause of death.
func apply_hit(damage: float, dir: Vector3, knockback: float = 0.0,
		source: String = "") -> float:
	if dead or invulnerable:
		return 0.0
	var scaled := damage * damage_taken_mult_now()
	var dealt := minf(scaled, health.health)
	if source != "":
		last_hit_source = source
	if dir.length_squared() > 0.01 and knockback > 0.0:
		var push := dir.normalized() * knockback
		velocity.x += push.x
		velocity.z += push.z
	health.take_damage(scaled, global_position)
	return dealt


## One entry per ability: how full the bar is (0..1), a short label, readiness.
func get_ability_state() -> Array:
	var super_fill := clampf(super_charge / SUPER_MAX, 0.0, 1.0)
	var dash_fill := 1.0
	var dash_label := "x%d" % dash_charges
	var dash_ready := not dash_recharging and dash_charges > 0
	if dash_recharging:
		dash_fill = clampf(1.0 - dash_recharge_t / maxf(DASH_RECHARGE
			* cooldown_mult_now(), 0.1), 0.0, 1.0)
		dash_label = "%.0f" % dash_recharge_t
	elif dash_charges_max > 0:
		dash_fill = float(dash_charges) / float(dash_charges_max)

	var heal_max := HEAL_CD_MAX * cooldown_mult_now()
	var heal_fill := clampf(1.0 - heal_cd / maxf(heal_max, 0.1), 0.0, 1.0)
	var super_label := "%d%%" % int(round(super_charge))
	if super_charge >= SUPER_MAX - 0.5:
		super_label = "200%!"
	elif super_charge >= SUPER_READY:
		super_label = "READY"

	return [
		{
			"name": ability_names[0],
			"key": ability_keys[0],
			"fill": super_fill,
			"label": super_label,
			"ready": super_charge >= SUPER_READY - 0.01,
		},
		{
			"name": ability_names[1],
			"key": ability_keys[1],
			"fill": dash_fill,
			"label": dash_label,
			"ready": dash_ready,
		},
		{
			"name": ability_names[2],
			"key": ability_keys[2],
			"fill": heal_fill,
			"label": "%.1f" % heal_cd if heal_cd > 0.05 else "READY",
			"ready": heal_cd <= 0.0,
		},
	]


# -------------------------------------------------------------- signals ----

func _on_damaged(amount: float, current: float, _hit_position: Vector3) -> void:
	hit_flash = 0.18
	GameManager.room_damage += amount
	ArenaMemory.note_damage(amount)
	health_changed.emit(current, health.max_health)
	damaged_received.emit(amount)
	_charge_super(amount * SUPER_PER_TAKEN)
	FX.burst(get_tree().current_scene, global_position + Vector3(0, 1.1, 0),
		Color(1.0, 0.2, 0.18), 26, 0.13, 0.5, 6.5)
	if camera != null:
		camera.shake(0.24)


func _on_healed(_amount: float, current: float) -> void:
	health_changed.emit(current, health.max_health)


func _on_died() -> void:
	if dead:
		return
	dead = true
	invulnerable = true
	collision_layer = 0
	call_deferred("_disable_collision")
	died.emit()
	var scene := get_tree().current_scene
	FX.burst(scene, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.15, 0.15),
		70, 0.17, 0.9, 9.5)
	FX.ring(scene, global_position + Vector3(0, 0.2, 0), Color(1.0, 0.3, 0.2), 3.0, 0.5)
	if camera != null:
		camera.shake(0.5)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.0, 0.04, 1.0), 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(visual, "visible", false, 0.05)


func _disable_collision() -> void:
	if _collision != null and is_instance_valid(_collision):
		_collision.disabled = true


# --------------------------------------------------------------- helpers ----

func _input_direction() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis.IDENTITY
	if camera != null:
		basis = camera.get_yaw_basis()
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var d := right * v.x + fwd * (-v.y)
	d.y = 0.0
	if d.length_squared() > 1.0:
		d = d.normalized()
	return d


func _attack_forward() -> Vector3:
	if camera != null:
		return camera.get_flat_forward()
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.001 else Vector3(0, 0, -1)


func animate_hit_flash(_delta: float) -> void:
	if hit_flash <= 0.0:
		var base: Color = stats["color"]
		_body_mat.albedo_color = base


# --------------------------------------------------------------- visuals ----

func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)

	_body_mat = Util.make_material(stats["color"], 0.55, 0.15)
	Util.add_capsule(visual, 0.45, 1.8, Vector3(0, 0.9, 0), _body_mat, 0.05)

	var accent := Util.make_material(stats["accent"], 0.7, 0.1)
	Util.add_sphere(visual, 0.3, Vector3(0, 1.95, 0), accent, 0.04)

	var eye_mat := Util.make_material(Color(0.95, 0.97, 1.0), 0.2, 0.0,
		Color(1, 1, 1), 1.6)
	Util.add_sphere(visual, 0.07, Vector3(-0.13, 2.0, -0.26), eye_mat)
	Util.add_sphere(visual, 0.07, Vector3(0.13, 2.0, -0.26), eye_mat)

	Util.add_box(visual, Vector3(0.22, 0.3, 0.22), Vector3(-0.18, 0.16, 0), accent, 0.03)
	Util.add_box(visual, Vector3(0.22, 0.3, 0.22), Vector3(0.18, 0.16, 0), accent, 0.03)

	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0.42, 1.3, 0.0)
	visual.add_child(_arm_pivot)

	if character_type == CHAR_SWORDSMAN:
		Util.add_box(_arm_pivot, Vector3(0.14, 0.14, 0.7), Vector3(0, 0, -0.3), accent, 0.03)
		Util.add_box(_arm_pivot, Vector3(0.34, 0.08, 0.1), Vector3(0, 0, -0.66),
			Util.make_material(Color(0.75, 0.6, 0.2), 0.35, 0.8), 0.02)
		Util.add_box(_arm_pivot, Vector3(0.08, 0.06, 1.5), Vector3(0, 0, -1.45),
			Util.make_material(Color(0.85, 0.88, 0.95), 0.15, 0.95, Color(0.6, 0.75, 1.0), 0.35),
			0.02)
	elif character_type == CHAR_ICE_MAGE:
		var staff := Util.make_material(Color(0.22, 0.3, 0.52), 0.6, 0.15)
		Util.add_box(_arm_pivot, Vector3(0.13, 0.13, 0.5), Vector3(0, 0, -0.2), accent, 0.03)
		Util.add_box(_arm_pivot, Vector3(0.09, 0.09, 1.75), Vector3(0, 0.04, -0.8),
			staff, 0.03)
		Util.add_cone(_arm_pivot, 0.14, 0.34, Vector3(0, 0.04, -1.68), staff, 0.03)
		var crystal := Util.make_material(Color(0.72, 0.95, 1.0), 0.1, 0.0,
			Color(0.35, 0.75, 1.0), 4.0)
		Util.add_sphere(_arm_pivot, 0.2, Vector3(0, 0.04, -1.86), crystal, 0.04)
		# Frozen pauldrons so the silhouette reads at a glance.
		var ice := Util.make_material(Color(0.75, 0.93, 1.0), 0.2, 0.1,
			Color(0.4, 0.8, 1.0), 1.6)
		for side in [-1.0, 1.0]:
			Util.add_cone(visual, 0.14, 0.4, Vector3(side * 0.4, 1.75, 0.0), ice, 0.04)
	else:
		Util.add_box(_arm_pivot, Vector3(0.14, 0.14, 0.5), Vector3(0, 0, -0.2), accent, 0.03)
		Util.add_sphere(_arm_pivot, 0.19, Vector3(0, 0, -0.52),
			Util.make_material(stats["color"], 0.5, 0.2), 0.03)


func _swing() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_arm_pivot.position.z = 0.0
	_arm_pivot.rotation.x = 0.0
	_swing_tween = create_tween()
	if character_type == CHAR_SWORDSMAN:
		_arm_pivot.rotation.x = -1.7
		_swing_tween.tween_property(_arm_pivot, "rotation:x", 1.1, 0.13) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_swing_tween.tween_property(_arm_pivot, "rotation:x", 0.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_swing_tween.tween_property(_arm_pivot, "position:z", -0.5, 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_swing_tween.tween_property(_arm_pivot, "position:z", 0.0, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _spin_visual() -> void:
	var tw := create_tween()
	tw.tween_property(visual, "rotation:y", visual.rotation.y + TAU, 0.45) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
