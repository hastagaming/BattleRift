extends Node

const BOOT := "res://scenes/boot/boot.tscn"
const AUTH := "res://scenes/auth/auth.tscn"
const LOBBY := "res://scenes/lobby/lobby.tscn"


func go(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Scene not found: %s" % path)
		return
	get_tree().change_scene_to_file.call_deferred(path)