extends CharacterBody2D
class_name JudgementRestoreHead

signal head_skill_activated(head: Node)
signal head_cycle_finished(head: Node)
signal head_damaged(head: Node, source: Node)
signal head_broken(head: Node)

enum HeadState {
	IDLE,
	ACTIVE,
	CAST,
	HEALING,
	INTERRUPTED,
	HIT,
	BROKEN,
}

const CHARACTER_LAYER := 2
const ENEMY_COLLISION_GROUP := &"enemy_bodies"
const JUDGEMENT_HEAD_GROUP := &"judgement_head_units"
const HEAD_KIND := &"restore"

@export var target_path: NodePath

@export_group("Combat Stats")
@export var max_hp: float = 2000.0
@export var hit_flash_duration: float = 0.12
@export var hit_flash_color: Color = Color(1.0, 0.42, 0.42, 1.0)

@export_group("Healing Cycle")
@export var initial_cycle_delay_sec: float = 1.2
@export var cycle_interval_sec: float = 3.2
@export var interrupted_cycle_delay_sec: float = 1.2
@export var retarget_retry_interval_sec: float = 0.45
@export var heal_ramp_duration_sec: float = 6.0
@export var heal_tick_interval_start_sec: float = 1.05
@export var heal_tick_interval_min_sec: float = 0.18
@export var heal_per_tick_start: float = 2.0
@export var heal_per_tick_max: float = 10.0

@export_group("Heal Link")
@export var heal_link_color: Color = Color(0.65, 0.92, 0.72, 0.55)
@export var heal_link_core_color: Color = Color(0.90, 1.0, 0.94, 0.82)
@export var heal_link_width: float = 5.0
@export var heal_link_core_width: float = 2.2

@export_group("Guard Mark")
@export var guard_mark_color: Color = Color(0.70, 0.78, 0.86, 0.42)
@export var guard_mark_core_color: Color = Color(0.92, 0.95, 1.0, 0.86)
@export var guard_mark_radius: float = 26.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var status_bars: EnemyStatusBars = $StatusBars

var _state: HeadState = HeadState.IDLE
var _current_hp: float = 0.0
var _cycle_cooldown_left: float = 0.0
var _hit_flash_timer: float = 0.0
var _target: Node2D
var _heal_target: Node2D
var _heal_tick_left: float = 0.0
var _heal_channel_time: float = 0.0
var _registered_collision_exception_ids: Dictionary = {}
var _guard_mark_source: Node2D
var _guard_reflect_ratio: float = 1.0
var _controller_driven: bool = false
var _cycle_in_progress: bool = false


func _ready() -> void:
	add_to_group(ENEMY_COLLISION_GROUP)
	add_to_group(JUDGEMENT_HEAD_GROUP)
	_current_hp = max_hp
	_cycle_cooldown_left = initial_cycle_delay_sec
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	_refresh_target()
	_sync_nonblocking_collisions()
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
					_enter_state(HeadState.ACTIVE)
		HeadState.HEALING:
			_update_healing(delta)
		_:
			pass

	_apply_collision_profile()
	queue_redraw()


func _draw() -> void:
	if _state != HeadState.HEALING:
		return
	if not _is_valid_heal_target(_heal_target):
		return

	var local_target: Vector2 = to_local(_heal_target.global_position + Vector2(0.0, -26.0))
	var origin: Vector2 = Vector2(0.0, -32.0)
	var time_value: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 0.5 + 0.5 * sin(time_value * 5.0)
	var curve_height: float = -18.0 - pulse * 8.0
	var mid_point: Vector2 = (origin + local_target) * 0.5 + Vector2(0.0, curve_height)
	var points: PackedVector2Array = PackedVector2Array([origin, mid_point, local_target])

	var glow_color: Color = heal_link_color
	glow_color.a *= 0.76 + pulse * 0.12
	draw_polyline(points, glow_color, heal_link_width, true)

	var core_color: Color = heal_link_core_color
	core_color.a *= 0.84 + pulse * 0.12
	draw_polyline(points, core_color, heal_link_core_width, true)

	draw_circle(origin, 5.5 + pulse * 1.2, Color(core_color.r, core_color.g, core_color.b, 0.30))
	draw_circle(local_target, 6.0 + pulse * 1.4, Color(core_color.r, core_color.g, core_color.b, 0.28))


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
	if _state == HeadState.HEALING or _state == HeadState.CAST:
		_interrupt_healing_cycle()


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
	if _state == HeadState.HEALING or _state == HeadState.CAST:
		_interrupt_healing_cycle()


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

	_heal_target = null
	_heal_tick_left = 0.0
	_heal_channel_time = 0.0
	clear_guard_mark()
	_state = HeadState.BROKEN
	velocity = Vector2.ZERO
	_apply_collision_profile()
	update_status_bars()
	animated_sprite.play(&"break")
	queue_redraw()
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
		HeadState.HEALING:
			animated_sprite.play(&"cast")
		HeadState.INTERRUPTED:
			animated_sprite.play(&"hit")
		HeadState.HIT:
			animated_sprite.play(&"hit")
		HeadState.BROKEN:
			animated_sprite.play(&"break")


