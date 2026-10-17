class_name PetSounds
extends RefCounted

# Each pet has its own sound, synthesized from math at first use. There are no audio files to ship.

const RATE := 22050
const PEAK := 0.8

static var _cache: Dictionary = {}


static func has_sound(pet_id: String) -> bool:
	return pet_id in PetDb.ORDER


static func samples_for(pet_id: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pet_id)
	var raw := PackedFloat32Array()
	match pet_id:
		"pet_volt":
			raw = _zap(rng)
		"pet_blaze":
			raw = _fire(rng)
		"pet_frost":
			raw = _chime()
		"pet_aero":
			raw = _gust(rng)
		"pet_terra":
			raw = _thud(rng)
		"pet_shadow":
			raw = _whoosh(rng)
		"pet_riftling":
			raw = _warp()
		"pet_falcon":
			raw = _screech(rng)
		"pet_catty":
			raw = _meow()
		"pet_creaton":
			raw = _hum()
		_:
			return raw
	return _finish(raw)


# Normalizes the peak and fades the last 12 ms so the sound never clicks.
static func _finish(raw: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0001
	for value in raw:
		peak = maxf(peak, absf(value))
	var fade := int(RATE * 0.012)
	var out := PackedFloat32Array()
	out.resize(raw.size())
	for i in raw.size():
		var gain := PEAK / peak
		var left := raw.size() - 1 - i
		if left < fade:
			gain *= float(left) / float(fade)
		out[i] = raw[i] * gain
	return out


static func stream_for(pet_id: String) -> AudioStreamWAV:
	if _cache.has(pet_id):
		return _cache[pet_id]
	var samples := samples_for(pet_id)
	if samples.is_empty():
		return null
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	_cache[pet_id] = stream
	return stream


static func play(source: Node3D, pet_id: String) -> void:
	if DisplayServer.get_name() == "headless" or source == null or not source.is_inside_tree():
		return
	var stream := stream_for(pet_id)
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = 8.0
	player.max_distance = 40.0
	player.volume_db = -4.0
	source.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _count(seconds: float) -> int:
	return int(RATE * seconds)


# Volt: a crackling electric zap.
static func _zap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_count(0.38))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (160.0 + 1100.0 * exp(-t * 5.0)) / RATE
		var saw := fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		var gate := 1.0 if int(t * 60.0) % 2 == 0 else 0.35
		var hiss := rng.randf_range(-1.0, 1.0) * 0.5 * exp(-t * 14.0)
		out[i] = (saw * 0.6 * gate + hiss) * exp(-t * 5.5) * minf(t / 0.004, 1.0)
	return out


# Blaze: a rising and falling roar of fire.
static func _fire(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var length := 0.55
	out.resize(_count(length))
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var hump := pow(sin(PI * t / length), 1.5)
		var cutoff := 0.05 + 0.3 * hump
		low += cutoff * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = (low * 2.2 + sin(TAU * 95.0 * t) * 0.3) * hump
	return out


# Frost: a glassy chime made of four bell tones.
static func _chime() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_count(0.7))
	var tones: Array[float] = [1318.0, 1760.0, 2637.0, 3520.0]
	var amps: Array[float] = [1.0, 0.6, 0.4, 0.25]
	for i in out.size():
		var t := float(i) / RATE
		var sum := 0.0
		for k in tones.size():
			sum += sin(TAU * tones[k] * t + 0.4 * sin(TAU * 5.0 * t)) * amps[k] * exp(-t * (4.0 + 2.0 * float(k)))
		out[i] = sum * minf(t / 0.003, 1.0)
	return out


# Aero: a soft wind gust.
static func _gust(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var length := 0.6
	out.resize(_count(length))
	var slow := 0.0
	var fast := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var shape := pow(sin(PI * t / length), 2.0)
		var noise := rng.randf_range(-1.0, 1.0)
		slow += 0.03 * (noise - slow)
		fast += (0.12 + 0.1 * shape) * (noise - fast)
		out[i] = (fast - slow) * 3.0 * shape
	return out


# Terra: a deep thud with a little gravel.
static func _thud(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_count(0.45))
	var low := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (40.0 + 25.0 * exp(-t * 12.0)) / RATE
		low += 0.08 * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = (sin(phase) * exp(-t * 7.0) + low * 1.5 * exp(-t * 16.0)) * minf(t / 0.002, 1.0)
	return out


# Shadow: a low, eerie sweep with a tremble.
static func _whoosh(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var length := 0.5
	out.resize(_count(length))
	var phase := 0.0
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var hump := sin(PI * t / length)
		phase += TAU * (260.0 * exp(-t * 2.2) + 90.0) / RATE
		low += 0.15 * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = (sin(phase) * (0.7 + 0.3 * sin(TAU * 18.0 * t)) + low * 0.8) * hump
	return out


# Riftling: a warping, bending tone.
static func _warp() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var length := 0.55
	out.resize(_count(length))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var carrier := 180.0 * pow(1100.0 / 180.0, t / length)
		phase += TAU * carrier / RATE
		var tone := sin(phase + 3.0 * sin(phase * 2.0)) * 0.7 + sin(TAU * 1800.0 * t) * 0.15
		out[i] = tone * sin(PI * t / length) * exp(-t * 1.5)
	return out


# Falcon: two sharp "kree" screeches.
static func _screech(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_count(0.5))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var local := fposmod(t, 0.25)
		if local > 0.2:
			continue
		var frequency := 1500.0 + 1100.0 * exp(-local * 11.0)
		phase += TAU * frequency / RATE
		var voice := sin(phase) + 0.4 * sin(phase * 2.0) + 0.15 * rng.randf_range(-1.0, 1.0)
		out[i] = voice * sin(PI * local / 0.2) * exp(-local * 3.0) * (1.0 if t < 0.25 else 0.8)
	return out


# Catty: a meow. The pitch rises and falls while the vowel opens, so it sounds like a voice.
static func _meow() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var length := 0.55
	out.resize(_count(length))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var u := t / length
		var vibrato := 1.0 + 0.02 * sin(TAU * 6.0 * t)
		var fundamental := (380.0 + 300.0 * sin(PI * u)) * vibrato
		phase += TAU * fundamental / RATE
		var open := 0.5 + 0.5 * sin(PI * u)
		var sum := 0.0
		for k in range(1, 12):
			var harmonic := fundamental * float(k)
			var first := exp(-pow((harmonic - (700.0 + 500.0 * open)) / 450.0, 2.0))
			var second := 0.6 * exp(-pow((harmonic - 2200.0) / 700.0, 2.0))
			sum += sin(phase * float(k)) * (first + second + 0.05) / float(k)
		out[i] = sum * pow(sin(PI * u), 0.6)
	return out


# Creaton: a warm crystal chord.
static func _hum() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var length := 0.7
	out.resize(_count(length))
	for i in out.size():
		var t := float(i) / RATE
		var tones := sin(TAU * 330.0 * t) + 0.8 * sin(TAU * 495.0 * t + 0.5) + 0.6 * sin(TAU * 662.0 * t) + 0.3 * sin(TAU * 990.0 * t)
		out[i] = tones * minf(t / 0.08, 1.0) * exp(-t * 3.0)
	return out