extends CharacterBody2D

enum TopState {
	OPERABLE,
	STUN,
	LAUNCH,
	DOWN,
	GET_UP,
	GRABBED,
	DEAD,
}

enum BehaviorState {
	IDLE,
	REPOSITION,
	ATTACK_PAUSE,
	ATTACKING,
	RECOVERY,
}

const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
const PLATFORM_LAYER := 3
const ENEMY_COLLISION_GROUP := &"enemy_bodies"
const ATTACK_FIRE_FRAME := 4

@export var facing: int = 1
@export var gravity_force: float = 1325.0
@export var fall_gravity_scale: float = 1.2
@export_group("Combat Stats")
@export var max_hp: float = 24.0
@export var base_damage: float = 8.0
@export var attack_interval_sec: float = 0.42
@export_group("")
@export var move_speed: float = 30.0
@export var hit_stun_horizontal_decel: float = 2800.0
@export var stun_base_duration_sec: float = 0.18
@export var stun_base_knockback_distance_px: float = 10.0
@export var launch_base_height_px: float = 66.0
@export var down_duration_sec: float = 0.82
@export var hit_flash_duration: float = 0.10
@export var hit_flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export var damage_popup_rise_speed: float = 24.0
@export var damage_popup_lifetime: float = 0.55
@export var damage_popup_color: Color = Color(1.0, 0.88, 0.62, 1.0)

@export_group("Behavior")
@export var target_path: NodePath
@export var detection_range: float = 224.0
@export var detection_vertical_tolerance: float = 92.0
@export var disengage_range: float = 256.0
@export var attack_range_min: float = 80.0
@export var attack_range_max: float = 180.0
@export var attack_vertical_tolerance: float = 108.0
@export var retreat_range: float = 56.0
@export var attack_pause_duration_sec: float = 0.18
@export var move_accel: float = 240.0

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_hit_effect: String = "stun"
@export var projectile_stun_duration_sec: float = 0.22
@export var projectile_launch_height_px: float = 44.0
@export var projectile_launch_distance_px: float = 18.0
@export var projectile_speed: float = 250.0
@export var projectile_lifetime_sec: float = 1.2
@export var aim_height_offset: float = -18.0
@export var muzzle_offset: Vector2 = Vector2(18.0, -15.0)
@export var fall_death_y: float = 100000.0
@export var ledge_avoidance_enabled: bool = true
@export var ledge_probe_forward_distance: float = 18.0
@export var ledge_probe_down_distance: float = 40.0
@export_group("Networking")
@export var network_snapshot_interval_sec: float = 0.05
@export var network_combat_snapshot_interval_sec: float = 0.016
@export var network_combat_snapshot_boost_duration_sec: float = 0.2
@export var network_interpolation_speed: float = 18.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var projectile_spawn: Node2D = $ProjectileSpawn
@onready var status_bars: EnemyStatusBars = $StatusBars
@onready var damage_popups_root: Node2D = $DamagePopups

var _top_state: TopState = TopState.OPERABLE
var _current_animation: StringName = &""
var _current_hp: float = 0.0
var _hit_flash_timer := 0.0
var _stun_timer := 0.0
var _down_timer := 0.0
var _attack_in_progress := false
var _attack_projectile_fired := false
var _grabber: Node2D
var _grabbed_slot_offset := Vector2.ZERO
var _last_received_damage := 0.0
var _behavior_state: BehaviorState = BehaviorState.IDLE
var _behavior_timer := 0.0
var _target: Node2D
var _attack_locked_target_position := Vector2.ZERO
var _registered_collision_exception_ids: Dictionary = {}
var _ledge_probe: RayCast2D
var _network_snapshot_timer := 0.0
var _network_combat_snapshot_boost_timer := 0.0
var _network_state_ready := false
var _network_received_state: Dictionary = {}
var _network_grabber_path := ""


