class_name TutorialDirector
extends Node

# Runs the gameplay part of the tutorial inside the real practice arena. It watches the real
# player (movement, camera, jump, dash, attack, knock-out) and never fakes progress.

const MOVE_DISTANCE := 4.0
const LOOK_RADIANS := 0.9
const JUMP_SPEED := 2.0
const DASH_SPEED_RATIO := 0.8

var state: MatchState
var player: PlayerController
var camera_rig: CameraRig
var local_peer: int = 0
var layer: Node
var flow: TutorialFlow

var _root: Control
var _panel: PanelContainer
var _step_label: Label
var _title_label: Label
var _body_label: Label
var _hint_label: Label
var _back_button: Button
var _continue_button: Button
var _skip_button: Button
var _active: bool = false
var _moved: float = 0.0
var _turned: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _last_yaw: float = 0.0


func _ready() -> void:
	var start := TutorialProgress.saved_index(PlayerData.data)
	if TutorialFlow.where_of(start) != TutorialFlow.WHERE_MATCH:
		start = TutorialFlow.first_match_index()
	flow = TutorialFlow.new(start)
	_build_ui()
	state.phase_changed.connect(_on_phase_changed)
	state.player_knocked_out.connect(_on_knocked_out)
	player.weapons.attacked.connect(_on_attacked)
	get_viewport().size_changed.connect(_layout)
	_refresh()
	if state.phase == MatchState.Phase.ACTIVE:
		_activate()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	layer.add_child(_root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 15)
	_step_label.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(_step_label)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(_title_label)
	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 19)
	column.add_child(_body_label)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_hint_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_back_button = _make_button("Back", _on_back_pressed)
	row.add_child(_back_button)
	_continue_button = _make_button("Continue", _on_continue_pressed)
	_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_continue_button)
	_skip_button = _make_button("Skip tutorial", _on_skip_pressed)
	row.add_child(_skip_button)
	_layout.call_deferred()


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.pressed.connect(callback)
	return button


func _layout() -> void:
	if _panel == null:
		return
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	var width := minf(area.size.x - 32.0, 600.0)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	_panel.size = Vector2(width, 0.0)
	_panel.position = Vector2(area.position.x + (area.size.x - width) * 0.5, area.position.y + 64.0)


func _on_phase_changed(phase: int) -> void:
	if phase == MatchState.Phase.ACTIVE:
		_activate()


func _activate() -> void:
	_active = true
	_root.visible = true
	_reset_trackers()
	_refresh()


func _reset_trackers() -> void:
	_moved = 0.0
	_turned = 0.0
	_last_position = player.global_position
	_last_yaw = camera_rig.yaw


func _process(_delta: float) -> void:
	if not _active or flow == null or not flow.is_action() or flow.is_completed():
		return
	match flow.kind():
		TutorialFlow.KIND_MOVE:
			var here := player.global_position
			_moved += Vector2(here.x - _last_position.x, here.z - _last_position.z).length()
			_last_position = here
			if _moved >= MOVE_DISTANCE:
				_report(TutorialFlow.KIND_MOVE)
		TutorialFlow.KIND_LOOK:
			_turned += absf(angle_difference(_last_yaw, camera_rig.yaw))
			_last_yaw = camera_rig.yaw
			if _turned >= LOOK_RADIANS:
				_report(TutorialFlow.KIND_LOOK)
		TutorialFlow.KIND_JUMP:
			if not player.is_on_floor() and player.velocity.y > JUMP_SPEED:
				_report(TutorialFlow.KIND_JUMP)
		TutorialFlow.KIND_DASH:
			var horizontal := Vector2(player.velocity.x, player.velocity.z).length()
			if horizontal >= PlayerController.DASH_SPEED * DASH_SPEED_RATIO:
				_report(TutorialFlow.KIND_DASH)


func _on_attacked(_weapon_id: String) -> void:
	if _active:
		_report(TutorialFlow.KIND_ATTACK)


func _on_knocked_out(victim_id: int, _killer_id: int) -> void:
	if _active and victim_id == local_peer:
		_report(TutorialFlow.KIND_FALL)


func _report(kind: String) -> void:
	if flow.report(kind):
		_refresh()


func _refresh() -> void:
	if flow == null or _panel == null:
		return
	var step := flow.current()
	_step_label.text = flow.progress_text()
	_title_label.text = String(step["title"])
	_body_label.text = String(step["body"])
	if not flow.is_action():
		_hint_label.text = ""
	elif flow.is_completed():
		_hint_label.text = "Done! Tap Continue."
		_hint_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	else:
		_hint_label.text = "Try it now to continue."
		_hint_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_hint_label.visible = not _hint_label.text.is_empty()
	_back_button.disabled = not flow.can_go_back()
	_continue_button.disabled = not flow.can_continue()
	var next_is_guide := flow.index + 1 < TutorialFlow.count() and TutorialFlow.where_of(flow.index + 1) != TutorialFlow.WHERE_MATCH
	_continue_button.text = "Next" if next_is_guide else "Continue"
	_layout.call_deferred()


func _on_continue_pressed() -> void:
	var result := flow.advance()
	if not bool(result["ok"]):
		return
	TutorialStore.save_step(flow.index)
	if bool(result["finished"]) or bool(result["scene_changed"]):
		TutorialStore.from_arena = true
		Router.go(Router.TUTORIAL)
		return
	_reset_trackers()
	_refresh()


func _on_back_pressed() -> void:
	if flow.back():
		TutorialStore.save_step(flow.index)
		_reset_trackers()
		_refresh()


func _on_skip_pressed() -> void:
	await TutorialStore.skip()
	Router.go(Router.LOBBY)