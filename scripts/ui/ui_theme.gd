class_name UiTheme
extends RefCounted

const BG := Color("#10131c")
const SURFACE := Color("#1b2133")
const SURFACE_HOVER := Color("#252d45")
const ACCENT := Color("#38e8c6")
const ACCENT_DIM := Color("#1c8f7c")
const DANGER := Color("#ff5a5f")
const GOLD := Color("#ffc857")
const TEXT := Color("#e8ecf6")
const MUTED := Color("#8b94ad")
const BORDER := Color("#34406a")


static func _box(color: Color, radius: int = 16, margin_h: float = 18.0, margin_v: float = 10.0, border: Color = Color(0.0, 0.0, 0.0, 0.0), border_width: int = 0, bottom_width: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
		if bottom_width > border_width:
			box.border_width_bottom = bottom_width
			box.content_margin_bottom = margin_v - float(bottom_width - border_width) * 0.5
	if shadow > 0:
		box.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
		box.shadow_size = shadow
		box.shadow_offset = Vector2(0.0, float(shadow) * 0.4)
	return box


# Colors a button so it keeps the same chunky look but carries its own accent.
static func tint_button(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", _box(SURFACE, 16, 18.0, 10.0, color.darkened(0.25), 2, 5, 6))
	button.add_theme_stylebox_override("hover", _box(SURFACE_HOVER, 16, 18.0, 10.0, color, 2, 5, 6))
	button.add_theme_stylebox_override("pressed", _box(color, 16, 18.0, 10.0, color.lightened(0.2), 2, 2, 0))
	button.add_theme_color_override("font_color", color.lightened(0.35))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", BG)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_stylebox("normal", "Button", _box(SURFACE, 16, 18.0, 10.0, BORDER, 2, 5, 6))
	theme.set_stylebox("hover", "Button", _box(SURFACE_HOVER, 16, 18.0, 10.0, ACCENT_DIM, 2, 5, 6))
	theme.set_stylebox("pressed", "Button", _box(ACCENT, 16, 18.0, 10.0, ACCENT.lightened(0.25), 2, 2, 0))
	theme.set_stylebox("disabled", "Button", _box(Color("#171b27"), 16, 18.0, 10.0, Color("#232a3d"), 2, 2, 0))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", BG)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("panel", "PanelContainer", _box(Color(SURFACE, 0.94), 20, 18.0, 12.0, BORDER, 2, 0, 12))
	theme.set_stylebox("normal", "LineEdit", _box(Color("#141a2a"), 14, 16.0, 10.0, BORDER, 2))
	theme.set_stylebox("focus", "LineEdit", _box(Color("#141a2a"), 14, 16.0, 10.0, ACCENT, 2))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_stylebox("background", "ProgressBar", _box(Color("#141a2a"), 8, 0.0, 0.0, BORDER, 1))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, 8, 0.0, 0.0))
	theme.set_stylebox("scroll", "VScrollBar", _box(Color(BG, 0.5), 6, 0.0, 0.0))
	theme.set_stylebox("grabber", "VScrollBar", _box(BORDER, 6, 0.0, 0.0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(ACCENT_DIM, 6, 0.0, 0.0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(ACCENT, 6, 0.0, 0.0))
	theme.set_color("font_color", "Label", TEXT)
	return theme


static func ensure(tree: SceneTree) -> void:
	if tree.root.theme == null:
		tree.root.theme = build()