func _ready() -> void:
	add_to_group(ENEMY_COLLISION_GROUP)
	_current_hp = max_hp
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	_setup_ledge_probe()
	_refresh_target()
	_sync_nonblocking_collisions()
	_sync_facing()
	_apply_collision_profile()
	update_status_bars()
	_update_animation_state()


func _physics_process(delta: float) -> void:
	if _is_network_replica():
		_physics_process_network_replica(delta)
		return

	_update_hit_flash(delta)
	_update_damage_popups(delta)
	_network_combat_snapshot_boost_timer = maxf(0.0, _network_combat_snapshot_boost_timer - delta)
	_refresh_target()
	_sync_nonblocking_collisions()
	if _top_state != TopState.DEAD and global_position.y >= fall_death_y:
		die()
		return

	if _top_state == TopState.DEAD:
		velocity = Vector2.ZERO
		_broadcast_network_snapshot(delta)
		return

	if _top_state == TopState.GRABBED:
		_update_grabbed_state()
		_broadcast_network_snapshot(delta)
		return

	match _top_state:
		TopState.OPERABLE:
			_physics_operable(delta)
		TopState.STUN:
			_physics_stun(delta)
		TopState.LAUNCH:
			_physics_launch(delta)
		TopState.DOWN:
			_physics_down(delta)
		TopState.GET_UP:
			_physics_get_up(delta)

	move_and_slide()
	_post_move_update()
	_apply_collision_profile()
	_update_animation_state()
	_broadcast_network_snapshot(delta)


func set_facing(direction: int) -> void:
	if direction == 0:
		return
	facing = 1 if direction > 0 else -1
	_sync_facing()
	_update_ledge_probe(facing)


func play_attack() -> bool:
	if _top_state != TopState.OPERABLE:
		return false
	if _attack_in_progress:
		return false

	_lock_attack_target()
	_attack_in_progress = true
	_attack_projectile_fired = false
	_set_behavior_state(BehaviorState.ATTACKING)
	animated_sprite.play(&"attack")
	_current_animation = &"attack"
	return true


func receive_weapon_hit(attack_data: Dictionary, source: Node) -> void:
	if _is_network_replica():
		request_receive_weapon_hit.rpc_id(1, attack_data.duplicate(true), _node_to_path_string(source))
		return
	if _top_state == TopState.DEAD:
		return

	_boost_network_snapshot_priority()
	var raw_damage: float = attack_data.get("damage", 0.0)
	_last_received_damage = maxf(0.0, raw_damage)
	apply_damage(_last_received_damage)
	if _top_state == TopState.DEAD:
		_broadcast_network_snapshot_immediately()
		return

	var source_is_on_left := true
	if source is Node2D:
		source_is_on_left = (source as Node2D).global_position.x < global_position.x

	var hit_effect: String = attack_data.get("hit_effect", "stun")
	match hit_effect:
		"launch":
			apply_launch_by_distance_from_source(
				source_is_on_left,
				attack_data.get("launch_height_px", launch_base_height_px),
				attack_data.get("launch_distance_px", 0.0)
			)
		_:
			apply_stun_from_source(
				source_is_on_left,
				attack_data.get("stun_duration_sec", stun_base_duration_sec)
			)
	_broadcast_network_snapshot_immediately()


func receive_grabbed_weapon_hit(attack_data: Dictionary, _source: Node) -> void:
	if _is_network_replica():
		request_receive_grabbed_weapon_hit.rpc_id(1, attack_data.duplicate(true))
		return
	if _top_state == TopState.DEAD:
		return

	_boost_network_snapshot_priority()
	var raw_damage: float = attack_data.get("damage", 0.0)
	_last_received_damage = maxf(0.0, raw_damage)
	apply_damage(_last_received_damage)
	trigger_hit_flash()
	_broadcast_network_snapshot_immediately()


func apply_damage(raw_damage: float) -> void:
	var final_damage := maxf(0.0, raw_damage)
	if final_damage <= 0.0:
		return

	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		show_damage_popup_remote.rpc(final_damage)
	trigger_hit_flash()
	_show_damage_popup(final_damage)
	_current_hp = clampf(_current_hp - final_damage, 0.0, max_hp)
	update_status_bars()
	if _current_hp <= 0.0:
		die()


