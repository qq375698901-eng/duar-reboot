extends Node2D
class_name DungeonRoom2D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const EXIT_DOOR_SCENE := preload("res://scenes/maps/dungeon_exit_door_2d.tscn")
const LOOT_CHEST_SCENE := preload("res://scenes/objects/dungeon_loot_chest_2d.tscn")
const ENEMY_BODY_GROUP := &"enemy_bodies"
const INSTANCE_RUNTIME_PATH := "/root/DungeonInstanceRuntime"
const ROOM_SESSION_RUNTIME_PATH := "/root/DungeonRoomSessionRuntime"
const NETWORK_SESSION_PATH := "/root/NetworkSession"
const LOCAL_DEFAULT_WEAPON_SCENE_PATH := "res://scenes/weapons/longsword_basic.tscn"

signal exit_requested(room_id: StringName)

enum RegionKind {
	DUNGEON,
	TOWN,
}

enum RoomType {
	UNKNOWN,
	MONSTER,
	ELITE_MONSTER,
	RESOURCE,
	BOSS,
	EXTRACTION,
	BATTLE_ROOM,
}

enum LootChestSize {
	NONE,
	SMALL,
	MEDIUM,
	LARGE,
}

@export var room_id: StringName
@export var room_display_name: String = ""
@export var region_kind: RegionKind = RegionKind.DUNGEON
@export var room_type: RoomType = RoomType.UNKNOWN
@export var room_type_label: String = ""
@export var gameplay_tags: PackedStringArray = []
@export_range(0, 10, 1) var encounter_level: int = 0
@export var player_spawn_path: NodePath = NodePath("PlayerSpawn")
@export var secondary_player_spawn_path: NodePath = NodePath("PlayerSpawnB")
@export var exit_door_spawn_path: NodePath = NodePath("ExitDoorSpawn")
@export_file("*.tscn") var exit_target_scene_path: String = ""
@export var fall_death_y: float = 960.0
@export var enemy_fall_death_y: float = 960.0
@export var loot_chest_size: LootChestSize = LootChestSize.NONE
@export var loot_chest_spawn_path: NodePath = NodePath("LootChestSpawn")
@export var loot_chest_spawn_offset: Vector2 = Vector2(84.0, 12.0)
@export var additional_peer_spawn_offset: Vector2 = Vector2(72.0, 0.0)

var _exit_door: Node2D
var _loot_chest: Node2D
var _local_interaction_player: Node2D
var _instance_assignment: Dictionary = {}
var _instance_debug_layer: CanvasLayer
var _instance_debug_label: Label
var _room_cleared_state: bool = false
var _tracked_room_players: Dictionary = {}
var _players_by_peer: Dictionary = {}
var _loot_chest_opened_state: bool = false


func _ready() -> void:
	call_deferred("_bootstrap_room")


func _physics_process(_delta: float) -> void:
	_sync_session_players_with_network_session()
	_refresh_tracked_room_players()
	_update_network_enemy_targets()
	_update_room_clear_interactables()
	_process_singleplayer_interaction()


func is_dungeon_room() -> bool:
	return region_kind == RegionKind.DUNGEON


func get_room_type_key() -> StringName:
	match room_type:
		RoomType.MONSTER:
			return &"monster"
		RoomType.ELITE_MONSTER:
			return &"elite_monster"
		RoomType.RESOURCE:
			return &"resource"
		RoomType.BOSS:
			return &"boss"
		RoomType.EXTRACTION:
			return &"extraction"
		RoomType.BATTLE_ROOM:
			return &"battle_room"
		_:
			return &"unknown"


func _bootstrap_room() -> void:
	_bind_instance_assignment()
	_connect_network_session_signals()
	_ensure_room_player()
	_configure_room_enemies()
	_ensure_exit_door()
	_ensure_loot_chest()
	_start_room_session()
	_update_room_clear_interactables()


func _ensure_room_player() -> void:
	if _has_active_network_session():
		_spawn_existing_session_players()
		_ensure_local_player_exists()
		var local_network_player: Node2D = _resolve_local_interaction_player()
		if local_network_player != null and local_network_player.has_method("set_fall_death_y"):
			local_network_player.call("set_fall_death_y", fall_death_y)
		_local_interaction_player = local_network_player
		if _local_interaction_player != null:
			_retarget_room_nodes(_local_interaction_player)
		return

	var existing_player: Node2D = get_node_or_null("Player") as Node2D
	if existing_player == null:
		existing_player = PLAYER_SCENE.instantiate() as Node2D
		if existing_player == null:
			return
		existing_player.name = "Player"
		add_child(existing_player)
		var spawn_node: Node2D = get_node_or_null(player_spawn_path) as Node2D
		if spawn_node != null:
			existing_player.global_position = spawn_node.global_position

	if existing_player != null and existing_player.has_method("set_fall_death_y"):
		existing_player.call("set_fall_death_y", fall_death_y)

	_local_interaction_player = existing_player
	_players_by_peer[_get_local_peer_id_or_fallback()] = existing_player
	_retarget_room_nodes(existing_player)


