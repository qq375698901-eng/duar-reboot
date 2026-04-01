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
	ADVANCE,
	PRESSURE_PAUSE,
	ATTACKING,
	RECOVERY,
}

const WORLD_LAYER: int = 1
const CHARACTER_LAYER: int = 2
const PLATFORM_LAYER: int = 3
const ENEMY_COLLISION_GROUP: StringName = &"enemy_bodies"

const ATTACK_ACTIVE_FRAMES := {
	&"attack_1": {
		4: {
			"offset": Vector2(34.0, -40.0),
			"size": Vector2(52.0, 24.0),
			"visual_angle": -8.0,
		},
		5: {
			"offset": Vector2(54.0, -34.0),
			"size": Vector2(74.0, 28.0),
			"visual_angle": 10.0,
		},
		6: {
			"offset": Vector2(72.0, -28.0),
			"size": Vector2(80.0, 28.0),
			"visual_angle": 18.0,
		},
	},
	&"attack_2": {
		17: {
			"offset": Vector2(38.0, -22.0),
			"size": Vector2(42.0, 48.0),
			"visual_angle": 72.0,
		},
		18: {
			"offset": Vector2(46.0, -10.0),
			"size": Vector2(48.0, 56.0),
			"visual_angle": 86.0,
		},
	},
	&"attack_3": {
		4: {
			"offset": Vector2(-34.0, -34.0),
			"size": Vector2(44.0, 24.0),
			"visual_angle": 168.0,
		},
		5: {
			"offset": Vector2(-10.0, -30.0),
			"size": Vector2(72.0, 28.0),
			"visual_angle": 188.0,
		},
		6: {
			"offset": Vector2(28.0, -24.0),
			"size": Vector2(88.0, 30.0),
			"visual_angle": 204.0,
		},
	},
}

const ATTACK_PAYLOADS := {
	&"attack_1": {
		"attack_id": "dungeon_overseer_attack_1",
		"damage_multiplier": 1.0,
		"launch_height_px": 70.0,
		"launch_distance_px": 56.0,
	},
	&"attack_2": {
		"attack_id": "dungeon_overseer_attack_2",
		"damage_multiplier": 1.2,
		"launch_height_px": 86.0,
		"launch_distance_px": 30.0,
	},
	&"attack_3": {
		"attack_id": "dungeon_overseer_attack_3",
		"damage_multiplier": 1.05,
		"launch_height_px": 64.0,
		"launch_distance_px": 48.0,
	},
}

@export var facing: int = 1
@export var gravity_force: float = 1425.0
@export var fall_gravity_scale: float = 1.18

@export_group("Combat Stats")
@export var max_hp: float = 180.0
@export var base_damage: float = 16.0
@export_group("")
@export var move_speed: float = 24.0
@export var hit_stun_horizontal_decel: float = 2500.0
@export var stun_base_duration_sec: float = 0.20
@export var stun_base_knockback_distance_px: float = 10.0
@export var launch_base_height_px: float = 76.0
@export var down_duration_sec: float = 1.1
@export var hit_flash_duration: float = 0.10
@export var hit_flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export var damage_popup_rise_speed: float = 24.0
@export var damage_popup_lifetime: float = 0.55
@export var damage_popup_color: Color = Color(1.0, 0.88, 0.62, 1.0)

@export_group("Behavior")
@export var target_path: NodePath
@export var detection_range: float = 260.0
@export var detection_vertical_tolerance: float = 46.0
@export var disengage_range: float = 320.0
@export var pressure_range: float = 120.0
@export var sweep_attack_range: float = 112.0
@export var punish_attack_range: float = 68.0
@export var rear_attack_range: float = 90.0
@export var attack_vertical_tolerance: float = 34.0
@export var rear_attack_vertical_tolerance: float = 42.0
@export var pressure_pause_duration_sec: float = 0.34
@export var move_accel: float = 90.0
@export var front_pressure_time_sec: float = 0.65
@export var front_pressure_decay_per_sec: float = 1.6
@export var rear_hold_front_tolerance_px: float = 10.0
@export var fall_death_y: float = 100000.0
@export var ledge_avoidance_enabled: bool = true
@export var ledge_probe_forward_distance: float = 18.0
@export var ledge_probe_down_distance: float = 40.0

