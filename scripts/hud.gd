class_name HUD
extends Control

const SLOT_W := 108.0
const SLOT_H := 104.0
const TOP_W := 640.0
const TOP_H := 132.0

const MULT_W := 210.0
const STATUS_W := 230.0

var player: Player

var _hp_fill: ColorRect
var _hp_text: Label
var _kills_label: Label
var _room_label: Label
var _left_label: Label
var _realm_label: Label
var _score_label: Label
var _slots: Array = []
var _ability_root: Control
var _banner: Label
var _voice: Label
var _voice_tween: Tween
var _vignette: ColorRect
var _banner_tween: Tween
var _flash_tween: Tween

var _enemies_left := 0

var _mult_value: Label
var _mult_rows: VBoxContainer
var _status_col: VBoxContainer
var _status_cache := ""

var _boss_root: Control
var _boss_fill: ColorRect
var _boss_label: Label
var _boss_detail: Label
var _boss_watch: TheCreator = null
var current_room := 0


func setup(p: Player) -> void:
	player = p
	player.damaged_received.connect(flash_damage)
	player.died.connect(hide_bars)
	player.buff_added.connect(func(_id, _n): _status_cache = "")
	player.curse_added.connect(func(_id, _n): _status_cache = "")


func watch_boss(boss: TheCreator) -> void:
	_boss_watch = boss


func clear_boss() -> void:
	_boss_watch = null
	if _boss_root != null:
		_boss_root.visible = false


## How many enemies are still standing in the room you are in.
func set_enemies_left(n: int) -> void:
	_enemies_left = maxi(0, n)


## Called when the run is over: drop the ability row, banner and damage flash.
func clear_bars() -> void:
	if _ability_root != null:
		_ability_root.visible = false
	if _vignette != null:
		_vignette.color = Color(0.85, 0.05, 0.05, 0.0)
	if _banner != null:
		_banner.visible = false
	if _voice != null:
		_voice.visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var pct := player.health.fraction()
	_hp_fill.anchor_right = pct
	_hp_fill.color = Color(0.3, 0.95, 0.4).lerp(Color(0.95, 0.2, 0.15), 1.0 - pct)
	# keep the inset from ever exceeding the filled width (avoids a negative rect)
	var inset := minf(3.0, pct * TOP_W * 0.5)
	_hp_fill.offset_left = inset
	_hp_fill.offset_right = -inset
	_hp_text.text = "%d / %d" % [ceili(player.health.health), ceili(player.health.max_health)]

	_kills_label.text = "KILLS   %d" % GameManager.kills
	_room_label.text = "ROOM   %d" % (current_room + 1)
	_left_label.text = "LEFT   %d" % _enemies_left
	_score_label.text = "SCORE   %d" % GameManager.score()
	_realm_label.text = GameManager.realm_name(current_room)

	_update_multiplier()
	_update_status()
	_update_boss()

	var state := player.get_ability_state()
	for i in mini(_slots.size(), state.size()):
		var slot: Dictionary = _slots[i]
		var info: Dictionary = state[i]
		var fill := clampf(float(info["fill"]), 0.0, 1.0)
		# the dark overlay hangs from the top, so the bar visually "fills up"
		(slot["overlay"] as ColorRect).offset_bottom = SLOT_H * (1.0 - fill)
		(slot["value"] as Label).text = str(info["label"])
		var col := Color(1, 1, 1, 1) if bool(info["ready"]) else Color(0.62, 0.65, 0.74, 0.92)
		(slot["root"] as Control).modulate = col


## The side panel: how much each clean, fast room is worth right now.
func _update_multiplier() -> void:
	if _mult_value == null:
		return
	var m := GameManager.multiplier()
	_mult_value.text = "x%.2f" % m
	_mult_value.modulate = Color(0.6, 0.65, 0.75).lerp(Color(1.0, 0.9, 0.3),
		clampf((m - 1.0) / 6.0, 0.0, 1.0))

	var base := GameManager.base_score_mult()
	var max_hp := maxf(100.0 + GameManager.hp_bonus(), 10.0)
	var clean := clampf(1.0 - GameManager.room_damage / max_hp, 0.0, 1.0)
	var fast := clampf((GameManager.PAR_TIME - GameManager.room_time)
		/ GameManager.PAR_TIME, 0.0, 1.0)

	var rows := [
		["base x%.1f" % base, Color(0.7, 0.74, 0.84)],
		["no damage  +%d%%" % int(round(clean * 200.0)),
			Color(0.4, 1.0, 0.6) if clean > 0.99 else Color(0.85, 0.5, 0.4)],
		["quick clear  +%d%%" % int(round(fast * 150.0)),
			Color(0.4, 1.0, 0.6) if fast > 0.99 else Color(0.6, 0.7, 0.9)],
	]
	for i in mini(_mult_rows.get_child_count(), rows.size()):
		var l := _mult_rows.get_child(i) as Label
		l.text = rows[i][0]
		l.add_theme_color_override("font_color", rows[i][1])


