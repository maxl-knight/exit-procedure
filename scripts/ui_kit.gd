class_name UIKit
extends RefCounted

## Shared bits of menu / overlay UI so every screen looks consistent.


static func flat(bg: Color, radius: int = 8, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func style_button(b: Button, normal: Color, hover: Color, pressed: Color,
		disabled: Color = Color(0.1, 0.1, 0.13, 0.7)) -> void:
	b.add_theme_stylebox_override("normal", flat(normal))
	b.add_theme_stylebox_override("hover", flat(hover))
	b.add_theme_stylebox_override("pressed", flat(pressed))
	b.add_theme_stylebox_override("disabled", flat(disabled))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.52))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))


static func button(text: String, font_size: int = 20, normal := Color(0.12, 0.14, 0.2),
		hover := Color(0.18, 0.22, 0.32), pressed := Color(0.25, 0.45, 0.85),
		min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = min_size
	style_button(b, normal, hover, pressed)
	return b


static func center_vbox(parent: Node, width: float, height: float,
		separation: int = 12) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", separation)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(col)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -width / 2.0
	col.offset_right = width / 2.0
	col.offset_top = -height / 2.0
	col.offset_bottom = height / 2.0
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	return col


static func label(parent: Node, text: String, font_size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func outline(l: Label, size: int = 8, color := Color(0, 0, 0)) -> void:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", color)


static func dim(parent: Node, color := Color(0, 0, 0, 0.68)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.anchor_left = 0.0
	r.anchor_top = 0.0
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.offset_left = 0.0
	r.offset_top = 0.0
	r.offset_right = 0.0
	r.offset_bottom = 0.0
	return r


static func row(parent: Node, separation: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", separation)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(h)
	return h


## A full-screen CenterContainer holding an auto-sized, perfectly centred column.
## Guarantees the content is on screen and fits, whatever the window size.
static func centered_column(parent: Node, separation: int = 12) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", separation)
	center.add_child(col)
	return col


static func panel(style_bg: Color, radius: int = 10, margin: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(style_bg, radius, margin))
	return p


static func small_label(parent: Node, text: String, font_size: int, color: Color,
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
