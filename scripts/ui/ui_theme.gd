class_name UiTheme
extends RefCounted

const BG := Color("#10131c")
const SURFACE := Color("#1b2133")
const SURFACE_HOVER := Color("#252d45")
const ACCENT := Color("#38e8c6")
const DANGER := Color("#ff5a5f")
const GOLD := Color("#ffc857")
const TEXT := Color("#e8ecf6")
const MUTED := Color("#8b94ad")


static func _box(color: Color, radius: int = 10, margin_h: float = 18.0, margin_v: float = 10.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_stylebox("normal", "Button", _box(SURFACE))
	theme.set_stylebox("hover", "Button", _box(SURFACE_HOVER))
	theme.set_stylebox("pressed", "Button", _box(ACCENT))
	theme.set_stylebox("disabled", "Button", _box(Color("#171b27")))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", BG)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("panel", "PanelContainer", _box(Color(BG, 0.88), 14, 16.0, 8.0))
	theme.set_stylebox("background", "ProgressBar", _box(SURFACE, 6, 0.0, 0.0))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, 6, 0.0, 0.0))
	theme.set_color("font_color", "Label", TEXT)
	return theme


static func ensure(tree: SceneTree) -> void:
	if tree.root.theme == null:
		tree.root.theme = build()