func _configure_room_enemies() -> void:
	for node in get_tree().get_nodes_in_group(ENEMY_BODY_GROUP):
		if not (node is Node):
			continue
		var body: Node = node as Node
		if body == self or not is_ancestor_of(body):
			continue
		if _is_networked_dungeon_room():
			body.set_multiplayer_authority(1, true)
		if body.has_method("set_fall_death_y"):
			body.call("set_fall_death_y", enemy_fall_death_y)


func _ensure_exit_door() -> void:
	if _exit_door != null and is_instance_valid(_exit_door):
		return

	var existing_door: Node2D = get_node_or_null("ExitDoor") as Node2D
	if existing_door != null:
		_exit_door = existing_door
	else:
		var spawn_node: Node2D = get_node_or_null(exit_door_spawn_path) as Node2D
		if spawn_node == null:
			return
		_exit_door = EXIT_DOOR_SCENE.instantiate() as Node2D
		if _exit_door == null:
			return
		_exit_door.name = "ExitDoor"
		add_child(_exit_door)
		_exit_door.global_position = spawn_node.global_position

	if _exit_door != null and _exit_door.has_signal("exit_interacted"):
		var callback: Callable = Callable(self, "_on_exit_door_interacted")
		if not _exit_door.is_connected("exit_interacted", callback):
			_exit_door.connect("exit_interacted", callback)
	if _exit_door != null and _exit_door.has_signal("interaction_requested"):
		var interaction_callback: Callable = Callable(self, "_on_exit_door_interaction_requested")
		if not _exit_door.is_connected("interaction_requested", interaction_callback):
			_exit_door.connect("interaction_requested", interaction_callback)

	_place_exit_door_in_draw_order()


func _ensure_loot_chest() -> void:
	if loot_chest_size == LootChestSize.NONE:
		return
	if _loot_chest != null and is_instance_valid(_loot_chest):
		_apply_loot_chest_configuration()
		return

	var existing_chest: Node2D = get_node_or_null("LootChest") as Node2D
	if existing_chest != null:
		_loot_chest = existing_chest
	else:
		_loot_chest = LOOT_CHEST_SCENE.instantiate() as Node2D
		if _loot_chest == null:
			return
		_loot_chest.name = "LootChest"
		add_child(_loot_chest)

	_apply_loot_chest_configuration()
	_place_loot_chest_in_draw_order()
	if _loot_chest != null and _loot_chest.has_signal("loot_opened"):
		var chest_callback: Callable = Callable(self, "_on_loot_chest_opened")
		if not _loot_chest.is_connected("loot_opened", chest_callback):
			_loot_chest.connect("loot_opened", chest_callback)
	if _loot_chest != null and _loot_chest.has_signal("interaction_requested"):
		var interaction_callback: Callable = Callable(self, "_on_loot_chest_interaction_requested")
		if not _loot_chest.is_connected("interaction_requested", interaction_callback):
			_loot_chest.connect("interaction_requested", interaction_callback)


func _retarget_room_nodes(player: Node2D) -> void:
	for node in _collect_descendants(self):
		if node == player:
			continue
		if not _has_target_path_property(node):
			continue
		node.set("target_path", node.get_path_to(player))


func _collect_descendants(root: Node) -> Array[Node]:
	var results: Array[Node] = []
	for child in root.get_children():
		if child is Node:
			results.append(child)
			results.append_array(_collect_descendants(child))
	return results


func _has_target_path_property(node: Node) -> bool:
	for property_info in node.get_property_list():
		if String(property_info.get("name", "")) == "target_path":
			return true
	return false


func _update_room_clear_interactables() -> void:
	if _is_network_room_client():
		_apply_room_state(_room_cleared_state, _loot_chest_opened_state)
		return

	var alive_enemy_count: int = _get_alive_enemy_count()
	var room_cleared: bool = alive_enemy_count <= 0
	if room_cleared != _room_cleared_state:
		_apply_room_state(room_cleared, _loot_chest_opened_state)
		_update_room_session_clear_state(alive_enemy_count)
		if _is_network_room_host():
			_sync_room_state_to_all_peers()
		_refresh_instance_debug_label()
	elif alive_enemy_count != -1:
		_apply_room_state(_room_cleared_state, _loot_chest_opened_state)
		_update_room_session_clear_state(alive_enemy_count)