@export_group("Attack")
@export var default_attack_hit_effect: String = "launch"
@export var default_attack_stun_duration_sec: float = 0.26
@export var attack_interval_min_sec: float = 2.0
@export var attack_interval_max_sec: float = 5.0
@export var attack_2_after_attack_1_count: int = 2
@export_range(0.0, 1.0, 0.05) var attack_2_trigger_chance: float = 0.45
@export_group("Networking")
@export var network_snapshot_interval_sec: float = 0.05
@export var network_combat_snapshot_interval_sec: float = 0.016
@export var network_combat_snapshot_boost_duration_sec: float = 0.2
@export var network_interpolation_speed: float = 18.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: EnemyAttackHitbox2D = $AttackPivot/AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackPivot/AttackHitbox/CollisionShape2D
@onready var status_bars: EnemyStatusBars = $StatusBars
@onready var damage_popups_root: Node2D = $DamagePopups

var _top_state: TopState = TopState.OPERABLE
var _behavior_state: BehaviorState = BehaviorState.IDLE
var _current_animation: StringName = &""
var _current_attack_animation: StringName = &""
var _current_hp: float = 0.0
var _hit_flash_timer: float = 0.0
var _stun_timer: float = 0.0
var _down_timer: float = 0.0
var _behavior_timer: float = 0.0
var _front_pressure_timer: float = 0.0
var _attack_in_progress: bool = false
var _target: Node2D
var _grabber: Node2D
var _grabbed_slot_offset: Vector2 = Vector2.ZERO
var _last_received_damage: float = 0.0
var _registered_collision_exception_ids: Dictionary = {}
var _attack_1_chain_count: int = 0
var _attack_3_lock_requested: bool = false
var _was_target_on_front_side: bool = true
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
	attack_hitbox.target_hit.connect(_on_attack_hitbox_target_hit)
	attack_hitbox.configure(self, _build_attack_payload(&"attack_1"))
	attack_hitbox.set_active(false)
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
	_sync_attack_hitbox_to_animation()
	_update_ledge_probe(facing)


func play_attack(attack_name: StringName) -> bool:
	if _top_state != TopState.OPERABLE:
		return false
	if _attack_in_progress:
		return false
	if not ATTACK_ACTIVE_FRAMES.has(attack_name):
		return false

	if attack_name == &"attack_3" and _has_valid_target():
		var to_target_x: float = _target.global_position.x - global_position.x
		if absf(to_target_x) > 1.0:
			set_facing(1 if to_target_x > 0.0 else -1)

	_attack_in_progress = true
	_current_attack_animation = attack_name
	_set_behavior_state(BehaviorState.ATTACKING)
	_front_pressure_timer = 0.0
	attack_hitbox.reset_hit_memory()
	attack_hitbox.set_attack_data(_build_attack_payload(attack_name))
	attack_hitbox.set_active(false)
	animated_sprite.play(attack_name)
	_current_animation = attack_name
	_sync_attack_hitbox_to_animation()
	return true


func receive_weapon_hit(attack_data: Dictionary, source: Node) -> void:
	if _is_network_replica():
		request_receive_weapon_hit.rpc_id(1, attack_data.duplicate(true), _node_to_path_string(source))
		return
	if _top_state == TopState.DEAD:
		return

	_boost_network_snapshot_priority()
	var raw_damage: float = float(attack_data.get("damage", 0.0))
	_last_received_damage = maxf(0.0, raw_damage)
	apply_damage(_last_received_damage)
	if _top_state == TopState.DEAD:
		_broadcast_network_snapshot_immediately()
		return

	if source is Node2D:
		var source_position: Vector2 = (source as Node2D).global_position
		var source_direction: int = 0
		if source_position.x > global_position.x:
			source_direction = 1
		elif source_position.x < global_position.x:
			source_direction = -1
		if source_direction != 0:
			set_facing(source_direction)
	_broadcast_network_snapshot_immediately()


