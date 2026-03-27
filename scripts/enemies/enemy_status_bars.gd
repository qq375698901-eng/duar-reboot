extends Control
class_name EnemyStatusBars

@export var full_width: float = 32.0
@export var center_x: float = 18.0

@onready var hp_fill: ColorRect = $HpBar/HpFill


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hp(current_value: float, max_value: float) -> void:
	_update_bar_fill(hp_fill, current_value, max_value)


func set_bar_visible(enabled: bool) -> void:
	visible = enabled


func _update_bar_fill(fill_rect: ColorRect, current_value: float, max_value: float) -> void:
	if fill_rect == null:
		return

	var ratio := 0.0
	if max_value > 0.0:
		ratio = clampf(current_value / max_value, 0.0, 1.0)

	var visible_width := full_width * ratio
	fill_rect.offset_left = center_x - visible_width * 0.5
	fill_rect.offset_right = center_x + visible_width * 0.5
