extends CharacterBody2D

signal defeated_state_changed(defeated: bool)

const ENEMY_COLLISION_GROUP := &"enemy_bodies"

@export var gravity_force: float = 1325.0
@export var fall_gravity_scale: float = 1.2
@export var ground_friction: float = 1600.0
@export var hit_stun_horizontal_decel: float = 3800.0
@export var stun_base_duration_sec: float = 0.22
@export var stun_base_knockback_distance_px: float = 7.0
@export var down_duration_sec: float = 1.0
@export var forced_get_up_height_px: float = 4.0
@export var hit_flash_duration: float = 0.12
@export var hit_flash_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var forced_get_up_hint_color: Color = Color(0.35, 1.0, 0.45, 1.0)
@export var damage_popup_rise_speed: float = 26.0
@export var damage_popup_lifetime: float = 0.55
@export var damage_popup_color: Color = Color(1.0, 0.92, 0.65, 1.0)
@export var max_hp: float = 250.0
@export var respawn_delay_sec: float = 6.0
@export var network_snapshot_interval_sec: float = 0.05
@export var network_combat_snapshot_interval_sec: float = 0.016
@export var network_combat_snapshot_boost_duration_sec: float = 0.2
@export var network_interpolation_speed: float = 18.0

enum TopState {
	OPERABLE,
	STUN,
	LAUNCH,
	DOWN,
	GRABBED,
}

enum MovePhase {
	GROUND,
	AIR,
}

const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
const PLATFORM_LAYER := 3

@onready var visuals: Node2D = $Visuals
@onready var body_pivot: Node2D = $Visuals/BodyPivot
@onready var torso: Sprite2D = $Visuals/BodyPivot/Torso
@onready var head_pivot: Node2D = $Visuals/BodyPivot/HeadPivot
@onready var left_leg_pivot: Node2D = $Visuals/BodyPivot/LeftLegPivot
@onready var right_leg_pivot: Node2D = $Visuals/BodyPivot/RightLegPivot
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var ground_check: RayCast2D = $GroundCheck
@onready var overlap_probe: Area2D = $OverlapProbe
@onready var status_label: Label = $StatusLabel
@onready var damage_popups_root: Node2D = $DamagePopups

var _top_state: TopState = TopState.OPERABLE
var _move_phase: MovePhase = MovePhase.GROUND
var _stun_timer := 0.0
var _down_timer := 0.0
var _hit_flash_timer := 0.0
var _launch_has_left_floor := false
var _stun_airborne := false
var _air_stun_freeze_timer := 0.0
var _current_animation := ""
var _last_received_damage_raw := 0.0
var facing: int = 1
var _grabber: Node2D
var _grabbed_slot_offset := Vector2.ZERO
var _spawn_position := Vector2.ZERO
var _current_hp := 0.0
var _is_defeated := false
var _defeated_respawn_timer := 0.0
var _network_snapshot_timer := 0.0
var _network_combat_snapshot_boost_timer := 0.0
var _network_state_ready := false
var _network_received_state: Dictionary = {}
var _network_grabber_path := ""


func _ready() -> void:
	add_to_group(ENEMY_COLLISION_GROUP)
	_spawn_position = global_position
	_current_hp = max_hp
	reset_visual_pose()
	_sync_facing()
	apply_collision_profile()
	update_animation_state()
	_refresh_status_label()


func _physics_process(delta: float) -> void:
	if _is_network_replica():
		_physics_process_network_replica(delta)
		return

	update_hit_flash(delta)
	_update_damage_popups(delta)
	_network_combat_snapshot_boost_timer = maxf(0.0, _network_combat_snapshot_boost_timer - delta)
	if _is_defeated:
		_handle_defeated_state(delta)
		apply_collision_profile()
		update_animation_state()
		_refresh_status_label()
		_broadcast_network_snapshot(delta)
		return

	match _top_state:
		TopState.OPERABLE:
			physics_operable(delta)
		TopState.STUN:
			physics_stun(delta)
		TopState.LAUNCH:
			physics_launch(delta)
		TopState.DOWN:
			physics_down(delta)
		TopState.GRABBED:
			update_grabbed_state()

	apply_collision_profile()
	move_and_slide()
	post_move_update()
	update_animation_state()
	_broadcast_network_snapshot(delta)


