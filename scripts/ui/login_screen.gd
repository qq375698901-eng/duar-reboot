extends Control

const TOWN_HUB_SCENE_PATH := "res://scenes/ui/town_hub_main_ui.tscn"

@onready var username_edit: LineEdit = $CenterContainer/Panel/MarginContainer/Content/UsernameEdit
@onready var password_edit: LineEdit = $CenterContainer/Panel/MarginContainer/Content/PasswordEdit
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/Content/StatusLabel
@onready var login_button: Button = $CenterContainer/Panel/MarginContainer/Content/ButtonRow/LoginButton
@onready var register_button: Button = $CenterContainer/Panel/MarginContainer/Content/ButtonRow/RegisterButton


func _ready() -> void:
	login_button.pressed.connect(_on_login_button_pressed)
	register_button.pressed.connect(_on_register_button_pressed)
	password_edit.text_submitted.connect(_on_password_submitted)
	_set_status(Marshalls.base64_to_utf8("6K+36L6T5YWl6LSm5Y+35LiO5a+G56CB44CC"), Color(0.78, 0.82, 0.9, 1.0))


func _on_login_button_pressed() -> void:
	_submit_auth_request(false)


func _on_register_button_pressed() -> void:
	_submit_auth_request(true)


func _on_password_submitted(_text: String) -> void:
	_submit_auth_request(false)


func _submit_auth_request(register_mode: bool) -> void:
	var account_runtime: Node = get_node_or_null("/root/AccountRuntime")
	if account_runtime == null:
		_set_status(Marshalls.base64_to_utf8("6LSm5Y+357O757uf5pyq5bCx57uq44CC"), Color(0.93, 0.4, 0.4, 1.0))
		return

	var username: String = username_edit.text.strip_edges()
	var password: String = password_edit.text
	var result: Dictionary
	if register_mode:
		result = account_runtime.call("register_account", username, password) as Dictionary
	else:
		result = account_runtime.call("login_account", username, password) as Dictionary

	var is_ok: bool = bool(result.get("ok", false))
	var message: String = String(result.get("message", ""))
	_set_status(message, Color(0.5, 0.88, 0.62, 1.0) if is_ok else Color(0.93, 0.4, 0.4, 1.0))
	if not is_ok:
		return

	get_tree().change_scene_to_file(TOWN_HUB_SCENE_PATH)


func _set_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color