func apply_stun_from_source(source_is_on_left: bool, duration_sec: float) -> void:
	if _top_state == TopState.DEAD:
		return

	set_facing(1 if source_is_on_left else -1)
	trigger_hit_flash()
	var knockback_speed := get_stun_knockback_speed()
	velocity.x = knockback_speed if source_is_on_left else -knockback_speed
	_interrupt_attack()
	_cancel_behavior()
	_top_state = TopState.STUN
	_stun_timer = maxf(0.0, duration_sec)
	if is_on_floor():
		velocity.y = 0.0
	animated_sprite.play(&"hit")


func apply_launch_by_distance_from_source(source_is_on_left: bool, height_px: float, distance_px: float) -> void:
	if _top_state == TopState.DEAD:
		return

	var horizontal_sign := 1 if source_is_on_left else -1
	var launch_height := maxf(0.0, height_px)
	var launch_vy := -sqrt(maxf(0.0, 2.0 * gravity_force * launch_height))
	var travel_time := get_launch_travel_time_for_height(launch_height)
	var launch_vx := 0.0
	if travel_time > 0.0:
		launch_vx = (distance_px / travel_time) * float(horizontal_sign)

	set_facing(horizontal_sign)
	trigger_hit_flash()
	_interrupt_attack()
	_cancel_behavior()
	_top_state = TopState.LAUNCH
	_stun_timer = 0.0
	velocity = Vector2(launch_vx, launch_vy)
	animated_sprite.play(&"launch")


func enter_grabbed_by(grabber: Node2D, slot_offset: Vector2 = Vector2.ZERO) -> void:
	if _top_state == TopState.DEAD:
		return

	_interrupt_attack()
	_cancel_behavior()
	_grabber = grabber
	_grabbed_slot_offset = slot_offset
	_top_state = TopState.GRABBED
	velocity = Vector2.ZERO
	_apply_collision_profile()
	animated_sprite.play(&"grabbed")


func release_grabbed() -> void:
	if _top_state != TopState.GRABBED:
		return

	_grabber = null
	_grabbed_slot_offset = Vector2.ZERO
	_top_state = TopState.OPERABLE
	_cancel_behavior()
	_apply_collision_profile()
	_update_animation_state()


func trigger_hit_flash() -> void:
	_hit_flash_timer = hit_flash_duration


func is_dead() -> bool:
	return _top_state == TopState.DEAD


func is_attack_disabled() -> bool:
	return _top_state == TopState.DEAD or _top_state == TopState.DOWN or _top_state == TopState.GRABBED


func set_fall_death_y(value: float) -> void:
	fall_death_y = value


func get_current_hp() -> float:
	return _current_hp


func update_status_bars() -> void:
	if status_bars == null:
		return
	status_bars.set_bar_visible(_top_state != TopState.DEAD)
	status_bars.set_hp(_current_hp, max_hp)


