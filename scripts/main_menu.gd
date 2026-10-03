extends Control

## Main menu: difficulty select, character select and the secret mode slot.

const CONTROLS_CELLS: Array[String] = [
	"WASD  -  Move",
	"Left click  -  Attack",
	"Q  -  Super move",
	"Shift  -  Dash",
	"E  -  Heal",
	"Esc  -  Pause",
]

var selected_difficulty: int = 1
var selected_character: int = 0

var _diff_group: ButtonGroup
var _char_group: ButtonGroup
var _diff_desc: Label
var _char_desc: Label
var _hint: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh_text()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.018, 0.03)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := UIKit.centered_column(self, 8)

	var title := UIKit.label(col, "LAST ASCEND", 58, Color(1, 1, 1))
	UIKit.outline(title, 14, Color(0.35, 0.12, 0.05))
	var sub := UIKit.label(col,
		"Climb from Hell to Earth to Heaven, then face The Creator.", 17,
		Color(0.6, 0.68, 0.8))
	UIKit.outline(sub, 5)

	_spacer(col, 14)

	UIKit.label(col, "DIFFICULTY", 19, Color(0.75, 0.8, 0.9))

	_diff_group = ButtonGroup.new()
	var diff_row := UIKit.row(col, 10)
	for i in 4:
		var b := _select_button(GameManager.DIFFICULTY_NAMES[i], _diff_group, 168, 46)
		if i == GameManager.Difficulty.HELL and not GameManager.hell_unlocked:
			b.disabled = true
			b.text = "HELL locked"
		b.pressed.connect(_on_difficulty.bind(i))
		diff_row.add_child(b)
		if i == selected_difficulty:
			b.button_pressed = true

	_diff_desc = UIKit.label(col, "", 16, Color(0.65, 0.7, 0.8))
	UIKit.outline(_diff_desc, 4)

	_spacer(col, 12)

	UIKit.label(col, "CHARACTER", 19, Color(0.75, 0.8, 0.9))

	_char_group = ButtonGroup.new()
	var char_row := UIKit.row(col, 14)
	for i in GameManager.CHARACTER_NAMES.size():
		var b := _select_button(GameManager.CHARACTER_NAMES[i], _char_group, 230, 52)
		b.pressed.connect(_on_character.bind(i))
		char_row.add_child(b)
		if i == selected_character:
			b.button_pressed = true

	_char_desc = UIKit.label(col, "", 16, Color(0.65, 0.7, 0.8))
	UIKit.outline(_char_desc, 4)

	_spacer(col, 18)

	var action_row := UIKit.row(col, 16)
	var play := UIKit.button("PLAY", 26, Color(0.1, 0.3, 0.16),
		Color(0.14, 0.45, 0.24), Color(0.2, 0.65, 0.32), Vector2(260, 62))
	play.pressed.connect(_on_play)
	action_row.add_child(play)

	var quit := UIKit.button("Quit", 22, Color(0.24, 0.12, 0.12),
		Color(0.36, 0.17, 0.17), Color(0.6, 0.25, 0.25), Vector2(150, 62))
	quit.pressed.connect(get_tree().quit)
	action_row.add_child(quit)

	_hint = UIKit.label(col, "", 15, Color(0.6, 0.65, 0.75))
	UIKit.outline(_hint, 4)

	_build_controls_panel(col)


## Small boxed reminder so players know what to press before they start.
func _build_controls_panel(col: Node) -> void:
	var panel := UIKit.panel(Color(0.06, 0.07, 0.11, 0.92), 10, 14)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	panel.add_child(inner)

	var head := UIKit.small_label(inner, "CONTROLS", 15, Color(0.75, 0.82, 0.95))
	UIKit.outline(head, 4)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(grid)

	for text: String in CONTROLS_CELLS:
		var cell := UIKit.small_label(grid, text, 14, Color(0.78, 0.82, 0.9),
			HORIZONTAL_ALIGNMENT_LEFT)
		UIKit.outline(cell, 3)


func _select_button(text: String, group: ButtonGroup, w: float, h: float) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 19)
	UIKit.style_button(b, Color(0.1, 0.12, 0.18), Color(0.16, 0.2, 0.3),
		Color(0.24, 0.42, 0.85), Color(0.08, 0.09, 0.12, 0.7))
	return b


func _spacer(parent: Node, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)


# ------------------------------------------------------------- handlers ------

func _on_difficulty(index: int) -> void:
	selected_difficulty = index
	_refresh_text()


func _on_character(index: int) -> void:
	selected_character = index
	_refresh_text()


func _refresh_text() -> void:
	_diff_desc.text = str(GameManager.DIFFICULTY_SETTINGS[selected_difficulty]["desc"])
	_char_desc.text = str(Player.DATA[selected_character]["desc"])
	if GameManager.hell_unlocked:
		_hint.text = "Hell is open  -  you beat The Creator on Hard."
		_hint.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	else:
		_hint.text = "Defeat The Creator on Hard to unlock Hell mode."
		_hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))


func _on_play() -> void:
	GameManager.start_run(selected_difficulty, selected_character)
	get_tree().change_scene_to_file("res://scenes/game.tscn")
