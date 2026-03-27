extends Node

@export var player_path: NodePath
@export var indicator_path: NodePath
@export var label_path: NodePath
@export var ready_color: Color = Color(0.2, 0.85, 0.3, 0.95)
@export var idle_color: Color = Color(0.9, 0.2, 0.2, 0.95)

@onready var player: Node = get_node_or_null(player_path)
@onready var indicator: ColorRect = get_node_or_null(indicator_path)
@onready var label: Label = get_node_or_null(label_path)


func _process(_delta: float) -> void:
	if indicator == null or label == null:
		return

	var can_forced_get_up := false
	if player != null and player.has_method("can_show_forced_get_up_indicator"):
		can_forced_get_up = bool(player.call("can_show_forced_get_up_indicator"))
	elif player != null and player.has_method("can_forced_get_up"):
		can_forced_get_up = bool(player.call("can_forced_get_up"))

	indicator.color = ready_color if can_forced_get_up else idle_color
	label.text = "FORCED GET UP\nREADY" if can_forced_get_up else "FORCED GET UP\nOFF"
