extends Control

## Hub-lite main menu: the Arena's waiting room rather than a level you walk.
## The backdrop, the voice line, the unlock stations and the log panels all
## read the persistent record, so the menu visibly changes as you go deeper -
## and as you finish runs.

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
var _diff_buttons: Array = []
var _diff_desc: Label
var _char_desc: Label
var _hint: Label
var _voice_label: Label
var _body_cell: Label
var _reveal_text := ""
var _reveal_at := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_start_reveal(ArenaMemory.menu_line())
	_refresh_text()


func _process(delta: float) -> void:
	if _reveal_at >= _reveal_text.length():
		return
	_reveal_at = mini(_reveal_text.length(), _reveal_at + 1 + int(delta * 60.0))
	_voice_label.text = _reveal_text.substr(0, _reveal_at)


## The room changes colour with the record: wing reached, Core broken, door
## taken. This is the cheapest possible "the hub changed because of you".
func _hub_bg() -> Color:
	match ArenaMemory.ending:
		"escape":
			return Color(0.01, 0.05, 0.045)
		"destroy":
			return Color(0.06, 0.018, 0.02)
		"control":
			return Color(0.03, 0.03, 0.085)
	if ArenaMemory.bosses_beaten > 0:
		return Color(0.05, 0.02, 0.03)
	if ArenaMemory.highest_room >= 40:
		return Color(0.05, 0.02, 0.06)
	if ArenaMemory.highest_room >= 20:
		return Color(0.01, 0.035, 0.045)
	if ArenaMemory.highest_room >= 5:
		return Color(0.03, 0.024, 0.014)
	return Color(0.015, 0.018, 0.03)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = _hub_bg()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := UIKit.centered_column(self, 5)

	# The Arena speaks first - before the title, before any choice.
	_voice_label = UIKit.label(col, "", 16, Color(0.55, 0.95, 0.8))
	UIKit.outline(_voice_label, 5)

	var title := UIKit.label(col, "LAST ASCEND", 48, Color(1, 1, 1))
	UIKit.outline(title, 14, Color(0.35, 0.12, 0.05))
	var sub := UIKit.label(col,
		"Reconstruction Wing, Adaptation Field, Core Perimeter  -  then The Core.",
		16, Color(0.6, 0.68, 0.8))
	UIKit.outline(sub, 5)

	_spacer(col, 8)

	UIKit.label(col, "DIFFICULTY", 19, Color(0.75, 0.8, 0.9))

	_diff_group = ButtonGroup.new()
	_diff_buttons.clear()
	var diff_row := UIKit.row(col, 10)
	for i in 4:
		var b := _select_button(GameManager.DIFFICULTY_NAMES[i], _diff_group, 168, 46)
		if i == GameManager.Difficulty.HELL and not GameManager.hell_unlocked:
			b.disabled = true
			b.text = "HELL locked"
		b.pressed.connect(_on_difficulty.bind(i))
		diff_row.add_child(b)
		_diff_buttons.append(b)
		if i == selected_difficulty:
			b.button_pressed = true

	_diff_desc = UIKit.label(col, "", 16, Color(0.65, 0.7, 0.8))
	UIKit.outline(_diff_desc, 4)

	_spacer(col, 6)

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

	_spacer(col, 10)

	var action_row := UIKit.row(col, 16)
	var play := UIKit.button("PLAY", 26, Color(0.1, 0.3, 0.16),
		Color(0.14, 0.45, 0.24), Color(0.2, 0.65, 0.32), Vector2(260, 62))
	play.pressed.connect(_on_play)
	action_row.add_child(play)

	var quit := UIKit.button("Quit", 22, Color(0.24, 0.12, 0.12),
		Color(0.36, 0.17, 0.17), Color(0.6, 0.25, 0.25), Vector2(150, 62))
	quit.pressed.connect(get_tree().quit)
	action_row.add_child(quit)

	# Unlock stations: the two things you can earn, framed as places in the hub.
	var stations := UIKit.row(col, 14)
	stations.add_child(_station_hell())
	stations.add_child(_station_admin())

	_hint = UIKit.label(col, "", 15, Color(0.6, 0.65, 0.75))
	UIKit.outline(_hint, 4)

	_spacer(col, 6)
	_build_bottom_panels(col)


# ------------------------------------------------------------------ hub -----

## Pressing an unlocked station does something: Hell jumps you to the mode,
## Administration reports that the chair is yours.
func _station_hell() -> Button:
	var open := GameManager.hell_unlocked
	var b := UIKit.button(
		"STATION  -  HELL   %s" % ("OPEN" if open else "SEALED  -  beat The Core on Hard"),
		16, Color(0.26, 0.1, 0.1), Color(0.34, 0.14, 0.13), Color(0.5, 0.2, 0.18),
		Vector2(340, 38))
	b.disabled = not open
	if open:
		b.pressed.connect(_on_station_hell)
	return b


