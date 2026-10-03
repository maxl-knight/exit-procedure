class_name GameOverScreen
extends Control

var game: Variant

var _title: Label
var _subtitle: Label
var _arena_line: Label
var _pattern: Label
var _learned: Label
var _kills: Label
var _rooms: Label
var _score: Label
var _unlock: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func show_stats() -> void:
	_kills.text = "Enemies defeated      %d" % GameManager.kills
	_rooms.text = "Rooms cleared         %d" % GameManager.rooms_cleared
	_score.text = "Score                 %d" % GameManager.score()
	_title.text = "YOU DIED"
	_subtitle.text = "%s  -  %s" % [GameManager.difficulty_name(), GameManager.character_name()]

	# The Arena files this death by cause and reports what it observed.
	_arena_line.text = ArenaMemory.death_line()
	_pattern.text = ArenaMemory.pattern_line()
	_pattern.visible = ArenaMemory.pattern_repeats()
	var lines: Array = ArenaMemory.learned_lines()
	_learned.text = "\n".join(PackedStringArray(lines))

	_unlock.visible = false
	_title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	if GameManager.announce_unlock:
		GameManager.announce_unlock = false
		_unlock.visible = true
		_unlock.text = "HELL MODE UNLOCKED"
		_title.text = "HARD MODE BEATEN"
		_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

	visible = true


func _build() -> void:
	UIKit.dim(self, Color(0.02, 0.02, 0.05, 0.85))

	var col := UIKit.centered_column(self, 10)

	_title = UIKit.label(col, "YOU DIED", 56, Color(1.0, 0.25, 0.2))
	UIKit.outline(_title, 12)

	_subtitle = UIKit.label(col, "", 18, Color(0.7, 0.75, 0.85))
	UIKit.outline(_subtitle, 5)

	_arena_line = UIKit.label(col, "Reconstruction approved.", 20, Color(0.55, 0.9, 1.0))
	UIKit.outline(_arena_line, 6)

	_pattern = UIKit.label(col, "", 16, Color(1.0, 0.55, 0.45))
	UIKit.outline(_pattern, 5)
	_pattern.visible = false

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	col.add_child(spacer)

	_kills = UIKit.label(col, "Enemies defeated      0", 26, Color(0.95, 0.95, 1.0))
	_rooms = UIKit.label(col, "Rooms cleared         0", 26, Color(0.95, 0.95, 1.0))
	_score = UIKit.label(col, "Score                 0", 30, Color(1.0, 0.85, 0.35))
	for l in [_kills, _rooms, _score]:
		UIKit.outline(l as Label, 7)

	# What the Arena observed about your run before it rebuilt you.
	var learned_panel := UIKit.panel(Color(0.05, 0.07, 0.1, 0.92), 8, 12)
	learned_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(learned_panel)
	var learned_col := VBoxContainer.new()
	learned_col.add_theme_constant_override("separation", 2)
	learned_panel.add_child(learned_col)
	var learned_head := UIKit.small_label(learned_col, "THE ARENA OBSERVED", 13,
		Color(0.55, 0.9, 1.0))
	UIKit.outline(learned_head, 3)
	_learned = UIKit.small_label(learned_col, "", 15, Color(0.75, 0.82, 0.9),
		HORIZONTAL_ALIGNMENT_LEFT)
	UIKit.outline(_learned, 3)

	_unlock = UIKit.label(col, "???  UNLOCKED", 24, Color(1.0, 0.85, 0.25))
	UIKit.outline(_unlock, 8)
	_unlock.visible = false

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 14)
	col.add_child(spacer2)

	var buttons := UIKit.row(col, 14)
	var retry := UIKit.button("Reconstruct", 22, Color(0.1, 0.3, 0.16),
		Color(0.14, 0.42, 0.22), Color(0.2, 0.6, 0.3), Vector2(190, 56))
	retry.pressed.connect(Callable(game, "restart"))
	buttons.add_child(retry)

	var menu := UIKit.button("Main Menu", 22, Color(0.14, 0.16, 0.24),
		Color(0.2, 0.24, 0.36), Color(0.3, 0.4, 0.7), Vector2(190, 56))
	menu.pressed.connect(Callable(game, "go_menu"))
	buttons.add_child(menu)