func _process_singleplayer_interaction() -> void:
	if _is_networked_dungeon_room():
		return
	if not _is_interact_up_just_pressed():
		return

	var local_player: Node2D = _resolve_local_interaction_player()
	if local_player == null:
		return

	var chest_distance_sq: float = _get_interactable_distance_sq(_loot_chest, local_player, "can_player_interact")
	var door_distance_sq: float = _get_interactable_distance_sq(_exit_door, local_player, "can_player_interact")

	if chest_distance_sq <= door_distance_sq:
		if _force_interact(_loot_chest, local_player):
			return
		_force_interact(_exit_door, local_player)
		return

	if _force_interact(_exit_door, local_player):
		return
	_force_interact(_loot_chest, local_player)


func _get_alive_enemy_count() -> int:
	var alive_count: int = 0
	for node in get_tree().get_nodes_in_group(ENEMY_BODY_GROUP):
		if not (node is Node):
			continue
		var body: Node = node as Node
		if body == self or not is_ancestor_of(body):
			continue
		if body.has_method("is_dead") and bool(body.call("is_dead")):
			continue
		alive_count += 1
	return alive_count


func _bind_instance_assignment() -> void:
	var instance_runtime: Node = get_node_or_null(INSTANCE_RUNTIME_PATH)
	_instance_assignment.clear()
	if instance_runtime == null or not instance_runtime.has_method("get_active_assignment"):
		_refresh_instance_debug_label()
		return

	var active_assignment: Dictionary = instance_runtime.call("get_active_assignment") as Dictionary
	if active_assignment.is_empty():
		_refresh_instance_debug_label()
		return

	var room_scene_path: String = String(active_assignment.get("room_scene_path", ""))
	if not room_scene_path.is_empty() and room_scene_path != String(scene_file_path):
		_refresh_instance_debug_label()
		return

	_instance_assignment = active_assignment.duplicate(true)
	_refresh_instance_debug_label()


func _start_room_session() -> void:
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime == null or not room_session_runtime.has_method("start_room_session"):
		return

	var room_context: Dictionary = _instance_assignment.duplicate(true)
	room_context["room_id"] = String(room_id)
	room_context["room_display_name"] = room_display_name
	room_context["room_type"] = String(get_room_type_key())
	room_context["room_scene_path"] = String(scene_file_path)
	room_session_runtime.call("start_room_session", room_context)
	_refresh_tracked_room_players()
	_flush_tracked_room_players_to_session()
	_update_room_session_clear_state(_get_alive_enemy_count())
	_refresh_instance_debug_label()


func _has_active_network_session() -> bool:
	var network_session: Node = get_node_or_null(NETWORK_SESSION_PATH)
	if network_session == null or not network_session.has_method("has_active_session"):
		return false
	return bool(network_session.call("has_active_session"))


func _is_networked_dungeon_room() -> bool:
	return _has_active_network_session() and multiplayer.has_multiplayer_peer()


func _is_network_room_host() -> bool:
	return _is_networked_dungeon_room() and multiplayer.is_server()


func _is_network_room_client() -> bool:
	return _is_networked_dungeon_room() and not multiplayer.is_server()


func _connect_network_session_signals() -> void:
	var network_session: Node = get_node_or_null(NETWORK_SESSION_PATH)
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


func _spawn_existing_session_players() -> void:
	var peer_ids: Array[int] = _get_sorted_session_peer_ids()
	if peer_ids.is_empty():
		_spawn_player_for_peer(_get_local_peer_id_or_fallback())
		return

	for peer_id in peer_ids:
		_spawn_player_for_peer(peer_id)


func _sync_session_players_with_network_session() -> void:
	if not _has_active_network_session():
		return

	var desired_peer_ids: Array[int] = _get_sorted_session_peer_ids()
	if desired_peer_ids.is_empty():
		desired_peer_ids.append(_get_local_peer_id_or_fallback())

	for peer_id in desired_peer_ids:
		_spawn_player_for_peer(peer_id)

	var current_peer_ids: Array[int] = []
	for peer_id_value in _players_by_peer.keys():
		current_peer_ids.append(int(peer_id_value))

	for peer_id in current_peer_ids:
		if desired_peer_ids.has(peer_id):
			continue
		_remove_player_for_peer(peer_id)


