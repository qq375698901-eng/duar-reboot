extends CharacterBody2D
class_name JudgementFireHead

signal head_skill_activated(head: Node)
signal head_cycle_finished(head: Node)
signal head_async_cycle_resolved(head: Node)
signal head_damaged(head: Node, source: Node)
signal head_broken(head: Node)

enum HeadState {
	IDLE,
	ACTIVE_LEFT,
	ACTIVE_RIGHT,
	CAST,
	WAITING_TRIGGER,
	COUNTDOWN,
	HIT,
	BROKEN,
}

const CHARACTER_LAYER := 2
const ENEMY_COLLISION_GROUP := &"enemy_bodies"
const JUDGEMENT_HEAD_GROUP := &"judgement_head_units"
const FIRE_PLATFORM_BLAST_SCENE := preload("res://scenes/hazards/judgement_fire_platform_blast.tscn")
const HEAD_KIND := &"fire"
const PLATFORM_SIDE_LEFT := &"left"
const PLATFORM_SIDE_RIGHT := &"right"

@export var target_path: NodePath

@export_group("Combat Stats")
@export var max_hp: float = 2000.0
@export var hit_flash_duration: float = 0.12
@export var hit_flash_color: Color = Color(1.0, 0.42, 0.42, 1.0)

@export_group("Fire Cycle")
@export var initial_cycle_delay_sec: float = 1.6
@export var cycle_interval_sec: float = 4.4
@export var aborted_cycle_delay_sec: float = 1.25
@export var countdown_duration_sec: float = 3.0

@export_group("Blast")
@export var blast_damage: float = 12.0
@export var blast_duration_sec: float = 0.28
@export var blast_launch_height_px: float = 56.0
@export var blast_launch_distance_px: float = 34.0

@export_group("Eye Binding Colors")
@export var wind_eye_color: Color = Color(0.96, 0.96, 0.96, 0.95)
@export var restore_eye_color: Color = Color(0.36, 0.96, 0.44, 0.95)
@export var guard_eye_color: Color = Color(0.10, 0.10, 0.10, 0.94)
@export var thunder_eye_color: Color = Color(1.0, 0.86, 0.28, 0.95)
@export var fire_eye_color: Color = Color(1.0, 0.54, 0.20, 0.95)

@export_group("Guard Mark")
@export var guard_mark_color: Color = Color(0.70, 0.78, 0.86, 0.42)
@export var guard_mark_core_color: Color = Color(0.92, 0.95, 1.0, 0.86)
@export var guard_mark_radius: float = 26.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var status_bars: EnemyStatusBars = $StatusBars
@onready var blasts_root: Node2D = $BlastsRoot

var _state: HeadState = HeadState.IDLE
var _resume_state_after_hit: HeadState = HeadState.IDLE
var _current_hp: float = 0.0
var _cycle_cooldown_left: float = 0.0
var _countdown_time_left: float = 0.0
var _hit_flash_timer: float = 0.0
var _target: Node2D
var _bound_head: Node2D
var _bound_head_kind: StringName = &""
var _marked_side: StringName = &""
var _eye_glow_color: Color = Color(0, 0, 0, 0)
var _left_platform_spans: Array[Dictionary] = []
var _right_platform_spans: Array[Dictionary] = []
var _registered_collision_exception_ids: Dictionary = {}
var _guard_mark_source: Node2D
var _guard_reflect_ratio: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _queued_countdown_start: bool = false
var _controller_driven: bool = false
var _cycle_in_progress: bool = false
var _controller_bind_candidates: Array[Node2D] = []
var _wave_slot_released: bool = false


func _ready() -> void:
	add_to_group(ENEMY_COLLISION_GROUP)
	add_to_group(JUDGEMENT_HEAD_GROUP)
	_rng.randomize()
	_current_hp = max_hp
	_cycle_cooldown_left = initial_cycle_delay_sec
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	_refresh_target()
	_sync_nonblocking_collisions()
	_collect_platform_spans()
	_apply_collision_profile()
	update_status_bars()
	_enter_state(HeadState.IDLE)


