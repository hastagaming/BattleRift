@tool
extends EditorPlugin

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "BattleRiftNotify"
	const AAR_DEBUG := "res://addons/battlerift_notify/bin/debug/battlerift-notify-debug.aar"
	const AAR_RELEASE := "res://addons/battlerift_notify/bin/release/battlerift-notify-release.aar"

	func _get_name() -> String:
		return PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR_DEBUG if debug else AAR_RELEASE])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"androidx.core:core-ktx:1.13.1",
			"androidx.activity:activity:1.9.0",
			"androidx.work:work-runtime-ktx:2.9.1",
		])