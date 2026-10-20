class_name Loc
extends RefCounted

# One place for every language feature: loading packs, choosing the language, translating text,
# plurals, number and date formats, text direction, and fonts. Packs are data files, so a new
# language is added by adding a pack and listing it, with no code change.

const INDEX_PATH := "res://i18n/index.toml"
const USER_DIR := "user://i18n/"
const PREFS_PATH := "user://locale.cfg"
const DEFAULT_LANGUAGE := "en"

static var _events: LocEvents = LocEvents.new()
static var _packs: Dictionary = {}
static var _current: String = DEFAULT_LANGUAGE
static var _ready: bool = false


static func events() -> LocEvents:
	return _events


# ---- Loading ----

static func initialize(force: bool = false) -> void:
	if _ready and not force:
		return
	_packs.clear()
	var index_text := FileAccess.get_file_as_string(INDEX_PATH)
	var index := TomlLite.parse(index_text)
	var codes: Variant = (index["tables"] as Dictionary).get("", {}).get("languages", [])
	if typeof(codes) == TYPE_ARRAY:
		for entry in codes:
			var code := String(entry)
			if not LocPack.is_valid_code(code):
				push_warning("Language index lists an invalid code: %s" % code)
				continue
			var text := FileAccess.get_file_as_string("res://i18n/%s.toml" % code)
			var result := LocPack.from_text(text)
			if bool(result["ok"]) and (result["pack"] as LocPack).code == code:
				var pack: LocPack = result["pack"]
				pack.builtin = true
				_packs[code] = pack
			else:
				push_warning("Language pack %s was not loaded: %s" % [code, "; ".join(result["errors"])])
	_load_user_packs()
	_ready = true
	var preferred := saved_language()
	if preferred.is_empty() or not _packs.has(preferred):
		preferred = suggested_language()
	_current = preferred if _packs.has(preferred) else DEFAULT_LANGUAGE


static func _ensure() -> void:
	if not _ready:
		initialize()


static func _load_user_packs() -> void:
	var directory := DirAccess.open(USER_DIR)
	if directory == null:
		return
	for file_name in directory.get_files():
		if not file_name.ends_with(".toml"):
			continue
		var text := FileAccess.get_file_as_string(USER_DIR + file_name)
		var result := LocPack.from_text(text)
		if not bool(result["ok"]):
			push_warning("Ignored language pack %s: %s" % [file_name, "; ".join(result["errors"])])
			continue
		_register(result["pack"])


# A downloaded pack never replaces a built-in or installed pack unless it is a newer version.
static func _register(pack: LocPack) -> bool:
	var existing: LocPack = _packs.get(pack.code)
	if existing != null and existing.version >= pack.version:
		return false
	_packs[pack.code] = pack
	return true


# Test helpers. They never touch the files on disk.
static func reset_for_tests() -> void:
	_packs.clear()
	_current = DEFAULT_LANGUAGE
	_ready = true


static func register_pack(pack: LocPack) -> bool:
	_ensure()
	return _register(pack)


# Checks a pack and installs it for the next launches. Used when a pack is downloaded or imported.
static func install_user_pack(text: String) -> Dictionary:
	_ensure()
	var result := LocPack.from_text(text)
	if not bool(result["ok"]):
		return {"ok": false, "errors": result["errors"]}
	var pack: LocPack = result["pack"]
	var existing: LocPack = _packs.get(pack.code)
	if existing != null and existing.version >= pack.version:
		return {"ok": false, "errors": ["Version %d of %s is already installed." % [existing.version, pack.code]]}
	if DirAccess.make_dir_recursive_absolute(USER_DIR) != OK:
		return {"ok": false, "errors": ["The pack folder could not be created."]}
	var file := FileAccess.open("%s%s.toml" % [USER_DIR, pack.code], FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["The pack could not be saved."]}
	file.store_string(text)
	file.close()
	_register(pack)
	return {"ok": true, "code": pack.code, "errors": []}


# ---- Choosing the language ----

static func available() -> Array[Dictionary]:
	_ensure()
	var list: Array[Dictionary] = []
	for code in _packs:
		list.append(language_info(String(code)))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name_en"]).naturalnocasecmp_to(String(b["name_en"])) < 0
	)
	return list


static func language_info(code: String) -> Dictionary:
	_ensure()
	var pack: LocPack = _packs.get(code)
	if pack == null:
		return {}
	return {"code": pack.code, "name": pack.native_name, "name_en": pack.english_name, "direction": pack.direction, "version": pack.version, "builtin": pack.builtin}


