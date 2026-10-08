extends Node

const BOOT := "res://scenes/boot/boot.tscn"
const AUTH := "res://scenes/auth/auth.tscn"
const LOBBY := "res://scenes/lobby/lobby.tscn"
const MATCH := "res://scenes/match/match.tscn"
const ROOM := "res://scenes/room/room.tscn"
const ONLINE_MATCH := "res://scenes/match/online_match.tscn"
const SHOP := "res://scenes/shop/shop.tscn"
const INVENTORY := "res://scenes/inventory/inventory.tscn"
const CUSTOMIZE := "res://scenes/customize/customize.tscn"
const PROFILE := "res://scenes/profile/profile.tscn"
const PLAY := "res://scenes/play/play.tscn"
const MISSIONS := "res://scenes/missions/missions.tscn"
const SETTINGS := "res://scenes/settings/settings.tscn"
const SOCIAL := "res://scenes/social/social.tscn"


func go(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Scene not found: %s" % path)
		return
	get_tree().change_scene_to_file.call_deferred(path)