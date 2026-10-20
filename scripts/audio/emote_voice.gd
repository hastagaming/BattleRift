class_name EmoteVoice
extends RefCounted

# Spoken lines for the emotes. If a recording exists at res://audio/voice/<emote id>.ogg (or .wav
# or .mp3) it is used. Otherwise the phone's own text to speech voice says the line.

const LINES := {
	"attack": "Attack!",
	"follow_me": "Follow me",
	"watch_out": "Watch out!",
	"hello_mate": "Hello mate",
}
# Rate and pitch per line, so each one sounds like it is meant.
const DELIVERY := {
	"attack": {"rate": 1.1, "pitch": 1.1},
	"follow_me": {"rate": 0.95, "pitch": 1.0},
	"watch_out": {"rate": 1.15, "pitch": 1.15},
	"hello_mate": {"rate": 0.95, "pitch": 0.95},
}
const RECORDING_DIR := "res://audio/voice/"
const RECORDING_FORMATS: Array[String] = ["ogg", "wav", "mp3"]
const HEARING_DISTANCE := 25.0


# The line in the language of the player. Emotes without a spoken line are silent.
static func line_for(emote_id: String) -> String:
	if not LINES.has(emote_id):
		return ""
	return Loc.t_or("emote.%s.say" % emote_id, String(LINES[emote_id]))


# A recording for the current language comes first: res://audio/voice/<language>/<emote id>.ogg.
# Then a recording for any language: res://audio/voice/<emote id>.ogg.
static func recording_for(emote_id: String) -> AudioStream:
	var folders: Array[String] = ["%s%s/" % [RECORDING_DIR, Loc.current()], RECORDING_DIR]
	for folder in folders:
		for format in RECORDING_FORMATS:
			var path := "%s%s.%s" % [folder, emote_id, format]
			if ResourceLoader.exists(path):
				return load(path) as AudioStream
	return null


# The phone voices for the current language. English is the last choice.
static func voices_for_language() -> PackedStringArray:
	var language := Loc.current().get_slice("-", 0)
	var voices := DisplayServer.tts_get_voices_for_language(language)
	if voices.is_empty() and language != "en":
		voices = DisplayServer.tts_get_voices_for_language("en")
	return voices


static func _is_heard(source: Node3D) -> bool:
	var camera := source.get_viewport().get_camera_3d()
	return camera == null or camera.global_position.distance_to(source.global_position) <= HEARING_DISTANCE


static func play(source: Node3D, emote_id: String) -> void:
	var line := line_for(emote_id)
	if line.is_empty() or DisplayServer.get_name() == "headless":
		return
	if source == null or not source.is_inside_tree() or not _is_heard(source):
		return
	var recording := recording_for(emote_id)
	if recording != null:
		var player := AudioStreamPlayer3D.new()
		player.stream = recording
		player.unit_size = 10.0
		player.max_distance = 40.0
		source.add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
		return
	var voices := voices_for_language()
	if voices.is_empty():
		return
	var delivery: Dictionary = DELIVERY[emote_id]
	DisplayServer.tts_speak(line, String(voices[0]), 90, float(delivery["pitch"]), float(delivery["rate"]), 0, true)