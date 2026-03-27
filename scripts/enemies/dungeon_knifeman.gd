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
	CHASE,
	ATTACK_PAUSE,
	ATTACKING,
	RECOVERY,
}

const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
const PLATFORM_LAYER := 3
const ATTACK_ACTIVE_FRAMES := {
	4: {
		"offset": Vector2(18.0, -17.0),
		"size": Vector2(22.0, 12.0),
	},
	5: {
		"offset": Vector2(23.0, -16.0),
		"size": Vector2(26.0, 12.0),
	},
}

@export var facing: int = 1
@export var gravity_force: float = 1325.0
@export var fall_gravity_scale: float = 1.2
@export_group("Combat Stats")
@export var max_hp: float = 42.0
@export var base_damage: float = 9.0
@export var attack_interval_sec: float = 0.26
@export_group("")
@export var move_speed: float = 34.0
@export var hit_stun_horizontal_decel: float = 2800.0
@export var stun_base_duration_sec: float = 0.22
@export var stun_base_knockback_distance_px: float = 8.0
@export var launch_base_height_px: float = 64.0
@export var down_duration_sec: float = 0.9
@export var hit_flash_duration: float = 0.10
@export var hit_flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)
@export var damage_popup_rise_speed: float = 24.0
@export var damage_popup_lifetime: float = 0.55
@export var damage_popup_color: Color = Color(1.0, 0.88, 0.62, 1.0)

@export_group("Behavior")
@export var target_path: NodePath
@export var detection_range: float = 136.0
@export var detection_vertical_tolerance: float = 28.0
@export var disengage_range: float = 164.0
@export var attack_range: float = 22.0
@export var attack_vertical_tolerance: float = 18.0
@export var attack_pause_duration_sec: float = 0.14
@export var move_accel: float = 220.0

@export_group("Attack")
@export var attack_hit_effect: String = "stun"
@export var attack_stun_duration_sec: float = 0.24
@export var attack_launch_height_px: float = 52.0
@export var attack_launch_distance_px: float = 24.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: EnemyAttackHitbox2D = $AttackPivot/AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackPivot/AttackHitbox/CollisionShape2D
@onready var damage_popups_root: Node2D = $DamagePopups

var _top_state: TopState = TopState.OPERABLE
var _current_animation: StringName = &""
var _current_hp: float = 0.0
var _hit_flash_timer := 0.0
var _stun_timer := 0.0
var _down_timer := 0.0
var _attack_in_progress := false
var _grabber: Node2D
var _grabbed_slot_offset := Vector2.ZERO
var _last_received_damage := 0.0
var _behavior_state: BehaviorState = BehaviorState.IDLE
var _behavior_timer := 0.0
var _target: Node2D


func _ready() -> void:
	_current_hp = max_hp
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	attack_hitbox.target_hit.connect(_on_attack_hitbox_target_hit)
	attack_hitbox.configure(self, _build_attack_payload())
	attack_hitbox.set_active(false)
	_refresh_target()
	_sync_facing()
	_apply_collision_profile()
	_update_animation_state()


func _physics_process(delta: float) -> void:
	_update_hit_flash(delta)
	_update_damage_popups(delta)
	_refresh_target()

	if _top_state == TopState.DEAD:
		velocity = Vector2.ZERO
		return

	if _top_state == TopState.GRABBED:
		_update_grabbed_state()
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


func set_facing(direction: int) -> void:
	if direction == 0:
		return
	facing = 1 if direction > 0 else -1
	_sync_facing()
	_sync_attack_hitbox_to_animation()


func play_attack() -> bool:
	if _top_state != TopState.OPERABLE:
		return false
	if _attack_in_progress:
		return false

	_attack_in_progress = true
	_set_behavior_state(BehaviorState.ATTACKING)
	attack_hitbox.reset_hit_memory()
	attack_hitbox.set_attack_data(_build_attack_payload())
	attack_hitbox.set_active(false)
	animated_sprite.play(&"attack")
	_current_animation = &"attack"
	_sync_attack_hitbox_to_animation()
	return true


func receive_weapon_hit(attack_data: Dictionary, source: Node) -> void:
	if _top_state == TopState.DEAD:
		return

	var raw_damage: float = attack_data.get("damage", 0.0)
	_last_received_damage = maxf(0.0, raw_damage)
	apply_damage(_last_received_damage)
	if _top_state == TopState.DEAD:
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


func receive_grabbed_weapon_hit(attack_data: Dictionary, _source: Node) -> void:
	if _top_state == TopState.DEAD:
		return

	var raw_damage: float = attack_data.get("damage", 0.0)
	_last_received_damage = maxf(0.0, raw_damage)
	apply_damage(_last_received_damage)
	trigger_hit_flash()


func apply_damage(raw_damage: float) -> void:
	var final_damage := maxf(0.0, raw_damage)
	if final_damage <= 0.0:
		return

	trigger_hit_flash()
	_show_damage_popup(final_damage)
	_current_hp = clampf(_current_hp - final_damage, 0.0, max_hp)
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


func is_dead() -> bool:
	return _top_state == TopState.DEAD