func receive_grabbed_weapon_hit(attack_data: Dictionary, _source: Node) -> void:
	if _is_network_replica():
		request_receive_grabbed_weapon_hit.rpc_id(1, attack_data.duplicate(true))
		return
	if _top_state == TopState.DEAD:
		return

	_boost_network_snapshot_priority()
	var raw_damage: float = float(attack_data.get("damage", 0.0))
	_last_received_damage = maxf(0.0, raw_damage)
	apply_damage(_last_received_damage)
	trigger_hit_flash()
	_broadcast_network_snapshot_immediately()


func apply_damage(raw_damage: float) -> void:
	var final_damage: float = maxf(0.0, raw_damage)
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


func apply_stun_from_source(source_is_on_left: bool, _duration_sec: float) -> void:
	if _top_state == TopState.DEAD:
		return
	if source_is_on_left:
		set_facing(1)
	else:
		set_facing(-1)
	trigger_hit_flash()


func apply_launch_by_distance_from_source(source_is_on_left: bool, _height_px: float, _distance_px: float) -> void:
	if _top_state == TopState.DEAD:
		return
	if source_is_on_left:
		set_facing(1)
	else:
		set_facing(-1)
	trigger_hit_flash()


func enter_grabbed_by(grabber: Node2D, _slot_offset: Vector2 = Vector2.ZERO) -> void:
	if _top_state == TopState.DEAD:
		return
	if grabber != null:
		var to_grabber_x: float = grabber.global_position.x - global_position.x
		if absf(to_grabber_x) > 1.0:
			set_facing(1 if to_grabber_x > 0.0 else -1)
	trigger_hit_flash()


func release_grabbed() -> void:
	return


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
	_current_attack_animation = &""
	attack_hitbox.set_active(false)
	attack_hitbox.reset_hit_memory()


func _cancel_behavior() -> void:
	_set_behavior_state(BehaviorState.IDLE)
	_behavior_timer = 0.0
	_front_pressure_timer = 0.0
	_attack_3_lock_requested = false


func _update_behavior(delta: float) -> void:
	if _attack_in_progress:
		velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
		return

	if not _has_valid_target():
		_set_behavior_state(BehaviorState.IDLE)
		velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
		_front_pressure_timer = 0.0
		return

	var to_target: Vector2 = _target.global_position - global_position
	var horizontal_distance: float = absf(to_target.x)
	var vertical_distance: float = absf(to_target.y)
	var target_detected: bool = _is_target_in_detection(horizontal_distance, vertical_distance)
	var target_engageable: bool = _is_target_in_engage_range(horizontal_distance, vertical_distance)
	var target_in_pressure_range: bool = _is_target_in_pressure_range(horizontal_distance, vertical_distance)
	var rear_attack_ready: bool = _is_target_in_rear_attack_window(to_target, horizontal_distance, vertical_distance)

	_update_attack_3_lock(to_target, vertical_distance)
	_update_front_pressure_timer(delta, to_target, horizontal_distance, vertical_distance)
	_update_facing_in_operable_state(to_target, rear_attack_ready)

	if _attack_3_lock_requested or rear_attack_ready:
		if play_attack(&"attack_3"):
			_attack_3_lock_requested = false
			return
		_set_behavior_state(BehaviorState.RECOVERY, _roll_attack_recovery_duration())
		return

	match _behavior_state:
		BehaviorState.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
			if target_detected:
				_set_behavior_state(BehaviorState.ADVANCE)
		BehaviorState.ADVANCE:
			if not target_engageable:
				_set_behavior_state(BehaviorState.IDLE)
				velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
				return
			if rear_attack_ready or target_in_pressure_range:
				_set_behavior_state(BehaviorState.PRESSURE_PAUSE, pressure_pause_duration_sec)
				velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.2 * delta)
				return
			var desired_direction: int = 1 if to_target.x > 0.0 else -1
			if not _has_floor_ahead(desired_direction):
				velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.2 * delta)
				return
			var desired_speed: float = float(desired_direction) * move_speed
			velocity.x = move_toward(velocity.x, desired_speed, move_accel * delta)
		BehaviorState.PRESSURE_PAUSE:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.5 * delta)
			if not target_engageable:
				_set_behavior_state(BehaviorState.IDLE)
				return
			_behavior_timer = maxf(0.0, _behavior_timer - delta)
			if _behavior_timer > 0.0:
				return

			var selected_attack: StringName = _select_attack(to_target, horizontal_distance, vertical_distance)
			if selected_attack == &"":
				_set_behavior_state(BehaviorState.ADVANCE)
				return
			if not play_attack(selected_attack):
				_set_behavior_state(BehaviorState.RECOVERY, _roll_attack_recovery_duration())
		BehaviorState.ATTACKING:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.5 * delta)
		BehaviorState.RECOVERY:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
			_behavior_timer = maxf(0.0, _behavior_timer - delta)
			if _behavior_timer <= 0.0:
				if not target_detected:
					_set_behavior_state(BehaviorState.IDLE)
				else:
					_set_behavior_state(BehaviorState.ADVANCE)


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