func _ensure_local_player_exists() -> void:
	_spawn_player_for_peer(_get_local_peer_id_or_fallback())


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
	if player.has_method("set_fall_death_y"):
		player.call("set_fall_death_y", fall_death_y)
	if is_local_player:
		_local_interaction_player = player
		_retarget_room_nodes(player)
	_refresh_tracked_room_players()


func _remove_player_for_peer(peer_id: int) -> void:
	if not _players_by_peer.has(peer_id):
		return

	var player: Node = _players_by_peer.get(peer_id, null) as Node
	_players_by_peer.erase(peer_id)
	if player == _local_interaction_player:
		_local_interaction_player = null
	if player != null:
		player.queue_free()
	_refresh_tracked_room_players()


func _get_local_peer_id_or_fallback() -> int:
	if multiplayer.has_multiplayer_peer():
		var local_peer_id: int = multiplayer.get_unique_id()
		if local_peer_id > 0:
			return local_peer_id
	return 1


func _get_sorted_session_peer_ids() -> Array[int]:
	var network_session: Node = get_node_or_null(NETWORK_SESSION_PATH)
	if network_session != null and network_session.has_method("get_session_peer_ids"):
		var peer_ids: Array[int] = network_session.call("get_session_peer_ids") as Array[int]
		if not peer_ids.is_empty():
			peer_ids.sort()
			return peer_ids

	var fallback_peer_ids: Array[int] = []
	var local_peer_id: int = _get_local_peer_id_or_fallback()
	fallback_peer_ids.append(local_peer_id)
	for peer_id_value in _players_by_peer.keys():
		var peer_id: int = int(peer_id_value)
		if not fallback_peer_ids.has(peer_id):
			fallback_peer_ids.append(peer_id)
	fallback_peer_ids.sort()
	return fallback_peer_ids


func _get_spawn_position_for_peer(peer_id: int) -> Vector2:
	var primary_spawn: Node2D = get_node_or_null(player_spawn_path) as Node2D
	var secondary_spawn: Node2D = get_node_or_null(secondary_player_spawn_path) as Node2D
	var base_position: Vector2 = global_position
	if primary_spawn != null:
		base_position = primary_spawn.global_position

	var peer_ids: Array[int] = _get_sorted_session_peer_ids()
	var peer_index: int = peer_ids.find(peer_id)
	if peer_index <= 0:
		return base_position
	if peer_index == 1 and secondary_spawn != null:
		return secondary_spawn.global_position
	return base_position + additional_peer_spawn_offset * float(peer_index)


func _on_network_peer_joined(peer_id: int) -> void:
	_spawn_player_for_peer(peer_id)
	_sync_room_state_to_peer(peer_id)


func _on_network_peer_left(peer_id: int) -> void:
	_remove_player_for_peer(peer_id)


func _on_network_status_changed(_message: String) -> void:
	if _has_active_network_session():
		_spawn_existing_session_players()
		return
	_players_by_peer.clear()


func _resolve_local_interaction_player() -> Node2D:
	if _is_local_interaction_player_valid(_local_interaction_player):
		return _local_interaction_player

	for child in get_children():
		if not (child is Node2D):
			continue
		var candidate: Node2D = child as Node2D
		if not _is_local_interaction_player_valid(candidate):
			continue
		_local_interaction_player = candidate
		return _local_interaction_player

	return null


func _is_local_interaction_player_valid(player: Node) -> bool:
	if not _is_room_player_candidate(player):
		return false
	var local_input_enabled: Variant = player.get("enable_local_input")
	if local_input_enabled is bool:
		return bool(local_input_enabled)
	return true


func _is_room_player_candidate(player: Node) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not String(player.name).begins_with("Player"):
		return false
	return true


func _is_interact_up_just_pressed() -> bool:
	return Input.is_action_just_pressed("interact_up") or Input.is_action_just_pressed("ui_up")


func _get_interactable_distance_sq(interactable: Node, player: Node2D, can_interact_method: String) -> float:
	if interactable == null or not is_instance_valid(interactable):
		return INF
	if not interactable.has_method(can_interact_method):
		return INF
	if not bool(interactable.call(can_interact_method, player)):
		return INF
	if interactable is Node2D:
		return player.global_position.distance_squared_to((interactable as Node2D).global_position)
	return 0.0


func _force_interact(interactable: Node, player: Node2D) -> bool:
	if interactable == null or not is_instance_valid(interactable):
		return false
	if not interactable.has_method("force_singleplayer_interact"):
		return false
	return bool(interactable.call("force_singleplayer_interact", player))