func _physics_process(delta: float) -> void:
	_refresh_target()
	_sync_nonblocking_collisions()
	_update_hit_flash(delta)

	if _state == HeadState.BROKEN:
		queue_redraw()
		return

	match _state:
		HeadState.IDLE:
			if not _controller_driven:
				_cycle_cooldown_left = maxf(0.0, _cycle_cooldown_left - delta)
				if _cycle_cooldown_left <= 0.0:
					_begin_cycle()
		HeadState.WAITING_TRIGGER:
			if not _is_valid_bound_target(_bound_head):
				_abort_cycle()
			elif _queued_countdown_start:
				_begin_countdown()
		HeadState.COUNTDOWN:
			_countdown_time_left = maxf(0.0, _countdown_time_left - delta)
			if _countdown_time_left <= 0.0:
				_trigger_platform_blasts()
				head_skill_activated.emit(self)
				_finish_cycle()
		HeadState.HIT:
			if _resume_state_after_hit == HeadState.COUNTDOWN:
				_countdown_time_left = maxf(0.0, _countdown_time_left - delta)
				if _countdown_time_left <= 0.0:
					_trigger_platform_blasts()
					head_skill_activated.emit(self)
					_finish_cycle()
			elif _resume_state_after_hit == HeadState.WAITING_TRIGGER:
				if not _is_valid_bound_target(_bound_head):
					_abort_cycle()
		_:
			pass

	_apply_collision_profile()
	queue_redraw()


func _draw() -> void:
	return


func receive_weapon_hit(attack_data: Dictionary, source: Node) -> void:
	if is_dead():
		return

	var raw_damage: float = maxf(0.0, float(attack_data.get("damage", 0.0)))
	if raw_damage > 0.0:
		head_damaged.emit(self, source)
	apply_damage(raw_damage)
	_apply_guard_reflect(raw_damage, source)
	if is_dead():
		return

	trigger_hit_flash()


func receive_grabbed_weapon_hit(attack_data: Dictionary, source: Node) -> void:
	if is_dead():
		return

	var raw_damage: float = maxf(0.0, float(attack_data.get("damage", 0.0)))
	if raw_damage > 0.0:
		head_damaged.emit(self, source)
	apply_damage(raw_damage)
	_apply_guard_reflect(raw_damage, source)
	if is_dead():
		return

	trigger_hit_flash()


func apply_damage(raw_damage: float) -> void:
	var final_damage: float = maxf(0.0, raw_damage)
	if final_damage <= 0.0:
		return

	_current_hp = clampf(_current_hp - final_damage, 0.0, max_hp)
	update_status_bars()
	if _current_hp <= 0.0:
		die()


func apply_head_heal(amount: float) -> float:
	if is_dead():
		return 0.0

	var resolved_amount: float = maxf(0.0, amount)
	if resolved_amount <= 0.0:
		return 0.0

	var previous_hp: float = _current_hp
	_current_hp = clampf(_current_hp + resolved_amount, 0.0, max_hp)
	update_status_bars()
	return _current_hp - previous_hp


func can_receive_head_heal() -> bool:
	return not is_dead() and _current_hp < max_hp


func get_head_hp_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(_current_hp / max_hp, 0.0, 1.0)


func get_judgement_head_kind() -> StringName:
	return HEAD_KIND


func set_controller_driven(enabled: bool) -> void:
	_controller_driven = enabled
	if enabled:
		_cycle_cooldown_left = 0.0


func set_controller_bind_candidates(candidates: Array) -> void:
	_controller_bind_candidates.clear()
	for candidate_variant in candidates:
		if candidate_variant is not Node2D:
			continue
		var candidate: Node2D = candidate_variant as Node2D
		if candidate == self:
			continue
		_controller_bind_candidates.append(candidate)


func is_available_for_controller() -> bool:
	return not is_dead() and _state == HeadState.IDLE


func begin_controlled_skill_cycle() -> bool:
	if not is_available_for_controller():
		return false
	_controller_driven = true
	_cycle_in_progress = true
	_wave_slot_released = false
	_begin_cycle()
	if _state == HeadState.IDLE:
		_cycle_in_progress = false
		_wave_slot_released = false
		return false
	return true


func can_receive_guard_mark() -> bool:
	return not is_dead()


func apply_guard_mark(source: Node2D, reflect_ratio: float = 1.0) -> void:
	_guard_mark_source = source
	_guard_reflect_ratio = maxf(0.0, reflect_ratio)


