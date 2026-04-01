extends Control

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 24567
const TOWN_HUB_SCENE_PATH := "res://scenes/ui/town_hub_main_ui.tscn"

@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/Panel/Margin/VBox/SubtitleLabel
@onready var ip_label: Label = $CenterContainer/Panel/Margin/VBox/IpLabel
@onready var ip_edit: LineEdit = $CenterContainer/Panel/Margin/VBox/IpEdit
@onready var port_label: Label = $CenterContainer/Panel/Margin/VBox/PortLabel
@onready var port_edit: LineEdit = $CenterContainer/Panel/Margin/VBox/PortEdit
@onready var host_button: Button = $CenterContainer/Panel/Margin/VBox/ButtonRow/HostButton
@onready var join_button: Button = $CenterContainer/Panel/Margin/VBox/ButtonRow/JoinButton
@onready var back_button: Button = $CenterContainer/Panel/Margin/VBox/BackButton
@onready var status_label: Label = $CenterContainer/Panel/Margin/VBox/StatusLabel


func _ready() -> void:
	title_label.text = "Online Showcase"
	subtitle_label.text = "First pass: host or join a 2-player showcase room."
	ip_label.text = "IP"
	port_label.text = "Port"
	host_button.text = "Host"
	join_button.text = "Join"
	back_button.text = "Back"
	ip_edit.placeholder_text = DEFAULT_HOST
	port_edit.placeholder_text = str(DEFAULT_PORT)
	ip_edit.text = DEFAULT_HOST
	port_edit.text = str(DEFAULT_PORT)
	status_label.text = "Choose host or join."

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	ip_edit.text_submitted.connect(_on_ip_submitted)
	port_edit.text_submitted.connect(_on_port_submitted)

	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null:
		if network_session.has_signal("status_changed"):
			var status_callback := Callable(self, "_on_network_status_changed")
			if not network_session.is_connected("status_changed", status_callback):
				network_session.connect("status_changed", status_callback)
		if network_session.has_signal("connection_failed"):
			var fail_callback := Callable(self, "_on_network_connection_failed")
			if not network_session.is_connected("connection_failed", fail_callback):
				network_session.connect("connection_failed", fail_callback)


func _on_host_pressed() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session == null or not network_session.has_method("host_showcase"):
		return
	status_label.text = "Hosting showcase room..."
	network_session.call("host_showcase", _get_port_value())


func _on_join_pressed() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session == null or not network_session.has_method("join_showcase"):
		return
	status_label.text = "Joining showcase room..."
	network_session.call("join_showcase", _get_host_value(), _get_port_value())


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TOWN_HUB_SCENE_PATH)


func _on_ip_submitted(_text: String) -> void:
	_on_join_pressed()


func _on_port_submitted(_text: String) -> void:
	_on_join_pressed()


func _on_network_status_changed(message: String) -> void:
	status_label.text = message


func _on_network_connection_failed() -> void:
	host_button.disabled = false
	join_button.disabled = false


func _get_host_value() -> String:
	var value := ip_edit.text.strip_edges()
	return DEFAULT_HOST if value.is_empty() else value


func _get_port_value() -> int:
	var parsed_port := int(port_edit.text.strip_edges())
	return DEFAULT_PORT if parsed_port <= 0 else parsed_port
