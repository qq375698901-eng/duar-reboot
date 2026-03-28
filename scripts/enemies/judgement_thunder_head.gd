extends CharacterBody2D
class_name JudgementThunderHead

signal head_skill_activated(head: Node)
signal head_cycle_finished(head: Node)
signal head_damaged(head: Node, source: Node)
signal head_broken(head: Node)

enum HeadState {
	IDLE,
	ACTIVE,
	CAST,
	WARNINGS_ACTIVE,
	HIT,
	BROKEN,
}

const CHARACTER_LAYER := 2
const ENEMY_COLLISION_GROUP := &"enemy_bodies"
const JUDGEMENT_HEAD_GROUP := &"judgement_head_units"
const THUNDER_STRIKE_SCENE := preload("res://scenes/hazards/judgement_thunder_strike.tscn")
const HEAD_KIND := &"thunder"

@export var target_path: NodePath

@export_group("Combat Stats")
@export var max_hp: float = 2000.0
@export var hit_flash_duration: float = 0.12
@export var hit_flash_color: Color = Color(1.0, 0.42, 0.42, 1.0)

@export_group("Thunder Cycle")
@export var initial_cycle_delay_sec: float = 1.2
@export var cycle_interval_sec: float = 3.8
@export var hit_recover_delay_sec: float = 1.0
@export var warning_duration_sec: float = 1.5
@export var strike_duration_sec: float = 0.18
@export var strikes_per_cast: int = 10
@export var strike_damage: float = 11.0
@export var strike_width: float = 18.0
@export var strike_launch_height_px: float = 52.0
@export var strike_launch_distance_px: float = 26.0

@export_group("Surface Sampling")
@export var strike_surface_margin_px: float = 14.0
@export var strike_min_spacing_px: float = 24.0
@export var strike_sampling_attempts: int = 140

@export_group("Guard Mark")
@export var guard_mark_color: Color = Color(0.70, 0.78, 0.86, 0.42)
@export var guard_mark_core_color: Color = Color(0.92, 0.95, 1.0, 0.86)
@export var guard_mark_radius: float = 26.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var status_bars: EnemyStatusBars = $StatusBars
@onready var guard_mark_overlay: Node2D = $GuardMarkOverlay
@onready var strikes_root: Node2D = $StrikesRoot

var _state: HeadState = HeadState.IDLE
var _current_hp: float = 0.0
var _cycle_cooldown_left: float = 0.0
var _hit_flash_timer: float = 0.0
var _target: Node2D
var _registered_collision_exception_ids: Dictionary = {}
var _guard_mark_source: Node2D
var _guard_reflect_ratio: float = 1.0
var _surface_spans: Array[Dictionary] = []
var _room_top_y: float = 0.0
var _active_strike_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _controller_driven: bool = false
var _cycle_in_progress: bool = false


func _ready() -> void:
	add_to_group(ENEMY_COLLISION_GROUP)
	add_to_group(JUDGEMENT_HEAD_GROUP)
	_rng.randomize()
	_current_hp = max_hp
	_cycle_cooldown_left = initial_cycle_delay_sec
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	_refresh_target()
	_sync_nonblocking_collisions()
	_collect_surface_spans()
	_apply_collision_profile()
	update_status_bars()
	_enter_state(HeadState.IDLE)


func _physics_process(delta: float) -> void:
	_refresh_target()
	_sync_nonblocking_collisions()
	_update_hit_flash(delta)

	if _state == HeadState.BROKEN:
		return

	match _state:
		HeadState.IDLE:
			if not _controller_driven:
				_cycle_cooldown_left = maxf(0.0, _cycle_cooldown_left - delta)
				if _cycle_cooldown_left <= 0.0:
					_enter_state(HeadState.ACTIVE)
		HeadState.WARNINGS_ACTIVE:
			if _active_strike_count <= 0:
				if _controller_driven and _cycle_in_progress:
					_cycle_in_progress = false
					head_cycle_finished.emit(self)
					_cycle_cooldown_left = 0.0
				else:
					_cycle_cooldown_left = cycle_interval_sec
				_enter_state(HeadState.IDLE)
		_:
			pass

	_apply_collision_profile()


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