func clear_guard_mark(source: Node = null) -> void:
	if source != null and _guard_mark_source != source:
		return
	_guard_mark_source = null
	_guard_reflect_ratio = 1.0


func has_active_guard_mark() -> bool:
	return _guard_mark_source != null and is_instance_valid(_guard_mark_source)


func get_guard_mark_visual_data() -> Dictionary:
	return {
		"center": Vector2(0.0, -34.0),
		"outer_color": guard_mark_color,
		"core_color": guard_mark_core_color,
		"radius": guard_mark_radius,
		"pulse_speed": 5.2,
	}


func trigger_hit_flash() -> void:
	_hit_flash_timer = hit_flash_duration


func update_status_bars() -> void:
	if status_bars == null:
		return
	status_bars.set_bar_visible(not is_dead())
	status_bars.set_hp(_current_hp, max_hp)


func die() -> void:
	if _state == HeadState.BROKEN:
		return

	_disconnect_bound_head_signals()
	_clear_active_blasts()
	clear_guard_mark()
	_controller_bind_candidates.clear()
	_bound_head = null
	_bound_head_kind = &""
	_marked_side = &""
	_queued_countdown_start = false
	_wave_slot_released = false
	_state = HeadState.BROKEN
	_resume_state_after_hit = HeadState.BROKEN
	velocity = Vector2.ZERO
	_apply_collision_profile()
	update_status_bars()
	animated_sprite.play(&"break")
	head_broken.emit(self)


func is_dead() -> bool:
	return _state == HeadState.BROKEN


func _enter_state(next_state: HeadState) -> void:
	_state = next_state
	match next_state:
		HeadState.IDLE:
			_resume_state_after_hit = HeadState.IDLE
			_set_mark_direction(0)
			animated_sprite.play(&"idle")
		HeadState.ACTIVE_LEFT:
			_set_mark_direction(-1)
			animated_sprite.play(&"active")
		HeadState.ACTIVE_RIGHT:
			_set_mark_direction(1)
			animated_sprite.play(&"active")
		HeadState.CAST:
			animated_sprite.play(&"cast")
		HeadState.WAITING_TRIGGER:
			_set_mark_direction(0)
			animated_sprite.play(&"idle")
		HeadState.COUNTDOWN:
			_set_mark_direction(0)
			animated_sprite.play(&"idle")
		HeadState.HIT:
			animated_sprite.play(&"hit")
		HeadState.BROKEN:
			animated_sprite.play(&"break")


func _enter_hit_state() -> void:
	if _state == HeadState.BROKEN:
		return
	if _state == HeadState.HIT:
		return
	_resume_state_after_hit = _state
	_enter_state(HeadState.HIT)


func _resume_from_hit() -> void:
	if _state != HeadState.HIT:
		return
	if _resume_state_after_hit == HeadState.BROKEN:
		return
	var target_state: HeadState = _resume_state_after_hit
	_resume_state_after_hit = HeadState.IDLE
	_enter_state(target_state)


func _begin_cycle() -> void:
	_collect_platform_spans()
	if _left_platform_spans.is_empty() and _right_platform_spans.is_empty():
		_cycle_cooldown_left = 1.0
		return

	var chosen_target: Node2D = _pick_bind_target()
	if chosen_target == null:
		_cycle_cooldown_left = 1.0
		return

	var chosen_side: StringName = _pick_marked_side()
	if chosen_side == &"":
		_cycle_cooldown_left = 1.0
		return

	_disconnect_bound_head_signals()
	_bound_head = chosen_target
	_bound_head_kind = _resolve_head_kind(chosen_target)
	_marked_side = chosen_side
	_eye_glow_color = _color_for_head_kind(_bound_head_kind)
	_queued_countdown_start = false
	_connect_bound_head_signals()

	if _marked_side == PLATFORM_SIDE_LEFT:
		_enter_state(HeadState.ACTIVE_LEFT)
	else:
		_enter_state(HeadState.ACTIVE_RIGHT)


func _begin_waiting_for_trigger() -> void:
	if not _is_valid_bound_target(_bound_head):
		_abort_cycle()
		return
	_enter_state(HeadState.WAITING_TRIGGER)
	_release_wave_slot_if_needed()