func _update_status() -> void:
	if _status_col == null or player == null:
		return
	var key := "%s|%s" % [str(player.buffs), str(player.curses)]
	if key == _status_cache:
		return
	_status_cache = key
	for child in _status_col.get_children():
		child.free()

	if player.buffs.is_empty() and player.curses.is_empty():
		var none := _label(_status_col, "no buffs yet", 13, Color(0.45, 0.5, 0.6))
		none.add_theme_constant_override("outline_size", 4)
		none.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		return

	for id in Content.BUFF_IDS:
		var n := player.buff_stacks(id)
		if n <= 0:
			continue
		var data: Dictionary = Content.BUFFS[id]
		var l := _label(_status_col, "%s  x%d" % [str(data["name"]).to_upper(), n],
			14, data["color"], HORIZONTAL_ALIGNMENT_LEFT)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	var seen := {}
	for c in player.curses:
		seen[c] = int(seen.get(c, 0)) + 1
	for id in Content.CURSE_IDS:
		var n := int(seen.get(id, 0))
		if n <= 0:
			continue
		var data: Dictionary = Content.CURSES[id]
		var suffix := "" if n == 1 else "  x%d" % n
		var l := _label(_status_col, "CURSE  %s%s" % [str(data["name"]).to_upper(), suffix],
			14, Color(1.0, 0.45, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))


func _update_boss() -> void:
	if _boss_root == null:
		return
	var boss := _boss_watch
	if boss == null or not is_instance_valid(boss) or boss.dead:
		_boss_root.visible = false
		return
	_boss_root.visible = true
	var pct := clampf(boss.hp / maxf(boss.max_hp, 0.001), 0.0, 1.0)
	_boss_fill.anchor_right = pct
	var inset := minf(3.0, pct * 540.0 * 0.5)
	_boss_fill.offset_left = inset
	_boss_fill.offset_right = -inset
	_boss_label.text = "THE CREATOR   %d / %d" % [ceili(boss.hp), ceili(boss.max_hp)]
	_boss_detail.text = boss.state_label() + ("   (invulnerable)" if boss.invulnerable else "")
	_boss_detail.modulate = Color(0.55, 0.6, 0.85) if boss.invulnerable \
		else Color(1.0, 0.85, 0.3)


# ---------------------------------------------------------------- build -----

func _build() -> void:
	_build_top()
	_build_abilities()
	_build_multiplier()
	_build_status()
	_build_boss_bar()

	_banner = _label(self, "", 42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_banner, Vector2(0.5, 0.5), Vector2(-580, -80), Vector2(1160, 160))
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.pivot_offset = Vector2(580, 80)
	_banner.visible = false

	# The Arena's voice: a typewriter subtitle line above the ability row.
	_voice = _label(self, "", 19, Color(0.55, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_place(_voice, Vector2(0.5, 1), Vector2(-460, -(SLOT_H + 74.0)), Vector2(920, 36))
	_voice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voice.add_theme_constant_override("outline_size", 7)
	_voice.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_voice.pivot_offset = Vector2(460, 18)
	_voice.visible = false

	_vignette = ColorRect.new()
	_vignette.color = Color(0.85, 0.05, 0.05, 0.0)
	_cover(_vignette)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)


## Everything the player needs to read sits in one centred block at the top.
func _build_top() -> void:
	var top := Control.new()
	_place(top, Vector2(0.5, 0), Vector2(-TOP_W / 2.0, 16), Vector2(TOP_W, TOP_H))
	add_child(top)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 5)
	top.add_child(col)

	var title := _label(col, "HEALTH", 15, Color(0.72, 0.77, 0.88))
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# --- health bar ---
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 32)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(bar)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.9)
	_cover(bg)
	bar.add_child(bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.95, 0.4)
	_cover(_hp_fill)
	_hp_fill.offset_left = 3.0
	_hp_fill.offset_top = 3.0
	_hp_fill.offset_right = -3.0
	_hp_fill.offset_bottom = -3.0
	_hp_fill.grow_horizontal = Control.GROW_DIRECTION_END
	bar.add_child(_hp_fill)

	_hp_text = _label(bar, "100 / 100", 17, Color(1, 1, 1))
	_cover(_hp_text)
	_hp_text.add_theme_constant_override("outline_size", 5)
	_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	# --- stats row ---
	var stats_row := HBoxContainer.new()
	stats_row.custom_minimum_size = Vector2(0, 30)
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stats_row.add_theme_constant_override("separation", 8)
	col.add_child(stats_row)

	_kills_label = _label(stats_row, "KILLS   0", 18, Color(0.95, 0.95, 1.0),
		HORIZONTAL_ALIGNMENT_LEFT)
	_room_label = _label(stats_row, "ROOM   1", 18, Color(1.0, 0.85, 0.4))
	_left_label = _label(stats_row, "LEFT   0", 18, Color(0.6, 0.9, 1.0))
	_score_label = _label(stats_row, "SCORE   0", 18, Color(0.5, 1.0, 0.75),
		HORIZONTAL_ALIGNMENT_RIGHT)
	for child in stats_row.get_children():
		var l := child as Label
		if l != null:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.add_theme_constant_override("outline_size", 6)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	# --- realm + difficulty ---
	var realm_row := HBoxContainer.new()
	realm_row.custom_minimum_size = Vector2(0, 22)
	realm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	realm_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	realm_row.add_theme_constant_override("separation", 8)
	col.add_child(realm_row)

	_realm_label = _label(realm_row, "HELL", 15, Color(1.0, 0.5, 0.35),
		HORIZONTAL_ALIGNMENT_LEFT)
	_realm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 2.0
	realm_row.add_child(spacer)
	_label(realm_row, GameManager.difficulty_name().to_upper(), 15,
		Color(0.65, 0.7, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	for child in realm_row.get_children():
		var l := child as Label
		if l != null:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.add_theme_constant_override("outline_size", 5)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0))


