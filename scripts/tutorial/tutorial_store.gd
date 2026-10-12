class_name TutorialStore
extends RefCounted

# Reads and writes tutorial progress through PlayerData. The progress lives in the player's
# server-side settings, so it follows the account across devices. Local developer accounts keep
# it in their save file.

# Set when the player finishes the arena steps, so the guide cards continue without a resume card.
static var from_arena: bool = false


static func landing_scene() -> String:
	if PlayerData.is_signed_in and TutorialProgress.needs_tutorial(PlayerData.data):
		return Router.TUTORIAL
	return Router.LOBBY


static func _write(new_status: String, step: int) -> void:
	PlayerData.set_setting(TutorialProgress.KEY, {"v": TutorialProgress.VERSION, "status": new_status, "step": TutorialFlow.clamp_index(step)})


static func save_step(step: int) -> void:
	_write(TutorialProgress.STATUS_ACTIVE, step)


static func restart() -> void:
	_write(TutorialProgress.STATUS_ACTIVE, 0)


static func complete() -> void:
	_write(TutorialProgress.STATUS_DONE, TutorialFlow.count() - 1)
	await PlayerData.flush_settings_now()


static func skip() -> void:
	_write(TutorialProgress.STATUS_SKIPPED, 0)
	await PlayerData.flush_settings_now()