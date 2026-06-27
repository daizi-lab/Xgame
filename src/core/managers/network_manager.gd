extends Node

# Signals
signal connection_status_changed(connected: bool, msg: String)
signal player_list_updated()
signal snapshot_received()

const GalaxyManager = preload("res://src/core/managers/galaxy_manager.gd")
const Planet = preload("res://src/core/models/planet.gd")
const Fleet = preload("res://src/core/models/fleet.gd")
const ShipDesign = preload("res://src/core/models/ship_design.gd")
const ComponentsData = preload("res://src/core/data/components_data.gd")

var is_server: bool = false
var client_name: String = "Player"
var peers: Dictionary = {} # peer_id (int) -> name (String)
var my_peer_id: int = 1
var allocated_home_node_id: String = ""

# Reference to the active galaxy manager (on client: local replica, on host: authoritative)
var galaxy_manager: GalaxyManager

# Lobby & Room Management (Server only)
var rooms: Dictionary = {} # room_name (String) -> RoomInfo (Dictionary)
var peer_to_room: Dictionary = {} # peer_id (int) -> room_name (String)

# Global active combats tracking (for resume viewing and map status displays)
var active_combats: Dictionary = {}

func _ready() -> void:
	# Set up global font and size theme (shrink to 12px)
	_setup_global_theme()
	
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _setup_global_theme() -> void:
	if DisplayServer.get_name() == "headless":
		return
		
	var theme = Theme.new()
	var sys_font = SystemFont.new()
	sys_font.font_names = PackedStringArray(["Microsoft YaHei", "Segoe UI", "Arial", "Sans-Serif"])
	sys_font.hinting = TextServer.HINTING_LIGHT
	sys_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_HALF
	
	theme.default_font = sys_font
	theme.default_font_size = 12 # Shrunk globally from default 16
	get_tree().root.theme = theme
	
	# If running headless or with --server, host the game (unless it's a test client)
	if (DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--server")) and not OS.get_cmdline_args().has("--client"):
		var max_players = 32
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--max-players="):
				max_players = int(arg.split("=")[1])
			elif arg.begins_with("--max_players="):
				max_players = int(arg.split("=")[1])
		call_deferred("host_game", 9999, max_players)

func host_game(port: int, max_players: int = 32) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var max_clients = max(1, max_players - 1)
	var err = peer.create_server(port, max_clients)
	if err != OK:
		print("[NetworkManager] Failed to start server: ", err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	my_peer_id = 1
	peers[1] = "Server Host"
	
	print("[NetworkManager] Server successfully hosted on port %d with max players %d" % [port, max_players])
	return true

func join_game(ip: String, port: int, p_name: String) -> bool:
	client_name = p_name
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		print("[NetworkManager] Failed to initialize client peer: ", err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	print("[NetworkManager] Connecting to server at %s:%d..." % [ip, port])
	return true

func stop_game() -> void:
	multiplayer.multiplayer_peer = null
	is_server = false
	peers.clear()
	galaxy_manager = null
	allocated_home_node_id = ""
	rooms.clear()
	peer_to_room.clear()
	print("[NetworkManager] Network stopped.")

var autosave_timer: float = 0.0

func _process(delta: float) -> void:
	if is_server:
		var needs_broadcast = false
		autosave_timer += delta
		if autosave_timer >= 5.0:
			autosave_timer = 0.0
			needs_broadcast = true
			
		for room_name in rooms:
			var room = rooms[room_name]
			if room.get("game_started", false) and room.get("galaxy_manager"):
				room["galaxy_manager"].tick(delta)
				if needs_broadcast:
					_broadcast_room_universe_update(room_name)

	# Tick active combats
	var finished_combats = []
	for node_id in active_combats:
		var combat = active_combats[node_id]
		combat["elapsed"] += delta
		if combat["elapsed"] >= combat["duration"]:
			finished_combats.append(node_id)
	for node_id in finished_combats:
		active_combats.erase(node_id)

# ----------------- Multiplayer Callbacks -----------------

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: ", id)
	if peers.has(id):
		peers.erase(id)
	
	if is_server:
		var room_name = peer_to_room.get(id)
		if room_name and rooms.has(room_name):
			var room = rooms[room_name]
			room["peers"].erase(id)
			room["ready_states"].erase(id)
			peer_to_room.erase(id)
			
			if room["peers"].is_empty():
				rooms.erase(room_name)
				print("[NetworkManager] Room '%s' is empty, deleted." % room_name)
			else:
				if room["host_id"] == id:
					var new_host = room["peers"].keys()[0]
					room["host_id"] = new_host
					room["ready_states"][new_host] = true # Host is always ready
					print("[NetworkManager] Host disconnected. Migrated room '%s' host to peer %d" % [room_name, new_host])
				
				if room["game_started"] and room["galaxy_manager"]:
					var faction_name = "peer_" + str(id)
					var gm = room["galaxy_manager"]
					for node_id in gm.nodes:
						var node = gm.nodes[node_id]
						if node.owner_name == faction_name:
							node.owner_name = "Neutral"
							for p in node.planets:
								p.owner_name = "Neutral"
					gm.moving_fleets = gm.moving_fleets.filter(func(f): return f.owner_name != faction_name)
					_broadcast_room_universe_update(room_name)
				
				_broadcast_room_state(room_name)
		player_list_updated.emit()

func _on_connected_to_server() -> void:
	my_peer_id = multiplayer.get_unique_id()
	print("[NetworkManager] Successfully connected to server. My peer ID: ", my_peer_id)
	connection_status_changed.emit(true, "已连接到服务器大厅，请创建或加入房间。")

func _on_connection_failed() -> void:
	print("[NetworkManager] Failed to connect to server.")
	connection_status_changed.emit(false, "连接失败，无法连接到主机。")
	stop_game()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected.")
	connection_status_changed.emit(false, "与服务器断开连接。")
	stop_game()
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://src/ui/main_menu.tscn")

# ----------------- Lobby Room RPCs -----------------

func _leave_current_room(peer_id: int) -> void:
	var room_name = peer_to_room.get(peer_id)
	if not room_name or not rooms.has(room_name):
		return
		
	var room = rooms[room_name]
	room["peers"].erase(peer_id)
	room["ready_states"].erase(peer_id)
	peer_to_room.erase(peer_id)
	
	if room["peers"].is_empty():
		rooms.erase(room_name)
		print("[NetworkManager] Room '%s' is empty, deleted." % room_name)
	else:
		if room["host_id"] == peer_id:
			var new_host = room["peers"].keys()[0]
			room["host_id"] = new_host
			room["ready_states"][new_host] = true
			print("[NetworkManager] Host left room '%s'. New host is peer %d" % [room_name, new_host])
		_broadcast_room_state(room_name)

@rpc("any_peer", "reliable")
func server_request_create_room(room_name: String, password: String, player_name: String) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_leave_current_room(sender_id)
	room_name = room_name.strip_edges()
	if room_name.is_empty():
		rpc_id(sender_id, "client_receive_lobby_error", "房间名称不能为空！")
		return
	
	if rooms.has(room_name):
		rpc_id(sender_id, "client_receive_lobby_error", "房间名称已存在！")
		return
		
	peers[sender_id] = player_name
	
	var room = {
		"room_name": room_name,
		"password": password,
		"host_id": sender_id,
		"peers": {sender_id: player_name},
		"ready_states": {sender_id: true},
		"galaxy_manager": null,
		"game_started": false
	}
	rooms[room_name] = room
	peer_to_room[sender_id] = room_name
	
	print("[NetworkManager] Peer %d created room '%s'" % [sender_id, room_name])
	_broadcast_room_state(room_name)

@rpc("any_peer", "reliable")
func server_request_join_room(room_name: String, password: String, player_name: String) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_leave_current_room(sender_id)
	room_name = room_name.strip_edges()
	if not rooms.has(room_name):
		rpc_id(sender_id, "client_receive_lobby_error", "房间不存在！")
		return
		
	var room = rooms[room_name]
	if room["game_started"]:
		rpc_id(sender_id, "client_receive_lobby_error", "该房间的游戏已经开始！")
		return
		
	if not room["password"].is_empty() and room["password"] != password:
		rpc_id(sender_id, "client_receive_lobby_error", "密码错误！")
		return
		
	peers[sender_id] = player_name
	room["peers"][sender_id] = player_name
	room["ready_states"][sender_id] = false
	peer_to_room[sender_id] = room_name
	
	print("[NetworkManager] Peer %d joined room '%s'" % [sender_id, room_name])
	_broadcast_room_state(room_name)

@rpc("any_peer", "reliable")
func server_request_toggle_ready() -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
		
	var room = rooms[room_name]
	if room["host_id"] == sender_id:
		return
		
	room["ready_states"][sender_id] = not room["ready_states"].get(sender_id, false)
	_broadcast_room_state(room_name)

@rpc("any_peer", "reliable")
func server_request_exit_room() -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
		
	var room = rooms[room_name]
	room["peers"].erase(sender_id)
	room["ready_states"].erase(sender_id)
	peer_to_room.erase(sender_id)
	
	rpc_id(sender_id, "client_receive_exit_room_success")
	
	if room["peers"].is_empty():
		rooms.erase(room_name)
		print("[NetworkManager] Room '%s' is empty, deleted." % room_name)
	else:
		if room["host_id"] == sender_id:
			var new_host = room["peers"].keys()[0]
			room["host_id"] = new_host
			room["ready_states"][new_host] = true
			print("[NetworkManager] Host left room '%s'. New host is peer %d" % [room_name, new_host])
		_broadcast_room_state(room_name)

@rpc("any_peer", "reliable")
func server_request_start_game() -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
		
	var room = rooms[room_name]
	if room["host_id"] != sender_id:
		return
		
	for pid in room["peers"]:
		if pid != room["host_id"] and not room["ready_states"].get(pid, false):
			rpc_id(sender_id, "client_receive_lobby_error", "还有玩家未准备，无法开始游戏！")
			return
			
	var gm = GalaxyManager.new()
	gm.generate_galaxy()
	room["galaxy_manager"] = gm
	
	# Set 10% of systems to "Enemy" to introduce PvE elements in multiplayer, others to "Neutral"
	var all_node_ids = gm.nodes.keys()
	all_node_ids.shuffle()
	var enemy_count = 0
	var target_enemy_max = 10 # 10% of 100 systems
	
	for node_id in all_node_ids:
		var node = gm.nodes[node_id]
		if enemy_count < target_enemy_max:
			node.owner_name = "Enemy"
			enemy_count += 1
		else:
			node.owner_name = "Neutral"
			
	var home_nodes = {}
	for pid in room["peers"]:
		var home_node_id = _allocate_room_home_system(gm, pid)
		home_nodes[pid] = home_node_id
		
	room["game_started"] = true
	print("[NetworkManager] Game started in room '%s'!" % room_name)
	
	for pid in room["peers"]:
		var snapshot_bytes = var_to_bytes_with_objects(gm)
		rpc_id(pid, "client_receive_start_game", snapshot_bytes, home_nodes[pid])

func _allocate_room_home_system(gm: GalaxyManager, peer_id: int) -> String:
	var faction_name = "peer_" + str(peer_id)
	
	var neutral_nodes = []
	for n_id in gm.nodes:
		if gm.nodes[n_id].owner_name == "Neutral":
			neutral_nodes.append(n_id)
			
	if neutral_nodes.is_empty():
		return ""
		
	var selected_id = neutral_nodes[randi() % neutral_nodes.size()]
	var node = gm.nodes[selected_id]
	node.owner_name = faction_name
	
	for idx in range(node.planets.size()):
		var p = node.planets[idx]
		p.owner_name = faction_name
		p.buildings = [
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0},
			{"type": "empty", "level": 0}
		]
		
	if not gm.player_resources.has(faction_name):
		gm.player_resources[faction_name] = {
			"metal": 1000.0,
			"crystal": 1000.0,
			"deuterium": 1000.0
		}
	return selected_id

func _broadcast_room_state(room_name: String) -> void:
	if not rooms.has(room_name):
		return
	var room = rooms[room_name]
	for pid in room["peers"]:
		rpc_id(pid, "client_receive_room_state", room_name, room["host_id"], room["peers"], room["ready_states"])

# ----------------- Client Lobby RPCs -----------------

@rpc("authority", "reliable")
func client_receive_lobby_error(err_msg: String) -> void:
	connection_status_changed.emit(false, err_msg)

@rpc("authority", "reliable")
func client_receive_room_state(room_name: String, host_id: int, peers_dict: Dictionary, ready_states: Dictionary) -> void:
	var lobby = get_tree().current_scene
	if lobby and lobby.has_method("update_waiting_room"):
		lobby.update_waiting_room(room_name, host_id, peers_dict, ready_states)

@rpc("authority", "reliable")
func client_receive_exit_room_success() -> void:
	var lobby = get_tree().current_scene
	if lobby and lobby.has_method("show_connect_panel"):
		lobby.show_connect_panel()

@rpc("authority", "reliable")
func client_receive_start_game(snapshot_bytes: PackedByteArray, home_node: String) -> void:
	var lobby = get_tree().current_scene
	if lobby and lobby.has_method("show_loading_screen"):
		lobby.show_loading_screen("正在初始化星系星图数据...")
		
	var tree = get_tree()
	if tree:
		await tree.process_frame
		await tree.process_frame
		
	allocated_home_node_id = home_node
	var loaded_manager = bytes_to_var_with_objects(snapshot_bytes) as GalaxyManager
	if loaded_manager:
		loaded_manager.reconnect_signals()
		galaxy_manager = loaded_manager
		var home = galaxy_manager.get_node_by_id(home_node)
		if home and not home.planets.is_empty():
			galaxy_manager.selected_planet = home.planets[0]
		print("[NetworkManager] Room game started. Home Node: ", home_node)
		snapshot_received.emit()

# ----------------- Client Gameplay RPCs -----------------

@rpc("authority", "reliable")
func client_receive_universe_update(snapshot_bytes: PackedByteArray) -> void:
	if is_server:
		return
	var loaded_manager = bytes_to_var_with_objects(snapshot_bytes) as GalaxyManager
	if loaded_manager:
		loaded_manager.reconnect_signals()
		var sel_planet_id = ""
		if galaxy_manager and galaxy_manager.selected_planet:
			sel_planet_id = galaxy_manager.selected_planet.planet_id
		
		galaxy_manager = loaded_manager
		
		if not sel_planet_id.is_empty():
			for n_id in galaxy_manager.nodes:
				var node = galaxy_manager.nodes[n_id]
				for p in node.planets:
					if p.planet_id == sel_planet_id:
						galaxy_manager.selected_planet = p
						break
		snapshot_received.emit()

func _broadcast_room_universe_update(room_name: String) -> void:
	if not is_server or not rooms.has(room_name):
		return
	var room = rooms[room_name]
	var gm = room["galaxy_manager"]
	if not gm:
		return
	var snapshot_bytes = var_to_bytes_with_objects(gm)
	for peer_id in room["peers"]:
		rpc_id(peer_id, "client_receive_universe_update", snapshot_bytes)

@rpc("authority", "reliable")
func client_receive_battle_occurred(report: Dictionary) -> void:
	if is_server:
		return
	if galaxy_manager:
		galaxy_manager.battle_occurred.emit(report)

func broadcast_battle(gm: GalaxyManager, report: Dictionary) -> void:
	if not is_server:
		return
	for room_name in rooms:
		var room = rooms[room_name]
		if room.get("galaxy_manager") == gm:
			for peer_id in room["peers"]:
				rpc_id(peer_id, "client_receive_battle_occurred", report)
			break

# ----------------- Client-to-Server Gameplay Actions -----------------

@rpc("any_peer", "reliable")
func server_request_upgrade_building(planet_id: String, slot_index: int, proposed_type: String) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
	var room = rooms[room_name]
	var gm = room["galaxy_manager"]
	if not gm:
		return
		
	var faction_name = "peer_" + str(sender_id)
	var planet: Planet = null
	for n_id in gm.nodes:
		var node = gm.nodes[n_id]
		for p in node.planets:
			if p.planet_id == planet_id:
				planet = p
				break
	
	if not planet or planet.owner_name != faction_name:
		return
		
	if not gm.player_resources.has(faction_name):
		return
	var res_pool = gm.player_resources[faction_name]
	
	# Validation checks
	if slot_index < 0 or slot_index >= planet.buildings.size():
		return
	var valid_types = ["metal_mine", "crystal_mine", "deuterium_synthesizer", "solar_power_plant", "shipyard"]
	var existing_type = planet.buildings[slot_index]["type"]
	if existing_type == "empty":
		if not proposed_type in valid_types:
			return
	else:
		if proposed_type != existing_type:
			return
			
	if planet.start_building_upgrade(slot_index, proposed_type, res_pool):
		print("[NetworkManager] Peer %d start upgrade/build in slot %d in room %s" % [sender_id, slot_index, room_name])
		_broadcast_room_universe_update(room_name)

@rpc("any_peer", "reliable")
func server_request_ship_construction_with_design(planet_id: String, design_name: String, quantity: int, design_dict: Dictionary) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
	var room = rooms[room_name]
	var gm = room["galaxy_manager"]
	if not gm:
		return
		
	var faction_name = "peer_" + str(sender_id)
	var planet: Planet = null
	var target_node = null
	for n_id in gm.nodes:
		var node = gm.nodes[n_id]
		for p in node.planets:
			if p.planet_id == planet_id:
				planet = p
				target_node = node
				break
		if planet:
			break
				
	if not planet or planet.owner_name != faction_name:
		return
		
	var design_obj = ShipDesign.new(design_dict.get("design_name", ""), design_dict.get("hull_id", ""))
	design_obj.weapons = design_dict.get("weapons", [])
	design_obj.shields = design_dict.get("shields", [])
	design_obj.utilities = design_dict.get("utilities", [])
	
	# Validation checks
	if quantity <= 0 or quantity > 1000000:
		return
	var hull_id = design_dict.get("hull_id", "")
	if not ComponentsData.HULLS.has(hull_id):
		return
	if not design_obj.is_valid():
		return
		
	if not gm.player_resources.has(faction_name):
		return
	var res_pool = gm.player_resources[faction_name]
	var cost = design_obj.get_total_cost()
	
	# Calculate system-wide shipyard level server-side
	var system_shipyard_lvl = 0
	if target_node:
		for p in target_node.planets:
			if p.owner_name == faction_name:
				system_shipyard_lvl += p.get_building_total_level("shipyard")
				
	if system_shipyard_lvl <= 0:
		return # Anti-cheat: must have at least one shipyard in the system
		
	if planet.start_ship_construction(design_name, design_obj.hull_id, quantity, cost, design_obj, res_pool, system_shipyard_lvl):
		print("[NetworkManager] Peer %d build ship in room %s" % [sender_id, room_name])
		_broadcast_room_universe_update(room_name)

@rpc("any_peer", "reliable")
func server_request_demolish_building(planet_id: String, slot_index: int) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
	var room = rooms[room_name]
	var gm = room["galaxy_manager"]
	if not gm:
		return
		
	var faction_name = "peer_" + str(sender_id)
	var planet: Planet = null
	for n_id in gm.nodes:
		var node = gm.nodes[n_id]
		for p in node.planets:
			if p.planet_id == planet_id:
				planet = p
				break
		if planet:
			break
				
	if not planet or planet.owner_name != faction_name:
		return
		
	if planet.demolish_building(slot_index):
		print("[NetworkManager] Peer %d demolished building in slot %d in room %s" % [sender_id, slot_index, room_name])
		_broadcast_room_universe_update(room_name)

@rpc("any_peer", "reliable")
func server_request_toggle_auto_manage(node_id: String, enabled: bool, target: String) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
	var room = rooms[room_name]
	var gm = room["galaxy_manager"]
	if not gm:
		return
		
	var faction_name = "peer_" + str(sender_id)
	var node = gm.get_node_by_id(node_id)
	if not node or node.owner_name != faction_name:
		return
		
	node.is_auto_managed = enabled
	node.auto_manage_target = target
	print("[NetworkManager] Peer %d set auto-manage for system %s: %s, target: %s" % [sender_id, node_id, enabled, target])
	_broadcast_room_universe_update(room_name)

@rpc("any_peer", "reliable")
func server_request_form_fleet(planet_id: String, fleet_name: String, ships_dict: Dictionary) -> void:
	if ships_dict.is_empty():
		return
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
	var room = rooms[room_name]
	var gm = room["galaxy_manager"]
	if not gm:
		return
		
	var faction_name = "peer_" + str(sender_id)
	var planet: Planet = null
	var node = null
	for n_id in gm.nodes:
		var n = gm.nodes[n_id]
		for p in n.planets:
			if p.planet_id == planet_id:
				planet = p
				node = n
				break
				
	if not planet or planet.owner_name != faction_name or not node:
		return
		
	# Validate quantities are strictly positive
	for d_name in ships_dict:
		if ships_dict[d_name] <= 0:
			return
			
	# Validate system-wide available ships
	for d_name in ships_dict:
		var qty_required = ships_dict[d_name]
		var total_available = 0
		for p in node.planets:
			if p.owner_name == faction_name:
				total_available += p.hangar.get(d_name, 0)
		if total_available < qty_required:
			return
			
	# Deduct ships from system's planets sequentially
	for d_name in ships_dict:
		var qty_to_deduct = ships_dict[d_name]
		for p in node.planets:
			if p.owner_name == faction_name and p.hangar.has(d_name):
				var available = p.hangar[d_name]
				var deduct = min(available, qty_to_deduct)
				p.hangar[d_name] -= deduct
				qty_to_deduct -= deduct
				if p.hangar[d_name] <= 0:
					p.hangar.erase(d_name)
				if qty_to_deduct <= 0:
					break
			
	var f = Fleet.new(fleet_name)
	f.owner_name = faction_name
	f.current_node_id = node.node_id
	
	for d_name in ships_dict:
		var qty = ships_dict[d_name]
		var design_obj = null
		for p in node.planets:
			if p.owner_name == faction_name and p.designs.has(d_name):
				design_obj = p.designs[d_name]
				break
		if design_obj:
			f.add_ships(design_obj, qty)
		else:
			var temp_design = ShipDesign.new(d_name, "frigate")
			f.add_ships(temp_design, qty)
			
	node.add_fleet(f)
	_broadcast_room_universe_update(room_name)

@rpc("any_peer", "reliable")
func server_request_dispatch_fleet(fleet_name: String, origin_node_id: String, target_node_id: String) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var room_name = peer_to_room.get(sender_id)
	if not room_name or not rooms.has(room_name):
		return
	var room = rooms[room_name]
	var gm = room["galaxy_manager"]
	if not gm:
		return
		
	var faction_name = "peer_" + str(sender_id)
	var origin_node = gm.get_node_by_id(origin_node_id)
	if not origin_node:
		return
		
	var fleet: Fleet = null
	for f in origin_node.stationed_fleets:
		if f.fleet_name == fleet_name and f.owner_name == faction_name:
			fleet = f
			break
			
	if not fleet:
		return
		
	if gm.dispatch_fleet(fleet, target_node_id):
		_broadcast_room_universe_update(room_name)

# ----------------- Helper Functions -----------------

func is_multiplayer_active() -> bool:
	var peer = multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)

func get_my_resources() -> Dictionary:
	if not galaxy_manager:
		return {"metal": 0.0, "crystal": 0.0, "deuterium": 0.0}
	if is_server:
		var room_name = peer_to_room.get(1)
		if room_name and rooms.has(room_name):
			var room = rooms[room_name]
			if room.get("galaxy_manager") and room["galaxy_manager"].player_resources.has("peer_1"):
				return room["galaxy_manager"].player_resources["peer_1"]
		return {"metal": 0.0, "crystal": 0.0, "deuterium": 0.0}
	else:
		if not is_multiplayer_active():
			return galaxy_manager.player_resources
		var faction_name = "peer_" + str(my_peer_id)
		if not galaxy_manager.player_resources.has(faction_name):
			return {"metal": 0.0, "crystal": 0.0, "deuterium": 0.0}
		return galaxy_manager.player_resources[faction_name] as Dictionary

func is_my_faction(owner_name: String) -> bool:
	if not is_multiplayer_active():
		return owner_name == "Player"
	return owner_name == "peer_" + str(my_peer_id)

func get_faction_color(owner_name: String) -> Color:
	if owner_name == "Neutral":
		return Color.GRAY
	if is_my_faction(owner_name):
		return Color.CYAN
	return Color.RED

func get_faction_display_name(owner_name: String) -> String:
	if owner_name == "Neutral":
		return "中立势力"
	if owner_name == "Player":
		return "玩家 (Player)"
	if owner_name == "Enemy":
		return "敌方 AI"
	if owner_name.begins_with("peer_"):
		var pid = int(owner_name.replace("peer_", ""))
		if pid == my_peer_id:
			return client_name + " (我)"
		return peers.get(pid, "玩家_" + str(pid))
	return owner_name
