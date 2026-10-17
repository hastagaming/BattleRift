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


static func line_for(emote_id: String) -> String:
	return String(LINES.get(emote_id, ""))


static func recording_for(emote_id: String) -> AudioStream:
	for format in RECORDING_FORMATS:
		var path := "%s%s.%s" % [RECORDING_DIR, emote_id, format]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


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
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	var delivery: Dictionary = DELIVERY[emote_id]
	DisplayServer.tts_speak(line, String(voices[0]), 90, float(delivery["pitch"]), float(delivery["rate"]), 0, true)