# Every key a pack defines. Used by tests and by the pack checker.
static func keys_of(code: String) -> Array[String]:
	_ensure()
	var result: Array[String] = []
	var pack: LocPack = _packs.get(code)
	if pack != null:
		for key in pack.strings:
			result.append(String(key))
	result.sort()
	return result


static func has_language(code: String) -> bool:
	_ensure()
	return _packs.has(code)


static func current() -> String:
	_ensure()
	return _current


static func set_language(code: String, persist: bool = true) -> bool:
	_ensure()
	if not _packs.has(code):
		return false
	var changed := code != _current
	_current = code
	if persist:
		_save_preference(code)
	if changed:
		_events.language_changed.emit(code)
	return true


static func saved_language() -> String:
	var config := ConfigFile.new()
	if config.load(PREFS_PATH) != OK:
		return ""
	return String(config.get_value("locale", "language", ""))


static func needs_first_choice() -> bool:
	return saved_language().is_empty()


static func _save_preference(code: String) -> void:
	var config := ConfigFile.new()
	config.load(PREFS_PATH)
	config.set_value("locale", "language", code)
	config.save(PREFS_PATH)


# Turns a device locale such as "id_ID", "zh_TW" or "in" into a pack code that is installed.
static func match_device_locale(device_locale: String) -> String:
	_ensure()
	var parts := device_locale.replace("-", "_").to_lower().split("_")
	if parts.is_empty() or String(parts[0]).is_empty():
		return ""
	var language := String(parts[0])
	var aliases := {"in": "id", "iw": "he", "nb": "no", "nn": "no", "tl": "fil", "jw": "jv"}
	language = String(aliases.get(language, language))
	if language == "zh":
		var traditional := false
		for part in parts:
			if String(part) in ["hant", "tw", "hk", "mo"]:
				traditional = true
		var chinese := "zh-Hant" if traditional else "zh-Hans"
		return chinese if _packs.has(chinese) else ""
	return language if _packs.has(language) else ""


static func suggested_language() -> String:
	return match_device_locale(OS.get_locale())


# Used after sign-in: the language saved on the account wins on a new device.
static func adopt_account_language(code: String) -> bool:
	if code.is_empty() or not has_language(code):
		return false
	return set_language(code, true)


# ---- Translating ----

# The packs to look in, best first: the language, its base language, its own fallback, English.
static func fallback_chain(code: String) -> Array[String]:
	_ensure()
	var chain: Array[String] = []
	var pack: LocPack = _packs.get(code)
	for candidate in [code, code.get_slice("-", 0), pack.fallback if pack != null else "", DEFAULT_LANGUAGE]:
		var text := String(candidate)
		if not text.is_empty() and text not in chain and _packs.has(text):
			chain.append(text)
	return chain


static func _lookup(key: String) -> String:
	for code in fallback_chain(_current):
		var pack: LocPack = _packs[code]
		if pack.strings.has(key):
			return String(pack.strings[key])
	return ""


# A key that no pack has never reaches the player. They see a readable English phrase instead.
static func _readable_key(key: String) -> String:
	var last := key.get_slice(".", key.get_slice_count(".") - 1).replace("_", " ")
	return last.substr(0, 1).to_upper() + last.substr(1)


static func _fill(text: String, args: Dictionary) -> String:
	var result := text
	for name in args:
		var value: Variant = args[name]
		var shown := format_number(float(value), 0 if typeof(value) == TYPE_INT else 2) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else String(value)
		result = result.replace("{%s}" % String(name), shown)
	return result


# True when the current language, or one it falls back to, defines this key.
static func has_key(key: String) -> bool:
	_ensure()
	return not _lookup(key).is_empty()


# The translation if some pack has it, otherwise the given text. Used for catalogs such as items and
# pets, whose English names live in data and are translated one entry at a time.
static func t_or(key: String, fallback: String, args: Dictionary = {}) -> String:
	_ensure()
	var text := _lookup(key)
	if text.is_empty():
		text = fallback
	return _fill(text, args)


# "Only the leader can kick" -> "only_the_leader_can_kick". Used to find the key of a server message.
static func slug(text: String) -> String:
	var result := ""
	var last_was_separator := true
	for character in text.to_lower():
		var code := character.unicode_at(0)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			result += character
			last_was_separator = false
		elif not last_was_separator:
			result += "_"
			last_was_separator = true
	return result.trim_suffix("_")