func _begin_countdown() -> void:
	if _state == HeadState.BROKEN:
		return
	_queued_countdown_start = false
	_countdown_time_left = countdown_duration_sec
	_enter_state(HeadState.COUNTDOWN)


func _finish_cycle() -> void:
	_disconnect_bound_head_signals()
	_controller_bind_candidates.clear()
	_bound_head = null
	_bound_head_kind = &""
	_marked_side = &""
	_eye_glow_color = Color(0, 0, 0, 0)
	_countdown_time_left = 0.0
	_queued_countdown_start = false
	if _controller_driven and _cycle_in_progress:
		_cycle_in_progress = false
		_release_wave_slot_if_needed()
		head_async_cycle_resolved.emit(self)
		_cycle_cooldown_left = 0.0
	else:
		_cycle_cooldown_left = cycle_interval_sec
	_wave_slot_released = false
	_enter_state(HeadState.IDLE)


func _abort_cycle() -> void:
	_disconnect_bound_head_signals()
	_controller_bind_candidates.clear()
	_bound_head = null
	_bound_head_kind = &""
	_marked_side = &""
	_eye_glow_color = Color(0, 0, 0, 0)
	_countdown_time_left = 0.0
	_queued_countdown_start = false
	if _controller_driven and _cycle_in_progress:
		_cycle_in_progress = false
		_release_wave_slot_if_needed()
		head_async_cycle_resolved.emit(self)
		_cycle_cooldown_left = 0.0
	else:
		_cycle_cooldown_left = aborted_cycle_delay_sec
	_wave_slot_released = false
	_enter_state(HeadState.IDLE)


func _release_wave_slot_if_needed() -> void:
	if not _controller_driven:
		return
	if _wave_slot_released:
		return
	_wave_slot_released = true
	head_cycle_finished.emit(self)


func _trigger_platform_blasts() -> void:
	var spans: Array[Dictionary] = _left_platform_spans if _marked_side == PLATFORM_SIDE_LEFT else _right_platform_spans
	if spans.is_empty():
		return

	var attack_payload: Dictionary = {
		"attack_id": "judgement_fire_head_platform_blast",
		"damage": blast_damage,
		"hit_effect": "launch",
		"launch_height_px": blast_launch_height_px,
		"launch_distance_px": blast_launch_distance_px,
	}

	for span in spans:
		var blast: JudgementFirePlatformBlast = FIRE_PLATFORM_BLAST_SCENE.instantiate() as JudgementFirePlatformBlast
		blasts_root.add_child(blast)
		blast.blast_duration_sec = blast_duration_sec
		blast.configure(self, attack_payload, span)


func _clear_active_blasts() -> void:
	if blasts_root == null:
		return
	for child in blasts_root.get_children():
		if child is Node:
			(child as Node).queue_free()


func _connect_bound_head_signals() -> void:
	if _bound_head == null:
		return
	if not is_instance_valid(_bound_head):
		return

	var activated_callable: Callable = Callable(self, "_on_bound_head_skill_activated")
	if _bound_head.has_signal("head_skill_activated") and not _bound_head.is_connected("head_skill_activated", activated_callable):
		_bound_head.connect("head_skill_activated", activated_callable)

	var broken_callable: Callable = Callable(self, "_on_bound_head_broken")
	if _bound_head.has_signal("head_broken") and not _bound_head.is_connected("head_broken", broken_callable):
		_bound_head.connect("head_broken", broken_callable)


func _disconnect_bound_head_signals() -> void:
	if _bound_head == null:
		return
	if not is_instance_valid(_bound_head):
		return

	var activated_callable: Callable = Callable(self, "_on_bound_head_skill_activated")
	if _bound_head.has_signal("head_skill_activated") and _bound_head.is_connected("head_skill_activated", activated_callable):
		_bound_head.disconnect("head_skill_activated", activated_callable)

	var broken_callable: Callable = Callable(self, "_on_bound_head_broken")
	if _bound_head.has_signal("head_broken") and _bound_head.is_connected("head_broken", broken_callable):
		_bound_head.disconnect("head_broken", broken_callable)


func _on_bound_head_skill_activated(head: Node) -> void:
	if head != _bound_head:
		return
	if _state == HeadState.BROKEN or _state == HeadState.COUNTDOWN:
		return
	_queued_countdown_start = true
	if _state == HeadState.WAITING_TRIGGER:
		_begin_countdown()


