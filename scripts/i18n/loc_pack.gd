class_name LocPack
extends RefCounted

# One language pack. Packs are plain data (a TOML text), so a bad or hostile pack can be refused
# without running anything. A pack that fails validation is never loaded.

const SUPPORTED_FORMAT := 1
const MAX_TEXT_BYTES := 524288
const MAX_STRINGS := 5000
const MAX_VALUE_LENGTH := 1000
const DIRECTIONS: Array[String] = ["ltr", "rtl"]
const DATE_ORDERS: Array[String] = ["dmy", "mdy", "ymd"]

var code: String = ""
var native_name: String = ""
var english_name: String = ""
var version: int = 0
var direction: String = "ltr"
var plural_rule: String = "one_other"
var decimal_separator: String = "."
var group_separator: String = ","
var date_order: String = "dmy"
var date_separator: String = "/"
var fallback: String = "en"
var strings: Dictionary = {}
var builtin: bool = false


static func is_valid_code(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}$")
	return pattern.search(value) != null


static func is_valid_key(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9_]+(\\.[a-z0-9_]+)*$")
	return pattern.search(value) != null


# The names inside {braces}. Returns null when the braces are not balanced or a name is invalid.
static func placeholders_of(text: String) -> Variant:
	var pattern := RegEx.new()
	pattern.compile("\\{([a-z_][a-z0-9_]*)\\}")
	var names: Array[String] = []
	var rest := text
	for found in pattern.search_all(text):
		var name := found.get_string(1)
		if name not in names:
			names.append(name)
		rest = rest.replace(found.get_string(0), "")
	if rest.contains("{") or rest.contains("}"):
		return null
	names.sort()
	return names


static func _string_of(table: Dictionary, key: String, errors: Array[String]) -> String:
	if not table.has(key) or typeof(table[key]) != TYPE_STRING:
		errors.append("[meta] needs a text value for '%s'." % key)
		return ""
	return String(table[key])


static func from_text(text: String) -> Dictionary:
	var errors: Array[String] = []
	if text.to_utf8_buffer().size() > MAX_TEXT_BYTES:
		return {"ok": false, "pack": null, "errors": ["The pack is larger than %d bytes." % MAX_TEXT_BYTES]}
	var parsed := TomlLite.parse(text)
	for problem in parsed["errors"]:
		errors.append(String(problem))
	var tables: Dictionary = parsed["tables"]
	var meta: Dictionary = tables.get("meta", {})
	var strings_table: Dictionary = tables.get("strings", {})
	if not tables.has("meta"):
		errors.append("The pack has no [meta] table.")
	if not tables.has("strings"):
		errors.append("The pack has no [strings] table.")
	for table_name in tables:
		if table_name not in ["", "meta", "strings"]:
			errors.append("The table [%s] is not allowed in a language pack." % table_name)
	if not errors.is_empty():
		return {"ok": false, "pack": null, "errors": errors}
	var pack := LocPack.new()
	if typeof(meta.get("format")) != TYPE_INT or int(meta["format"]) != SUPPORTED_FORMAT:
		errors.append("This pack uses format %s but the game reads format %d." % [str(meta.get("format")), SUPPORTED_FORMAT])
	pack.code = _string_of(meta, "code", errors)
	if not pack.code.is_empty() and not is_valid_code(pack.code):
		errors.append("The language code '%s' is not valid." % pack.code)
	pack.native_name = _string_of(meta, "name", errors).strip_edges()
	pack.english_name = _string_of(meta, "name_en", errors).strip_edges()
	if pack.native_name.is_empty() or pack.native_name.length() > 40 or pack.english_name.is_empty() or pack.english_name.length() > 40:
		errors.append("The language names must be 1 to 40 characters.")
	if typeof(meta.get("version")) != TYPE_INT or int(meta["version"]) < 1:
		errors.append("The pack version must be a whole number of 1 or more.")
	else:
		pack.version = int(meta["version"])
	pack.direction = _string_of(meta, "direction", errors)
	if pack.direction not in DIRECTIONS:
		errors.append("The direction must be ltr or rtl.")
	pack.plural_rule = _string_of(meta, "plural_rule", errors)
	if not LocPlural.has_rule(pack.plural_rule):
		errors.append("The plural rule '%s' is not known. Use one of: %s." % [pack.plural_rule, ", ".join(LocPlural.RULES)])
	pack.decimal_separator = _string_of(meta, "decimal_separator", errors)
	pack.group_separator = String(meta.get("group_separator", ""))
	if pack.decimal_separator.length() != 1 or pack.group_separator.length() > 1 or pack.decimal_separator == pack.group_separator:
		errors.append("The decimal separator must be one character and differ from the group separator.")
	pack.date_order = _string_of(meta, "date_order", errors)
	if pack.date_order not in DATE_ORDERS:
		errors.append("The date order must be dmy, mdy, or ymd.")
	pack.date_separator = _string_of(meta, "date_separator", errors)
	if pack.date_separator.length() != 1:
		errors.append("The date separator must be one character.")
	pack.fallback = String(meta.get("fallback", "en"))
	if not is_valid_code(pack.fallback):
		errors.append("The fallback code '%s' is not valid." % pack.fallback)
	if strings_table.size() > MAX_STRINGS:
		errors.append("The pack has more than %d strings." % MAX_STRINGS)
	var bases_with_plurals: Dictionary = {}
	for key in strings_table:
		var key_text := String(key)
		var value: Variant = strings_table[key]
		if not is_valid_key(key_text):
			errors.append("The key '%s' is not valid. Use lowercase letters, digits, _ and dots." % key_text)
			continue
		if typeof(value) != TYPE_STRING:
			errors.append("The value of '%s' must be text." % key_text)
			continue
		var value_text := String(value)
		if value_text.length() > MAX_VALUE_LENGTH:
			errors.append("The value of '%s' is longer than %d characters." % [key_text, MAX_VALUE_LENGTH])
			continue
		if value_text.contains("\r") or value_text.contains("\t"):
			errors.append("The value of '%s' contains a tab or carriage return." % key_text)
			continue
		if placeholders_of(value_text) == null:
			errors.append("The value of '%s' has an unbalanced or invalid {placeholder}." % key_text)
			continue
		pack.strings[key_text] = value_text
		var last_part := key_text.get_slice(".", key_text.get_slice_count(".") - 1)
		if last_part in LocPlural.CATEGORIES and key_text.contains("."):
			bases_with_plurals[key_text.substr(0, key_text.length() - last_part.length() - 1)] = true
	for base in bases_with_plurals:
		for needed in LocPlural.categories_for(pack.plural_rule):
			if not pack.strings.has("%s.%s" % [base, needed]):
				errors.append("The plural '%s' is missing the '%s' form that rule %s needs." % [base, needed, pack.plural_rule])
	if not errors.is_empty():
		return {"ok": false, "pack": null, "errors": errors}
	return {"ok": true, "pack": pack, "errors": errors}