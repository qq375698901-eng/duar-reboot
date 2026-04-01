extends Node2D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const EXIT_DOOR_SCENE := preload("res://scenes/maps/dungeon_exit_door_2d.tscn")
const LOOT_CHEST_SCENE := preload("res://scenes/objects/dungeon_loot_chest_2d.tscn")
const TOWN_HUB_SCENE_PATH := "res://scenes/ui/town_hub_main_ui.tscn"
const LOCAL_DEFAULT_WEAPON_SCENE_PATH := "res://scenes/weapons/longsword_basic.tscn"
const ENEMY_BODY_GROUP := &"enemy_bodies"
const SHOWCASE_EXIT_DOOR_NAME := "ShowcaseExitDoor"
const SHOWCASE_LOOT_CHEST_NAME := "ShowcaseLootChest"
const SHOWCASE_CHEST_SIZE := 0
const SHOWCASE_OBJECT_INTERACT_DISTANCE := 96.0
const SHOWCASE_PLAYER_RESPAWN_DELAY_SEC := 3.0

@onready var map_room: Node2D = $MapRoom
@onready var player_spawn_a: Marker2D = $PlayerSpawnA
@onready var player_spawn_b: Marker2D = $PlayerSpawnB
@onready var exit_door_spawn: Marker2D = $ExitDoorSpawn
@onready var loot_chest_spawn: Marker2D = $LootChestSpawn
@onready var training_dummy: CharacterBody2D = get_node_or_null("MapRoom/TrainingDummy") as CharacterBody2D
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $UiLayer/InfoPanel/Margin/InfoLabel

var _players_by_peer: Dictionary = {}
var _respawn_timer_by_peer: Dictionary = {}
var _showcase_exit_door: Node2D
var _showcase_loot_chest: Node2D
var _room_cleared := false
var _showcase_chest_opened := false


