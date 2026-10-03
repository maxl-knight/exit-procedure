class_name PauseMenu
extends Control

## Lives on the UI layer with PROCESS_MODE_ALWAYS so it can catch Esc while the
## tree is paused.

const CONTROLS := "WASD move   |   Left click attack   |   Q super   |   " + \
	"Shift dash   |   E heal   |   Esc pause"

var game: Variant


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func _process(_delta: float) -> void:
	if game == null:
		return
	if Input.is_action_just_pressed("pause"):
		game.toggle_pause()


func _build() -> void:
	UIKit.dim(self)

	var col := UIKit.centered_column(self, 12)

	var title := UIKit.label(col, "PAUSED", 46, Color(1, 1, 1))
	UIKit.outline(title, 10)
	var sub := UIKit.label(col, "Take a breath.", 16, Color(0.6, 0.65, 0.75))
	UIKit.outline(sub, 4)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	col.add_child(spacer)

	var resume := UIKit.button("Resume", 22, Color(0.1, 0.3, 0.16),
		Color(0.14, 0.42, 0.22), Color(0.2, 0.6, 0.3), Vector2(320, 52))
	resume.pressed.connect(game.toggle_pause)
	col.add_child(resume)

	var restart := UIKit.button("Restart Run", 20, Color(0.14, 0.16, 0.24),
		Color(0.2, 0.24, 0.36), Color(0.3, 0.4, 0.7), Vector2(320, 48))
	restart.pressed.connect(game.restart)
	col.add_child(restart)

	var menu := UIKit.button("Main Menu", 20, Color(0.24, 0.12, 0.12),
		Color(0.36, 0.17, 0.17), Color(0.6, 0.25, 0.25), Vector2(320, 48))
	menu.pressed.connect(game.go_menu)
	col.add_child(menu)

	var hint := UIKit.label(col, "Press Esc to resume", 14, Color(0.55, 0.6, 0.7))
	UIKit.outline(hint, 4)

	var controls := UIKit.small_label(col, CONTROLS, 13, Color(0.6, 0.66, 0.78))
	UIKit.outline(controls, 4)