func _select_attack(to_target: Vector2, horizontal_distance: float, vertical_distance: float) -> StringName:
	if _is_target_in_rear_attack_window(to_target, horizontal_distance, vertical_distance):
		return &"attack_3"

	if not _is_target_in_front(to_target.x):
		return &""

	if horizontal_distance <= punish_attack_range and _front_pressure_timer >= front_pressure_time_sec and _can_use_attack_2():
		return &"attack_2"

	if horizontal_distance <= sweep_attack_range:
		return &"attack_1"

	return &""


func _update_front_pressure_timer(delta: float, to_target: Vector2, horizontal_distance: float, _vertical_distance: float) -> void:
	if horizontal_distance <= punish_attack_range and _is_target_in_front(to_target.x):
		_front_pressure_timer = minf(front_pressure_time_sec + 0.45, _front_pressure_timer + delta)
		return

	_front_pressure_timer = maxf(0.0, _front_pressure_timer - (front_pressure_decay_per_sec * delta))


func _update_attack_3_lock(to_target: Vector2, vertical_distance: float) -> void:
	if vertical_distance > rear_attack_vertical_tolerance:
		return

	var is_on_front_side: bool = _is_target_in_front(to_target.x)
	if _was_target_on_front_side and not is_on_front_side:
		_attack_3_lock_requested = true
	_was_target_on_front_side = is_on_front_side


func _update_facing_in_operable_state(to_target: Vector2, rear_attack_ready: bool) -> void:
	if rear_attack_ready:
		return
	if absf(to_target.x) <= 1.0:
		return
	set_facing(1 if to_target.x > 0.0 else -1)


func _refresh_target() -> void:
	if _is_valid_target(_target):
		return

	_target = null
	_attack_3_lock_requested = false
	_was_target_on_front_side = true
	if target_path != NodePath():
		var target_node: Node = get_node_or_null(target_path)
		if target_node is Node2D and _is_valid_target(target_node as Node2D):
			_target = target_node as Node2D
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var named_player: Node = current_scene.find_child("Player", true, false)
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

	var body_id: int = body.get_instance_id()
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
	if candidate.has_method("is_dead") and bool(candidate.call("is_dead")):
		return false
	return true


func _is_target_in_detection(horizontal_distance: float, vertical_distance: float) -> bool:
	if horizontal_distance > detection_range:
		return false
	if horizontal_distance <= pressure_range:
		return true
	return vertical_distance <= detection_vertical_tolerance


func _is_target_in_engage_range(horizontal_distance: float, vertical_distance: float) -> bool:
	if horizontal_distance > disengage_range:
		return false
	if horizontal_distance <= pressure_range:
		return true
	return vertical_distance <= detection_vertical_tolerance


func _is_target_in_pressure_range(horizontal_distance: float, _vertical_distance: float) -> bool:
	return horizontal_distance <= pressure_range


func _is_target_in_front(horizontal_offset: float) -> bool:
	if facing > 0:
		return horizontal_offset >= -rear_hold_front_tolerance_px
	return horizontal_offset <= rear_hold_front_tolerance_px


func _is_target_in_rear_attack_window(to_target: Vector2, _horizontal_distance: float, _vertical_distance: float) -> bool:
	return not _is_target_in_front(to_target.x)


