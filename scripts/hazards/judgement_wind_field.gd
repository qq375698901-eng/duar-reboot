extends Area2D
class_name JudgementWindField

signal field_enabled()
signal field_disabled()

@export var slow_scale: float = 0.55
@export var pulse_speed: float = 2.2
@export var mist_color: Color = Color(0.66, 0.75, 0.82, 0.10)
@export var ring_color: Color = Color(0.78, 0.87, 0.94, 0.18)
@export var swirl_color: Color = Color(0.88, 0.95, 0.98, 0.34)
@export var core_highlight_color: Color = Color(0.96, 0.98, 1.0, 0.22)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var owner_body: Node
var modifier_key: StringName = &""
var _active: bool = false
var _affected_body_ids: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = false
	monitorable = false
	visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	if _active:
		queue_redraw()


func _physics_process(_delta: float) -> void:
	if not _active:
		return

	_apply_existing_overlaps()


func _exit_tree() -> void:
	_clear_all_modifiers()


func configure(owner_node: Node, slow_modifier_key: StringName, resolved_slow_scale: float = -1.0) -> void:
	owner_body = owner_node
	modifier_key = slow_modifier_key
	if resolved_slow_scale > 0.0:
		slow_scale = resolved_slow_scale


func is_field_active() -> bool:
	return _active


func set_field_active(enabled: bool) -> void:
	if _active == enabled:
		if not enabled:
			_clear_all_modifiers()
		return

	_active = enabled
	visible = enabled
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", false)
	queue_redraw()

	if enabled:
		field_enabled.emit()
		call_deferred("_apply_existing_overlaps")
	else:
		_clear_all_modifiers()
		field_disabled.emit()


func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if not _is_valid_slow_target(body):
		return

	_apply_slow_to_body(body)


func _on_body_exited(body: Node) -> void:
	if body == null:
		return

	_clear_slow_from_body(body)


func _apply_existing_overlaps() -> void:
	if not _active:
		return

	for body in get_overlapping_bodies():
		if not _is_valid_slow_target(body):
			continue
		_apply_slow_to_body(body)


func _is_valid_slow_target(body: Node) -> bool:
	if body == null:
		return false
	if not is_instance_valid(body):
		return false
	if body == owner_body:
		return false
	if not body.has_method("set_movement_speed_modifier"):
		return false
	if not body.has_method("clear_movement_speed_modifier"):
		return false
	if body.has_method("is_dead") and body.call("is_dead"):
		return false
	return true


func _apply_slow_to_body(body: Node) -> void:
	if modifier_key == &"":
		return

	var body_id: int = body.get_instance_id()
	if _affected_body_ids.has(body_id):
		return

	_affected_body_ids[body_id] = true
	body.call("set_movement_speed_modifier", modifier_key, slow_scale)


func _clear_slow_from_body(body: Node) -> void:
	if body == null:
		return
	if not is_instance_valid(body):
		return
	if modifier_key == &"":
		return

	var body_id: int = body.get_instance_id()
	if not _affected_body_ids.has(body_id):
		return

	_affected_body_ids.erase(body_id)
	body.call("clear_movement_speed_modifier", modifier_key)


func _clear_all_modifiers() -> void:
	if modifier_key == &"":
		_affected_body_ids.clear()
		return

	var body_ids: Array = _affected_body_ids.keys()
	_affected_body_ids.clear()
	for body_id_variant in body_ids:
		var body_id: int = int(body_id_variant)
		var body: Node = instance_from_id(body_id) as Node
		if body == null or not is_instance_valid(body):
			continue
		if body.has_method("clear_movement_speed_modifier"):
			body.call("clear_movement_speed_modifier", modifier_key)