func _on_bound_head_broken(head: Node) -> void:
	if head != _bound_head:
		return
	if _state == HeadState.COUNTDOWN:
		return
	if _state == HeadState.HIT and _resume_state_after_hit == HeadState.COUNTDOWN:
		return
	if _state != HeadState.BROKEN:
		_abort_cycle()


func _pick_bind_target() -> Node2D:
	var candidates: Array[Node2D] = []
	if _controller_driven:
		for candidate in _controller_bind_candidates:
			if not _is_valid_bound_target(candidate):
				continue
			candidates.append(candidate)
	else:
		for node in get_tree().get_nodes_in_group(JUDGEMENT_HEAD_GROUP):
			if node == self:
				continue
			if node is not Node2D:
				continue
			var candidate: Node2D = node as Node2D
			if not _is_valid_bound_target(candidate):
				continue
			candidates.append(candidate)

	if candidates.is_empty():
		return null

	var candidate_index: int = _rng.randi_range(0, candidates.size() - 1)
	return candidates[candidate_index]


func _pick_marked_side() -> StringName:
	var candidates: Array[StringName] = []
	if not _left_platform_spans.is_empty():
		candidates.append(PLATFORM_SIDE_LEFT)
	if not _right_platform_spans.is_empty():
		candidates.append(PLATFORM_SIDE_RIGHT)
	if candidates.is_empty():
		return &""
	var candidate_index: int = _rng.randi_range(0, candidates.size() - 1)
	return candidates[candidate_index]


func _is_valid_bound_target(candidate: Node2D) -> bool:
	if candidate == null:
		return false
	if not is_instance_valid(candidate):
		return false
	if candidate == self:
		return false
	if candidate.has_method("is_dead") and candidate.call("is_dead"):
		return false
	if not candidate.has_signal("head_skill_activated"):
		return false
	return true


func _resolve_head_kind(head: Node) -> StringName:
	if head == null:
		return &""
	if head.has_method("get_judgement_head_kind"):
		return head.call("get_judgement_head_kind")
	return &""


func _color_for_head_kind(head_kind: StringName) -> Color:
	match head_kind:
		&"wind":
			return wind_eye_color
		&"restore":
			return restore_eye_color
		&"guard":
			return guard_eye_color
		&"thunder":
			return thunder_eye_color
		&"fire":
			return fire_eye_color
		_:
			return Color(0.86, 0.86, 0.86, 0.92)


func _set_mark_direction(direction: int) -> void:
	if visuals == null:
		return
	if direction < 0:
		visuals.scale = Vector2(1.0, 1.0)
	elif direction > 0:
		visuals.scale = Vector2(-1.0, 1.0)
	else:
		visuals.scale = Vector2(1.0, 1.0)


func _collect_platform_spans() -> void:
	_left_platform_spans.clear()
	_right_platform_spans.clear()
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var room_center_x: float = 0.0
	var background_node: Node = current_scene.get_node_or_null("Map/Background")
	if background_node is Sprite2D:
		var background: Sprite2D = background_node as Sprite2D
		var texture_size: Vector2 = background.texture.get_size() if background.texture != null else Vector2.ZERO
		var background_scale: Vector2 = background.global_scale
		var world_size: Vector2 = Vector2(texture_size.x * background_scale.x, texture_size.y * background_scale.y)
		var world_top_left: Vector2 = background.global_position
		if background.centered:
			world_top_left -= world_size * 0.5
		room_center_x = world_top_left.x + world_size.x * 0.5

	var platforms_node: Node = current_scene.get_node_or_null("Map/Platforms")
	if platforms_node == null:
		return

	for child in platforms_node.get_children():
		if child is not CollisionPolygon2D:
			continue
		var span: Dictionary = _extract_top_surface_from_polygon(child as CollisionPolygon2D)
		if span.is_empty():
			continue
		var mid_x: float = (float(span.get("x_min", 0.0)) + float(span.get("x_max", 0.0))) * 0.5
		if mid_x < room_center_x:
			_left_platform_spans.append(span)
		else:
			_right_platform_spans.append(span)


