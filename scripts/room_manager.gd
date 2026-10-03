class_name RoomManager
extends Node3D

## Generates rooms infinitely along -Z, keeps the three around the player alive
## and frees everything else. Also owns the room schedule: which room is a
## challenge, which room defects you, which is a breather or a memory, and
## which room is the Creator's arena.
##
## Room kinds, in banner priority order (one special thing per room):
##   defect > milestone(boss) > elite/upgrade > adaptive > recovery >
##   memory > milestone(realm wall) > combat

signal room_entered(index: int)
signal room_cleared(index: int)

const LENGTH := Room.LENGTH
const WIDTH := Room.WIDTH

const CHALLENGE_SEED := 40501
const CURSE_SEED := 777001
const ADAPTIVE_SEED := 60613
const RECOVERY_SEED := 11827
const MEMORY_SEED := 29081

var player: Player
var rooms := {}
var current_index := 0


func _ready() -> void:
	_ensure(0)
	_ensure(1)


func center_of(i: int) -> Vector3:
	return Vector3(0, 0, -i * LENGTH)


## Deterministic so it does not depend on the order rooms get built in.
## `i` is the zero-based room index.
func challenge_for(i: int) -> int:
	if i <= 0 or GameManager.is_boss_room(i):
		return Room.Challenge.NONE
	var target := i + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = CHALLENGE_SEED
	var next_challenge := rng.randi_range(3, 5)
	var n := 1
	while n <= target:
		if n == next_challenge:
			var kind := Room.Challenge.VAULT if rng.randf() < 0.45 \
				else Room.Challenge.ELITE_TRIAL
			next_challenge = n + rng.randi_range(3, 5)
			if n == target:
				return kind
		n += 1
	return Room.Challenge.NONE


## True on the rooms where a defect lands (every 10-13 rooms).
func is_curse_room(i: int) -> bool:
	if i <= 0:
		return false
	var target := i + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = CURSE_SEED
	var next_curse := rng.randi_range(10, 13)
	var n := 1
	while n <= target:
		if n == next_curse:
			if n == target:
				return true
			next_curse = n + rng.randi_range(10, 13)
		n += 1
	return false


## Which behavior the Arena is testing in this room, or "" when the room is
## ordinary. Slots land every 4-6 rooms and are skipped whenever a challenge,
## defect or boss already owns that room - one special thing at a time.
## The kind comes from the live behavior flags, so the test follows your run.
func adaptive_for(i: int) -> String:
	if i <= 0 or GameManager.is_boss_room(i):
		return ""
	if challenge_for(i) != Room.Challenge.NONE or is_curse_room(i):
		return ""
	var target := i + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = ADAPTIVE_SEED
	var next_slot := rng.randi_range(4, 6)
	var n := 1
	while n <= target:
		if n == next_slot:
			if n == target:
				var flag := ArenaMemory.flagged_behavior()
				return flag if flag != "" else "melee"
			next_slot = n + rng.randi_range(4, 6)
		n += 1
	return ""


## True on the recovery rooms (every 7-9 rooms): lighter fight, no traps,
## and reconstruction pays out when you clear it.
func recovery_for(i: int) -> bool:
	if i <= 0 or GameManager.is_boss_room(i):
		return false
	if challenge_for(i) != Room.Challenge.NONE or is_curse_room(i):
		return false
	if adaptive_for(i) != "":
		return false
	return _slot_walk(RECOVERY_SEED, i, 7, 9)


## True on the memory rooms (every 6-8 rooms, room 6 onward preferred):
## the Arena shows you a fragment of a warrior it still remembers.
func memory_for(i: int) -> bool:
	if i < 5 or GameManager.is_boss_room(i):
		return false
	if challenge_for(i) != Room.Challenge.NONE or is_curse_room(i):
		return false
	if adaptive_for(i) != "" or recovery_for(i):
		return false
	return _slot_walk(MEMORY_SEED, i, 6, 8)


## Deterministic slot walk: the n-th 1-based room is special when it lands on
## `next`, then the walk resumes from there with the same gap range.
func _slot_walk(seed_value: int, i: int, lo: int, hi: int) -> bool:
	var target := i + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var next_slot := rng.randi_range(lo, hi)
	var n := 1
	while n <= target:
		if n == next_slot:
			if n == target:
				return true
			next_slot = n + rng.randi_range(lo, hi)
		n += 1
	return false


## One label per room for banners and the HUD, in the same priority order
## _config_for() uses: defect > boss > elite/upgrade > adaptive > recovery >
## memory > combat.
func kind_for(i: int) -> String:
	if is_curse_room(i):
		return "defect"
	if GameManager.is_boss_room(i):
		return "boss"
	var challenge := challenge_for(i)
	if challenge == Room.Challenge.ELITE_TRIAL:
		return "elite"
	if challenge == Room.Challenge.VAULT:
		return "upgrade"
	if adaptive_for(i) != "":
		return "adaptive"
	if recovery_for(i):
		return "recovery"
	if memory_for(i):
		return "memory"
	return "combat"


func _config_for(i: int) -> Dictionary:
	var cfg := {}
	var challenge := challenge_for(i)
	if challenge != Room.Challenge.NONE:
		cfg["challenge"] = challenge
	else:
		var adaptive := adaptive_for(i)
		if adaptive != "":
			cfg["adaptive"] = adaptive
		elif recovery_for(i):
			cfg["kind"] = "recovery"
		elif memory_for(i):
			cfg["kind"] = "memory"
	if GameManager.is_boss_room(i):
		cfg["boss"] = true
	return cfg


func _ensure(i: int) -> void:
	if rooms.has(i):
		return
	var room := Room.new()
	room.position = center_of(i)
	add_child(room)
	room.build(i, player, _config_for(i))
	room.cleared.connect(_on_room_cleared)
	rooms[i] = room


func _on_room_cleared(room: Room) -> void:
	GameManager.add_room()
	room_cleared.emit(room.index)


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var idx := floori(-player.global_position.z / LENGTH + 0.5)
	if idx < 0:
		idx = 0

	if idx != current_index:
		current_index = idx
		# Slam the shutter behind them - rooms are one-way.
		if rooms.has(idx):
			(rooms[idx] as Room).seal_back()
		room_entered.emit(idx)

	_ensure(idx)
	_ensure(idx + 1)
	_trim(idx)


## Only used after the Creator falls and the player chooses to descend again.
func descend() -> void:
	var target_idx := current_index + 1
	_ensure(target_idx)
	_ensure(target_idx + 1)
	if player == null or not is_instance_valid(player):
		return
	player.global_position = center_of(target_idx) + Vector3(0, 0.1, LENGTH / 2.0 - 4.0)
	player.velocity = Vector3.ZERO
	current_index = target_idx
	if rooms.has(target_idx):
		(rooms[target_idx] as Room).seal_back()
	room_entered.emit(target_idx)
	_trim(target_idx)


func room_at(i: int) -> Room:
	var r = rooms.get(i)
	return r if r != null and is_instance_valid(r) else null


## Alive enemies standing in a room (including the Creator's summons).
func enemies_in(i: int) -> int:
	var r := room_at(i)
	if r == null:
		return 0
	var n := 0
	for child in r.get_children():
		if child is Enemy and not (child as Enemy).dead:
			n += 1
	return n


## Keeps the previous room alive: it owns the entry wall of the current one.
func _trim(idx: int) -> void:
	var stale: Array = []
	for key in rooms.keys():
		if key < idx - 1 or key > idx + 1:
			stale.append(key)
	for key in stale:
		var room = rooms.get(key)
		rooms.erase(key)
		if room != null and is_instance_valid(room):
			room.queue_free()
