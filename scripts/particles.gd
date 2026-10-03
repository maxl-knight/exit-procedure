class_name FX
extends RefCounted

## One-shot particle bursts used for every hit / death / ability.


static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 24,
		size: float = 0.12, life: float = 0.55, speed: float = 6.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var tree := parent.get_tree()
	if tree == null:
		return

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(amount, 4)
	p.lifetime = life
	p.explosiveness = 1.0
	p.randomness = 0.7
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -15, 0)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size * 1.5
	p.color = color

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	p.mesh = mesh

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true

	var timer := tree.create_timer(life + 0.6)
	timer.timeout.connect(p.queue_free)


## A quick expanding ring, used for the big area abilities.
static func ring(parent: Node, pos: Vector3, color: Color, radius: float = 3.0,
		life: float = 0.45) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var tree := parent.get_tree()
	if tree == null:
		return

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = radius * 1.4
	p.initial_velocity_max = radius * 1.9
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.14
	p.color = color

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.25, 1.0)
	p.mesh = mesh
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true

	var timer := tree.create_timer(life + 0.6)
	timer.timeout.connect(p.queue_free)
