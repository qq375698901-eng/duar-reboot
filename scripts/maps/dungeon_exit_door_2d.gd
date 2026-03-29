extends Node2D
class_name DungeonExitDoor2D

signal exit_interacted()

const CLOSED_TEXTURE := preload("res://art/Medieval/PNG/Objects/door1.png")
const OPEN_TEXTURE := preload("res://art/Medieval/PNG/Objects/door2.png")

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var prompt_label: Label = $PromptLabel

var _is_open: bool = false
var _player_inside_count: int = 0


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
	if body.name != "Player":
		return
	_player_inside_count += 1
	_refresh_visual_state()


func _on_body_exited(body: Node) -> void:
	if body.name != "Player":
		return
	_player_inside_count = max(0, _player_inside_count - 1)
	_refresh_visual_state()


func _refresh_visual_state() -> void:
	sprite.texture = OPEN_TEXTURE if _is_open else CLOSED_TEXTURE
	prompt_label.visible = _is_open and _player_inside_count > 0
