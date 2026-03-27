extends Area2D
class_name EnemyAttackHitbox2D

signal target_hit(target: Node, attack_id: StringName, attack_data: Dictionary)

@export var attack_id: StringName = &"attack"
@export var show_debug_shape := true
@export var debug_active_color: Color = Color(1.0, 0.28, 0.12, 0.4)
@export var debug_outline_color: Color = Color(1.0, 0.52, 0.35, 0.95)

var _active := false
var _owner_body: Node
var _attack_data: Dictionary = {}
var _hit_targets: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = false
	monitorable = false
	_set_collision_shapes_enabled(false)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not _active:
		return

	_emit_existing_overlaps()


func configure(owner_body: Node, attack_data: Dictionary) -> void:
	_owner_body = owner_body
	set_attack_data(attack_data)


func set_attack_data(attack_data: Dictionary) -> void:
	_attack_data = attack_data.duplicate(true)


func set_active(enabled: bool) -> void:
	_active = enabled
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)
	_set_collision_shapes_enabled(enabled)
	queue_redraw()
	if enabled:
		call_deferred("_emit_existing_overlaps")


func reset_hit_memory() -> void:
	_hit_targets.clear()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if body == null:
		return
	if body == _owner_body:
		return
	if _hit_targets.has(body.get_instance_id()):
		return

	_queue_target_hit(body)


func _emit_existing_overlaps() -> void:
	if not _active:
		return

	for body in get_overlapping_bodies():
		if body == null:
			continue
		if body == _owner_body:
			continue
		if _hit_targets.has(body.get_instance_id()):
			continue

		_queue_target_hit(body)


func _queue_target_hit(body: Node) -> void:
	if body == null:
		return

	_hit_targets[body.get_instance_id()] = true
	var payload := _attack_data.duplicate(true)
	call_deferred("_emit_target_hit_deferred", body, attack_id, payload)


func _emit_target_hit_deferred(body: Node, resolved_attack_id: StringName, attack_data: Dictionary) -> void:
	if body == null:
		return
	if not is_instance_valid(body):
		return
	if body == _owner_body:
		return

	target_hit.emit(body, resolved_attack_id, attack_data)


func _draw() -> void:
	if not show_debug_shape:
		return
	if not _active:
		return

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
			draw_rect(rect, debug_active_color, true)
			draw_rect(rect, debug_outline_color, false, 1.0)
		elif collision_shape.shape is CircleShape2D:
			var circle_shape := collision_shape.shape as CircleShape2D
			draw_circle(collision_shape.position, circle_shape.radius, debug_active_color)
			draw_arc(collision_shape.position, circle_shape.radius, 0.0, TAU, 24, debug_outline_color, 1.0)


func _set_collision_shapes_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not enabled)
