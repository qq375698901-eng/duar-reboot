extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 7.5
@export var lookahead_distance: float = 48.0
@export var vertical_offset: float = -18.0
@export var velocity_influence: float = 0.12

var _target: Node2D


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D


func _physics_process(delta: float) -> void:
	if _target == null:
		return

	var desired := _target.global_position + Vector2(0.0, vertical_offset)
	var lookahead_x := 0.0

	if _target is CharacterBody2D:
		var body := _target as CharacterBody2D
		lookahead_x = clampf(body.velocity.x * velocity_influence, -lookahead_distance, lookahead_distance)

	desired.x += lookahead_x
	global_position = global_position.lerp(desired, clampf(delta * follow_speed, 0.0, 1.0))
