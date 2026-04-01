extends Node2D
class_name DungeonExitDoor2D

signal exit_interacted()
signal interaction_requested(peer_id: int)

const CLOSED_TEXTURE := preload("res://art/Medieval/PNG/Objects/door1.png")
const OPEN_TEXTURE := preload("res://art/Medieval/PNG/Objects/door2.png")

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var collision_shape: CollisionShape2D = $InteractArea/CollisionShape2D
@onready var prompt_label: Label = $PromptLabel

var _is_open: bool = false
var _player_inside_count: int = 0
var _local_interacting_peer_id: int = 1


func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_refresh_visual_state()


func _physics_process(_delta: float) -> void:
	_refresh_local_interaction_state()
	if not _is_open:
		return
	if _player_inside_count <= 0:
		return
	if _is_interact_up_just_pressed():
		if _should_route_interaction_to_network():
			interaction_requested.emit(_local_interacting_peer_id)
		return


func set_is_open(open: bool) -> void:
	if _is_open == open:
		_refresh_visual_state()
		return
	_is_open = open
	_refresh_visual_state()


func is_open() -> bool:
	return _is_open


func can_player_interact(player: Node) -> bool:
	return _is_open and _is_player_close_enough(player)


func force_singleplayer_interact(player: Node = null) -> bool:
	if not can_player_interact(player):
		return false
	_local_interacting_peer_id = _resolve_body_peer_id(player)
	exit_interacted.emit()
	return true


func _should_route_interaction_to_network() -> bool:
	return multiplayer.has_multiplayer_peer() and not get_signal_connection_list("interaction_requested").is_empty()


func _on_body_entered(body: Node) -> void:
	if not _is_local_interaction_body(body):
		return
	_player_inside_count += 1
	_local_interacting_peer_id = _resolve_body_peer_id(body)
	_refresh_visual_state()


func _on_body_exited(body: Node) -> void:
	if not _is_local_interaction_body(body):
		return
	_player_inside_count = max(0, _player_inside_count - 1)
	_refresh_visual_state()


func _refresh_visual_state() -> void:
	sprite.texture = OPEN_TEXTURE if _is_open else CLOSED_TEXTURE
	prompt_label.visible = _is_open and _player_inside_count > 0


func _refresh_local_interaction_state() -> void:
	if interact_area == null:
		return

	var overlapping_local_player_count: int = 0
	var resolved_peer_id: int = _local_interacting_peer_id
	for body in interact_area.get_overlapping_bodies():
		if not _is_local_interaction_body(body):
			continue
		overlapping_local_player_count += 1
		resolved_peer_id = _resolve_body_peer_id(body)

	if overlapping_local_player_count <= 0:
		var fallback_player: Node = _find_local_interaction_player()
		if _is_player_close_enough(fallback_player):
			overlapping_local_player_count = 1
			resolved_peer_id = _resolve_body_peer_id(fallback_player)

	if overlapping_local_player_count == _player_inside_count and resolved_peer_id == _local_interacting_peer_id:
		return

	_player_inside_count = overlapping_local_player_count
	_local_interacting_peer_id = resolved_peer_id
	_refresh_visual_state()


func _is_interact_up_just_pressed() -> bool:
	return Input.is_action_just_pressed("interact_up") or Input.is_action_just_pressed("ui_up")


func _is_local_interaction_body(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not String(body.name).begins_with("Player"):
		return false
	var local_input_enabled: Variant = body.get("enable_local_input")
	if local_input_enabled is bool:
		return bool(local_input_enabled)
	return true


func _resolve_body_peer_id(body: Node) -> int:
	if body == null or not is_instance_valid(body):
		return 1
	if body is Node:
		return int((body as Node).get_multiplayer_authority())
	return 1


func _find_local_interaction_player() -> Node:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	for child in current_scene.get_children():
		if _is_local_interaction_body(child):
			return child
	return current_scene.find_child("Player", true, false)


func _is_player_close_enough(body: Node) -> bool:
	if not _is_local_interaction_body(body):
		return false
	if not (body is Node2D):
		return false

	var body_position: Vector2 = (body as Node2D).global_position
	var offset: Vector2 = body_position - global_position
	var half_size := Vector2(26.0, 48.0)
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		half_size = (collision_shape.shape as RectangleShape2D).size * 0.5
	return absf(offset.x - collision_shape.position.x) <= half_size.x + 14.0 \
		and absf(offset.y - collision_shape.position.y) <= half_size.y + 20.0
