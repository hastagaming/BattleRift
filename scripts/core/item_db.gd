class_name ItemDb
extends RefCounted

const CATEGORY_ORDER: Array[String] = ["character", "skin", "accessory", "weapon", "effect", "pet", "emote"]
const CATEGORY_LABELS := {
	"character": "Characters",
	"skin": "Skins",
	"accessory": "Accessories",
	"weapon": "Weapons",
	"effect": "Effects",
	"pet": "Pets",
	"emote": "Emotes",
}
const SLOT_ORDER: Array[String] = ["character", "skin", "head", "face", "body", "back", "weapon", "effect", "pet", "emote"]
const SLOT_LABELS := {
	"character": "Character",
	"skin": "Skin",
	"head": "Head",
	"face": "Face",
	"body": "Body",
	"back": "Back",
	"weapon": "Weapon",
	"effect": "Effect",
	"pet": "Pet",
	"emote": "Emote",
}
const FALLBACK_COLOR := Color("#8b94ad")

const ITEMS := {
	"rifter": {"category": "character", "name": "Rifter", "desc": "The default Rift runner.", "color": Color("#38e8c6")},
	"vanguard": {"category": "character", "name": "Vanguard", "desc": "Red-armored front liner.", "color": Color("#ff5a5f")},
	"default": {"category": "skin", "name": "Classic", "desc": "Standard skin tone.", "color": Color("#d9a273")},
	"frost": {"category": "skin", "name": "Frost", "desc": "Icy blue skin.", "color": Color("#8fd3ff")},
	"ember": {"category": "skin", "name": "Ember", "desc": "Glowing orange skin.", "color": Color("#ff7a4d")},
	"shadow": {"category": "skin", "name": "Shadow", "desc": "Dim violet skin.", "color": Color("#5b5472")},
	"crown": {"category": "accessory", "slot": "head", "name": "Gold Crown", "desc": "Head accessory for the Rift champion.", "color": Color("#ffc857")},
	"visor": {"category": "accessory", "slot": "face", "name": "Neon Visor", "desc": "Face accessory with a glowing strip.", "color": Color("#38e8c6")},
	"scarf": {"category": "accessory", "slot": "body", "name": "Red Scarf", "desc": "Body accessory, warm and loud.", "color": Color("#ff5a5f")},
	"cape": {"category": "accessory", "slot": "back", "name": "Rift Cape", "desc": "Back accessory that follows you.", "color": Color("#7a5cff")},
	"wave": {"category": "emote", "name": "Wave", "desc": "A friendly wave.", "color": Color("#9fe8ff")},
	"spin": {"category": "emote", "name": "Spin", "desc": "A full victory spin.", "color": Color("#c9f27a")},
	"cheer": {"category": "emote", "name": "Cheer", "desc": "Both arms up.", "color": Color("#ffc857")},
}

const LOCAL_PRICES := {
	"frost": ["cr", 500],
	"ember": ["cr", 500],
	"shadow": ["br", 120],
	"vanguard": ["cr", 1500],
	"spin": ["cr", 300],
	"cheer": ["cr", 300],
	"hammer": ["cr", 800],
	"spear": ["cr", 800],
	"shield": ["cr", 1000],
	"bow": ["cr", 1200],
	"blaster": ["cr", 1500],
	"rocket_launcher": ["cr", 3000],
	"laser": ["cr", 2500],
	"crown": ["cr", 800],
	"visor": ["cr", 400],
	"scarf": ["cr", 300],
	"cape": ["br", 150],
}


static func info(item_id: String) -> Dictionary:
	if ITEMS.has(item_id):
		return ITEMS[item_id]
	if WeaponDb.has(item_id):
		var weapon := WeaponDb.get_weapon(item_id)
		return {
			"category": "weapon",
			"name": String(weapon["name"]),
			"desc": "%s  |  DMG %.1f  KB %.1f" % [String(weapon["kind"]).capitalize(), float(weapon["damage"]), float(weapon["knockback"])],
			"color": weapon["color"],
		}
	return {}


static func display_name(item_id: String) -> String:
	var data := info(item_id)
	if data.is_empty():
		return item_id.capitalize()
	return String(data["name"])


static func color_of(item_id: String) -> Color:
	var data := info(item_id)
	return data.get("color", FALLBACK_COLOR)


static func slot_of(category: String, item_id: String) -> String:
	if category == "accessory":
		return String(info(item_id).get("slot", ""))
	return category


static func local_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in LOCAL_PRICES:
		var price: Array = LOCAL_PRICES[item_id]
		result.append({
			"id": String(item_id),
			"category": String(info(String(item_id)).get("category", "")),
			"currency": String(price[0]),
			"price": int(price[1]),
		})
	return result