func _sync_facing() -> void:
	if visuals != null:
		visuals.scale.x = facing


func _update_hit_flash(delta: float) -> void:
	if visuals == null:
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		var t: float = 0.0
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

	var popup: Label = Label.new()
	popup.text = str(int(round(damage_value)))
	popup.position = Vector2(-14.0 + randf_range(-4.0, 4.0), -62.0 + randf_range(-3.0, 3.0))
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

		var popup: Label = child as Label
		var lifetime_left: float = float(popup.get_meta("lifetime_left", damage_popup_lifetime))
		lifetime_left = maxf(0.0, lifetime_left - delta)
		popup.set_meta("lifetime_left", lifetime_left)
		popup.position.y -= damage_popup_rise_speed * delta

		var alpha: float = 0.0
		if damage_popup_lifetime > 0.0:
			alpha = lifetime_left / damage_popup_lifetime
		var color: Color = damage_popup_color
		color.a *= alpha
		popup.modulate = color

		if lifetime_left <= 0.0:
			popup.queue_free()


func _update_animation_state() -> void:
	var target_animation: StringName = _current_animation

	match _top_state:
		TopState.STUN:
			target_animation = &"hit"
		TopState.LAUNCH:
			target_animation = &"launch"
		TopState.DOWN:
			target_animation = &"down"
		TopState.GET_UP:
			target_animation = &"get_up"
		TopState.GRABBED:
			target_animation = &"grabbed"
		TopState.DEAD:
			target_animation = &"death"
		_:
			if _attack_in_progress:
				target_animation = _current_attack_animation
			elif absf(velocity.x) > 4.0 and is_on_floor():
				target_animation = &"move"
			else:
				target_animation = &"idle"

	if _current_animation == target_animation:
		return

	_current_animation = target_animation
	animated_sprite.play(target_animation)
	_sync_attack_hitbox_to_animation()


func _apply_collision_profile() -> void:
	if _top_state == TopState.DEAD or _top_state == TopState.DOWN or _top_state == TopState.GRABBED:
		collision_layer = 0
		collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER)
		return

	collision_layer = _layer_bit(CHARACTER_LAYER)
	collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER)


func _build_attack_payload(attack_name: StringName) -> Dictionary:
	var payload_template: Dictionary = ATTACK_PAYLOADS.get(attack_name, ATTACK_PAYLOADS[&"attack_1"])
	var payload := {
		"attack_id": payload_template.get("attack_id", "dungeon_overseer_attack"),
		"damage": base_damage * float(payload_template.get("damage_multiplier", 1.0)),
		"hit_effect": default_attack_hit_effect,
		"stun_duration_sec": default_attack_stun_duration_sec,
		"launch_height_px": float(payload_template.get("launch_height_px", launch_base_height_px)),
		"launch_distance_px": float(payload_template.get("launch_distance_px", 40.0)),
		"guard_break": attack_name == &"attack_2",
	}
	return payload


func _sync_attack_hitbox_to_animation() -> void:
	if attack_hitbox == null:
		return
	if attack_shape == null:
		return
	if attack_shape.shape is not RectangleShape2D:
		return
	if not _attack_in_progress:
		attack_hitbox.set_active(false)
		return
	if not ATTACK_ACTIVE_FRAMES.has(_current_attack_animation):
		attack_hitbox.set_active(false)
		return
	if animated_sprite.animation != _current_attack_animation:
		attack_hitbox.set_active(false)
		return

	var active_frames: Dictionary = ATTACK_ACTIVE_FRAMES[_current_attack_animation]
	if not active_frames.has(animated_sprite.frame):
		attack_hitbox.set_active(false)
		return

	var frame_data: Dictionary = active_frames[animated_sprite.frame]
	var rect_shape: RectangleShape2D = attack_shape.shape as RectangleShape2D
	rect_shape.size = frame_data.get("size", rect_shape.size)
	var local_offset: Vector2 = frame_data.get("offset", Vector2.ZERO)
	attack_pivot.position = Vector2(local_offset.x * facing, local_offset.y)
	if attack_hitbox.has_method("set_debug_slash_style"):
		var visual_angle: float = float(frame_data.get("visual_angle", 12.0))
		var resolved_visual_angle: float = visual_angle if facing > 0 else 180.0 - visual_angle
		attack_hitbox.call("set_debug_slash_style", resolved_visual_angle, 1.3, 0.78)
	attack_hitbox.set_active(true)