func _draw() -> void:
	if not _active:
		return
	if collision_shape == null:
		return
	var time_value: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 0.5 + 0.5 * sin(time_value * pulse_speed)

	if collision_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		var radius: float = circle_shape.radius
		var center: Vector2 = collision_shape.position
		var outer_radius: float = radius * (1.0 + pulse * 0.06)
		var inner_radius: float = radius * (0.68 + pulse * 0.04)
		var core_radius: float = radius * 0.36

		var outer_color: Color = ring_color
		outer_color.a *= 0.82 + pulse * 0.12
		draw_circle(center, outer_radius, mist_color)
		draw_circle(center, inner_radius, outer_color)
		draw_circle(center, core_radius, core_highlight_color)

		var swirl_count: int = 3
		for index in range(swirl_count):
			var base_angle: float = time_value * (0.9 + index * 0.18) + index * 1.6
			var arc_radius: float = radius * (0.42 + index * 0.17 + pulse * 0.03)
			var from_angle: float = base_angle
			var to_angle: float = base_angle + PI * (0.88 + index * 0.12)
			var arc_color: Color = swirl_color
			arc_color.a *= 0.68 - index * 0.12 + pulse * 0.08
			draw_arc(center, arc_radius, from_angle, to_angle, 24, arc_color, 2.0)

		var horizontal_glow: Color = core_highlight_color
		horizontal_glow.a *= 0.72 + pulse * 0.18
		draw_line(
			center + Vector2(-radius * 0.56, 0.0),
			center + Vector2(radius * 0.56, 0.0),
			horizontal_glow,
			1.8
		)
		return

	if collision_shape.shape is not RectangleShape2D:
		return

	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	var rect: Rect2 = Rect2(
		collision_shape.position - rect_shape.size * 0.5,
		rect_shape.size
	)
	_draw_room_wind_effect(rect, time_value, pulse)


func _draw_room_wind_effect(rect: Rect2, time_value: float, pulse: float) -> void:
	var outer_rect: Rect2 = rect.grow(12.0 + pulse * 5.0)
	var inner_rect: Rect2 = rect.grow(-14.0)
	var edge_color: Color = ring_color
	edge_color.a *= 0.9 + pulse * 0.08

	draw_rect(outer_rect, mist_color, true)
	draw_rect(rect, edge_color, false, 2.0)
	draw_rect(inner_rect, _scale_alpha(core_highlight_color, 0.4 + pulse * 0.1), false, 1.0)

	var band_count: int = 5
	for index in range(band_count):
		var band_y: float = lerpf(rect.position.y + 26.0, rect.end.y - 26.0, float(index) / float(max(1, band_count - 1)))
		var drift: float = sin(time_value * (1.2 + index * 0.17) + index * 1.4) * 16.0
		var band_color: Color = swirl_color
		band_color.a *= 0.38 + pulse * 0.08 - index * 0.04
		draw_line(
			Vector2(rect.position.x + 14.0 + drift, band_y),
			Vector2(rect.end.x - 14.0 + drift * 0.35, band_y),
			band_color,
			2.0
		)

	var column_count: int = 4
	for index in range(column_count):
		var x_ratio: float = (float(index) + 1.0) / float(column_count + 1)
		var swirl_center: Vector2 = Vector2(lerpf(rect.position.x, rect.end.x, x_ratio), rect.position.y + rect.size.y * (0.35 + 0.08 * sin(time_value + index)))
		var swirl_radius: float = 34.0 + pulse * 6.0 + index * 4.0
		var swirl_arc_color: Color = core_highlight_color
		swirl_arc_color.a *= 0.46 + pulse * 0.1
		draw_arc(swirl_center, swirl_radius, time_value * 0.8 + index, time_value * 0.8 + index + PI * 1.45, 20, swirl_arc_color, 1.8)

	var center_flash: Color = core_highlight_color
	center_flash.a *= 0.28 + pulse * 0.08
	draw_rect(
		Rect2(rect.position.x, rect.position.y + rect.size.y * 0.34, rect.size.x, rect.size.y * 0.32),
		center_flash,
		true
	)


func _scale_alpha(color: Color, alpha_scale: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha_scale)
