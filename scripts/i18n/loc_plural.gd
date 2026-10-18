class_name LocPlural
extends RefCounted

# Plural categories by rule, following the CLDR categories. A language pack picks one rule by name.

const RULES: Array[String] = ["none", "one_other", "one_other_zero_one", "east_slavic", "polish", "czech", "arabic"]
const CATEGORIES: Array[String] = ["zero", "one", "two", "few", "many", "other"]


static func has_rule(rule: String) -> bool:
	return rule in RULES


# The categories a rule can produce. A pack must supply every one of them.
static func categories_for(rule: String) -> Array[String]:
	match rule:
		"none":
			return ["other"]
		"one_other", "one_other_zero_one":
			return ["one", "other"]
		"east_slavic", "polish":
			return ["one", "few", "many", "other"]
		"czech":
			return ["one", "few", "many", "other"]
		"arabic":
			return ["zero", "one", "two", "few", "many", "other"]
	return ["other"]


static func category(rule: String, count: float) -> String:
	var is_whole := is_equal_approx(count, roundf(count))
	var whole := int(absf(roundf(count)))
	var last := whole % 10
	var last_two := whole % 100
	match rule:
		"one_other":
			return "one" if is_whole and whole == 1 else "other"
		"one_other_zero_one":
			return "one" if absf(count) >= 0.0 and absf(count) < 2.0 else "other"
		"east_slavic":
			if not is_whole:
				return "other"
			if last == 1 and last_two != 11:
				return "one"
			if last >= 2 and last <= 4 and (last_two < 12 or last_two > 14):
				return "few"
			return "many"
		"polish":
			if not is_whole:
				return "other"
			if whole == 1:
				return "one"
			if last >= 2 and last <= 4 and (last_two < 12 or last_two > 14):
				return "few"
			return "many"
		"czech":
			if not is_whole:
				return "many"
			if whole == 1:
				return "one"
			if whole >= 2 and whole <= 4:
				return "few"
			return "other"
		"arabic":
			if not is_whole:
				return "other"
			if whole == 0:
				return "zero"
			if whole == 1:
				return "one"
			if whole == 2:
				return "two"
			if last_two >= 3 and last_two <= 10:
				return "few"
			if last_two >= 11:
				return "many"
			return "other"
	return "other"