func _ensure_instance_debug_label() -> void:
	if _instance_debug_layer != null and is_instance_valid(_instance_debug_layer) \
			and _instance_debug_label != null and is_instance_valid(_instance_debug_label):
		return

	_instance_debug_layer = CanvasLayer.new()
	_instance_debug_layer.name = "InstanceDebugLayer"
	add_child(_instance_debug_layer)

	_instance_debug_label = Label.new()
	_instance_debug_label.name = "InstanceDebugLabel"
	_instance_debug_label.position = Vector2(18.0, 18.0)
	_instance_debug_label.size = Vector2(1080.0, 78.0)
	_instance_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instance_debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_instance_debug_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.95))
	_instance_debug_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.1, 0.95))
	_instance_debug_label.add_theme_constant_override("outline_size", 4)
	_instance_debug_layer.add_child(_instance_debug_label)


func _refresh_instance_debug_label() -> void:
	var header_text: String = _build_instance_debug_header()
	var session_summary_text: String = _build_room_session_debug_summary()
	var should_show: bool = not header_text.is_empty() or session_summary_text != "SESSION UNKNOWN"
	if not should_show:
		if _instance_debug_label != null and is_instance_valid(_instance_debug_label):
			_instance_debug_label.visible = false
		return

	_ensure_instance_debug_label()
	_instance_debug_label.text = "%s\n%s" % [header_text, session_summary_text]
	_instance_debug_label.visible = true


func _build_room_session_debug_summary() -> String:
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime == null or not room_session_runtime.has_method("build_debug_summary_text"):
		return "SESSION UNKNOWN"
	return String(room_session_runtime.call("build_debug_summary_text"))


func _build_instance_debug_header() -> String:
	if not _instance_assignment.is_empty():
		var stage_number: int = max(0, int(_instance_assignment.get("stage_index", -1))) + 1
		return "INSTANCE %s | STAGE %d | RUN %s" % [
			String(_instance_assignment.get("instance_id", "UNKNOWN")),
			stage_number,
			String(_instance_assignment.get("run_id", "UNKNOWN")),
		]

	if _has_active_network_session():
		return "DIRECT ROOM | %s | NETWORK SESSION" % String(room_id)

	if not room_id.is_empty():
		return "DIRECT ROOM | %s | LOCAL" % String(room_id)

	return ""


func _apply_room_state(room_cleared: bool, chest_opened: bool) -> void:
	_room_cleared_state = room_cleared
	_loot_chest_opened_state = chest_opened

	if _exit_door != null and is_instance_valid(_exit_door) and _exit_door.has_method("set_is_open"):
		_exit_door.call("set_is_open", _room_cleared_state)

	if _loot_chest != null and is_instance_valid(_loot_chest):
		if _loot_chest.has_method("set_is_unlocked"):
			_loot_chest.call("set_is_unlocked", _room_cleared_state)
		if _loot_chest.has_method("set_is_opened"):
			_loot_chest.call("set_is_opened", _loot_chest_opened_state, "")


func _update_room_session_clear_state(alive_enemy_count: int) -> void:
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime == null or not room_session_runtime.has_method("set_room_clear_state"):
		return
	room_session_runtime.call("set_room_clear_state", _room_cleared_state, alive_enemy_count)


func _sync_room_state_to_all_peers() -> void:
	if not _is_network_room_host():
		return
	sync_dungeon_room_state.rpc(_room_cleared_state, _loot_chest_opened_state)


func _sync_room_state_to_peer(peer_id: int) -> void:
	if not _is_network_room_host():
		return
	sync_dungeon_room_state.rpc_id(peer_id, _room_cleared_state, _loot_chest_opened_state)


func _grant_dungeon_chest_reward_to_peer(peer_id: int, reward_payload: Dictionary) -> void:
	if peer_id == _get_local_peer_id_or_fallback() or not _is_networked_dungeon_room():
		_apply_dungeon_chest_reward_local(reward_payload)
		return
	receive_dungeon_room_chest_reward.rpc_id(peer_id, reward_payload.duplicate(true))


func _apply_dungeon_chest_reward_local(reward_payload: Dictionary) -> void:
	if _loot_chest == null or not is_instance_valid(_loot_chest):
		return
	var local_player: Node2D = _resolve_local_interaction_player()
	var reward_result := _loot_chest.call(
		"grant_reward_payload_to_local_player",
		reward_payload.duplicate(true),
		local_player
	) as Dictionary
	var exp_reward: int = int(reward_result.get("exp_reward", int(reward_payload.get("exp_reward", 0))))
	var granted_definition_ids := _coerce_definition_ids(
		reward_result.get("granted_definition_ids", PackedStringArray())
	)
	if _loot_chest.has_method("show_status_message"):
		_loot_chest.call("show_status_message", _build_chest_reward_status(exp_reward, granted_definition_ids.size()))