func _station_admin() -> Button:
	var open := GameManager.endless_admin
	var b := UIKit.button(
		"STATION  -  ENDLESS ADMINISTRATION   %s"
		% ("OPEN" if open else "SEALED  -  Take Control"),
		16, Color(0.1, 0.13, 0.26), Color(0.14, 0.18, 0.34), Color(0.24, 0.3, 0.6),
		Vector2(400, 38))
	b.disabled = not open
	if open:
		b.pressed.connect(_on_station_admin)
	return b


func _on_station_hell() -> void:
	_on_difficulty(GameManager.Difficulty.HELL)
	if _diff_buttons.size() > GameManager.Difficulty.HELL:
		(_diff_buttons[GameManager.Difficulty.HELL] as Button).button_pressed = true
	_start_reveal("ARENA: reconstruction wing primed. do not waste it.")


func _on_station_admin() -> void:
	_start_reveal("ARENA: the chair is yours. the Arena runs itself now.")


func _start_reveal(text: String) -> void:
	_reveal_text = text
	_reveal_at = 0
	_voice_label.text = ""


# ---------------------------------------------------------------- panels ----

## Controls, the Core's projection and the Arena Log sit side by side so the
## menu keeps growing upward without ever leaving the window.
func _build_bottom_panels(col: Node) -> void:
	var row := UIKit.row(col, 16)
	row.add_child(_controls_panel())
	row.add_child(_projection_panel())
	row.add_child(_log_panel())


func _controls_panel() -> PanelContainer:
	var panel := UIKit.panel(Color(0.06, 0.07, 0.11, 0.92), 10, 14)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	panel.add_child(inner)

	var head := UIKit.small_label(inner, "CONTROLS", 15, Color(0.75, 0.82, 0.95))
	UIKit.outline(head, 4)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	inner.add_child(grid)
	for text: String in CONTROLS_CELLS:
		var cell := UIKit.small_label(grid, text, 14, Color(0.78, 0.82, 0.9),
			HORIZONTAL_ALIGNMENT_LEFT)
		UIKit.outline(cell, 3)
	return panel


## The Core's projection: a piece of the boss living in the menu, rewritten by
## what you did to it last.
func _projection_panel() -> PanelContainer:
	var panel := UIKit.panel(Color(0.07, 0.075, 0.13, 0.92), 10, 14)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	var head := UIKit.small_label(inner, "PROJECTION", 15, Color(0.85, 0.6, 0.7))
	UIKit.outline(head, 4)

	var body := UIKit.small_label(inner, ArenaMemory.menu_projection(), 14,
		Color(0.8, 0.78, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	UIKit.outline(body, 3)
	return panel


## The Arena Log: the persistent record, laid out as a compact grid.
func _log_panel() -> PanelContainer:
	var panel := UIKit.panel(Color(0.06, 0.085, 0.1, 0.92), 10, 14)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	panel.add_child(inner)

	var head := UIKit.small_label(inner, "ARENA LOG", 15, Color(0.6, 0.9, 0.95))
	UIKit.outline(head, 4)

	var end_label := "unwritten"
	if Content.ENDINGS.has(ArenaMemory.ending):
		end_label = str(Content.ENDINGS[ArenaMemory.ending]["title"])

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 3)
	inner.add_child(grid)

	var rows := [
		"reconstructions   %d" % ArenaMemory.runs,
		"deaths   %d" % ArenaMemory.deaths,
		"best room   %d" % ArenaMemory.highest_room,
		"cores broken   %d" % ArenaMemory.bosses_beaten,
		"fragments   %d" % ArenaMemory.fragments_seen,
		"ending   %s" % end_label,
	]
	for i in rows.size():
		var cell := UIKit.small_label(grid, str(rows[i]), 13,
			Color(0.76, 0.84, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
		UIKit.outline(cell, 3)
		if i == 2:
			# Slot between "best room" and "cores broken": per-body deaths, so
			# the log answers "how many times has THIS warrior gone down?"
			_body_cell = UIKit.small_label(grid, "", 13,
				Color(0.76, 0.84, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
			UIKit.outline(_body_cell, 3)
	return panel


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
	if _body_cell != null:
		_body_cell.text = "deaths this body   %d" % int(
			ArenaMemory.deaths_by_char.get(selected_character, 0))
	if GameManager.hell_unlocked:
		_hint.text = "Hell is open  -  you beat The Core on Hard."
		_hint.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	else:
		_hint.text = "Defeat The Core on Hard to unlock Hell mode."
		_hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))


func _on_play() -> void:
	GameManager.start_run(selected_difficulty, selected_character)
	get_tree().change_scene_to_file("res://scenes/game.tscn")
