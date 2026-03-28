extends CharacterBody2D
class_name JudgementWindHead

signal head_skill_activated(head: Node)
signal head_cycle_finished(head: Node)
signal head_damaged(head: Node, source: Node)
signal head_broken(head: Node)

enum HeadState {
	IDLE,
	ACTIVE,
	CAST,
	WIND_ACTIVE,
	HIT,
	BROKEN,
}

const CHARACTER_LAYER := 2
const ENEMY_COLLISION_GROUP := &"enemy_bodies"
const JUDGEMENT_HEAD_GROUP := &"judgement_head_units"
const CAST_TRIGGER_FRAME := 3
const HEAD_KIND := &"wind"

@export var target_path: NodePath

@export_group("Combat Stats")
@export var max_hp: float = 2000.0
@export_range(0.05, 1.0, 0.05) var starting_hp_ratio: float = 1.0
@export var hit_flash_duration: float = 0.12
@export var hit_flash_color: Color = Color(1.0, 0.42, 0.42, 1.0)

@export_group("Wind Cycle")
@export var initial_cycle_delay_sec: float = 1.0
@export var cycle_interval_sec: float = 3.5
@export var hit_recover_delay_sec: float = 0.8
@export var wind_field_duration_sec: float = 3.2
@export_range(0.1, 1.0, 0.05) var wind_slow_scale: float = 0.275
@export_range(0.1, 1.0, 0.05) var wind_jump_scale: float = 0.5

@export_group("Guard Mark")
@export var guard_mark_color: Color = Color(0.70, 0.78, 0.86, 0.42)
@export var guard_mark_core_color: Color = Color(0.92, 0.95, 1.0, 0.86)
@export var guard_mark_radius: float = 26.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var status_bars: EnemyStatusBars = $StatusBars
@onready var wind_field: JudgementWindField = $WindField

var _state: HeadState = HeadState.IDLE
var _current_hp: float = 0.0
var _cycle_cooldown_left: float = 0.0
var _field_time_left: float = 0.0
var _hit_flash_timer: float = 0.0
var _field_triggered_in_cast: bool = false
var _target: Node2D
var _registered_collision_exception_ids: Dictionary = {}
var _guard_mark_source: Node2D
var _guard_reflect_ratio: float = 1.0
var _controller_driven: bool = false
var _cycle_in_progress: bool = false


func _ready() -> void:
	add_to_group(ENEMY_COLLISION_GROUP)
	add_to_group(JUDGEMENT_HEAD_GROUP)
	_current_hp = clampf(max_hp * starting_hp_ratio, 1.0, max_hp)
	_cycle_cooldown_left = initial_cycle_delay_sec
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	_refresh_target()
	_sync_nonblocking_collisions()
	_apply_collision_profile()
	var slow_key: StringName = StringName("judgement_wind_field_%s" % get_instance_id())
	wind_field.configure(self, slow_key, wind_slow_scale, wind_jump_scale)
	_fit_wind_field_to_room_background()
	wind_field.set_field_active(false)
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
		HeadState.WIND_ACTIVE:
			_field_time_left = maxf(0.0, _field_time_left - delta)
			if _field_time_left <= 0.0:
				_deactivate_wind_field()
				if _controller_driven and _cycle_in_progress:
					_cycle_in_progress = false
					head_cycle_finished.emit(self)
				else:
					_cycle_cooldown_left = cycle_interval_sec
				_enter_state(HeadState.IDLE)
		_:
			pass

	_apply_collision_profile()
	if _guard_mark_source != null:
		queue_redraw()


func receive_weapon_hit(attack_data: Dictionary, _source: Node) -> void:
	if is_dead():
		return

	var raw_damage: float = maxf(0.0, float(attack_data.get("damage", 0.0)))
	if raw_damage > 0.0:
		head_damaged.emit(self, _source)
	apply_damage(raw_damage)
	_apply_guard_reflect(raw_damage, _source)
	if is_dead():
		return

	trigger_hit_flash()


