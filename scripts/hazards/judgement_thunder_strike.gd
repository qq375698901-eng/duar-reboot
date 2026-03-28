extends Node2D
class_name JudgementThunderStrike

signal strike_finished(strike: JudgementThunderStrike)

const ENEMY_COLLISION_GROUP := &"enemy_bodies"

enum StrikeState {
	WARNING,
	STRIKING,
	FINISHED,
}

@export var warning_duration_sec: float = 1.5
@export var strike_duration_sec: float = 0.18
@export var strike_width: float = 18.0
@export var strike_damage: float = 12.0
@export var strike_stun_duration_sec: float = 0.24
@export var warning_ring_color: Color = Color(0.86, 0.92, 1.0, 0.62)
@export var warning_core_color: Color = Color(0.70, 0.82, 1.0, 0.24)
@export var strike_glow_color: Color = Color(0.82, 0.90, 1.0, 0.34)
@export var strike_core_color: Color = Color(0.96, 0.98, 1.0, 0.94)

@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = $HitArea/CollisionShape2D

var owner_body: Node
var attack_payload: Dictionary = {}
var strike_height: float = 0.0
var strike_top_y: float = 0.0
var strike_surface_y: float = 0.0
var _state: StrikeState = StrikeState.WARNING
var _state_time_left: float = 0.0
var _hit_targets: Dictionary = {}


func _ready() -> void:
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	hit_area.monitoring = false
	hit_area.monitorable = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_state_time_left = warning_duration_sec


func _physics_process(delta: float) -> void:
	if _state == StrikeState.FINISHED:
		return

	_state_time_left = maxf(0.0, _state_time_left - delta)
	if _state == StrikeState.WARNING:
		if _state_time_left <= 0.0:
			_begin_strike()
	elif _state == StrikeState.STRIKING:
		if _state_time_left <= 0.0:
			_finish_strike()

	queue_redraw()


func configure(owner_node: Node, payload: Dictionary, surface_point: Vector2, room_top_y: float, line_height: float) -> void:
	owner_body = owner_node
	attack_payload = payload.duplicate(true)
	global_position = surface_point
	strike_surface_y = surface_point.y
	strike_top_y = room_top_y
	strike_height = maxf(24.0, line_height)
	_configure_hit_shape()


func cancel_strike() -> void:
	if _state == StrikeState.FINISHED:
		return
	_finish_strike()


func _configure_hit_shape() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is not RectangleShape2D:
		return
	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	rect_shape.size = Vector2(strike_width, strike_height)
	collision_shape.position = Vector2(0.0, -strike_height * 0.5)


func _begin_strike() -> void:
	_state = StrikeState.STRIKING
	_state_time_left = strike_duration_sec
	_hit_targets.clear()
	hit_area.set_deferred("monitoring", true)
	hit_area.set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	call_deferred("_emit_existing_overlaps")


func _finish_strike() -> void:
	_state = StrikeState.FINISHED
	_state_time_left = 0.0
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_redraw()
	strike_finished.emit(self)
	queue_free()


func _emit_existing_overlaps() -> void:
	if _state != StrikeState.STRIKING:
		return

	for body in hit_area.get_overlapping_bodies():
		_try_hit_body(body)


func _on_hit_area_body_entered(body: Node) -> void:
	_try_hit_body(body)


func _try_hit_body(body: Node) -> void:
	if _state != StrikeState.STRIKING:
		return
	if not _is_valid_damage_target(body):
		return
	var body_id: int = body.get_instance_id()
	if _hit_targets.has(body_id):
		return
	_hit_targets[body_id] = true
	call_deferred("_deliver_hit_deferred", body, attack_payload.duplicate(true))


func _deliver_hit_deferred(body: Node, payload: Dictionary) -> void:
	if not _is_valid_damage_target(body):
		return

	if body.has_method("receive_weapon_hit"):
		body.call("receive_weapon_hit", payload, self)
		return

	var target_x: float = global_position.x
	if body is Node2D:
		target_x = (body as Node2D).global_position.x
	var source_is_on_left: bool = global_position.x < target_x
	if String(payload.get("hit_effect", "stun")) == "launch":
		if body.has_method("apply_launch_by_distance_from_source"):
			body.call(
				"apply_launch_by_distance_from_source",
				source_is_on_left,
				payload.get("launch_height_px", 0.0),
				payload.get("launch_distance_px", 0.0)
			)
	elif body.has_method("apply_stun_from_source"):
		body.call(
			"apply_stun_from_source",
			source_is_on_left,
			payload.get("stun_duration_sec", 0.0)
		)


func _is_valid_damage_target(body: Node) -> bool:
	if body == null:
		return false
	if not is_instance_valid(body):
		return false
	if body == owner_body:
		return false
	if body.is_in_group(ENEMY_COLLISION_GROUP):
		return false
	if body.has_method("is_dead") and body.call("is_dead"):
		return false
	return true


func _draw() -> void:
	if _state == StrikeState.FINISHED:
		return

	if _state == StrikeState.WARNING:
		_draw_warning()
	elif _state == StrikeState.STRIKING:
		_draw_strike()


func _draw_warning() -> void:
	var progress: float = 1.0
	if warning_duration_sec > 0.0:
		progress = clampf(1.0 - (_state_time_left / warning_duration_sec), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * 9.0)
	var ring_radius: float = 10.0 + progress * 9.0 + pulse * 1.8
	var ring_color: Color = warning_ring_color
	ring_color.a *= 0.72 + pulse * 0.16
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 28, ring_color, 2.0)
	draw_arc(Vector2.ZERO, ring_radius * 0.58, 0.0, TAU, 22, Color(warning_core_color.r, warning_core_color.g, warning_core_color.b, 0.38 + progress * 0.18), 1.4)
	draw_circle(Vector2.ZERO, 4.0 + pulse * 0.5, Color(warning_core_color.r, warning_core_color.g, warning_core_color.b, 0.24))

	var line_alpha: float = 0.08 + progress * 0.18
	var line_color: Color = Color(warning_ring_color.r, warning_ring_color.g, warning_ring_color.b, line_alpha)
	draw_line(Vector2(0.0, -strike_height), Vector2.ZERO, line_color, 1.4)


func _draw_strike() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * 32.0)
	var glow_width: float = strike_width * (0.72 + pulse * 0.22)
	var core_width: float = strike_width * 0.28
	var top_point: Vector2 = Vector2(0.0, -strike_height)
	var bottom_point: Vector2 = Vector2.ZERO

	var glow_color: Color = strike_glow_color
	glow_color.a *= 0.82 + pulse * 0.14
	draw_line(top_point, bottom_point, glow_color, glow_width)

	var core_color: Color = strike_core_color
	draw_line(top_point, bottom_point, core_color, core_width)
	draw_circle(bottom_point, strike_width * 0.85, Color(glow_color.r, glow_color.g, glow_color.b, 0.26))