func _build_chest_reward_status(exp_reward: int, loot_count: int) -> String:
	if exp_reward > 0:
		return "EXP +%d" % exp_reward
	if loot_count > 0:
		return "Loot x%d" % loot_count
	return "Opened"


func _coerce_definition_ids(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var definition_ids := PackedStringArray()
	if value is Array:
		for entry in value:
			definition_ids.append(String(entry))
	return definition_ids


func _can_peer_interact_with_interactable(peer_id: int, interactable: Node) -> bool:
	if interactable == null or not is_instance_valid(interactable):
		return false
	var player: Node2D = _players_by_peer.get(peer_id, null) as Node2D
	if player == null or not is_instance_valid(player):
		return false
	if player.has_method("is_dead") and bool(player.call("is_dead")):
		return false
	if not interactable.has_method("can_player_interact"):
		return false
	return bool(interactable.call("can_player_interact", player))


func _advance_room_exit_for_all() -> void:
	exit_requested.emit(room_id)
	var flow_runtime: Node = get_node_or_null("/root/DungeonFlowRuntime")
	if flow_runtime != null \
			and flow_runtime.has_method("is_run_active") \
			and bool(flow_runtime.call("is_run_active")) \
			and flow_runtime.has_method("advance_after_room_exit"):
		flow_runtime.call_deferred("advance_after_room_exit")
		return
	if not exit_target_scene_path.is_empty():
		get_tree().change_scene_to_file(exit_target_scene_path)


func _refresh_tracked_room_players() -> void:
	var discovered_players: Dictionary = {}
	for candidate in _collect_room_player_nodes():
		var player_key: String = _resolve_room_player_key(candidate)
		if player_key.is_empty():
			continue
		discovered_players[player_key] = candidate
		if not _tracked_room_players.has(player_key):
			_track_room_player(candidate, player_key)

	for tracked_key_value in _tracked_room_players.keys():
		var tracked_key: String = String(tracked_key_value)
		if discovered_players.has(tracked_key):
			continue
		_untrack_room_player(tracked_key)


func _flush_tracked_room_players_to_session() -> void:
	for player_value in _tracked_room_players.values():
		if not (player_value is Node2D):
			continue
		var player: Node2D = player_value as Node2D
		_upsert_room_player_session_entry(player, _is_primary_room_player(player))


func _collect_room_player_nodes() -> Array[Node2D]:
	var players: Array[Node2D] = []
	for node in _collect_descendants(self):
		if not (node is Node2D):
			continue
		var candidate: Node2D = node as Node2D
		if not _is_room_player_candidate(candidate):
			continue
		players.append(candidate)
	return players


func _collect_room_enemy_nodes() -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for node in _collect_descendants(self):
		if not (node is Node2D):
			continue
		var candidate: Node2D = node as Node2D
		if not candidate.is_in_group(ENEMY_BODY_GROUP):
			continue
		enemies.append(candidate)
	return enemies


func _update_network_enemy_targets() -> void:
	if not _is_network_room_host():
		return

	var alive_players := _collect_alive_room_players()
	if alive_players.is_empty():
		return

	for enemy in _collect_room_enemy_nodes():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not _has_target_path_property(enemy):
			continue
		var target_player: Node2D = _find_nearest_room_player_for_enemy(enemy, alive_players)
		if target_player == null:
			continue
		enemy.set("target_path", enemy.get_path_to(target_player))


func _collect_alive_room_players() -> Array[Node2D]:
	var alive_players: Array[Node2D] = []
	for player in _collect_room_player_nodes():
		if player == null or not is_instance_valid(player):
			continue
		if player.has_method("is_dead") and bool(player.call("is_dead")):
			continue
		alive_players.append(player)
	return alive_players


func _find_nearest_room_player_for_enemy(enemy: Node2D, players: Array[Node2D]) -> Node2D:
	var best_player: Node2D = null
	var best_distance_sq: float = INF
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		var distance_sq: float = enemy.global_position.distance_squared_to(player.global_position)
		if distance_sq >= best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best_player = player
	return best_player


func _resolve_room_player_key(player: Node) -> String:
	if player == null or not is_instance_valid(player):
		return ""
	if player.has_method("get_runtime_player_session_snapshot"):
		var snapshot: Dictionary = player.call("get_runtime_player_session_snapshot") as Dictionary
		var player_key: String = String(snapshot.get("player_key", ""))
		if not player_key.is_empty():
			return player_key
	return "%d:%s" % [player.get_multiplayer_authority(), String(player.name)]


func _track_room_player(player: Node2D, player_key: String) -> void:
	if player == null or not is_instance_valid(player) or player_key.is_empty():
		return

	_tracked_room_players[player_key] = player
	if player.has_signal("attribute_profile_changed"):
		var profile_callback := Callable(self, "_on_tracked_player_attribute_profile_changed").bind(player)
		if not player.is_connected("attribute_profile_changed", profile_callback):
			player.connect("attribute_profile_changed", profile_callback)
	if player.has_signal("resources_changed"):
		var resources_callback := Callable(self, "_on_tracked_player_resources_changed").bind(player)
		if not player.is_connected("resources_changed", resources_callback):
			player.connect("resources_changed", resources_callback)
	if player.has_signal("death_state_changed"):
		var death_callback := Callable(self, "_on_tracked_player_death_state_changed").bind(player)
		if not player.is_connected("death_state_changed", death_callback):
			player.connect("death_state_changed", death_callback)
	var exit_callback := Callable(self, "_on_tracked_player_tree_exiting").bind(player_key)
	if not player.is_connected("tree_exiting", exit_callback):
		player.connect("tree_exiting", exit_callback)

	_upsert_room_player_session_entry(player, _is_primary_room_player(player))


func _untrack_room_player(player_key: String) -> void:
	if player_key.is_empty():
		return
	_tracked_room_players.erase(player_key)
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime != null and room_session_runtime.has_method("remove_player_entry"):
		room_session_runtime.call("remove_player_entry", player_key)
	_refresh_instance_debug_label()


func _upsert_room_player_session_entry(player: Node2D, make_primary: bool = false) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("get_runtime_player_session_snapshot"):
		return

	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime == null or not room_session_runtime.has_method("upsert_player_entry"):
		return

	var player_entry: Dictionary = player.call("get_runtime_player_session_snapshot") as Dictionary
	var spawn_node: Node2D = get_node_or_null(player_spawn_path) as Node2D
	player_entry["spawn_position"] = spawn_node.global_position if spawn_node != null else player.global_position
	player_entry["current_position"] = player.global_position
	player_entry["room_id"] = String(room_id)
	room_session_runtime.call("upsert_player_entry", player_entry, make_primary)


func _is_primary_room_player(player: Node) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var local_input_enabled: Variant = player.get("enable_local_input")
	if local_input_enabled is bool and bool(local_input_enabled):
		return true
	return player == _local_interaction_player


func _on_loot_chest_opened(chest_size: int, granted_definition_ids: PackedStringArray) -> void:
	_loot_chest_opened_state = true
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime != null and room_session_runtime.has_method("record_chest_opened"):
		room_session_runtime.call("record_chest_opened", chest_size, granted_definition_ids)
	_refresh_instance_debug_label()


func _on_tracked_player_attribute_profile_changed(_snapshot: Dictionary, player: Node2D) -> void:
	_upsert_room_player_session_entry(player, _is_primary_room_player(player))
	_refresh_instance_debug_label()


func _on_tracked_player_resources_changed(_current_hp: float, _max_hp: float, _current_mp: float, _max_mp: float, player: Node2D) -> void:
	_upsert_room_player_session_entry(player, _is_primary_room_player(player))
	_refresh_instance_debug_label()


func _on_tracked_player_death_state_changed(dead: bool, player: Node2D) -> void:
	_upsert_room_player_session_entry(player, _is_primary_room_player(player))
	var player_name: String = ""
	if player != null and is_instance_valid(player):
		if player.has_method("get_display_name"):
			player_name = String(player.call("get_display_name"))
		else:
			player_name = String(player.name)
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime != null and room_session_runtime.has_method("set_player_death_state"):
		room_session_runtime.call("set_player_death_state", _resolve_room_player_key(player), dead, player_name)
	_refresh_instance_debug_label()


func _on_tracked_player_tree_exiting(player_key: String) -> void:
	_untrack_room_player(player_key)


func _on_loot_chest_interaction_requested(peer_id: int) -> void:
	if _is_network_room_client():
		request_host_open_dungeon_chest.rpc_id(1, peer_id)
		return
	_handle_host_dungeon_chest_request(peer_id)


func _on_exit_door_interaction_requested(peer_id: int) -> void:
	if _is_network_room_client():
		request_host_use_dungeon_exit.rpc_id(1, peer_id)
		return
	_handle_host_dungeon_exit_request(peer_id)


func _handle_host_dungeon_chest_request(peer_id: int) -> void:
	if _loot_chest == null or _loot_chest_opened_state or not _room_cleared_state:
		return
	if not _can_peer_interact_with_interactable(peer_id, _loot_chest):
		return

	var reward_payload := _loot_chest.call("roll_reward_payload") as Dictionary
	var granted_definition_ids := _coerce_definition_ids(
		reward_payload.get("definition_ids", PackedStringArray())
	)
	_apply_room_state(true, true)
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime != null and room_session_runtime.has_method("record_chest_opened"):
		room_session_runtime.call("record_chest_opened", int(loot_chest_size) - 1, granted_definition_ids)
	_refresh_instance_debug_label()
	_sync_room_state_to_all_peers()
	_grant_dungeon_chest_reward_to_peer(peer_id, reward_payload)


func _handle_host_dungeon_exit_request(peer_id: int) -> void:
	if _exit_door == null or not _room_cleared_state:
		return
	if not _can_peer_interact_with_interactable(peer_id, _exit_door):
		return

	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime != null and room_session_runtime.has_method("record_exit_requested"):
		room_session_runtime.call("record_exit_requested")
	_refresh_instance_debug_label()

	if _is_networked_dungeon_room():
		advance_dungeon_room_for_all.rpc()
		return
	_advance_room_exit_for_all()


func _on_exit_door_interacted() -> void:
	if _is_networked_dungeon_room():
		return
	if _get_alive_enemy_count() > 0:
		return
	var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
	if room_session_runtime != null and room_session_runtime.has_method("record_exit_requested"):
		room_session_runtime.call("record_exit_requested")
	_refresh_instance_debug_label()
	_advance_room_exit_for_all()


func _place_exit_door_in_draw_order() -> void:
	if _exit_door == null or not is_instance_valid(_exit_door):
		return

	var target_index: int = get_child_count() - 1
	for index in range(get_child_count()):
		var child: Node = get_child(index)
		if child == _exit_door:
			continue
		if child is CharacterBody2D:
			target_index = index
			break

	move_child(_exit_door, target_index)


func _apply_loot_chest_configuration() -> void:
	if _loot_chest == null or not is_instance_valid(_loot_chest):
		return

	var mapped_chest_size: int = max(0, int(loot_chest_size) - 1)
	if _loot_chest.has_method("set_chest_size"):
		_loot_chest.call("set_chest_size", mapped_chest_size)
	_loot_chest.global_position = _resolve_loot_chest_spawn_position()
	if _loot_chest.has_method("snap_to_floor"):
		_loot_chest.call_deferred("snap_to_floor")


func _resolve_loot_chest_spawn_position() -> Vector2:
	var spawn_node: Node2D = get_node_or_null(loot_chest_spawn_path) as Node2D
	if spawn_node != null:
		return spawn_node.global_position

	var exit_spawn_node: Node2D = get_node_or_null(exit_door_spawn_path) as Node2D
	if exit_spawn_node != null:
		return exit_spawn_node.global_position + loot_chest_spawn_offset

	return global_position + loot_chest_spawn_offset


func _place_loot_chest_in_draw_order() -> void:
	if _loot_chest == null or not is_instance_valid(_loot_chest):
		return

	var target_index: int = get_child_count() - 1
	for index in range(get_child_count()):
		var child: Node = get_child(index)
		if child == _loot_chest:
			continue
		if child is CharacterBody2D:
			target_index = max(0, index - 1)
			break

	move_child(_loot_chest, target_index)


@rpc("authority", "call_remote", "reliable")
func sync_dungeon_room_state(room_cleared: bool, chest_opened: bool) -> void:
	var previous_chest_opened: bool = _loot_chest_opened_state
	_apply_room_state(room_cleared, chest_opened)
	_update_room_session_clear_state(-1)
	if chest_opened and not previous_chest_opened:
		var room_session_runtime: Node = get_node_or_null(ROOM_SESSION_RUNTIME_PATH)
		if room_session_runtime != null and room_session_runtime.has_method("record_chest_opened"):
			room_session_runtime.call("record_chest_opened", int(loot_chest_size) - 1, PackedStringArray())
	_refresh_instance_debug_label()


@rpc("authority", "call_remote", "reliable")
func receive_dungeon_room_chest_reward(reward_payload: Dictionary) -> void:
	_apply_dungeon_chest_reward_local(reward_payload)
	_refresh_instance_debug_label()


@rpc("authority", "call_local", "reliable")
func advance_dungeon_room_for_all() -> void:
	_advance_room_exit_for_all()


@rpc("any_peer", "call_remote", "reliable")
func request_host_open_dungeon_chest(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_handle_host_dungeon_chest_request(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_host_use_dungeon_exit(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_handle_host_dungeon_exit_request(peer_id)