func _physics_operable(delta: float) -> void:
	_update_behavior(delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += _get_effective_gravity() * delta


func _physics_stun(delta: float) -> void:
	_stun_timer = maxf(0.0, _stun_timer - delta)
	velocity.x = move_toward(velocity.x, 0.0, hit_stun_horizontal_decel * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += _get_effective_gravity() * delta

	if _stun_timer <= 0.0 and is_on_floor():
		_top_state = TopState.OPERABLE
		_cancel_behavior()


func _physics_launch(delta: float) -> void:
	velocity.y += _get_effective_gravity() * delta


func _physics_down(delta: float) -> void:
	_down_timer = maxf(0.0, _down_timer - delta)
	velocity.x = move_toward(velocity.x, 0.0, hit_stun_horizontal_decel * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += _get_effective_gravity() * delta

	if _down_timer <= 0.0 and is_on_floor():
		_top_state = TopState.GET_UP
		animated_sprite.play(&"get_up")


func _physics_get_up(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, hit_stun_horizontal_decel * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += _get_effective_gravity() * delta


func _post_move_update() -> void:
	if _top_state == TopState.LAUNCH and is_on_floor() and velocity.y >= 0.0:
		enter_down()


func enter_down() -> void:
	_interrupt_attack()
	_cancel_behavior()
	_top_state = TopState.DOWN
	_down_timer = down_duration_sec
	velocity = Vector2.ZERO
	animated_sprite.play(&"down")


func die() -> void:
	if _top_state == TopState.DEAD:
		return

	_interrupt_attack()
	_cancel_behavior()
	_top_state = TopState.DEAD
	velocity = Vector2.ZERO
	_apply_collision_profile()
	update_status_bars()
	animated_sprite.play(&"death")
	_broadcast_network_snapshot_immediately()


func _interrupt_attack() -> void:
	_attack_in_progress = false
	_attack_projectile_fired = false
	_attack_locked_target_position = global_position


func _cancel_behavior() -> void:
	_set_behavior_state(BehaviorState.IDLE)
	_behavior_timer = 0.0


func _update_behavior(delta: float) -> void:
	if _attack_in_progress:
		velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
		return

	if not _has_valid_target():
		_set_behavior_state(BehaviorState.IDLE)
		velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
		return

	var to_target := _target.global_position - global_position
	var horizontal_distance := absf(to_target.x)
	var vertical_distance := absf(to_target.y)
	if horizontal_distance > 1.0:
		set_facing(1 if to_target.x > 0.0 else -1)

	var target_detected := _is_target_in_detection(horizontal_distance, vertical_distance)
	var target_engageable := _is_target_in_engage_range(horizontal_distance, vertical_distance)
	var target_in_attack_range := _is_target_in_attack_range(horizontal_distance, vertical_distance)
	var desired_direction := 0.0
	if horizontal_distance < retreat_range:
		desired_direction = -1.0 if to_target.x > 0.0 else 1.0
	elif horizontal_distance < attack_range_min:
		desired_direction = -1.0 if to_target.x > 0.0 else 1.0
	elif horizontal_distance > attack_range_max:
		desired_direction = 1.0 if to_target.x > 0.0 else -1.0

	match _behavior_state:
		BehaviorState.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
			if target_detected:
				_set_behavior_state(BehaviorState.REPOSITION)
		BehaviorState.REPOSITION:
			if not target_engageable:
				_set_behavior_state(BehaviorState.IDLE)
				velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
				return
			if target_in_attack_range:
				_set_behavior_state(BehaviorState.ATTACK_PAUSE, attack_pause_duration_sec)
				velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
				return
			if desired_direction == 0.0:
				velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
			else:
				var desired_direction_sign: int = 1 if desired_direction > 0.0 else -1
				if not _has_floor_ahead(desired_direction_sign):
					velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
					return
				var desired_speed := desired_direction * move_speed
				velocity.x = move_toward(velocity.x, desired_speed, move_accel * delta)
		BehaviorState.ATTACK_PAUSE:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
			if not target_engageable:
				_set_behavior_state(BehaviorState.IDLE)
				return
			if not target_in_attack_range:
				_set_behavior_state(BehaviorState.REPOSITION)
				return
			_behavior_timer = maxf(0.0, _behavior_timer - delta)
			if _behavior_timer <= 0.0:
				if not play_attack():
					_set_behavior_state(BehaviorState.RECOVERY, attack_interval_sec)
		BehaviorState.ATTACKING:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
		BehaviorState.RECOVERY:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
			_behavior_timer = maxf(0.0, _behavior_timer - delta)
			if _behavior_timer <= 0.0:
				if target_detected:
					_set_behavior_state(BehaviorState.REPOSITION)
				else:
					_set_behavior_state(BehaviorState.IDLE)


func _set_behavior_state(next_state: BehaviorState, timer_sec: float = 0.0) -> void:
	_behavior_state = next_state
	_behavior_timer = maxf(0.0, timer_sec)


func _setup_ledge_probe() -> void:
	if _ledge_probe != null:
		return
	_ledge_probe = RayCast2D.new()
	_ledge_probe.name = "LedgeProbe"
	_ledge_probe.enabled = true
	_ledge_probe.collide_with_areas = false
	_ledge_probe.collide_with_bodies = true
	_ledge_probe.collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER)
	add_child(_ledge_probe)
	_update_ledge_probe(facing)


func _update_ledge_probe(direction: int) -> void:
	if _ledge_probe == null:
		return
	var facing_sign: int = 1 if direction >= 0 else -1
	_ledge_probe.position = Vector2.ZERO
	_ledge_probe.target_position = Vector2(float(facing_sign) * ledge_probe_forward_distance, ledge_probe_down_distance)


func _has_floor_ahead(direction: int) -> bool:
	if not ledge_avoidance_enabled or not is_on_floor():
		return true
	if _ledge_probe == null:
		return true
	_update_ledge_probe(direction)
	_ledge_probe.force_raycast_update()
	return _ledge_probe.is_colliding()


func _refresh_target() -> void:
	if _is_valid_target(_target):
		return

	_target = null
	if target_path != NodePath():
		var target_node := get_node_or_null(target_path)
		if target_node is Node2D and _is_valid_target(target_node as Node2D):
			_target = target_node as Node2D
			return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var named_player := current_scene.find_child("Player", true, false)
	if named_player is Node2D and _is_valid_target(named_player as Node2D):
		_target = named_player as Node2D


func _sync_nonblocking_collisions() -> void:
	if not is_inside_tree():
		return

	if _has_valid_target() and _target is PhysicsBody2D:
		_register_collision_exception(_target as PhysicsBody2D)

	for node in get_tree().get_nodes_in_group(ENEMY_COLLISION_GROUP):
		if node == self:
			continue
		if node is PhysicsBody2D:
			_register_collision_exception(node as PhysicsBody2D)


func _register_collision_exception(body: PhysicsBody2D) -> void:
	if body == null:
		return
	if not is_instance_valid(body):
		return

	var body_id := body.get_instance_id()
	if _registered_collision_exception_ids.has(body_id):
		return

	_registered_collision_exception_ids[body_id] = true
	add_collision_exception_with(body)
	body.add_collision_exception_with(self)


func _has_valid_target() -> bool:
	return _is_valid_target(_target)


func _is_valid_target(candidate: Node2D) -> bool:
	if candidate == null:
		return false
	if not is_instance_valid(candidate):
		return false
	if candidate == self:
		return false
	if candidate.has_method("is_dead") and candidate.call("is_dead"):
		return false
	return true


func _is_target_in_detection(horizontal_distance: float, vertical_distance: float) -> bool:
	return horizontal_distance <= detection_range and vertical_distance <= detection_vertical_tolerance


func _is_target_in_engage_range(horizontal_distance: float, vertical_distance: float) -> bool:
	return horizontal_distance <= disengage_range and vertical_distance <= detection_vertical_tolerance


func _is_target_in_attack_range(horizontal_distance: float, vertical_distance: float) -> bool:
	return horizontal_distance >= attack_range_min and horizontal_distance <= attack_range_max and vertical_distance <= attack_vertical_tolerance


func _sync_facing() -> void:
	if visuals != null:
		visuals.scale.x = facing
	if projectile_spawn != null:
		projectile_spawn.position = Vector2(muzzle_offset.x * facing, muzzle_offset.y)


func _lock_attack_target() -> void:
	var locked_target := global_position + Vector2(float(facing) * attack_range_max, aim_height_offset)
	if _has_valid_target():
		locked_target = _target.global_position + Vector2(0.0, aim_height_offset)
		var direction_x := locked_target.x - global_position.x
		if absf(direction_x) > 1.0:
			set_facing(1 if direction_x > 0.0 else -1)
	_attack_locked_target_position = locked_target


func _spawn_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile_instance := projectile_scene.instantiate()
	if projectile_instance == null:
		return
	if projectile_instance is Node:
		(projectile_instance as Node).set_multiplayer_authority(1, true)

	var current_scene := get_tree().current_scene
	if current_scene == null:
		current_scene = self
	current_scene.add_child(projectile_instance)

	if projectile_instance is Node2D:
		(projectile_instance as Node2D).global_position = projectile_spawn.global_position

	var direction := (_attack_locked_target_position - projectile_spawn.global_position).normalized()
	if direction.length_squared() <= 0.0:
		direction = Vector2.RIGHT if facing > 0 else Vector2.LEFT

	var payload := _build_attack_payload()
	if projectile_instance.has_method("launch"):
		projectile_instance.call("launch", direction, payload, self)
	if projectile_instance.has_method("set"):
		projectile_instance.set("speed", projectile_speed)
		projectile_instance.set("lifetime_sec", projectile_lifetime_sec)


func _build_attack_payload() -> Dictionary:
	return {
		"attack_id": "dungeon_crossbowman_bolt",
		"damage": base_damage,
		"hit_effect": projectile_hit_effect,
		"stun_duration_sec": projectile_stun_duration_sec,
		"launch_height_px": projectile_launch_height_px,
		"launch_distance_px": projectile_launch_distance_px,
	}


func _update_hit_flash(delta: float) -> void:
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


func _is_network_replica() -> bool:
	return multiplayer.has_multiplayer_peer() and not is_multiplayer_authority()


func _physics_process_network_replica(delta: float) -> void:
	_update_hit_flash(delta)
	_update_damage_popups(delta)
	if not _network_state_ready:
		update_status_bars()
		return

	var target_position := _get_network_state_vector2("position", global_position)
	var follow_weight := clampf(delta * network_interpolation_speed, 0.0, 1.0)
	global_position = global_position.lerp(target_position, follow_weight)
	if global_position.distance_to(target_position) <= 0.5:
		global_position = target_position

	velocity = _get_network_state_vector2("velocity", velocity)
	_top_state = _get_network_state_int("top_state", int(_top_state))
	_current_hp = _get_network_state_float("current_hp", _current_hp)
	_hit_flash_timer = _get_network_state_float("hit_flash_timer", _hit_flash_timer)
	_attack_in_progress = _get_network_state_bool("attack_in_progress", _attack_in_progress)
	_attack_projectile_fired = _get_network_state_bool("attack_projectile_fired", _attack_projectile_fired)
	_attack_locked_target_position = _get_network_state_vector2("attack_locked_target_position", _attack_locked_target_position)
	_network_grabber_path = _get_network_state_string("grabber_path", "")
	_resolve_network_grabber()
	set_facing(_get_network_state_int("facing", facing))
	_sync_network_animation_state(
		_get_network_state_string("current_animation", String(_current_animation)),
		_get_network_state_int("current_frame", 0)
	)
	_apply_collision_profile()
	update_status_bars()


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
		"facing": facing,
		"current_hp": _current_hp,
		"hit_flash_timer": _hit_flash_timer,
		"attack_in_progress": _attack_in_progress,
		"attack_projectile_fired": _attack_projectile_fired,
		"attack_locked_target_position": _attack_locked_target_position,
		"grabber_path": _node_to_path_string(_grabber),
		"current_animation": String(animated_sprite.animation) if animated_sprite != null else String(_current_animation),
		"current_frame": animated_sprite.frame if animated_sprite != null else 0,
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
	if _attack_in_progress:
		return true
	return absf(velocity.x) > 30.0 or absf(velocity.y) > 45.0


func _boost_network_snapshot_priority(duration_sec: float = -1.0, broadcast_now: bool = false) -> void:
	if duration_sec <= 0.0:
		duration_sec = network_combat_snapshot_boost_duration_sec
	_network_combat_snapshot_boost_timer = maxf(_network_combat_snapshot_boost_timer, duration_sec)
	if broadcast_now:
		_broadcast_network_snapshot_immediately()


func _resolve_network_grabber() -> void:
	if _network_grabber_path.is_empty():
		_grabber = null
		return
	_grabber = get_node_or_null(NodePath(_network_grabber_path)) as Node2D


func _sync_network_animation_state(animation_name: String, frame_value: int) -> void:
	if animated_sprite == null or animation_name.is_empty():
		return
	var animation_key := StringName(animation_name)
	if animated_sprite.animation != animation_key:
		animated_sprite.play(animation_key)
	elif not animated_sprite.is_playing():
		animated_sprite.play()
	if animated_sprite.frame != frame_value:
		animated_sprite.frame = frame_value
	_current_animation = animation_key


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


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_authority_snapshot(snapshot: Dictionary) -> void:
	if not _is_network_replica():
		return
	_network_received_state = snapshot.duplicate(true)
	_network_state_ready = true


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


@rpc("authority", "call_remote", "reliable")
func show_damage_popup_remote(damage_value: float) -> void:
	if not _is_network_replica():
		return
	_show_damage_popup(damage_value)


func _show_damage_popup(damage_value: float) -> void:
	if damage_popups_root == null:
		return
	if damage_value <= 0.0:
		return

	var popup := Label.new()
	popup.text = str(int(round(damage_value)))
	popup.position = Vector2(-10.0 + randf_range(-3.0, 3.0), -42.0 + randf_range(-2.0, 2.0))
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


func _update_animation_state() -> void:
	var target := _current_animation

	match _top_state:
		TopState.STUN:
			target = &"hit"
		TopState.LAUNCH:
			target = &"launch"
		TopState.DOWN:
			target = &"down"
		TopState.GET_UP:
			target = &"get_up"
		TopState.GRABBED:
			target = &"grabbed"
		TopState.DEAD:
			target = &"death"
		_:
			if _attack_in_progress:
				target = &"attack"
			elif absf(velocity.x) > 6.0 and is_on_floor():
				target = &"move"
			else:
				target = &"idle"

	if _current_animation == target:
		return

	_current_animation = target
	animated_sprite.play(target)


func _apply_collision_profile() -> void:
	if _top_state == TopState.DEAD or _top_state == TopState.DOWN or _top_state == TopState.GRABBED:
		collision_layer = 0
		collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER)
		return

	collision_layer = _layer_bit(CHARACTER_LAYER)
	collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER)


func _on_animated_sprite_frame_changed() -> void:
	if _top_state != TopState.OPERABLE:
		return
	if not _attack_in_progress:
		return
	if animated_sprite.animation != &"attack":
		return
	if animated_sprite.frame != ATTACK_FIRE_FRAME:
		return
	if _attack_projectile_fired:
		return

	_attack_projectile_fired = true
	_spawn_projectile()


func _on_animated_sprite_animation_finished() -> void:
	match animated_sprite.animation:
		&"attack":
			_attack_in_progress = false
			_attack_projectile_fired = false
			if _top_state == TopState.OPERABLE:
				_set_behavior_state(BehaviorState.RECOVERY, attack_interval_sec)
			_update_animation_state()
		&"get_up":
			_top_state = TopState.OPERABLE
			_cancel_behavior()
			_update_animation_state()


func _update_grabbed_state() -> void:
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


func _get_effective_gravity() -> float:
	return gravity_force if velocity.y < 0.0 else gravity_force * fall_gravity_scale


func get_launch_travel_time_for_height(height_px: float) -> float:
	if height_px <= 0.0:
		return 0.0

	var rise_time := sqrt((2.0 * height_px) / gravity_force)
	var fall_time := sqrt((2.0 * height_px) / (gravity_force * fall_gravity_scale))
	return rise_time + fall_time


func get_stun_knockback_speed() -> float:
	if stun_base_duration_sec <= 0.0:
		return 0.0
	return (2.0 * stun_base_knockback_distance_px) / stun_base_duration_sec


func _layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
