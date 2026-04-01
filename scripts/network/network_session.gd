extends Node

signal session_started(hosting: bool)
signal session_stopped()
signal connection_succeeded()
signal connection_failed()
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal status_changed(message: String)

const DEFAULT_PORT := 24567
const MAX_CLIENTS := 2
const SHOWCASE_ROOM_SCENE_PATH := "res://scenes/network/multiplayer_showcase_room.tscn"
const SHOWCASE_LOBBY_SCENE_PATH := "res://scenes/network/multiplayer_showcase_lobby.tscn"
const TOWN_HUB_SCENE_PATH := "res://scenes/ui/town_hub_main_ui.tscn"

var _is_hosting: bool = false
var _pending_join_address: String = "127.0.0.1"
var _pending_join_port: int = DEFAULT_PORT


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host_showcase(port: int = DEFAULT_PORT) -> bool:
	stop_session(false)

	var peer := ENetMultiplayerPeer.new()
	var error_code: int = peer.create_server(port, MAX_CLIENTS)
	if error_code != OK:
		status_changed.emit("Failed to host showcase room. Error %d." % error_code)
		return false

	multiplayer.multiplayer_peer = peer
	_is_hosting = true
	_pending_join_port = port
	status_changed.emit("Hosting showcase room on port %d." % port)
	session_started.emit(true)
	get_tree().change_scene_to_file(SHOWCASE_ROOM_SCENE_PATH)
	return true


func join_showcase(address: String, port: int = DEFAULT_PORT) -> bool:
	stop_session(false)

	var resolved_address := address.strip_edges()
	if resolved_address.is_empty():
		resolved_address = "127.0.0.1"

	var peer := ENetMultiplayerPeer.new()
	var error_code: int = peer.create_client(resolved_address, port)
	if error_code != OK:
		status_changed.emit("Failed to join showcase room. Error %d." % error_code)
		return false

	multiplayer.multiplayer_peer = peer
	_is_hosting = false
	_pending_join_address = resolved_address
	_pending_join_port = port
	status_changed.emit("Joining showcase room at %s:%d..." % [resolved_address, port])
	return true


func stop_session(return_to_town: bool = true) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_is_hosting = false
	status_changed.emit("Showcase session closed.")
	session_stopped.emit()

	if return_to_town:
		get_tree().change_scene_to_file(TOWN_HUB_SCENE_PATH)


func leave_to_lobby() -> void:
	stop_session(false)
	get_tree().change_scene_to_file(SHOWCASE_LOBBY_SCENE_PATH)


func has_active_session() -> bool:
	return multiplayer.multiplayer_peer != null


func is_hosting_session() -> bool:
	return has_active_session() and _is_hosting


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()


func get_session_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	if not has_active_session():
		return peer_ids

	peer_ids.append(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		if not peer_ids.has(peer_id):
			peer_ids.append(peer_id)
	peer_ids.sort()
	return peer_ids


func _on_connected_to_server() -> void:
	status_changed.emit("Connected to showcase host %s:%d." % [_pending_join_address, _pending_join_port])
	connection_succeeded.emit()
	session_started.emit(false)
	get_tree().change_scene_to_file(SHOWCASE_ROOM_SCENE_PATH)


func _on_connection_failed() -> void:
	status_changed.emit("Failed to connect to showcase host.")
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	status_changed.emit("Disconnected from showcase host.")
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	session_stopped.emit()
	get_tree().change_scene_to_file(SHOWCASE_LOBBY_SCENE_PATH)


func _on_peer_connected(peer_id: int) -> void:
	status_changed.emit("Peer %d joined the showcase room." % peer_id)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	status_changed.emit("Peer %d left the showcase room." % peer_id)
	peer_left.emit(peer_id)
