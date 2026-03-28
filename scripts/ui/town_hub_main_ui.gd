extends Control

const PANEL_OPEN_OFFSET := Vector2(96.0, 18.0)
const PANEL_OPEN_DURATION := 0.24
const PANEL_FADE_DURATION := 0.18

@onready var inventory_button: Button = $InventoryButton
@onready var character_button: Button = $CharacterButton
@onready var inventory_screen: Control = $InventoryScreen
@onready var inventory_panel: Control = $InventoryScreen
@onready var character_screen: Control = $CharacterScreen
@onready var character_panel: Control = $CharacterScreen
@onready var inventory_overlay_dim: ColorRect = $InventoryScreen/OverlayDim
@onready var overlay_dim: ColorRect = $CharacterScreen/OverlayDim
@onready var inventory_panel_shell: Control = $InventoryScreen/PanelShell
@onready var panel_shell: Control = $CharacterScreen/PanelShell
@onready var inventory_close_button: Button = $InventoryScreen/PanelShell/CloseButton
@onready var close_button: Button = $CharacterScreen/PanelShell/CloseButton

var _inventory_open_position: Vector2 = Vector2.ZERO
var _panel_open_position: Vector2 = Vector2.ZERO
var _inventory_tween: Tween
var _panel_tween: Tween


func _ready() -> void:
	_inventory_open_position = inventory_panel_shell.position
	_panel_open_position = panel_shell.position
	_reset_inventory_screen_visuals()
	_reset_character_screen_visuals()
	inventory_screen.visible = false
	character_screen.visible = false
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	character_button.pressed.connect(_on_character_button_pressed)
	inventory_close_button.pressed.connect(_on_inventory_close_pressed)
	close_button.pressed.connect(_on_character_close_pressed)
	inventory_overlay_dim.gui_input.connect(_on_inventory_overlay_gui_input)
	overlay_dim.gui_input.connect(_on_overlay_gui_input)


func _on_inventory_button_pressed() -> void:
	if inventory_screen.visible:
		return
	if character_screen.visible:
		_force_hide_character_screen()
	_play_inventory_open()


func _on_character_button_pressed() -> void:
	if character_screen.visible:
		return
	if inventory_screen.visible:
		_force_hide_inventory_screen()
	_play_character_open()


func _on_inventory_close_pressed() -> void:
	if not inventory_screen.visible:
		return
	_play_inventory_close()


func _on_character_close_pressed() -> void:
	if not character_screen.visible:
		return
	_play_character_close()


func _unhandled_input(event: InputEvent) -> void:
	if inventory_screen.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_play_inventory_close()
		return
	if not character_screen.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_play_character_close()


func _on_inventory_overlay_gui_input(event: InputEvent) -> void:
	if not inventory_screen.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_inventory_close()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if not character_screen.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_character_close()


func _play_inventory_open() -> void:
	_stop_inventory_tween()
	if inventory_panel != null and inventory_panel.has_method("refresh_display"):
		inventory_panel.call("refresh_display")
	inventory_screen.visible = true
	inventory_overlay_dim.modulate.a = 0.0
	inventory_panel_shell.modulate.a = 0.0
	inventory_panel_shell.position = _inventory_open_position + PANEL_OPEN_OFFSET

	_inventory_tween = create_tween()
	_inventory_tween.set_parallel(true)
	_inventory_tween.tween_property(inventory_overlay_dim, "modulate:a", 1.0, PANEL_FADE_DURATION)
	_inventory_tween.tween_property(inventory_panel_shell, "modulate:a", 1.0, PANEL_FADE_DURATION)
	_inventory_tween.tween_property(inventory_panel_shell, "position", _inventory_open_position, PANEL_OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_inventory_close() -> void:
	_stop_inventory_tween()
	_inventory_tween = create_tween()
	_inventory_tween.set_parallel(true)
	_inventory_tween.tween_property(inventory_overlay_dim, "modulate:a", 0.0, PANEL_FADE_DURATION)
	_inventory_tween.tween_property(inventory_panel_shell, "modulate:a", 0.0, PANEL_FADE_DURATION)
	_inventory_tween.tween_property(inventory_panel_shell, "position", _inventory_open_position + PANEL_OPEN_OFFSET, PANEL_OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_inventory_tween.finished.connect(_on_inventory_close_transition_finished)


func _play_character_open() -> void:
	_stop_active_tween()
	if character_panel != null and character_panel.has_method("refresh_display"):
		character_panel.call("refresh_display")
	character_screen.visible = true
	overlay_dim.modulate.a = 0.0
	panel_shell.modulate.a = 0.0
	panel_shell.position = _panel_open_position + PANEL_OPEN_OFFSET

	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(overlay_dim, "modulate:a", 1.0, PANEL_FADE_DURATION)
	_panel_tween.tween_property(panel_shell, "modulate:a", 1.0, PANEL_FADE_DURATION)
	_panel_tween.tween_property(panel_shell, "position", _panel_open_position, PANEL_OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_character_close() -> void:
	_stop_active_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(overlay_dim, "modulate:a", 0.0, PANEL_FADE_DURATION)
	_panel_tween.tween_property(panel_shell, "modulate:a", 0.0, PANEL_FADE_DURATION)
	_panel_tween.tween_property(panel_shell, "position", _panel_open_position + PANEL_OPEN_OFFSET, PANEL_OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_panel_tween.finished.connect(_on_close_transition_finished)


func _on_inventory_close_transition_finished() -> void:
	inventory_screen.visible = false
	_reset_inventory_screen_visuals()


func _on_close_transition_finished() -> void:
	character_screen.visible = false
	_reset_character_screen_visuals()


func _reset_inventory_screen_visuals() -> void:
	inventory_overlay_dim.modulate.a = 1.0
	inventory_panel_shell.modulate.a = 1.0
	inventory_panel_shell.position = _inventory_open_position


func _reset_character_screen_visuals() -> void:
	overlay_dim.modulate.a = 1.0
	panel_shell.modulate.a = 1.0
	panel_shell.position = _panel_open_position


func _force_hide_inventory_screen() -> void:
	_stop_inventory_tween()
	inventory_screen.visible = false
	_reset_inventory_screen_visuals()


func _force_hide_character_screen() -> void:
	_stop_active_tween()
	character_screen.visible = false
	_reset_character_screen_visuals()


func _stop_inventory_tween() -> void:
	if _inventory_tween != null and _inventory_tween.is_running():
		_inventory_tween.kill()


func _stop_active_tween() -> void:
	if _panel_tween != null and _panel_tween.is_running():
		_panel_tween.kill()
