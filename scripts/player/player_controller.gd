class_name PlayerController
extends CharacterBody3D

signal ragdoll_started
signal ragdoll_ended
signal damage_changed(percent: float)

enum State { NORMAL, RAGDOLL }

const WALK_SPEED := 5.5
const GROUND_ACCEL := 40.0
const AIR_ACCEL := 10.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 20.0
const DASH_SPEED := 15.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 1.0
const RAGDOLL_THRESHOLD := 9.0
const RAGDOLL_MIN_TIME := 1.0
const RAGDOLL_MAX_TIME := 6.0
const KILL_Y := -25.0
const TURN_SPEED := 14.0

var state: State = State.NORMAL
var controllable: bool = true
var spawn_point: Vector3 = Vector3.ZERO
var model: CharacterModel
var weapons: WeaponController
var damage_percent: float = 0.0
var guard_remaining: float = 0.0

var _shape_node: CollisionShape3D
var _ragdoll: Ragdoll
var _ragdoll_time: float = 0.0
var _dash_time: float = 0.0
var _dash_cooldown: float = 0.0
var _hitstun: float = 0.0


func _ready() -> void:
	collision_layer = Ragdoll.LAYER_PLAYER
	collision_mask = Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROPS
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = capsule
	_shape_node.position = Vector3(0.0, 0.85, 0.0)
	add_child(_shape_node)
	model = CharacterModel.new()
	add_child(model)
	weapons = WeaponController.new()
	weapons.owner_body = self
	add_child(weapons)
	PlayerData.equipment_changed.connect(_on_equipment_changed)


func _on_equipment_changed(_slot: String) -> void:
	model.apply_equipped()


func aim_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -model.global_transform.basis.z
	return -camera.global_transform.basis.z


func face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		return
	flat = flat.normalized()
	model.rotation.y = atan2(-flat.x, -flat.z)


func apply_hit(hit: Dictionary) -> void:
	if state != State.NORMAL:
		return
	var guarding := guard_remaining > 0.0
	var impulse := CombatResolver.victim_impulse(hit, damage_percent, guarding)
	damage_percent += CombatResolver.victim_damage(hit, guarding)
	damage_changed.emit(damage_percent)
	apply_knockback(impulse)


func apply_knockback(impulse: Vector3) -> void:
	if state != State.NORMAL:
		return
	var total := velocity + impulse
	_dash_time = 0.0
	if impulse.length() >= RAGDOLL_THRESHOLD:
		_enter_ragdoll(total)
	else:
		velocity = total
		_hitstun = clampf(impulse.length() * 0.06, 0.15, 0.6)


func launch(boost: Vector3) -> void:
	if state != State.NORMAL:
		return
	velocity = Vector3(velocity.x + boost.x, boost.y, velocity.z + boost.z)


func respawn() -> void:
	_dispose_ragdoll()
	_set_state(State.NORMAL)
	global_position = spawn_point
	velocity = Vector3.ZERO
	_dash_time = 0.0
	_hitstun = 0.0
	guard_remaining = 0.0
	damage_percent = 0.0
	damage_changed.emit(0.0)


func _physics_process(delta: float) -> void:
	if state == State.RAGDOLL:
		_process_ragdoll(delta)
		return
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	guard_remaining = maxf(guard_remaining - delta, 0.0)
	_hitstun = maxf(_hitstun - delta, 0.0)
	var input := Vector2.ZERO
	if controllable:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative(input)
	if input.length() > 0.1 and model.is_emoting():
		model.stop_emote()
	if controllable and Input.is_action_just_pressed("emote"):
		_play_equipped_emote()
	if controllable and Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and _hitstun <= 0.0:
		_start_dash(direction)
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity.y = 0.0
	else:
		_apply_movement(direction, delta)
	move_and_slide()
	_update_facing(direction, delta)
	model.animate(Vector2(velocity.x, velocity.z).length(), is_on_floor(), delta)
	if global_position.y < KILL_Y:
		respawn()


func _apply_movement(direction: Vector3, delta: float) -> void:
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var target := direction * WALK_SPEED
	if _hitstun > 0.0:
		var drag := 8.0 if is_on_floor() else 2.0
		velocity.x = move_toward(velocity.x, 0.0, drag * delta)
		velocity.z = move_toward(velocity.z, 0.0, drag * delta)
	else:
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if is_on_floor() and velocity.y <= 0.0:
		if controllable and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


func _start_dash(direction: Vector3) -> void:
	var dash_direction := direction
	if dash_direction.length() < 0.1:
		dash_direction = model.global_transform.basis.z * -1.0
		dash_direction.y = 0.0
	dash_direction = dash_direction.normalized()
	velocity.x = dash_direction.x * DASH_SPEED
	velocity.z = dash_direction.z * DASH_SPEED
	_dash_time = DASH_DURATION
	_dash_cooldown = DASH_COOLDOWN


func _update_facing(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.1 or model.is_emoting():
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _camera_relative(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var yaw := camera.global_rotation.y if camera != null else 0.0
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)


func _play_equipped_emote() -> void:
	var emote_id := "wave"
	if PlayerData.is_signed_in:
		emote_id = String(PlayerData.data["equipped"].get("emote", ""))
	if not emote_id.is_empty():
		model.play_emote(emote_id)


func _enter_ragdoll(total_velocity: Vector3) -> void:
	_set_state(State.RAGDOLL)
	_ragdoll = Ragdoll.spawn(get_parent(), model, total_velocity, model.skin_color, model.accent_color)
	_ragdoll_time = 0.0
	velocity = Vector3.ZERO


func _process_ragdoll(delta: float) -> void:
	if not is_instance_valid(_ragdoll):
		respawn()
		return
	_ragdoll_time += delta
	var torso := _ragdoll.torso_position()
	global_position = torso - Vector3(0.0, CharacterModel.TORSO_Y, 0.0)
	if torso.y < KILL_Y:
		respawn()
		return
	if _ragdoll_time >= RAGDOLL_MAX_TIME or (_ragdoll_time >= RAGDOLL_MIN_TIME and _ragdoll.is_settled()):
		_dispose_ragdoll()
		global_position = torso
		velocity = Vector3.ZERO
		_set_state(State.NORMAL)


func _dispose_ragdoll() -> void:
	if is_instance_valid(_ragdoll):
		_ragdoll.queue_free()
	_ragdoll = null


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	if state == State.RAGDOLL:
		model.stop_emote()
		model.visible = false
		_shape_node.set_deferred("disabled", true)
		ragdoll_started.emit()
	else:
		model.visible = true
		_shape_node.set_deferred("disabled", false)
		ragdoll_ended.emit()