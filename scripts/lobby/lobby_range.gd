class_name LobbyRange
extends Node3D


func _ready() -> void:
	var crate_color := Color("#8a6a3d")
	for x in [-1.5, 0.0, 1.5]:
		add_child(PhysicsProp.create("box", 1.0, crate_color, Vector3(x, 0.5, -8.0)))
	for x in [-0.75, 0.75]:
		add_child(PhysicsProp.create("box", 1.0, crate_color, Vector3(x, 1.5, -8.0)))
	add_child(PhysicsProp.create("box", 1.0, crate_color, Vector3(0.0, 2.5, -8.0)))
	for ball_position in [Vector3(-4.0, 0.5, -6.0), Vector3(4.0, 0.5, -6.0), Vector3(0.0, 0.5, -4.0)]:
		add_child(PhysicsProp.create("ball", 1.0, UiTheme.DANGER, ball_position))
	var sign_label := Label3D.new()
	sign_label.text = "TRAINING RANGE"
	sign_label.font_size = 96
	sign_label.pixel_size = 0.01
	sign_label.modulate = UiTheme.ACCENT
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.position = Vector3(0.0, 4.6, -8.0)
	add_child(sign_label)