# A message from the server, in the language of the player. Messages that have no translation yet
# are shown in English with a capital letter, as before.
static func error_text(message: String) -> String:
	if message.strip_edges().is_empty():
		return t("error.generic")
	return t_or("error.%s" % slug(message), _capitalize_message(message))


# English fallback for a server message: a capital first letter, and CR and BR (the currencies)
# written in capitals. Only whole words change, so "brand" and "crash" stay as they are.
static func _capitalize_message(message: String) -> String:
	var words := message.split(" ")
	for i in words.size():
		var word := String(words[i])
		if word == "cr" or word == "br":
			words[i] = word.to_upper()
	var text := " ".join(words)
	return text.substr(0, 1).to_upper() + text.substr(1)


static func t(key: String, args: Dictionary = {}) -> String:
	_ensure()
	var text := _lookup(key)
	if text.is_empty():
		if OS.is_debug_build():
			push_warning("Missing translation key: %s" % key)
		text = _readable_key(key)
	return _fill(text, args)


# A message that depends on a count, for example "{count} languages available".
static func n(key: String, count: float, args: Dictionary = {}) -> String:
	_ensure()
	var merged := args.duplicate()
	merged["count"] = int(count) if is_equal_approx(count, roundf(count)) else count
	for code in fallback_chain(_current):
		var pack: LocPack = _packs[code]
		var wanted := "%s.%s" % [key, LocPlural.category(pack.plural_rule, count)]
		if pack.strings.has(wanted):
			return _fill(String(pack.strings[wanted]), merged)
		var other := "%s.other" % key
		if pack.strings.has(other):
			return _fill(String(pack.strings[other]), merged)
	if OS.is_debug_build():
		push_warning("Missing translation key: %s" % key)
	return _fill(_readable_key(key), merged)


# ---- Numbers and dates ----

static func _current_pack() -> LocPack:
	_ensure()
	return _packs.get(_current) as LocPack


static func format_number(value: float, decimals: int = 0) -> String:
	var pack := _current_pack()
	var decimal_mark := pack.decimal_separator if pack != null else "."
	var group_mark := pack.group_separator if pack != null else ","
	var text := String.num(absf(value), decimals)
	var whole := text.get_slice(".", 0)
	var fraction := text.get_slice(".", 1) if text.contains(".") else ""
	var grouped := ""
	var count := 0
	for i in range(whole.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0 and not group_mark.is_empty():
			grouped = group_mark + grouped
		grouped = whole[i] + grouped
		count += 1
	var result := grouped
	if decimals > 0:
		result += decimal_mark + fraction
	if value < 0.0 and (grouped != "0" or not fraction.is_empty()):
		result = "-" + result
	return result


# A calendar date in the order and separator of the language. The time zone is the device's.
static func format_date(unix_time: int) -> String:
	var pack := _current_pack()
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var parts := Time.get_datetime_dict_from_unix_time(unix_time + bias_minutes * 60)
	var day := "%02d" % int(parts["day"])
	var month := "%02d" % int(parts["month"])
	var year := "%04d" % int(parts["year"])
	var separator := pack.date_separator if pack != null else "/"
	var order := pack.date_order if pack != null else "dmy"
	match order:
		"mdy":
			return separator.join([month, day, year])
		"ymd":
			return separator.join([year, month, day])
	return separator.join([day, month, year])


static func format_clock(seconds: int) -> String:
	var total := maxi(seconds, 0)
	return "%d:%02d" % [total / 60, total % 60]


# ---- Direction and fonts ----

static func is_rtl() -> bool:
	var pack := _current_pack()
	return pack != null and pack.direction == "rtl"


# Call this on the root control of every screen. Everything inside follows its direction, so rows
# and containers mirror for right to left languages. Text itself picks its direction from its letters.
static func apply_to(screen: Control) -> void:
	screen.layout_direction = Control.LAYOUT_DIRECTION_RTL if is_rtl() else Control.LAYOUT_DIRECTION_LTR


# The main font with the phone's own fonts behind it, so scripts the main font lacks
# (Japanese, Arabic, Thai, Devanagari, and others) still draw instead of showing empty boxes.
static func make_font() -> Font:
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["sans-serif"])
	system.allow_system_fallback = true
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.fallbacks = [system]
	return variation