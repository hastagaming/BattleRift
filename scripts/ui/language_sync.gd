class_name LanguageSync
extends RefCounted

# Keeps the language the same on every device. The account stores it as the "language" setting.


# Call after sign-in or after a saved session is restored.
static func apply_account() -> void:
	var saved := String(PlayerData.get_setting("language", ""))
	if not saved.is_empty() and Loc.adopt_account_language(saved):
		return
	if saved.is_empty() or not Loc.has_language(saved):
		PlayerData.set_setting("language", Loc.current())


# Call after the player picks a language while signed in.
static func push_to_account() -> void:
	if PlayerData.is_signed_in:
		PlayerData.set_setting("language", Loc.current())