func _on_attack_hitbox_target_hit(target: Node, _attack_id: StringName, attack_data: Dictionary) -> void:
	if target == self:
		return
	if _top_state == TopState.DEAD:
		return

	if target.has_method("receive_weapon_hit"):
		target.call("receive_weapon_hit", attack_data.duplicate(true), self)
		return

	var target_x: float = global_position.x
	if target is Node2D:
		target_x = (target as Node2D).global_position.x
	var source_is_on_left: bool = global_position.x < target_x
	match String(attack_data.get("hit_effect", "stun")):
		"launch":
			if target.has_method("apply_launch_by_distance_from_source"):
				target.call(
					"apply_launch_by_distance_from_source",
					source_is_on_left,
					float(attack_data.get("launch_height_px", launch_base_height_px)),
					float(attack_data.get("launch_distance_px", 0.0))
				)
		_:
			if target.has_method("apply_stun_from_source"):
				target.call(
					"apply_stun_from_source",
					source_is_on_left,
					float(attack_data.get("stun_duration_sec", default_attack_stun_duration_sec))
				)


func _on_animated_sprite_frame_changed() -> void:
	_sync_attack_hitbox_to_animation()


func _on_animated_sprite_animation_finished() -> void:
	match animated_sprite.animation:
		&"attack_1", &"attack_2", &"attack_3":
			_register_completed_attack(animated_sprite.animation)
			_attack_in_progress = false
			_current_attack_animation = &""
			attack_hitbox.set_active(false)
			if _top_state == TopState.OPERABLE:
				_set_behavior_state(BehaviorState.RECOVERY, _roll_attack_recovery_duration())
			_update_animation_state()
		&"get_up":
			_top_state = TopState.OPERABLE
			_cancel_behavior()
			_update_animation_state()
		&"death":
			attack_hitbox.set_active(false)


func _update_grabbed_state() -> void:
	if not is_instance_valid(_grabber):
		release_grabbed()
		return

	var grab_facing: float = 1.0
	var grabber_facing_value: Variant = _grabber.get("facing")
	if grabber_facing_value != null:
		grab_facing = float(grabber_facing_value)
	var resolved_offset: Vector2 = Vector2(_grabbed_slot_offset.x * grab_facing, _grabbed_slot_offset.y)
	global_position = _grabber.global_position + resolved_offset
	velocity = Vector2.ZERO
	set_facing(int(grab_facing))


func _get_effective_gravity() -> float:
	return gravity_force if velocity.y < 0.0 else gravity_force * fall_gravity_scale


func get_launch_travel_time_for_height(height_px: float) -> float:
	if height_px <= 0.0:
		return 0.0

	var rise_time: float = sqrt((2.0 * height_px) / gravity_force)
	var fall_time: float = sqrt((2.0 * height_px) / (gravity_force * fall_gravity_scale))
	return rise_time + fall_time


func get_stun_knockback_speed() -> float:
	if stun_base_duration_sec <= 0.0:
		return 0.0
	return (2.0 * stun_base_knockback_distance_px) / stun_base_duration_sec


func _can_use_attack_2() -> bool:
	if _attack_1_chain_count < attack_2_after_attack_1_count:
		return false
	return randf() <= attack_2_trigger_chance


func _register_completed_attack(attack_name: StringName) -> void:
	match attack_name:
		&"attack_1":
			_attack_1_chain_count += 1
		&"attack_2":
			_attack_1_chain_count = 0


func _roll_attack_recovery_duration() -> float:
	var min_interval: float = minf(attack_interval_min_sec, attack_interval_max_sec)
	var max_interval: float = maxf(attack_interval_min_sec, attack_interval_max_sec)
	return randf_range(min_interval, max_interval)


func _layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
