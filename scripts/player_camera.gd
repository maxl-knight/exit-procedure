class_name CameraRig
extends Node3D

## Third person orbit camera. The rig sits at the player's head, yaw is driven
## by the mouse, and the camera is placed with an explicit ray cast so it never
## clips through walls.

var target: Node3D

var yaw := 0.0
var pitch := -0.35
var distance := 6.5
var sensitivity := 0.0032
var pitch_min := -1.1
var pitch_max := 0.45
var min_distance := 0.45

var camera: Camera3D

var _shake := 0.0
var _exclude: Array[RID] = []


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)


func set_target(body: Node3D) -> void:
	target = body
	_exclude.clear()
	if body is CollisionObject3D:
		_exclude.append((body as CollisionObject3D).get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, pitch_min, pitch_max)


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position + Vector3(0, 1.6, 0)
	rotation = Vector3(0, yaw, 0)
	_update_camera()


func _process(delta: float) -> void:
	_shake = lerpf(_shake, 0.0, 7.0 * delta)
	if camera != null:
		var s := _shake
		camera.h_offset = randf_range(-s, s)
		camera.v_offset = randf_range(-s, s)


func shake(amount: float) -> void:
	_shake = minf(_shake + amount, 0.45)


func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func get_flat_forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	return f.normalized()


func get_flat_right() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0.0
	if r.length_squared() < 0.0001:
		return Vector3(1, 0, 0)
	return r.normalized()


func _update_camera() -> void:
	if camera == null:
		return
	var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var desired := global_position + rot * Vector3(0, 0, distance)

	var dir := desired - global_position
	var dist := dir.length()
	if dist < 0.01:
		return
	dir /= dist

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, desired,
		Combat.LAYER_WORLD, _exclude)
	query.hit_from_inside = false
	var hit := space.intersect_ray(query)

	var resolved := desired
	if not hit.is_empty():
		resolved = hit.get("position")
		if resolved.distance_to(global_position) < min_distance:
			resolved = global_position + dir * min_distance

	camera.global_position = resolved
	camera.look_at(global_position + Vector3(0, -0.1, 0), Vector3.UP)