func receive_grabbed_weapon_hit(attack_data: Dictionary, _source: Node) -> void:
	if is_dead():
		return

	var raw_damage: float = maxf(0.0, float(attack_data.get("damage", 0.0)))
	if raw_damage > 0.0:
		head_damaged.emit(self, _source)
	apply_damage(raw_damage)
	_apply_guard_reflect(raw_damage, _source)
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

	_deactivate_wind_field()
	clear_guard_mark()
	_state = HeadState.BROKEN
	velocity = Vector2.ZERO
	_apply_collision_profile()
	update_status_bars()
	animated_sprite.play(&"break")
	head_broken.emit(self)


func is_dead() -> bool:
	return _state == HeadState.BROKEN


func can_receive_head_heal() -> bool:
	return not is_dead() and _current_hp < max_hp


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


func _interrupt_cycle_with_hit() -> void:
	if _state == HeadState.BROKEN:
		return
	if _state == HeadState.HIT:
		return

	if not wind_field.is_field_active():
		_cycle_cooldown_left = maxf(_cycle_cooldown_left, hit_recover_delay_sec)
		_field_triggered_in_cast = false

	_enter_state(HeadState.HIT)


func _enter_state(next_state: HeadState) -> void:
	_state = next_state
	match next_state:
		HeadState.IDLE:
			animated_sprite.play(&"idle")
		HeadState.ACTIVE:
			animated_sprite.play(&"active")
		HeadState.CAST:
			_field_triggered_in_cast = false
			animated_sprite.play(&"cast")
		HeadState.WIND_ACTIVE:
			animated_sprite.play(&"idle")
		HeadState.HIT:
			animated_sprite.play(&"hit")
		HeadState.BROKEN:
			animated_sprite.play(&"break")


func _activate_wind_field() -> void:
	_field_triggered_in_cast = true
	_field_time_left = wind_field_duration_sec
	wind_field.set_field_active(true)
	head_skill_activated.emit(self)


func _deactivate_wind_field() -> void:
	_field_time_left = 0.0
	_field_triggered_in_cast = false
	wind_field.set_field_active(false)


func _on_animated_sprite_frame_changed() -> void:
	if _state != HeadState.CAST:
		return
	if _field_triggered_in_cast:
		return
	if animated_sprite.frame < CAST_TRIGGER_FRAME:
		return

	_activate_wind_field()


func _on_animated_sprite_animation_finished() -> void:
	match _state:
		HeadState.ACTIVE:
			_enter_state(HeadState.CAST)
		HeadState.CAST:
			if not _field_triggered_in_cast:
				_activate_wind_field()
			_enter_state(HeadState.WIND_ACTIVE)
		HeadState.HIT:
			if wind_field.is_field_active() and _field_time_left > 0.0:
				_enter_state(HeadState.WIND_ACTIVE)
			else:
				if _controller_driven and _cycle_in_progress:
					_cycle_in_progress = false
					head_cycle_finished.emit(self)
				_enter_state(HeadState.IDLE)
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


func _fit_wind_field_to_room_background() -> void:
	if wind_field == null:
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var background_node: Node = current_scene.get_node_or_null("Map/Background")
	if background_node is not Sprite2D:
		return

	var background: Sprite2D = background_node as Sprite2D
	if background.texture == null:
		return

	var texture_size: Vector2 = background.texture.get_size()
	var global_scale_value: Vector2 = background.global_scale
	var world_size: Vector2 = Vector2(texture_size.x * global_scale_value.x, texture_size.y * global_scale_value.y)
	var world_top_left: Vector2 = background.global_position
	if background.centered:
		world_top_left -= world_size * 0.5
	var world_center: Vector2 = world_top_left + world_size * 0.5

	wind_field.global_position = world_center
	var collision_shape: CollisionShape2D = wind_field.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return
	if collision_shape.shape is not RectangleShape2D:
		return

	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	rect_shape.size = world_size
	collision_shape.position = Vector2.ZERO
	wind_field.queue_redraw()


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


func _layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