func is_available_for_controller() -> bool:
	return not is_dead() and _state == HeadState.IDLE


func begin_controlled_skill_cycle() -> bool:
	if not is_available_for_controller():
		return false
	_controller_driven = true
	_cycle_in_progress = true
	_enter_state(HeadState.ACTIVE)
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

	clear_guard_mark()
	_clear_active_strikes()
	_state = HeadState.BROKEN
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
			animated_sprite.play(&"idle")
		HeadState.ACTIVE:
			animated_sprite.play(&"active")
		HeadState.CAST:
			animated_sprite.play(&"cast")
		HeadState.WARNINGS_ACTIVE:
			animated_sprite.play(&"idle")
		HeadState.HIT:
			animated_sprite.play(&"hit")
		HeadState.BROKEN:
			animated_sprite.play(&"break")


func _spawn_thunder_warnings() -> void:
	_clear_active_strikes()
	var strike_points: Array[Vector2] = _generate_strike_points()
	if strike_points.is_empty():
		if _controller_driven and _cycle_in_progress:
			_cycle_in_progress = false
			head_cycle_finished.emit(self)
			_cycle_cooldown_left = 0.0
		else:
			_cycle_cooldown_left = 1.0
		_enter_state(HeadState.IDLE)
		return

	var attack_payload: Dictionary = {
		"attack_id": "judgement_thunder_head_strike",
		"damage": strike_damage,
		"hit_effect": "launch",
		"launch_height_px": strike_launch_height_px,
		"launch_distance_px": strike_launch_distance_px,
	}

	for point in strike_points:
		var strike: JudgementThunderStrike = THUNDER_STRIKE_SCENE.instantiate() as JudgementThunderStrike
		strikes_root.add_child(strike)
		var line_height: float = maxf(24.0, point.y - _room_top_y)
		strike.configure(self, attack_payload, point, _room_top_y, line_height)
		strike.warning_duration_sec = warning_duration_sec
		strike.strike_duration_sec = strike_duration_sec
		strike.strike_width = strike_width
		strike.strike_damage = strike_damage
		strike.strike_finished.connect(_on_thunder_strike_finished)
		_active_strike_count += 1

	_enter_state(HeadState.WARNINGS_ACTIVE)
	head_skill_activated.emit(self)


func _clear_active_strikes() -> void:
	_active_strike_count = 0
	if strikes_root == null:
		return
	for child in strikes_root.get_children():
		if child is JudgementThunderStrike:
			(child as JudgementThunderStrike).cancel_strike()
		elif child is Node:
			(child as Node).queue_free()


func _generate_strike_points() -> Array[Vector2]:
	if _surface_spans.is_empty():
		_collect_surface_spans()
	if _surface_spans.is_empty():
		return []

	var results: Array[Vector2] = []
	var attempts: int = 0
	while results.size() < strikes_per_cast and attempts < strike_sampling_attempts:
		attempts += 1
		var span: Dictionary = _surface_spans[_rng.randi_range(0, _surface_spans.size() - 1)]
		var x_min: float = float(span.get("x_min", 0.0)) + strike_surface_margin_px
		var x_max: float = float(span.get("x_max", 0.0)) - strike_surface_margin_px
		if x_max <= x_min:
			continue
		var sample_x: float = _rng.randf_range(x_min, x_max)
		var sample_y: float = float(span.get("y", 0.0))
		var too_close: bool = false
		for existing_point in results:
			if absf(existing_point.x - sample_x) < strike_min_spacing_px and absf(existing_point.y - sample_y) < 8.0:
				too_close = true
				break
		if too_close:
			continue
		results.append(Vector2(sample_x, sample_y))

	if results.size() < strikes_per_cast:
		for span in _surface_spans:
			if results.size() >= strikes_per_cast:
				break
			var x_min: float = float(span.get("x_min", 0.0)) + strike_surface_margin_px
			var x_max: float = float(span.get("x_max", 0.0)) - strike_surface_margin_px
			if x_max <= x_min:
				continue
			var fallback_point: Vector2 = Vector2((x_min + x_max) * 0.5, float(span.get("y", 0.0)))
			results.append(fallback_point)

	return results