func _begin_healing(target: Node2D) -> void:
	_heal_target = target
	_heal_channel_time = 0.0
	_heal_tick_left = 0.0
	_enter_state(HeadState.HEALING)
	head_skill_activated.emit(self)


func _finish_healing_cycle(cooldown_sec: float = cycle_interval_sec) -> void:
	_heal_target = null
	_heal_tick_left = 0.0
	_heal_channel_time = 0.0
	if _controller_driven and _cycle_in_progress:
		_cycle_in_progress = false
		head_cycle_finished.emit(self)
		_cycle_cooldown_left = 0.0
	else:
		_cycle_cooldown_left = cooldown_sec
	_enter_state(HeadState.IDLE)


func _interrupt_healing_cycle() -> void:
	_heal_target = null
	_heal_tick_left = 0.0
	_heal_channel_time = 0.0
	if _controller_driven and _cycle_in_progress:
		_cycle_in_progress = false
		head_cycle_finished.emit(self)
		_cycle_cooldown_left = 0.0
	else:
		_cycle_cooldown_left = interrupted_cycle_delay_sec
	_enter_state(HeadState.INTERRUPTED)


func _update_healing(delta: float) -> void:
	_heal_channel_time += delta
	_heal_tick_left = maxf(0.0, _heal_tick_left - delta)

	if not _is_valid_heal_target(_heal_target):
		_finish_healing_cycle(retarget_retry_interval_sec)
		return

	if _heal_tick_left > 0.0:
		return

	var ramp_t: float = 1.0
	if heal_ramp_duration_sec > 0.0:
		ramp_t = clampf(_heal_channel_time / heal_ramp_duration_sec, 0.0, 1.0)

	var current_tick_interval: float = lerpf(heal_tick_interval_start_sec, heal_tick_interval_min_sec, ramp_t)
	var current_heal_per_tick: float = lerpf(heal_per_tick_start, heal_per_tick_max, ramp_t)
	_heal_tick_left = maxf(0.05, current_tick_interval)
	if _heal_target.has_method("apply_head_heal"):
		_heal_target.call("apply_head_heal", current_heal_per_tick)
	if not _is_valid_heal_target(_heal_target):
		_finish_healing_cycle(cycle_interval_sec)


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


func _on_animated_sprite_animation_finished() -> void:
	match _state:
		HeadState.ACTIVE:
			_enter_state(HeadState.CAST)
		HeadState.CAST:
			var chosen_target: Node2D = _pick_heal_target()
			if chosen_target == null:
				_finish_healing_cycle(1.0)
				return
			_begin_healing(chosen_target)
		HeadState.HEALING:
			if _state == HeadState.HEALING:
				animated_sprite.play(&"cast")
		HeadState.INTERRUPTED:
			_enter_state(HeadState.IDLE)
		_:
			pass


func _pick_heal_target() -> Node2D:
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(JUDGEMENT_HEAD_GROUP):
		if node == self:
			continue
		if node is not Node2D:
			continue
		var candidate: Node2D = node as Node2D
		if not _is_valid_heal_target(candidate):
			continue
		candidates.append(candidate)

	if candidates.is_empty():
		return null

	var candidate_index: int = randi() % candidates.size()
	return candidates[candidate_index]


func _is_valid_heal_target(candidate: Node2D) -> bool:
	if candidate == null:
		return false
	if not is_instance_valid(candidate):
		return false
	if candidate == self:
		return false
	if candidate.has_method("is_dead") and candidate.call("is_dead"):
		return false
	if not candidate.has_method("can_receive_head_heal"):
		return false
	return bool(candidate.call("can_receive_head_heal"))


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


func _layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
