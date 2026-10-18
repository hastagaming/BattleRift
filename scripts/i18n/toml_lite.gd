class_name TomlLite
extends RefCounted

# A small, safe reader for the TOML subset that language packs use. It only reads data and never
# runs anything. Supported: comments, [tables], "quoted" or bare keys, strings with the usual
# escapes, integers, true and false, and arrays of strings.

const MAX_LINES := 20000
const MAX_STRING_LENGTH := 2000
const MAX_ARRAY_ITEMS := 500


static func parse(text: String) -> Dictionary:
	var tables: Dictionary = {"": {}}
	var errors: Array[String] = []
	var lines := text.split("\n")
	if lines.size() > MAX_LINES:
		errors.append("The file has more than %d lines." % MAX_LINES)
		return {"tables": tables, "errors": errors}
	var current := ""
	for index in lines.size():
		var number := index + 1
		var line := String(lines[index]).strip_edges()
		if index == 0:
			line = line.trim_prefix("\ufeff")
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("["):
			if line.begins_with("[[") or not line.ends_with("]"):
				errors.append("Line %d: a table header must look like [name]." % number)
				continue
			var table_name := line.substr(1, line.length() - 2).strip_edges()
			if not _is_bare_key(table_name):
				errors.append("Line %d: the table name '%s' is not valid." % [number, table_name])
				continue
			if tables.has(table_name):
				errors.append("Line %d: the table [%s] appears twice." % [number, table_name])
				continue
			tables[table_name] = {}
			current = table_name
			continue
		var pair := _parse_pair(line)
		if not bool(pair["ok"]):
			errors.append("Line %d: %s" % [number, String(pair["error"])])
			continue
		var table: Dictionary = tables[current]
		if table.has(pair["key"]):
			errors.append("Line %d: the key '%s' appears twice." % [number, String(pair["key"])])
			continue
		table[pair["key"]] = pair["value"]
	return {"tables": tables, "errors": errors}


static func _is_bare_key(text: String) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		var code := text.unicode_at(i)
		var ok := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95 or code == 45
		if not ok:
			return false
	return true


static func _skip_spaces(text: String, start: int) -> int:
	var position := start
	while position < text.length() and (text[position] == " " or text[position] == "\t"):
		position += 1
	return position


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _parse_pair(line: String) -> Dictionary:
	var position := 0
	var key := ""
	if line[0] == "\"":
		var quoted := _read_string(line, 0)
		if not bool(quoted["ok"]):
			return quoted
		key = String(quoted["value"])
		position = int(quoted["end"])
	else:
		var start := 0
		while position < line.length() and line[position] != " " and line[position] != "\t" and line[position] != "=":
			position += 1
		key = line.substr(start, position - start)
		if not _is_bare_key(key):
			return _fail("the key '%s' is not valid. Put it in quotes." % key)
	if key.is_empty():
		return _fail("the key is empty.")
	position = _skip_spaces(line, position)
	if position >= line.length() or line[position] != "=":
		return _fail("expected '=' after the key.")
	position = _skip_spaces(line, position + 1)
	if position >= line.length():
		return _fail("the value is missing.")
	var value: Variant
	var next := position
	var first := line[position]
	if first == "\"":
		var result := _read_string(line, position)
		if not bool(result["ok"]):
			return result
		value = String(result["value"])
		next = int(result["end"])
	elif first == "[":
		var array_result := _read_array(line, position)
		if not bool(array_result["ok"]):
			return array_result
		value = array_result["value"]
		next = int(array_result["end"])
	else:
		var end := position
		while end < line.length() and line[end] != " " and line[end] != "\t" and line[end] != "#":
			end += 1
		var word := line.substr(position, end - position)
		if word == "true":
			value = true
		elif word == "false":
			value = false
		elif word.is_valid_int():
			value = word.to_int()
		else:
			return _fail("the value '%s' is not supported. Use a quoted string, an integer, true, false, or an array of strings." % word)
		next = end
	next = _skip_spaces(line, next)
	if next < line.length() and line[next] != "#":
		return _fail("unexpected text after the value.")
	return {"ok": true, "key": key, "value": value}


static func _read_array(text: String, start: int) -> Dictionary:
	var items: Array[String] = []
	var position := _skip_spaces(text, start + 1)
	while true:
		if position >= text.length():
			return _fail("the array is not closed.")
		if text[position] == "]":
			return {"ok": true, "value": items, "end": position + 1}
		if text[position] != "\"":
			return _fail("arrays may only hold quoted strings.")
		if items.size() >= MAX_ARRAY_ITEMS:
			return _fail("the array is too long.")
		var item := _read_string(text, position)
		if not bool(item["ok"]):
			return item
		items.append(String(item["value"]))
		position = _skip_spaces(text, int(item["end"]))
		if position < text.length() and text[position] == ",":
			position = _skip_spaces(text, position + 1)
		elif position < text.length() and text[position] != "]":
			return _fail("expected ',' or ']' in the array.")
	return _fail("the array is not closed.")


static func _hex_value(text: String) -> int:
	if text.is_empty() or not text.is_valid_hex_number():
		return -1
	return text.hex_to_int()


# Reads a double quoted string that starts at `start`. Returns the text and the index after it.
static func _read_string(text: String, start: int) -> Dictionary:
	var result := ""
	var position := start + 1
	while position < text.length():
		var character := text[position]
		if character == "\"":
			return {"ok": true, "value": result, "end": position + 1}
		var code := text.unicode_at(position)
		if code < 32 and code != 9:
			return _fail("a control character is not allowed inside a string.")
		if character == "\\":
			position += 1
			if position >= text.length():
				break
			var escape := text[position]
			match escape:
				"\"":
					result += "\""
				"\\":
					result += "\\"
				"n":
					result += "\n"
				"t":
					result += "\t"
				"r":
					result += "\r"
				"u", "U":
					var width := 4 if escape == "u" else 8
					var digits := text.substr(position + 1, width)
					var value := _hex_value(digits)
					if digits.length() != width or value < 0 or value > 0x10FFFF or (value >= 0xD800 and value <= 0xDFFF):
						return _fail("a \\%s escape is not valid." % escape)
					result += char(value)
					position += width
				_:
					return _fail("the escape '\\%s' is not supported." % escape)
		else:
			result += character
		if result.length() > MAX_STRING_LENGTH:
			return _fail("a string is longer than %d characters." % MAX_STRING_LENGTH)
		position += 1
	return _fail("a string is not closed.")