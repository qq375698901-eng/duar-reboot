extends Area2D

signal target_hit(target: Node, attack_id: StringName)

@export var attack_id: StringName
@export var show_debug_shape := true
@export var debug_inactive_color: Color = Color(1.0, 0.15, 0.15, 0.18)
@export var debug_active_color: Color = Color(1.0, 0.1, 0.1, 0.42)
@export var debug_outline_color: Color = Color(1.0, 0.3, 0.3, 0.95)

var _middle_phase_enabled := false
var _hit_targets: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = false
	monitorable = false
	_set_collision_shapes_enabled(false)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not _middle_phase_enabled:
		return

	_emit_existing_overlaps()


func get_attack_id() -> StringName:
	return attack_id


func set_middle_phase_enabled(enabled: bool) -> void:
	_middle_phase_enabled = enabled
	monitoring = enabled
	_set_collision_shapes_enabled(enabled)
	queue_redraw()
	if enabled:
		call_deferred("_emit_existing_overlaps")


func reset_hit_memory() -> void:
	_hit_targets.clear()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not _middle_phase_enabled:
		return
	if body == null:
		return
	if _hit_targets.has(body.get_instance_id()):
		return

	_hit_targets[body.get_instance_id()] = true
	target_hit.emit(body, attack_id)


func _emit_existing_overlaps() -> void:
	if not _middle_phase_enabled:
		return

	for body in get_overlapping_bodies():
		if body == null:
			continue
		if _hit_targets.has(body.get_instance_id()):
			continue

		_hit_targets[body.get_instance_id()] = true
		target_hit.emit(body, attack_id)


func _draw() -> void:
	if not show_debug_shape:
		return
	if not _middle_phase_enabled:
		return

	var fill_color := debug_active_color
	for child in get_children():
		if child is not CollisionShape2D:
			continue

		var collision_shape := child as CollisionShape2D
		if collision_shape.shape == null:
			continue

		if collision_shape.shape is RectangleShape2D:
			var rect_shape := collision_shape.shape as RectangleShape2D
			var rect := Rect2(
				collision_shape.position - rect_shape.size * 0.5,
				rect_shape.size
			)
			draw_rect(rect, fill_color, true)
			draw_rect(rect, debug_outline_color, false, 1.0)
		elif collision_shape.shape is CircleShape2D:
			var circle_shape := collision_shape.shape as CircleShape2D
			draw_circle(collision_shape.position, circle_shape.radius, fill_color)
			draw_arc(collision_shape.position, circle_shape.radius, 0.0, TAU, 24, debug_outline_color, 1.0)


func _set_collision_shapes_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = not enabled
