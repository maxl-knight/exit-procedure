class_name VictoryScreen
extends Control

## Shown the moment The Creator falls: final score plus the choice to keep the
## run going by falling out of Heaven and back into Hell.

signal descend
signal to_menu

var _descend_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_stats() -> void:
	for child in get_children():
		child.free()

	UIKit.dim(self, Color(0.02, 0.01, 0.05, 0.86))
	var col := UIKit.centered_column(self, 14)

	var title := UIKit.small_label(col, "YOU HAVE ASCENDED", 52, Color(1.0, 0.9, 0.5))
	UIKit.outline(title, 10)
	var sub := UIKit.small_label(col,
		"Hell, Earth and Heaven are behind you.", 18, Color(0.78, 0.8, 0.9))
	UIKit.outline(sub, 5)

	var stats_box := UIKit.panel(Color(0.07, 0.08, 0.13, 0.95), 12, 20)
	col.add_child(stats_box)
	var stats_col := VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 6)
	stats_box.add_child(stats_col)
	UIKit.small_label(stats_col, "FINAL SCORE   %d" % GameManager.score(),
		32, Color(0.4, 1.0, 0.6))
	UIKit.small_label(stats_col, "kills %d     rooms cleared %d     difficulty %s" % [
		GameManager.kills, GameManager.rooms_cleared, GameManager.difficulty_name()],
		17, Color(0.7, 0.74, 0.84))

	if GameManager.announce_unlock:
		GameManager.announce_unlock = false
		var unlock := UIKit.small_label(col, "HELL MODE UNLOCKED", 26,
			Color(1.0, 0.35, 0.25))
		UIKit.outline(unlock, 7)
		UIKit.small_label(col, "Hell was sealed behind a Hard clear. It is open now.",
			15, Color(0.8, 0.6, 0.6))

	_descend_button = UIKit.button("FALL FROM HEAVEN  -  keep fighting for score",
		20, Color(0.5, 0.1, 0.12), Color(0.7, 0.16, 0.18), Color(0.9, 0.3, 0.25),
		Vector2(520, 56))
	_descend_button.pressed.connect(_on_descend)
	col.add_child(_descend_button)

	var menu := UIKit.button("MAIN MENU", 20)
	menu.custom_minimum_size = Vector2(520, 48)
	menu.pressed.connect(func(): to_menu.emit())
	col.add_child(menu)

	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_descend() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	descend.emit()
