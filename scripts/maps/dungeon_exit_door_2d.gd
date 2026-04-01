extends Node2D
class_name DungeonExitDoor2D

signal exit_interacted()
signal interaction_requested(peer_id: int)

const CLOSED_TEXTURE := preload("res://art/Medieval/PNG/Objects/door1.png")
const OPEN_TEXTURE := preload("res://art/Medieval/PNG/Objects/door2.png")

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var prompt_label: Label = $PromptLabel

var _is_open: bool = false
var _player_inside_count: int = 0
var _local_interacting_peer_id: int = 1


func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_refresh_visual_state()


func _physics_process(_delta: float) -> void:
	if not _is_open:
		return
	if _player_inside_count <= 0:
		return
	if Input.is_action_just_pressed("interact_up"):
		if multiplayer.has_multiplayer_peer():
			interaction_requested.emit(_local_interacting_peer_id)
			return
		exit_interacted.emit()


func set_is_open(open: bool) -> void:
	if _is_open == open:
		_refresh_visual_state()
		return
	_is_open = open
	_refresh_visual_state()


func is_open() -> bool:
	return _is_open


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