func _build_multiplier() -> void:
	var panel := Control.new()
	_place(panel, Vector2(0, 0.5), Vector2(14, -96), Vector2(MULT_W, 192))
	add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1, 0.82)
	_cover(bg)
	panel.add_child(bg)
	var frame := ColorRect.new()
	frame.color = Color(1.0, 0.85, 0.3, 0.35)
	frame.anchor_left = 0.0
	frame.anchor_right = 1.0
	frame.anchor_top = 0.0
	frame.anchor_bottom = 0.0
	frame.offset_left = 0.0
	frame.offset_right = 0.0
	frame.offset_top = 0.0
	frame.offset_bottom = 2.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	col.offset_left = 12.0
	col.offset_right = -12.0
	col.offset_top = 10.0
	col.offset_bottom = -8.0
	panel.add_child(col)

	var head := _label(col, "SCORE MULTIPLIER", 13, Color(0.72, 0.77, 0.88),
		HORIZONTAL_ALIGNMENT_LEFT)
	head.add_theme_constant_override("outline_size", 4)
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	_mult_value = _label(col, "x1.00", 48, Color(1.0, 0.9, 0.3),
		HORIZONTAL_ALIGNMENT_LEFT)
	_mult_value.add_theme_constant_override("outline_size", 8)
	_mult_value.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	_mult_rows = VBoxContainer.new()
	_mult_rows.add_theme_constant_override("separation", 3)
	col.add_child(_mult_rows)
	for i in 3:
		var l := _label(_mult_rows, "", 13, Color(0.7, 0.74, 0.84),
			HORIZONTAL_ALIGNMENT_LEFT)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))


func _build_status() -> void:
	var panel := Control.new()
	_place(panel, Vector2(1, 0.5),
		Vector2(-14.0 - STATUS_W, -112), Vector2(STATUS_W, 224))
	add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1, 0.78)
	_cover(bg)
	panel.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 3)
	col.offset_left = 12.0
	col.offset_right = -10.0
	col.offset_top = 8.0
	col.offset_bottom = -8.0
	panel.add_child(col)

	var head := _label(col, "RUN STATUS", 13, Color(0.72, 0.77, 0.88),
		HORIZONTAL_ALIGNMENT_LEFT)
	head.add_theme_constant_override("outline_size", 4)
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	_status_col = VBoxContainer.new()
	_status_col.add_theme_constant_override("separation", 3)
	col.add_child(_status_col)


func _build_boss_bar() -> void:
	_boss_root = Control.new()
	_place(_boss_root, Vector2(0.5, 0),
		Vector2(-270, 16 + TOP_H + 6), Vector2(540, 48))
	_boss_root.visible = false
	_boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_root)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08, 0.9)
	_cover(bg)
	_boss_root.add_child(bg)

	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(1.0, 0.78, 0.25)
	_cover(_boss_fill)
	_boss_root.add_child(_boss_fill)

	_boss_label = _label(_boss_root, "THE CREATOR", 17, Color(1, 1, 1))
	_place(_boss_label, Vector2(0, 0), Vector2(8, 1), Vector2(524, 24))
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_label.add_theme_constant_override("outline_size", 5)
	_boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	_boss_detail = _label(_boss_root, "", 14, Color(1.0, 0.85, 0.3))
	_place(_boss_detail, Vector2(0, 0), Vector2(8, 25), Vector2(524, 20))
	_boss_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_detail.add_theme_constant_override("outline_size", 5)
	_boss_detail.add_theme_color_override("font_outline_color", Color(0, 0, 0))