func _extract_top_surface_from_polygon(collision_polygon: CollisionPolygon2D) -> Dictionary:
	var points: PackedVector2Array = collision_polygon.polygon
	if points.size() < 2:
		return {}

	var best_y: float = INF
	var best_x_min: float = 0.0
	var best_x_max: float = 0.0
	for index in range(points.size()):
		var next_index: int = (index + 1) % points.size()
		var point_a: Vector2 = collision_polygon.to_global(points[index])
		var point_b: Vector2 = collision_polygon.to_global(points[next_index])
		if absf(point_a.y - point_b.y) > 1.5:
			continue
		var edge_y: float = (point_a.y + point_b.y) * 0.5
		if edge_y < best_y:
			best_y = edge_y
			best_x_min = minf(point_a.x, point_b.x)
			best_x_max = maxf(point_a.x, point_b.x)

	if best_y == INF:
		return {}
	return {
		"x_min": best_x_min,
		"x_max": best_x_max,
		"y": best_y,
	}


func _on_animated_sprite_animation_finished() -> void:
	match _state:
		HeadState.ACTIVE_LEFT, HeadState.ACTIVE_RIGHT:
			_enter_state(HeadState.CAST)
		HeadState.CAST:
			_begin_waiting_for_trigger()
		HeadState.HIT:
			_resume_from_hit()
		_:
			pass


func _refresh_target() -> void:
	if _is_valid_target(_target):
		return

	_target = null
	if not target_path.is_empty():
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

	if _target is PhysicsBody2D:
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


func _update_hit_flash(delta: float) -> void:
	if visuals == null:
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		var blend_t: float = 0.0
		if hit_flash_duration > 0.0:
			blend_t = _hit_flash_timer / hit_flash_duration
		visuals.modulate = Color(1, 1, 1, 1).lerp(hit_flash_color, blend_t)
	else:
		visuals.modulate = Color(1, 1, 1, 1)


func _apply_collision_profile() -> void:
	if is_dead():
		collision_layer = 0
		collision_mask = 0
		return

	collision_layer = _layer_bit(CHARACTER_LAYER)
	collision_mask = 0


func _apply_guard_reflect(raw_damage: float, source: Node) -> void:
	if _guard_mark_source == null:
		return
	if not is_instance_valid(_guard_mark_source):
		clear_guard_mark()
		return

	var attacker: Node = _resolve_attacker_body(source)
	if attacker == null:
		return
	if attacker == self or attacker == _guard_mark_source:
		return

	var reflected_damage: float = maxf(0.0, raw_damage * _guard_reflect_ratio)
	if reflected_damage <= 0.0:
		return
	if attacker.has_method("apply_damage"):
		attacker.call("apply_damage", reflected_damage)
	if attacker.has_method("trigger_hit_flash"):
		attacker.call("trigger_hit_flash")


func _resolve_attacker_body(source: Node) -> Node:
	var current: Node = source
	while current != null:
		if current is CharacterBody2D:
			return current
		current = current.get_parent()
	return null


func _get_effective_state() -> HeadState:
	if _state == HeadState.HIT:
		return _resume_state_after_hit
	return _state


func get_fire_binding_visual_data() -> Dictionary:
	if _state == HeadState.BROKEN:
		return {"visible": false}

	var effective_state: HeadState = _get_effective_state()
	var show_overlay: bool = effective_state in [HeadState.ACTIVE_LEFT, HeadState.ACTIVE_RIGHT, HeadState.CAST]
	if not show_overlay:
		return {"visible": false}

	var pulse_speed: float = 4.0 if effective_state == HeadState.ACTIVE_LEFT or effective_state == HeadState.ACTIVE_RIGHT else 7.0
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed)
	var eye_alpha_scale: float = 0.38
	if effective_state == HeadState.CAST:
		eye_alpha_scale = 0.78
	elif effective_state == HeadState.WAITING_TRIGGER:
		eye_alpha_scale = 0.62 + pulse * 0.12
	elif effective_state == HeadState.COUNTDOWN:
		eye_alpha_scale = 0.72 + pulse * 0.18

	return {
		"visible": true,
		"state": int(effective_state),
		"base_color": _eye_glow_color,
		"is_guard_kind": _bound_head_kind == &"guard",
		"eye_alpha_scale": eye_alpha_scale,
	}


func _layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
