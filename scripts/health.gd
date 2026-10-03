class_name Health
extends Node

## Tiny reusable health component.

signal damaged(amount: float, current: float, hit_position: Vector3)
signal healed(amount: float, current: float)
signal died

var max_health: float = 100.0
var health: float = 100.0
var invulnerable := false


func setup(max_hp: float) -> void:
	max_health = maxf(max_hp, 1.0)
	health = max_health


func is_dead() -> bool:
	return health <= 0.0


func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> bool:
	if invulnerable or health <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	damaged.emit(amount, health, hit_position)
	if health <= 0.0:
		died.emit()
	return true


func heal(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	var before := health
	health = minf(max_health, health + amount)
	if health > before:
		healed.emit(health - before, health)


func fraction() -> float:
	return health / maxf(max_health, 0.001)