func _physics_process_network_replica(delta: float) -> void:
	update_hit_flash(delta)
	_update_damage_popups(delta)
	if not _network_state_ready:
		update_animation_state()
		return

	var target_position := _get_network_state_vector2("position", global_position)
	var follow_weight := clampf(delta * network_interpolation_speed, 0.0, 1.0)
	global_position = global_position.lerp(target_position, follow_weight)
	if global_position.distance_to(target_position) <= 0.5:
		global_position = target_position

	velocity = _get_network_state_vector2("velocity", velocity)
	_top_state = _get_network_state_int("top_state", TopState.OPERABLE)
	_move_phase = _get_network_state_int("move_phase", MovePhase.GROUND)
	_stun_airborne = _get_network_state_bool("stun_airborne", false)
	_launch_has_left_floor = _get_network_state_bool("launch_has_left_floor", false)
	_hit_flash_timer = _get_network_state_float("hit_flash_timer", 0.0)
	_stun_timer = _get_network_state_float("stun_timer", 0.0)
	_down_timer = _get_network_state_float("down_timer", 0.0)
	set_facing(_get_network_state_int("facing", facing))
	_network_grabber_path = _get_network_state_string("grabber_path", "")
	_resolve_network_grabber()
	_current_hp = _get_network_state_float("current_hp", _current_hp)
	_is_defeated = _get_network_state_bool("is_defeated", false)
	_defeated_respawn_timer = _get_network_state_float("defeated_respawn_timer", 0.0)
	apply_collision_profile()
	update_animation_state()
	_refresh_status_label()


func physics_operable(delta: float) -> void:
	if is_on_floor():
		_move_phase = MovePhase.GROUND
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.y = 0.0
	else:
		_move_phase = MovePhase.AIR
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.25 * delta)
		velocity.y += get_effective_gravity() * delta


func physics_stun(delta: float) -> void:
	_stun_timer = maxf(0.0, _stun_timer - delta)
	velocity.x = move_toward(velocity.x, 0.0, get_stun_knockback_decel() * delta)

	if _stun_airborne:
		_move_phase = MovePhase.AIR
		if _air_stun_freeze_timer > 0.0:
			_air_stun_freeze_timer = maxf(0.0, _air_stun_freeze_timer - delta)
			velocity.y = 0.0
		else:
			velocity.y += get_effective_gravity() * delta
	else:
		_move_phase = MovePhase.GROUND
		velocity.y = 0.0

	if _stun_airborne and _stun_timer <= 0.0:
		_stun_timer = 0.0
		return

	if _stun_timer <= 0.0:
		_top_state = TopState.OPERABLE
		_move_phase = MovePhase.GROUND if is_on_floor() else MovePhase.AIR
		velocity.x = 0.0
		_stun_airborne = false
		_air_stun_freeze_timer = 0.0


func physics_launch(delta: float) -> void:
	_move_phase = MovePhase.AIR
	velocity.y += get_effective_gravity() * delta