func get_current_hp() -> float:
	return _current_hp


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
	velocity.x = 0.0
	velocity.y = 0.0
	animated_sprite.play(&"down")


func die() -> void:
	if _top_state == TopState.DEAD:
		return

	_interrupt_attack()
	_cancel_behavior()
	_top_state = TopState.DEAD
	velocity = Vector2.ZERO
	_apply_collision_profile()
	animated_sprite.play(&"death")


func _interrupt_attack() -> void:
	_attack_in_progress = false
	attack_hitbox.set_active(false)
	attack_hitbox.reset_hit_memory()


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

	match _behavior_state:
		BehaviorState.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
			if target_detected:
				_set_behavior_state(BehaviorState.CHASE)
		BehaviorState.CHASE:
			if not target_engageable:
				_set_behavior_state(BehaviorState.IDLE)
				velocity.x = move_toward(velocity.x, 0.0, move_accel * delta)
				return
			if target_in_attack_range:
				_set_behavior_state(BehaviorState.ATTACK_PAUSE, attack_pause_duration_sec)
				velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
				return
			var desired_speed := (1.0 if to_target.x > 0.0 else -1.0) * move_speed
			velocity.x = move_toward(velocity.x, desired_speed, move_accel * delta)
		BehaviorState.ATTACK_PAUSE:
			velocity.x = move_toward(velocity.x, 0.0, move_accel * 2.0 * delta)
			if not target_engageable:
				_set_behavior_state(BehaviorState.IDLE)
				return
			if not target_in_attack_range:
				_set_behavior_state(BehaviorState.CHASE)
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
					_set_behavior_state(BehaviorState.CHASE)
				else:
					_set_behavior_state(BehaviorState.IDLE)


func _set_behavior_state(next_state: BehaviorState, timer_sec: float = 0.0) -> void:
	_behavior_state = next_state
	_behavior_timer = maxf(0.0, timer_sec)


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
	return horizontal_distance <= attack_range and vertical_distance <= attack_vertical_tolerance


func _sync_facing() -> void:
	if visuals != null:
		visuals.scale.x = facing


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
	_sync_attack_hitbox_to_animation()


func _apply_collision_profile() -> void:
	if _top_state == TopState.DEAD or _top_state == TopState.DOWN or _top_state == TopState.GRABBED:
		collision_layer = 0
		collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER)
		return

	collision_layer = _layer_bit(CHARACTER_LAYER)
	collision_mask = _layer_bit(WORLD_LAYER) | _layer_bit(PLATFORM_LAYER) | _layer_bit(CHARACTER_LAYER)


func _build_attack_payload() -> Dictionary:
	var attack_data := {
		"attack_id": "dungeon_knifeman_attack",
		"damage": base_damage,
		"hit_effect": attack_hit_effect,
		"stun_duration_sec": attack_stun_duration_sec,
		"launch_height_px": attack_launch_height_px,
		"launch_distance_px": attack_launch_distance_px,
	}
	return attack_data


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
	if animated_sprite.animation != &"attack":
		attack_hitbox.set_active(false)
		return
	if not ATTACK_ACTIVE_FRAMES.has(animated_sprite.frame):
		attack_hitbox.set_active(false)
		return

	var frame_data: Dictionary = ATTACK_ACTIVE_FRAMES[animated_sprite.frame]
	var rect_shape := attack_shape.shape as RectangleShape2D
	rect_shape.size = frame_data.get("size", rect_shape.size)
	var local_offset: Vector2 = frame_data.get("offset", Vector2.ZERO)
	attack_pivot.position = Vector2(local_offset.x * facing, local_offset.y)
	attack_hitbox.set_active(true)


func _on_attack_hitbox_target_hit(target: Node, _attack_id: StringName, attack_data: Dictionary) -> void:
	if target == self:
		return
	if _top_state == TopState.DEAD:
		return

	if target.has_method("receive_weapon_hit"):
		target.call("receive_weapon_hit", attack_data.duplicate(true), self)
		return

	var target_x := global_position.x
	if target is Node2D:
		target_x = (target as Node2D).global_position.x
	var source_is_on_left := global_position.x < target_x
	match String(attack_data.get("hit_effect", "stun")):
		"launch":
			if target.has_method("apply_launch_by_distance_from_source"):
				target.call(
					"apply_launch_by_distance_from_source",
					source_is_on_left,
					attack_data.get("launch_height_px", attack_launch_height_px),
					attack_data.get("launch_distance_px", attack_launch_distance_px)
				)
		_:
			if target.has_method("apply_stun_from_source"):
				target.call(
					"apply_stun_from_source",
					source_is_on_left,
					attack_data.get("stun_duration_sec", attack_stun_duration_sec)
				)


func _on_animated_sprite_frame_changed() -> void:
	_sync_attack_hitbox_to_animation()


func _on_animated_sprite_animation_finished() -> void:
	match animated_sprite.animation:
		&"attack":
			_attack_in_progress = false
			attack_hitbox.set_active(false)
			if _top_state == TopState.OPERABLE:
				_set_behavior_state(BehaviorState.RECOVERY, attack_interval_sec)
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
