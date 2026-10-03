class_name SpikeTrap
extends Node3D

## Floor spikes on a safe / warn / active cycle. Damages the player and enemies.

enum Phase { SAFE, WARN, ACTIVE }

const SAFE_TIME := 2.1
const WARN_TIME := 0.75
const ACTIVE_TIME := 1.4
const HIT_INTERVAL := 0.9

var damage := 12.0
var trap_size := 3.2

## Adaptive-room tuning: >1.0 shortens every phase. The Arena speeds the
## hazards up when it has learned that you dash on reflex.
var haste := 1.0

var phase: int = Phase.SAFE
var timer := SAFE_TIME

var _spikes: Node3D
var _area: Area3D
var _plate_mat: StandardMaterial3D
var _spike_mat: StandardMaterial3D
var _last_hit: Dictionary = {}


func _ready() -> void:
	timer = SAFE_TIME / maxf(haste, 0.1)
	var dark := Util.make_material(Color(0.13, 0.13, 0.16), 0.6, 0.5)
	Util.add_box(self, Vector3(trap_size, 0.14, trap_size),
		Vector3(0, 0.07, 0), dark)

	_plate_mat = Util.make_material(Color(0.2, 0.16, 0.14), 0.5, 0.6,
		Color(1.0, 0.25, 0.05), 0.0)
	Util.add_box(self, Vector3(trap_size * 0.9, 0.06, trap_size * 0.9),
		Vector3(0, 0.15, 0), _plate_mat)

	_spike_mat = Util.make_material(Color(0.7, 0.72, 0.78), 0.25, 0.9,
		Color(1.0, 0.2, 0.05), 0.0)

	_spikes = Node3D.new()
	_spikes.position.y = -0.7
	add_child(_spikes)
	var half := trap_size * 0.5 - 0.5
	for ix in 3:
		for iz in 3:
			var x := (ix - 1) * half
			var z := (iz - 1) * half
			Util.add_cone(_spikes, 0.18, 0.7, Vector3(x, 0.3, z), _spike_mat, 0.02)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Combat.LAYER_PLAYER | Combat.LAYER_ENEMY
	_area.monitoring = true
	_area.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(trap_size, 1.3, trap_size)
	cs.shape = box
	cs.position = Vector3(0, 0.65, 0)
	_area.add_child(cs)
	add_child(_area)


func _physics_process(delta: float) -> void:
	timer -= delta
	match phase:
		Phase.SAFE:
			_spikes.position.y = lerpf(_spikes.position.y, -0.7, 9.0 * delta)
			_set_glow(0.0)
			if timer <= 0.0:
				_enter(Phase.WARN, WARN_TIME)
		Phase.WARN:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
			_set_glow(0.6 + pulse * 2.4)
			_spikes.position.y = lerpf(_spikes.position.y, -0.35, 9.0 * delta)
			if timer <= 0.0:
				_enter(Phase.ACTIVE, ACTIVE_TIME)
		Phase.ACTIVE:
			_set_glow(1.6)
			_spikes.position.y = lerpf(_spikes.position.y, 0.3, 22.0 * delta)
			_do_damage()
			if timer <= 0.0:
				_enter(Phase.SAFE, SAFE_TIME)


func _enter(next_phase: int, duration: float) -> void:
	phase = next_phase
	timer = duration / maxf(haste, 0.1)


func _set_glow(energy: float) -> void:
	if energy <= 0.001:
		_plate_mat.emission_energy_multiplier = 0.0
		_spike_mat.emission_energy_multiplier = 0.0
		return
	_plate_mat.emission_enabled = true
	_spike_mat.emission_enabled = true
	_plate_mat.emission_energy_multiplier = energy * 0.5
	_spike_mat.emission_energy_multiplier = energy


func _do_damage() -> void:
	if _area == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var scene := get_tree().current_scene
	for body in _area.get_overlapping_bodies():
		if not body.has_method("apply_hit"):
			continue
		var id: int = body.get_instance_id()
		var last: float = _last_hit.get(id, -100.0)
		if now - last < HIT_INTERVAL:
			continue
		_last_hit[id] = now
		var dir := body.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() < 0.01:
			dir = Vector3(0, 0, 1)
		else:
			dir = dir.normalized()
		body.call("apply_hit", damage, dir, 6.0, ArenaMemory.CAUSE_TRAP)
		FX.burst(scene, body.global_position + Vector3(0, 0.5, 0),
			Color(1.0, 0.55, 0.12), 18, 0.1, 0.4, 5.5)