func physics_down(delta: float) -> void:
	_down_timer = maxf(0.0, _down_timer - delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	if not is_on_floor():
		_move_phase = MovePhase.AIR
		velocity.y += get_effective_gravity() * delta
	else:
		_move_phase = MovePhase.GROUND
		velocity.y = 0.0

	if _down_timer <= 0.0:
		_top_state = TopState.OPERABLE
		_move_phase = MovePhase.GROUND if is_on_floor() else MovePhase.AIR
		resolve_overlap_after_get_up()


func post_move_update() -> void:
	if _top_state == TopState.LAUNCH:
		if not is_on_floor():
			_launch_has_left_floor = true
		elif _launch_has_left_floor and velocity.y > -2.0:
			enter_down()
	elif _top_state == TopState.STUN and _stun_airborne:
		if not is_on_floor():
			_launch_has_left_floor = true
		elif _launch_has_left_floor and velocity.y > -2.0:
			enter_down()


func _is_network_replica() -> bool:
	return multiplayer.has_multiplayer_peer() and not is_multiplayer_authority()


func _broadcast_network_snapshot(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority():
		return

	_network_snapshot_timer = maxf(0.0, _network_snapshot_timer - delta)
	if _network_snapshot_timer > 0.0:
		return

	_network_snapshot_timer = _get_active_network_snapshot_interval()
	receive_authority_snapshot.rpc(_build_network_snapshot())


func _broadcast_network_snapshot_immediately() -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority():
		return

	_network_snapshot_timer = _get_active_network_snapshot_interval()
	receive_authority_snapshot.rpc(_build_network_snapshot())


func _build_network_snapshot() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"top_state": int(_top_state),
		"move_phase": int(_move_phase),
		"facing": facing,
		"stun_airborne": _stun_airborne,
		"launch_has_left_floor": _launch_has_left_floor,
		"hit_flash_timer": _hit_flash_timer,
		"stun_timer": _stun_timer,
		"down_timer": _down_timer,
		"grabber_path": _node_to_path_string(_grabber),
		"current_hp": _current_hp,
		"is_defeated": _is_defeated,
		"defeated_respawn_timer": _defeated_respawn_timer,
	}


func _get_active_network_snapshot_interval() -> float:
	if _should_use_fast_network_snapshot():
		return maxf(network_combat_snapshot_interval_sec, 0.008)
	return maxf(network_snapshot_interval_sec, 0.02)


func _should_use_fast_network_snapshot() -> bool:
	if _network_combat_snapshot_boost_timer > 0.0:
		return true
	if _top_state != TopState.OPERABLE:
		return true
	return absf(velocity.x) > 30.0 or absf(velocity.y) > 45.0


func _boost_network_snapshot_priority(duration_sec: float = -1.0, broadcast_now: bool = false) -> void:
	if duration_sec <= 0.0:
		duration_sec = network_combat_snapshot_boost_duration_sec
	_network_combat_snapshot_boost_timer = maxf(_network_combat_snapshot_boost_timer, duration_sec)
	if broadcast_now:
		_broadcast_network_snapshot_immediately()


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_authority_snapshot(snapshot: Dictionary) -> void:
	if not _is_network_replica():
		return

	_network_received_state = snapshot.duplicate(true)
	_network_state_ready = true
	_network_grabber_path = _get_network_state_string("grabber_path", "")
	_resolve_network_grabber()


func _resolve_network_grabber() -> void:
	if _network_grabber_path.is_empty():
		_grabber = null
		return
	_grabber = get_node_or_null(NodePath(_network_grabber_path)) as Node2D


func _node_to_path_string(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	return str(node.get_path())


func _get_network_state_vector2(key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _network_received_state.get(key, fallback)
	return value if value is Vector2 else fallback


func _get_network_state_float(key: String, fallback: float) -> float:
	return float(_network_received_state.get(key, fallback))


func _get_network_state_int(key: String, fallback: int) -> int:
	return int(_network_received_state.get(key, fallback))


func _get_network_state_bool(key: String, fallback: bool) -> bool:
	return bool(_network_received_state.get(key, fallback))


func _get_network_state_string(key: String, fallback: String) -> String:
	return String(_network_received_state.get(key, fallback))


@rpc("any_peer", "call_remote", "reliable")
func request_receive_weapon_hit(attack_data: Dictionary, source_path: String) -> void:
	if not is_multiplayer_authority():
		return
	var source := get_node_or_null(NodePath(source_path))
	receive_weapon_hit(attack_data, source)


@rpc("any_peer", "call_remote", "reliable")
func request_receive_grabbed_weapon_hit(attack_data: Dictionary) -> void:
	if not is_multiplayer_authority():
		return
	receive_grabbed_weapon_hit(attack_data, null)


@rpc("any_peer", "call_remote", "reliable")
func request_apply_stun_from_source(source_is_on_left: bool, duration_sec: float) -> void:
	if not is_multiplayer_authority():
		return
	apply_stun_from_source(source_is_on_left, duration_sec)


@rpc("any_peer", "call_remote", "reliable")
func request_apply_launch_by_distance_from_source(source_is_on_left: bool, height_px: float, distance_px: float) -> void:
	if not is_multiplayer_authority():
		return
	apply_launch_by_distance_from_source(source_is_on_left, height_px, distance_px)


@rpc("any_peer", "call_remote", "reliable")
func request_enter_grabbed_by(grabber_path: String, slot_offset: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	var grabber := get_node_or_null(NodePath(grabber_path)) as Node2D
	enter_grabbed_by(grabber, slot_offset)


@rpc("any_peer", "call_remote", "reliable")
func request_release_grabbed() -> void:
	if not is_multiplayer_authority():
		return
	release_grabbed()


@rpc("authority", "call_remote", "reliable")
func show_damage_popup_remote(damage_value: float) -> void:
	if not _is_network_replica():
		return
	_show_damage_popup(damage_value)


func receive_weapon_hit(attack_data: Dictionary, source: Node) -> void:
	if _is_network_replica():
		request_receive_weapon_hit.rpc_id(1, attack_data.duplicate(true), _node_to_path_string(source))
		return
	if _top_state == TopState.DOWN or _is_defeated:
		return

	_boost_network_snapshot_priority()
	var source_is_on_left := true
	if source is Node2D:
		source_is_on_left = (source as Node2D).global_position.x < global_position.x

	_last_received_damage_raw = maxf(0.0, float(attack_data.get("damage", 0.0)))
	_show_damage_popup(_last_received_damage_raw)
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		show_damage_popup_remote.rpc(_last_received_damage_raw)
	trigger_hit_flash()
	if _apply_damage_local(_last_received_damage_raw):
		_broadcast_network_snapshot_immediately()
		return

	var hit_effect: String = String(attack_data.get("hit_effect", "stun"))
	match hit_effect:
		"launch":
			apply_launch_by_distance_from_source(
				source_is_on_left,
				float(attack_data.get("launch_height_px", 0.0)),
				float(attack_data.get("launch_distance_px", 0.0))
			)
		_:
			apply_stun_from_source(
				source_is_on_left,
				float(attack_data.get("stun_duration_sec", stun_base_duration_sec))
			)
	_broadcast_network_snapshot_immediately()


func receive_grabbed_weapon_hit(attack_data: Dictionary, _source: Node) -> void:
	if _is_network_replica():
		request_receive_grabbed_weapon_hit.rpc_id(1, attack_data.duplicate(true))
		return
	if _is_defeated:
		return
	_boost_network_snapshot_priority()
	var damage_value := maxf(0.0, float(attack_data.get("damage", 0.0)))
	_show_damage_popup(damage_value)
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		show_damage_popup_remote.rpc(damage_value)
	trigger_hit_flash()
	if _apply_damage_local(damage_value):
		_broadcast_network_snapshot_immediately()
		return
	_broadcast_network_snapshot_immediately()


func apply_stun(duration_sec: float) -> void:
	if _top_state == TopState.DOWN or _is_defeated:
		return

	if _top_state == TopState.LAUNCH and velocity.y > 0.0 and can_forced_get_up():
		var ground_point := ground_check.get_collision_point()
		global_position.y = ground_point.y
		velocity = Vector2.ZERO
		_move_phase = MovePhase.GROUND
		_launch_has_left_floor = false
		enter_stun(duration_sec, false)
		return

	var airborne_stun := not is_on_floor() or _move_phase == MovePhase.AIR or _top_state == TopState.LAUNCH
	enter_stun(duration_sec, airborne_stun)
	_broadcast_network_snapshot_immediately()


func apply_stun_from_source(source_is_on_left: bool, duration_sec: float) -> void:
	if _is_network_replica():
		request_apply_stun_from_source.rpc_id(1, source_is_on_left, duration_sec)
		return
	if _top_state == TopState.DOWN or _is_defeated:
		return

	_boost_network_snapshot_priority()
	velocity.x = get_stun_knockback_speed() if source_is_on_left else -get_stun_knockback_speed()
	apply_stun(duration_sec)


func enter_stun(duration_sec: float, from_launch: bool) -> void:
	_stun_timer = duration_sec
	_stun_airborne = from_launch
	_air_stun_freeze_timer = duration_sec * 0.5 if from_launch else 0.0
	_top_state = TopState.STUN
	_launch_has_left_floor = not is_on_floor()
	if from_launch:
		_move_phase = MovePhase.AIR
	else:
		_move_phase = MovePhase.GROUND
		velocity.y = 0.0


func apply_launch_by_distance_from_source(source_is_on_left: bool, height_px: float, distance_px: float) -> void:
	if _is_network_replica():
		request_apply_launch_by_distance_from_source.rpc_id(1, source_is_on_left, height_px, distance_px)
		return
	if _top_state == TopState.DOWN or _is_defeated:
		return

	_boost_network_snapshot_priority()
	var horizontal_sign := 1 if source_is_on_left else -1
	var launch_height := maxf(0.0, height_px)
	var launch_vy := -sqrt(maxf(0.0, 2.0 * gravity_force * launch_height))
	var travel_time := get_launch_travel_time_for_height(launch_height)
	var launch_vx := 0.0
	if travel_time > 0.0:
		launch_vx = (distance_px / travel_time) * float(horizontal_sign)

	_top_state = TopState.LAUNCH
	_move_phase = MovePhase.AIR
	velocity = Vector2(launch_vx, launch_vy)
	_launch_has_left_floor = false
	_stun_airborne = false
	_air_stun_freeze_timer = 0.0
	_broadcast_network_snapshot_immediately()


func apply_launch_from_source(source_is_on_left: bool, height_coef: float, distance_coef: float) -> void:
	apply_launch_by_distance_from_source(
		source_is_on_left,
		80.0 * height_coef,
		140.0 * distance_coef
	)


func can_forced_get_up() -> bool:
	ground_check.force_raycast_update()
	if not ground_check.is_colliding():
		return false
	return ground_check.get_collision_point().distance_to(ground_check.global_position) <= forced_get_up_height_px


func can_show_forced_get_up_indicator() -> bool:
	return _top_state == TopState.LAUNCH and velocity.y > 0.0 and can_forced_get_up()


func enter_down() -> void:
	if _is_defeated:
		return
	_top_state = TopState.DOWN
	_down_timer = down_duration_sec
	_move_phase = MovePhase.GROUND
	velocity.y = 0.0
	_stun_airborne = false
	_broadcast_network_snapshot_immediately()


func enter_grabbed_by(grabber: Node2D, slot_offset: Vector2 = Vector2.ZERO) -> void:
	if _is_network_replica():
		request_enter_grabbed_by.rpc_id(1, _node_to_path_string(grabber), slot_offset)
		return
	if _is_defeated:
		return
	_boost_network_snapshot_priority()
	_grabber = grabber
	_grabbed_slot_offset = slot_offset
	_top_state = TopState.GRABBED
	_move_phase = MovePhase.GROUND
	velocity = Vector2.ZERO
	_stun_airborne = false
	_air_stun_freeze_timer = 0.0
	_launch_has_left_floor = false
	apply_collision_profile()
	update_animation_state()
	_broadcast_network_snapshot_immediately()


func release_grabbed() -> void:
	if _is_network_replica():
		request_release_grabbed.rpc_id(1)
		return
	if _top_state != TopState.GRABBED and not _is_defeated:
		return

	_boost_network_snapshot_priority()
	_grabber = null
	_grabbed_slot_offset = Vector2.ZERO
	_top_state = TopState.OPERABLE
	_move_phase = MovePhase.GROUND if is_on_floor() else MovePhase.AIR
	apply_collision_profile()
	update_animation_state()
	_broadcast_network_snapshot_immediately()


func update_grabbed_state() -> void:
	if not is_instance_valid(_grabber):
		release_grabbed()
		return

	var grab_facing := 1.0
	var grabber_facing_value: Variant = _grabber.get("facing")
	if grabber_facing_value != null:
		grab_facing = float(grabber_facing_value)
	var resolved_offset := Vector2(_grabbed_slot_offset.x * grab_facing, _grabbed_slot_offset.y)
	global_position = _grabber.global_position + resolved_offset
	velocity = Vector2.ZERO
	set_facing(int(grab_facing))


func resolve_overlap_after_get_up() -> void:
	for body in overlap_probe.get_overlapping_bodies():
		if body == self:
			continue
		if body is CharacterBody2D:
			var push_dir := -1.0 if body.global_position.x < global_position.x else 1.0
			body.global_position.x += push_dir * 6.0


func apply_collision_profile() -> void:
	if _is_defeated:
		collision_layer = 0
		collision_mask = layer_bit(WORLD_LAYER) | layer_bit(PLATFORM_LAYER)
		return
	if _top_state == TopState.DOWN or _top_state == TopState.GRABBED:
		collision_layer = 0
		collision_mask = layer_bit(WORLD_LAYER) | layer_bit(PLATFORM_LAYER)
		return

	if _top_state == TopState.LAUNCH:
		collision_layer = layer_bit(CHARACTER_LAYER)
		collision_mask = layer_bit(WORLD_LAYER) | layer_bit(PLATFORM_LAYER) | layer_bit(CHARACTER_LAYER)
		return

	collision_layer = layer_bit(CHARACTER_LAYER)
	collision_mask = layer_bit(WORLD_LAYER) | layer_bit(PLATFORM_LAYER) | layer_bit(CHARACTER_LAYER)


func layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)


func reset_visual_pose() -> void:
	if body_pivot == null:
		return

	body_pivot.position = Vector2.ZERO
	body_pivot.rotation_degrees = 0.0
	torso.position = Vector2(0, -17)
	torso.rotation_degrees = 0.0
	head_pivot.position = Vector2(0, -24)
	head_pivot.rotation_degrees = 0.0
	left_leg_pivot.position = Vector2(-3, -10)
	left_leg_pivot.rotation_degrees = 0.0
	right_leg_pivot.position = Vector2(3, -10)
	right_leg_pivot.rotation_degrees = 0.0
	visuals.modulate = Color(1, 1, 1, 1)


func set_facing(direction: int) -> void:
	if direction == 0:
		return
	facing = 1 if direction > 0 else -1
	_sync_facing()


func _sync_facing() -> void:
	if visuals == null:
		return
	visuals.scale.x = absf(visuals.scale.x) * float(facing)


func update_animation_state() -> void:
	if animation_player == null:
		return

	var target := "idle"
	if _is_defeated:
		target = "down"
	elif _top_state == TopState.STUN:
		target = "air_stun" if _stun_airborne else "stun"
	elif _top_state == TopState.LAUNCH:
		target = "launch"
	elif _top_state == TopState.DOWN:
		target = "down"
	elif _top_state == TopState.GRABBED:
		target = "stun"
	else:
		target = "idle"

	if target != _current_animation:
		if target == "idle":
			reset_visual_pose()
		_current_animation = target
		animation_player.play(target)


func update_hit_flash(delta: float) -> void:
	if visuals == null:
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		var t := 0.0
		if hit_flash_duration > 0.0:
			t = _hit_flash_timer / hit_flash_duration
		visuals.modulate = Color(1, 1, 1, 1).lerp(hit_flash_color, t)
	else:
		visuals.modulate = Color(1, 1, 1, 1)


func trigger_hit_flash() -> void:
	_hit_flash_timer = hit_flash_duration


func get_stun_knockback_speed() -> float:
	if stun_base_duration_sec <= 0.0:
		return 0.0
	return (2.0 * stun_base_knockback_distance_px) / stun_base_duration_sec


func get_stun_knockback_decel() -> float:
	if stun_base_duration_sec <= 0.0:
		return hit_stun_horizontal_decel
	return get_stun_knockback_speed() / stun_base_duration_sec


func get_effective_gravity() -> float:
	return gravity_force if velocity.y < 0.0 else gravity_force * fall_gravity_scale


func get_launch_travel_time_for_height(height_px: float) -> float:
	if height_px <= 0.0:
		return 0.0

	var rise_time := sqrt((2.0 * height_px) / gravity_force)
	var fall_time := sqrt((2.0 * height_px) / (gravity_force * fall_gravity_scale))
	return rise_time + fall_time


func is_defeated() -> bool:
	return _is_defeated


func is_dead() -> bool:
	return _is_defeated


func get_current_hp() -> float:
	return _current_hp


func get_max_hp() -> float:
	return max_hp


func _apply_damage_local(raw_damage: float) -> bool:
	if _is_defeated:
		return false
	_current_hp = clampf(_current_hp - maxf(0.0, raw_damage), 0.0, max_hp)
	_refresh_status_label()
	if _current_hp > 0.0:
		return false
	_enter_defeated_state_local()
	return true


func _enter_defeated_state_local() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	_defeated_respawn_timer = maxf(0.0, respawn_delay_sec)
	_top_state = TopState.DOWN
	_move_phase = MovePhase.GROUND
	_stun_timer = 0.0
	_down_timer = 0.0
	_stun_airborne = false
	_air_stun_freeze_timer = 0.0
	_launch_has_left_floor = false
	_grabber = null
	_grabbed_slot_offset = Vector2.ZERO
	velocity = Vector2.ZERO
	_refresh_status_label()
	defeated_state_changed.emit(true)


func _handle_defeated_state(delta: float) -> void:
	velocity = Vector2.ZERO
	_defeated_respawn_timer = maxf(0.0, _defeated_respawn_timer - delta)
	if _defeated_respawn_timer <= 0.0:
		_respawn_dummy_local()


func _respawn_dummy_local() -> void:
	_is_defeated = false
	_defeated_respawn_timer = 0.0
	_current_hp = max_hp
	_top_state = TopState.OPERABLE
	_move_phase = MovePhase.GROUND
	_stun_timer = 0.0
	_down_timer = 0.0
	_stun_airborne = false
	_air_stun_freeze_timer = 0.0
	_launch_has_left_floor = false
	_grabber = null
	_grabbed_slot_offset = Vector2.ZERO
	global_position = _spawn_position
	velocity = Vector2.ZERO
	trigger_hit_flash()
	_refresh_status_label()
	defeated_state_changed.emit(false)
	_broadcast_network_snapshot_immediately()


func _refresh_status_label() -> void:
	if status_label == null:
		return
	if _is_defeated:
		status_label.visible = true
		status_label.text = "DEFEATED"
		return
	status_label.visible = true
	status_label.text = "HP %.0f / %.0f" % [_current_hp, max_hp]


func _show_damage_popup(damage_value: float) -> void:
	if damage_popups_root == null or damage_value <= 0.0:
		return

	var popup := Label.new()
	popup.text = str(snappedf(damage_value, 0.1))
	popup.position = Vector2(-14.0, -52.0)
	popup.modulate = damage_popup_color
	popup.z_index = 10
	damage_popups_root.add_child(popup)
	popup.set_meta("lifetime_left", damage_popup_lifetime)


func _update_damage_popups(delta: float) -> void:
	if damage_popups_root == null:
		return

	for child in damage_popups_root.get_children():
		if child is not Label:
			continue

		var popup := child as Label
		var lifetime_left := float(popup.get_meta("lifetime_left", damage_popup_lifetime))
		lifetime_left = maxf(0.0, lifetime_left - delta)
		popup.set_meta("lifetime_left", lifetime_left)
		popup.position.y -= damage_popup_rise_speed * delta

		var alpha := 0.0
		if damage_popup_lifetime > 0.0:
			alpha = lifetime_left / damage_popup_lifetime
		var color := damage_popup_color
		color.a *= alpha
		popup.modulate = color

		if lifetime_left <= 0.0:
			popup.queue_free()