func _ready() -> void:
	_disable_map_camera()
	_ensure_showcase_objects()
	_connect_network_session_signals()
	_connect_room_runtime_signals()
	_spawn_existing_session_players()
	_ensure_local_player_exists()
	_initialize_room_state()
	_update_info_label()


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_refresh_room_clear_state_from_enemies()
	if _respawn_timer_by_peer.is_empty():
		return

	var ready_peer_ids: Array[int] = []
	for peer_id_value in _respawn_timer_by_peer.keys():
		var peer_id := int(peer_id_value)
		var timer_left := maxf(0.0, float(_respawn_timer_by_peer[peer_id]) - delta)
		_respawn_timer_by_peer[peer_id] = timer_left
		if timer_left <= 0.0:
			ready_peer_ids.append(peer_id)

	for peer_id in ready_peer_ids:
		_respawn_timer_by_peer.erase(peer_id)
		_respawn_showcase_player(peer_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_showcase_room()


func _spawn_existing_session_players() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session == null or not network_session.has_method("get_session_peer_ids"):
		_spawn_player_for_peer(_get_local_peer_id_or_fallback())
		return

	var peer_ids: Array[int] = network_session.call("get_session_peer_ids") as Array[int]
	var local_peer_id := _get_local_peer_id_or_fallback()
	if not peer_ids.has(local_peer_id):
		peer_ids.append(local_peer_id)
	peer_ids.sort()
	for peer_id in peer_ids:
		_spawn_player_for_peer(peer_id)


func _spawn_player_for_peer(peer_id: int) -> void:
	if _players_by_peer.has(peer_id):
		return

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	if player == null:
		return

	var is_local_player: bool = peer_id == multiplayer.get_unique_id() or not multiplayer.has_multiplayer_peer()
	player.name = "Player_%d" % peer_id
	player.global_position = _get_spawn_position_for_peer(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.set("enable_local_input", is_local_player)
	player.set("network_replica_mode", not is_local_player)
	player.set("use_account_runtime_state", is_local_player)
	player.set("use_inventory_runtime_state", is_local_player)
	player.set("spawn_runtime_attribute_debug_panel", is_local_player)
	player.set("spawn_runtime_battle_inventory_panel", is_local_player)
	player.set("spawn_runtime_battle_death_overlay", is_local_player)
	player.set("default_network_weapon_scene_path", LOCAL_DEFAULT_WEAPON_SCENE_PATH)
	add_child(player)
	_players_by_peer[peer_id] = player
	_connect_player_runtime_signals(player, peer_id)

	if is_local_player and camera != null:
		camera.set("target_path", camera.get_path_to(player))


func _connect_player_runtime_signals(player: CharacterBody2D, peer_id: int) -> void:
	if player == null or not player.has_signal("death_state_changed"):
		return
	var callback := Callable(self, "_on_player_death_state_changed").bind(peer_id)
	if not player.is_connected("death_state_changed", callback):
		player.connect("death_state_changed", callback)


func _remove_player_for_peer(peer_id: int) -> void:
	if not _players_by_peer.has(peer_id):
		return

	var player: Node = _players_by_peer[peer_id] as Node
	_players_by_peer.erase(peer_id)
	_respawn_timer_by_peer.erase(peer_id)
	if player != null:
		player.queue_free()
	_update_info_label()


func _get_spawn_position_for_peer(peer_id: int) -> Vector2:
	var peer_ids := _get_sorted_session_peer_ids()
	var peer_index := peer_ids.find(peer_id)
	if peer_index <= 0:
		return player_spawn_a.global_position
	if peer_index == 1:
		return player_spawn_b.global_position
	return player_spawn_b.global_position + Vector2(140.0 * float(peer_index - 1), 0.0)


func _connect_network_session_signals() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session == null:
		return

	if network_session.has_signal("peer_joined"):
		var joined_callback := Callable(self, "_on_network_peer_joined")
		if not network_session.is_connected("peer_joined", joined_callback):
			network_session.connect("peer_joined", joined_callback)
	if network_session.has_signal("peer_left"):
		var left_callback := Callable(self, "_on_network_peer_left")
		if not network_session.is_connected("peer_left", left_callback):
			network_session.connect("peer_left", left_callback)
	if network_session.has_signal("status_changed"):
		var status_callback := Callable(self, "_on_network_status_changed")
		if not network_session.is_connected("status_changed", status_callback):
			network_session.connect("status_changed", status_callback)


func _connect_room_runtime_signals() -> void:
	if training_dummy != null and training_dummy.has_signal("defeated_state_changed"):
		var dummy_callback := Callable(self, "_on_training_dummy_defeated_state_changed")
		if not training_dummy.is_connected("defeated_state_changed", dummy_callback):
			training_dummy.connect("defeated_state_changed", dummy_callback)


func _ensure_showcase_objects() -> void:
	if map_room == null:
		return

	var existing_exit_door := map_room.get_node_or_null(SHOWCASE_EXIT_DOOR_NAME) as Node2D
	if existing_exit_door != null:
		_showcase_exit_door = existing_exit_door
	else:
		_showcase_exit_door = EXIT_DOOR_SCENE.instantiate() as Node2D
		if _showcase_exit_door != null:
			_showcase_exit_door.name = SHOWCASE_EXIT_DOOR_NAME
			map_room.add_child(_showcase_exit_door)

	if _showcase_exit_door != null:
		_showcase_exit_door.global_position = exit_door_spawn.global_position
		if _showcase_exit_door.has_signal("interaction_requested"):
			var exit_callback := Callable(self, "_on_exit_door_interaction_requested")
			if not _showcase_exit_door.is_connected("interaction_requested", exit_callback):
				_showcase_exit_door.connect("interaction_requested", exit_callback)
		if _showcase_exit_door.has_signal("exit_interacted"):
			var singleplayer_exit_callback := Callable(self, "_on_exit_door_singleplayer_interacted")
			if not _showcase_exit_door.is_connected("exit_interacted", singleplayer_exit_callback):
				_showcase_exit_door.connect("exit_interacted", singleplayer_exit_callback)

	var existing_loot_chest := map_room.get_node_or_null(SHOWCASE_LOOT_CHEST_NAME) as Node2D
	if existing_loot_chest != null:
		_showcase_loot_chest = existing_loot_chest
	else:
		_showcase_loot_chest = LOOT_CHEST_SCENE.instantiate() as Node2D
		if _showcase_loot_chest != null:
			_showcase_loot_chest.name = SHOWCASE_LOOT_CHEST_NAME
			map_room.add_child(_showcase_loot_chest)

	if _showcase_loot_chest != null:
		_showcase_loot_chest.global_position = loot_chest_spawn.global_position
		if _showcase_loot_chest.has_method("set_chest_size"):
			_showcase_loot_chest.call("set_chest_size", SHOWCASE_CHEST_SIZE)
		_showcase_loot_chest.call_deferred("snap_to_floor")
		if _showcase_loot_chest.has_signal("interaction_requested"):
			var chest_callback := Callable(self, "_on_loot_chest_interaction_requested")
			if not _showcase_loot_chest.is_connected("interaction_requested", chest_callback):
				_showcase_loot_chest.connect("interaction_requested", chest_callback)


func _initialize_room_state() -> void:
	_refresh_room_clear_state_from_enemies()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_broadcast_room_state()


func _on_network_peer_joined(peer_id: int) -> void:
	_spawn_player_for_peer(peer_id)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_room_state_to_peer(peer_id)
	_update_info_label()


func _on_network_peer_left(peer_id: int) -> void:
	_remove_player_for_peer(peer_id)


func _on_network_status_changed(_message: String) -> void:
	_ensure_local_player_exists()
	_update_info_label()


func _on_training_dummy_defeated_state_changed(defeated: bool) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_refresh_room_clear_state_from_enemies()


func _on_loot_chest_interaction_requested(peer_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_host_open_showcase_chest.rpc_id(1, peer_id)
		return
	_handle_host_showcase_chest_request(peer_id)


func _on_exit_door_interaction_requested(peer_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_host_use_showcase_exit.rpc_id(1, peer_id)
		return
	_handle_host_showcase_exit_request(peer_id)


func _on_exit_door_singleplayer_interacted() -> void:
	_handle_host_showcase_exit_request(_get_local_peer_id_or_fallback())


func _on_player_death_state_changed(dead: bool, peer_id: int) -> void:
	if not dead:
		_update_info_label()
		return

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_schedule_player_respawn(peer_id)
		elif peer_id == multiplayer.get_unique_id():
			request_host_schedule_player_respawn.rpc_id(1, peer_id)
	else:
		_schedule_player_respawn(peer_id)
	_update_info_label()


func _update_info_label() -> void:
	if info_label == null:
		return

	var network_session := get_node_or_null("/root/NetworkSession")
	var session_line := "Single-player fallback"
	if network_session != null and network_session.has_method("is_hosting_session") and bool(network_session.call("has_active_session")):
		session_line = "Role: Host" if bool(network_session.call("is_hosting_session")) else "Role: Client"

	var peers_line := "Players: %d" % _players_by_peer.size()
	var dummy_line := _build_dummy_status_line()
	var room_line := "Door: Open  Chest: Open" if _room_cleared and _showcase_chest_opened else (
		"Door: Open  Chest: Ready" if _room_cleared else "Door: Closed  Chest: Locked"
	)
	info_label.text = "%s\n%s\n%s\n%s\nESC: Leave room" % [session_line, peers_line, dummy_line, room_line]


func _build_dummy_status_line() -> String:
	if training_dummy == null:
		return "Dummy: Missing"
	if training_dummy.has_method("is_defeated") and bool(training_dummy.call("is_defeated")):
		return "Dummy: Defeated"
	if training_dummy.has_method("get_current_hp") and training_dummy.has_method("get_max_hp"):
		return "Dummy HP: %.0f / %.0f" % [
			float(training_dummy.call("get_current_hp")),
			float(training_dummy.call("get_max_hp")),
		]
	return "Dummy: Ready"


func _disable_map_camera() -> void:
	var map_camera := $MapRoom.get_node_or_null("Camera2D") as Camera2D
	if map_camera != null:
		map_camera.enabled = false


func _ensure_local_player_exists() -> void:
	var local_peer_id := _get_local_peer_id_or_fallback()
	_spawn_player_for_peer(local_peer_id)


func _get_local_peer_id_or_fallback() -> int:
	if multiplayer.has_multiplayer_peer():
		var local_peer_id := multiplayer.get_unique_id()
		if local_peer_id > 0:
			return local_peer_id
	return 1


func _get_sorted_session_peer_ids() -> Array[int]:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null and network_session.has_method("get_session_peer_ids"):
		var peer_ids: Array[int] = network_session.call("get_session_peer_ids") as Array[int]
		if not peer_ids.is_empty():
			peer_ids.sort()
			return peer_ids

	var fallback_peer_ids: Array[int] = []
	var local_peer_id := _get_local_peer_id_or_fallback()
	fallback_peer_ids.append(local_peer_id)
	for peer_id in _players_by_peer.keys():
		var peer_id_int := int(peer_id)
		if not fallback_peer_ids.has(peer_id_int):
			fallback_peer_ids.append(peer_id_int)
	fallback_peer_ids.sort()
	return fallback_peer_ids


func _apply_room_state(room_cleared: bool, chest_opened: bool) -> void:
	_room_cleared = room_cleared
	_showcase_chest_opened = chest_opened
	if _showcase_exit_door != null:
		_showcase_exit_door.call("set_is_open", _room_cleared)
	if _showcase_loot_chest != null:
		_showcase_loot_chest.call("set_is_unlocked", _room_cleared)
		_showcase_loot_chest.call("set_is_opened", _showcase_chest_opened, "")
		if not _showcase_chest_opened:
			_showcase_loot_chest.call("show_status_message", "")
	_update_info_label()


func _refresh_room_clear_state_from_enemies() -> void:
	var room_cleared := _get_alive_enemy_count() <= 0
	if _room_cleared == room_cleared:
		return
	_apply_room_state(room_cleared, false if not room_cleared else _showcase_chest_opened)
	_broadcast_room_state()


func _get_alive_enemy_count() -> int:
	var alive_count := 0
	for node in get_tree().get_nodes_in_group(ENEMY_BODY_GROUP):
		if not (node is Node):
			continue
		var body := node as Node
		if body == self or not is_ancestor_of(body):
			continue
		if body.has_method("is_dead") and bool(body.call("is_dead")):
			continue
		alive_count += 1
	return alive_count


func _broadcast_room_state() -> void:
	_apply_room_state(_room_cleared, _showcase_chest_opened)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_showcase_room_state.rpc(_room_cleared, _showcase_chest_opened)


func _sync_room_state_to_peer(peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	sync_showcase_room_state.rpc_id(peer_id, _room_cleared, _showcase_chest_opened)


func _handle_host_showcase_chest_request(peer_id: int) -> void:
	if _showcase_loot_chest == null or _showcase_chest_opened or not _room_cleared:
		return
	if not _can_peer_interact_with_object(peer_id, _showcase_loot_chest):
		return

	var reward_payload := _showcase_loot_chest.call("roll_reward_payload") as Dictionary
	_apply_room_state(true, true)
	_broadcast_room_state()
	_grant_showcase_chest_reward_to_peer(peer_id, reward_payload)


func _grant_showcase_chest_reward_to_peer(peer_id: int, reward_payload: Dictionary) -> void:
	if peer_id == _get_local_peer_id_or_fallback() or not multiplayer.has_multiplayer_peer():
		_apply_showcase_chest_reward_local(reward_payload)
		return
	receive_showcase_chest_reward.rpc_id(peer_id, reward_payload.duplicate(true))


func _apply_showcase_chest_reward_local(reward_payload: Dictionary) -> void:
	if _showcase_loot_chest == null:
		return
	var local_player := _get_local_player()
	var reward_result := _showcase_loot_chest.call("grant_reward_payload_to_local_player", reward_payload.duplicate(true), local_player) as Dictionary
	var exp_reward := int(reward_result.get("exp_reward", int(reward_payload.get("exp_reward", 0))))
	var granted_definition_ids := _coerce_definition_ids(reward_result.get("granted_definition_ids", PackedStringArray()))
	_showcase_loot_chest.call("show_status_message", _build_chest_reward_status(exp_reward, granted_definition_ids.size()))
	_update_info_label()


func _build_chest_reward_status(exp_reward: int, loot_count: int) -> String:
	if exp_reward > 0:
		return "EXP +%d" % exp_reward
	if loot_count > 0:
		return "Loot x%d" % loot_count
	return "Opened"


func _handle_host_showcase_exit_request(peer_id: int) -> void:
	if _showcase_exit_door == null or not _room_cleared:
		return
	if not _can_peer_interact_with_object(peer_id, _showcase_exit_door):
		return

	if peer_id == _get_local_peer_id_or_fallback() or not multiplayer.has_multiplayer_peer():
		_leave_showcase_room()
		return
	receive_showcase_exit.rpc_id(peer_id)


func _can_peer_interact_with_object(peer_id: int, object_node: Node2D) -> bool:
	var player := _players_by_peer.get(peer_id, null) as Node2D
	if player == null or object_node == null:
		return false
	if player.has_method("is_dead") and bool(player.call("is_dead")):
		return false
	return player.global_position.distance_to(object_node.global_position) <= SHOWCASE_OBJECT_INTERACT_DISTANCE


func _schedule_player_respawn(peer_id: int) -> void:
	if not _players_by_peer.has(peer_id):
		return
	_respawn_timer_by_peer[peer_id] = SHOWCASE_PLAYER_RESPAWN_DELAY_SEC
	_update_info_label()


func _respawn_showcase_player(peer_id: int) -> void:
	var player := _players_by_peer.get(peer_id, null) as CharacterBody2D
	if player == null:
		return
	if player.has_method("respawn_at"):
		player.call("respawn_at", _get_spawn_position_for_peer(peer_id), true)
	_update_info_label()


func _get_local_player() -> Node:
	return _players_by_peer.get(_get_local_peer_id_or_fallback(), null) as Node


func _coerce_definition_ids(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var definition_ids := PackedStringArray()
	if value is Array:
		for entry in value:
			definition_ids.append(String(entry))
	return definition_ids


func _leave_showcase_room() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null and network_session.has_method("stop_session"):
		network_session.call("stop_session")
		return
	get_tree().change_scene_to_file(TOWN_HUB_SCENE_PATH)


@rpc("authority", "call_remote", "reliable")
func sync_showcase_room_state(room_cleared: bool, chest_opened: bool) -> void:
	_apply_room_state(room_cleared, chest_opened)


@rpc("authority", "call_remote", "reliable")
func receive_showcase_chest_reward(reward_payload: Dictionary) -> void:
	_apply_showcase_chest_reward_local(reward_payload)


@rpc("authority", "call_remote", "reliable")
func receive_showcase_exit() -> void:
	_leave_showcase_room()


@rpc("any_peer", "call_remote", "reliable")
func request_host_open_showcase_chest(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_handle_host_showcase_chest_request(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_host_use_showcase_exit(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_handle_host_showcase_exit_request(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_host_schedule_player_respawn(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_schedule_player_respawn(peer_id)