func _collect_surface_spans() -> void:
	_surface_spans.clear()
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var background_node: Node = current_scene.get_node_or_null("Map/Background")
	if background_node is Sprite2D:
		var background: Sprite2D = background_node as Sprite2D
		var texture_size: Vector2 = background.texture.get_size() if background.texture != null else Vector2.ZERO
		var background_scale: Vector2 = background.global_scale
		var world_size: Vector2 = Vector2(texture_size.x * background_scale.x, texture_size.y * background_scale.y)
		var world_top_left: Vector2 = background.global_position
		if background.centered:
			world_top_left -= world_size * 0.5
		_room_top_y = world_top_left.y

	var platforms_node: Node = current_scene.get_node_or_null("Map/Platforms")
	if platforms_node != null:
		for child in platforms_node.get_children():
			if child is CollisionPolygon2D:
				var platform_span: Dictionary = _extract_top_surface_from_polygon(child as CollisionPolygon2D)
				if not platform_span.is_empty():
					_surface_spans.append(platform_span)

	var ground_node: Node = current_scene.get_node_or_null("Map/Ground")
	var floor_span: Dictionary = {}
	if ground_node != null:
		for child in ground_node.get_children():
			if child is not CollisionPolygon2D:
				continue
			var ground_span: Dictionary = _extract_lowest_surface_from_polygon(child as CollisionPolygon2D)
			if ground_span.is_empty():
				continue
			if floor_span.is_empty() or float(ground_span.get("y", 0.0)) > float(floor_span.get("y", 0.0)):
				floor_span = ground_span
	if not floor_span.is_empty():
		_surface_spans.append(floor_span)


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


func _extract_lowest_surface_from_polygon(collision_polygon: CollisionPolygon2D) -> Dictionary:
	var points: PackedVector2Array = collision_polygon.polygon
	if points.size() < 2:
		return {}
	var best_y: float = -INF
	var best_x_min: float = 0.0
	var best_x_max: float = 0.0
	for index in range(points.size()):
		var next_index: int = (index + 1) % points.size()
		var point_a: Vector2 = collision_polygon.to_global(points[index])
		var point_b: Vector2 = collision_polygon.to_global(points[next_index])
		if absf(point_a.y - point_b.y) > 1.5:
			continue
		var edge_y: float = (point_a.y + point_b.y) * 0.5
		if edge_y > best_y:
			best_y = edge_y
			best_x_min = minf(point_a.x, point_b.x)
			best_x_max = maxf(point_a.x, point_b.x)
	if best_y == -INF:
		return {}
	return {
		"x_min": best_x_min,
		"x_max": best_x_max,
		"y": best_y,
	}


func _on_animated_sprite_animation_finished() -> void:
	match _state:
		HeadState.ACTIVE:
			_enter_state(HeadState.CAST)
		HeadState.CAST:
			_spawn_thunder_warnings()
		HeadState.HIT:
			if _state == HeadState.HIT:
				if _active_strike_count > 0:
					_enter_state(HeadState.WARNINGS_ACTIVE)
				else:
					if _controller_driven and _cycle_in_progress:
						_cycle_in_progress = false
						head_cycle_finished.emit(self)
					_enter_state(HeadState.IDLE)
		_:
			pass


func _on_thunder_strike_finished(_strike: JudgementThunderStrike) -> void:
	_active_strike_count = max(0, _active_strike_count - 1)


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


func _layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