## Super / Dash / Heal, pinned to the bottom centre of the screen.
func _build_abilities() -> void:
	var total_w := SLOT_W * 3.0 + 20.0
	var bottom := Control.new()
	_place(bottom, Vector2(0.5, 1),
		Vector2(-total_w / 2.0, -(SLOT_H + 26.0)), Vector2(total_w, SLOT_H))
	add_child(bottom)
	_ability_root = bottom

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(row)

	for i in 3:
		var slot := _make_slot(player.ability_names[i], player.ability_keys[i])
		row.add_child(slot["root"])
		_slots.append(slot)


func _make_slot(name_text: String, key_text: String) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09, 0.85)
	_cover(bg)
	root.add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.anchor_left = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_top = 0.0
	overlay.anchor_bottom = 0.0
	overlay.offset_left = 0.0
	overlay.offset_right = 0.0
	overlay.offset_top = 0.0
	overlay.offset_bottom = 0.0
	overlay.grow_vertical = Control.GROW_DIRECTION_END
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	var outline_size := 6
	var outline_color := Color(0, 0, 0)

	var name_label := _label(root, name_text, 13, Color(0.8, 0.85, 0.95))
	_place(name_label, Vector2(0, 0), Vector2(4, 5), Vector2(SLOT_W - 8.0, 20))

	var key_label := _label(root, key_text, 30, Color(1, 1, 1))
	_place(key_label, Vector2(0, 0), Vector2(0, 27), Vector2(SLOT_W, 42))

	var value := _label(root, "", 17, Color(1.0, 0.88, 0.4))
	_place(value, Vector2(0, 0), Vector2(0, 74), Vector2(SLOT_W, 24))
	value.visible = true

	for lbl in [name_label, key_label, value]:
		var l := lbl as Label
		l.add_theme_constant_override("outline_size", outline_size)
		l.add_theme_color_override("font_outline_color", outline_color)

	return {"root": root, "overlay": overlay, "value": value}


# ------------------------------------------------------------- helpers ------

func _place(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y
	if anchor.x >= 0.99:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif absf(anchor.x - 0.5) < 0.01:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	else:
		c.grow_horizontal = Control.GROW_DIRECTION_END
	if anchor.y >= 0.99:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	elif absf(anchor.y - 0.5) < 0.01:
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
	else:
		c.grow_vertical = Control.GROW_DIRECTION_END


func _cover(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


func _label(parent: Node, text: String, font_size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ------------------------------------------------------------ feedback -------

func show_banner(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.modulate = Color(color.r, color.g, color.b, 1.0)
	_banner.scale = Vector2(1.2, 1.2)
	_banner.visible = true
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.45)
	_banner_tween.tween_callback(_hide_banner)


func _hide_banner() -> void:
	_banner.visible = false
	var m := _banner.modulate
	m.a = 1.0
	_banner.modulate = m


## The Arena speaking: a typewriter subtitle above the ability row. Stacks a
## new line over the old one without interruption - the latest word wins.
func show_voice(text: String) -> void:
	if _voice == null:
		return
	if _voice_tween != null and _voice_tween.is_valid():
		_voice_tween.kill()
	_voice.text = text
	_voice.modulate = Color(1, 1, 1, 1)
	_voice.visible = true
	_voice.visible_characters = 0
	_voice_tween = create_tween()
	_voice_tween.tween_method(_set_voice_chars, 0, text.length(),
		clampf(text.length() * 0.024, 0.3, 1.4))
	_voice_tween.tween_interval(2.6)
	_voice_tween.tween_property(_voice, "modulate:a", 0.0, 0.5)
	_voice_tween.tween_callback(_hide_voice)


func _set_voice_chars(n: Variant) -> void:
	if _voice != null:
		_voice.visible_characters = int(n)


func _hide_voice() -> void:
	if _voice != null:
		_voice.visible = false
		_voice.visible_characters = -1


func flash_damage(_amount: float = 0.0) -> void:
	if _vignette == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_vignette.color = Color(0.85, 0.05, 0.05, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_vignette, "color:a", 0.0, 0.42)


func hide_bars() -> void:
	if _vignette == null:
		return
	_vignette.color = Color(0.85, 0.05, 0.05, 0.0)
