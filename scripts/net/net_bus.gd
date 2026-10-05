class_name NetBus
extends RefCounted

static var headless: bool = DisplayServer.get_name() == "headless"
static var blast_hook: Callable = Callable()
static var beam_hook: Callable = Callable()


static func emit_blast(context: Node, center: Vector3, radius: float, color: Color) -> void:
	if blast_hook.is_valid():
		blast_hook.call(context, center, radius, color)


static func emit_beam(context: Node, from: Vector3, to: Vector3, color: Color) -> void:
	if beam_hook.is_valid():
		beam_hook.call(context, from, to, color)