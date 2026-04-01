extends Control

const TOWN_HUB_SCENE_PATH := "res://scenes/ui/town_hub_main_ui.tscn"
const RETURN_TO_TOWN_TEXT_B64 := "5Zue5Yiw5Z+O6ZWH"

@onready var tint_rect: ColorRect = $Tint
@onready var message_label: Label = $CenterBox/Panel/VBox/MessageLabel
@onready var return_button: Button = $CenterBox/Panel/VBox/ReturnButton

var _fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	return_button.text = Marshalls.base64_to_utf8(RETURN_TO_TOWN_TEXT_B64)
	message_label.text = "Defeated"
	return_button.pressed.connect(_on_return_button_pressed)
	hide_overlay()


func show_overlay() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tint_rect.modulate.a = 0.0
	return_button.visible = false
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(tint_rect, "modulate:a", 0.72, 0.8)
	_fade_tween.tween_callback(Callable(self, "_show_return_button"))


func hide_overlay() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	visible = false
	return_button.visible = false
	tint_rect.modulate.a = 0.0


func _show_return_button() -> void:
	return_button.visible = true


func _on_return_button_pressed() -> void:
	var dungeon_flow_runtime: Node = get_node_or_null("/root/DungeonFlowRuntime")
	if dungeon_flow_runtime != null and dungeon_flow_runtime.has_method("cancel_run"):
		dungeon_flow_runtime.call("cancel_run")
	get_tree().change_scene_to_file(TOWN_HUB_SCENE_PATH)
