class_name GalaxyManager
extends Resource

const GalaxyNode = preload("res://src/core/models/galaxy_node.gd")
const Fleet = preload("res://src/core/models/fleet.gd")
const ShipDesign = preload("res://src/core/models/ship_design.gd")
const BattleSimulator = preload("res://src/core/simulator/battle_simulator.gd")
const Planet = preload("res://src/core/models/planet.gd")

signal fleet_dispatched(fleet: Fleet)
signal fleet_moved(fleet: Fleet)
signal fleet_arrived(fleet: Fleet, node: GalaxyNode)
signal battle_occurred(result: Dictionary)
signal planet_ship_completed(planet: Planet, design_name: String)

@export var nodes: Dictionary = {} # node_id (String) -> GalaxyNode
@export var moving_fleets: Array[Fleet] = []
var battle_logs_history: Array[Dictionary] = []

@export var player_resources: Dictionary = {
	"metal": 1000.0,
	"crystal": 1000.0,
	"deuterium": 1000.0
}
@export var enemy_resources: Dictionary = {
	"metal": 1000.0,
	"crystal": 1000.0,
	"deuterium": 1000.0
}
@export var selected_planet: Planet = null
@export var singleplayer_home_node_id: String = ""

@export var game_time_elapsed: float = 0.0
var ai_tick_timer: float = 0.0


func _init() -> void:
	pass

func get_enemy_resource_pool(faction_name: String) -> Dictionary:
	if enemy_resources.has("metal") and not enemy_resources.has(faction_name):
		if faction_name == "Enemy":
			return enemy_resources
		var old_res = enemy_resources.duplicate()
		enemy_resources.clear()
		enemy_resources["Enemy"] = old_res
		
	if not enemy_resources.has(faction_name):
		enemy_resources[faction_name] = {
			"metal": 1000.0,
			"crystal": 1000.0,
			"deuterium": 1000.0
		}
	return enemy_resources[faction_name]

func generate_galaxy(faction_count: int = 1, map_size: String = "medium") -> void:
	_generate_default_galaxy(faction_count, map_size)

func _get_roman_num(idx: int) -> String:
	match idx:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
	return str(idx)

func _generate_default_galaxy(faction_count: int = 1, map_size: String = "medium") -> void:
	nodes.clear()
	
	# Determine if we are in multiplayer mode by checking the autoload NetworkManager
	var is_multiplayer = false
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root and main_loop.root.has_node("NetworkManager"):
		var nm = main_loop.root.get_node("NetworkManager")
		if nm.has_method("is_multiplayer_active") and nm.is_multiplayer_active():
			is_multiplayer = true
			
	var base_names = [
		"太阳系 (Sol)", "大角星系 (Arcturus)", "半人马座 (Centauri)", "天狼星系 (Sirius)", 
		"织女星系 (Vega)", "参宿四 (Betelgeuse)", "北极星系 (Polaris)", "心宿二 (Antares)", 
		"毕宿五 (Aldebaran)", "五车二 (Capella)", "南河三 (Procyon)", "北河三 (Pollux)", 
		"角宿一 (Spica)", "河鼓二 (Altair)", "北落师门 (Fomalhaut)", "天津四 (Deneb)", 
		"轩辕十四 (Regulus)", "玉衡星系 (Alioth)", "天枢星系 (Dubhe)", "天玑星系 (Phecda)"
	]
	
	var greek_prefixes = ["阿尔法 (Alpha)", "贝塔 (Beta)", "伽马 (Gamma)", "德尔塔 (Delta)", "伊普西龙 (Epsilon)", "泽塔 (Zeta)", "艾塔 (Eta)", "西塔 (Theta)", "约塔 (Iota)", "卡帕 (Kappa)", "兰姆达 (Lambda)", "缪 (Mu)", "纽 (Nu)", "克西 (Xi)", "奥密克戎 (Omicron)", "派 (Pi)", "罗 (Rho)", "西格玛 (Sigma)", "陶 (Tau)", "宇普西龙 (Upsilon)", "斐 (Phi)", "希 (Chi)", "普赛 (Psi)", "欧米伽 (Omega)"]
	var cosmic_suffixes = ["星区 (Sector)", "星域 (Reach)", "极星 (Prime)", "主星 (Major)", "伴星 (Minor)", "二号 (Secundus)", "三号 (Tertius)", "星系 (System)", "新星 (Nova)", "要塞 (Fortress)", "边界 (Frontier)", "核心 (Core)", "枢纽 (Nexus)", "集聚区 (Cluster)"]
	
	var names = []
	names.append_array(base_names)
	
	var generated_names_set = {}
	for n in base_names:
		generated_names_set[n] = true
		
	# Randomize seed
	randomize()
	
	# Generate procedural names up to 120 unique ones
	while names.size() < 120:
		var pref = greek_prefixes[randi() % greek_prefixes.size()]
		var suff = cosmic_suffixes[randi() % cosmic_suffixes.size()]
		var pref_zh = pref.split(" ")[0]
		var pref_en = pref.split(" ")[1].replace("(", "").replace(")", "")
		var suff_zh = suff.split(" ")[0]
		var suff_en = suff.split(" ")[1].replace("(", "").replace(")", "")
		var comb_name = "%s%s (%s %s)" % [pref_zh, suff_zh, pref_en, suff_en]
		if not generated_names_set.has(comb_name):
			generated_names_set[comb_name] = true
			names.append(comb_name)
			
	var generated_nodes = []
	var planets_min = 1
	var planets_max = 4
	
	if is_multiplayer:
		# Multiplayer: 100 systems randomly distributed in 2000x2000 space
		var num_nodes = 100
		var min_dist = 100.0
		var max_attempts = 1500
		var system_count = 0
		var attempts = 0
		while system_count < num_nodes and attempts < max_attempts:
			attempts += 1
			var x = randf_range(100.0, 1900.0)
			var y = randf_range(100.0, 1900.0)
			var pos = Vector2(x, y)
			
			var overlap = false
			for n in generated_nodes:
				if pos.distance_to(n.position) < min_dist:
					overlap = true
					break
			if overlap:
				continue
				
			var node_id = "sys_" + str(system_count)
			var node_name = names[system_count]
			
			var node = GalaxyNode.new(node_id, node_name, pos, "Neutral")
			add_node(node)
			generated_nodes.append(node)
			system_count += 1
	else:
		# Singleplayer layout configuration based on map_size
		var num_nodes = 50
		var sol_pos = Vector2(80, 250)
		var x_min = 160.0
		var x_max = 640.0
		var y_min = 50.0
		var y_max = 450.0
		var min_dist = 85.0
		
		if map_size == "small":
			num_nodes = 20
			sol_pos = Vector2(80, 300)
			x_min = 160.0
			x_max = 800.0
			y_min = 50.0
			y_max = 550.0
			min_dist = 85.0
			planets_min = 1
			planets_max = 2
		elif map_size == "large":
			num_nodes = 100
			sol_pos = Vector2(80, 600)
			x_min = 180.0
			x_max = 1800.0
			y_min = 50.0
			y_max = 1200.0
			min_dist = 100.0
			planets_min = 2
			planets_max = 5
		else: # "medium"
			num_nodes = 50
			sol_pos = Vector2(80, 420)
			x_min = 180.0
			x_max = 1200.0
			y_min = 50.0
			y_max = 800.0
			min_dist = 90.0
			planets_min = 1
			planets_max = 4
			
		# Place Sol (Player starting system - initially Neutral until selected)
		var sol = GalaxyNode.new("sol", names[0], sol_pos, "Neutral")
		add_node(sol)
		generated_nodes.append(sol)
		
		# Place AI factions starting systems
		var starting_nodes = []
		for i in range(1, faction_count + 1):
			var faction_name = "Enemy" if faction_count == 1 else "Enemy_" + str(i)
			var node_id = "enemy_start_" + str(i)
			var node_name = names[i]
			
			# Find a spaced position for this faction's start
			var start_pos = Vector2.ZERO
			var pos_attempts = 0
			var min_dist_from_others = 200.0
			var min_dist_from_sol = 220.0
			if map_size == "small":
				min_dist_from_others = 140.0
				min_dist_from_sol = 160.0
			elif map_size == "large":
				min_dist_from_others = 300.0
				min_dist_from_sol = 350.0
				
			while pos_attempts < 200:
				pos_attempts += 1
				var rx = randf_range(x_min + 50.0, x_max - 50.0)
				var ry = randf_range(y_min + 50.0, y_max - 50.0)
				var candidate = Vector2(rx, ry)
				
				if candidate.distance_to(sol_pos) < min_dist_from_sol:
					continue
				
				var too_close = false
				for placed in starting_nodes:
					if candidate.distance_to(placed.position) < min_dist_from_others:
						too_close = true
						break
				if too_close:
					continue
					
				start_pos = candidate
				break
				
			if start_pos == Vector2.ZERO:
				# Fallback position spacing out
				var fraction = float(i) / float(faction_count)
				start_pos = Vector2(x_min + (x_max - x_min) * fraction, y_min + (y_max - y_min) * fraction)
				
			var node = GalaxyNode.new(node_id, node_name, start_pos, faction_name)
			add_node(node)
			generated_nodes.append(node)
			starting_nodes.append(node)
			
		# Generate remaining random neutral nodes
		var system_count = 1 + faction_count
		var attempts = 0
		var max_attempts = 400 if map_size == "small" else (800 if map_size == "medium" else 1500)
		while system_count < num_nodes and attempts < max_attempts:
			attempts += 1
			var x = randf_range(x_min, x_max)
			var y = randf_range(y_min, y_max)
			var pos = Vector2(x, y)
			
			var overlap = false
			for n in generated_nodes:
				if pos.distance_to(n.position) < min_dist:
					overlap = true
					break
			if overlap:
				continue
				
			var node_id = "sys_" + str(system_count)
			var node_name = names[system_count]
			
			var owner = "Neutral"
			# original balance: if only 1 faction, assign 2 random nodes to it as well
			if faction_count == 1 and (system_count == 2 or system_count == 3):
				owner = "Enemy"
				
			var node = GalaxyNode.new(node_id, node_name, pos, owner)
			add_node(node)
			generated_nodes.append(node)
			system_count += 1
			
	# Generate planets for each system
	for node in generated_nodes:
		var num_planets = randi_range(planets_min, planets_max)
		node.planets.clear()
		for i in range(1, num_planets + 1):
			var p_id = node.node_id + "_p" + str(i)
			var base_name = node.node_name.split(" ")[0]
			var p_name = base_name + " " + _get_roman_num(i)
			var planet = Planet.new(p_id, p_name, node.owner_name)
			planet.ship_completed.connect(func(d_name, _hull_id):
				planet_ship_completed.emit(planet, d_name)
			)
			node.planets.append(planet)
			
	# Default selected planet
	if is_multiplayer:
		selected_planet = null
	else:
		var sol_node = get_node_by_id("sol")
		if sol_node and sol_node.planets.size() > 0:
			selected_planet = sol_node.planets[0]
		
	# Connect lanes (Minimum Spanning Tree)
	var visited = [generated_nodes[0]]
	var unvisited = generated_nodes.slice(1)
	
	while unvisited.size() > 0:
		var min_dist = 99999.0
		var best_u = null
		var best_v = null
		for u in visited:
			for v in unvisited:
				var d = u.position.distance_to(v.position)
				if d < min_dist:
					min_dist = d
					best_u = u
					best_v = v
		if best_u and best_v:
			connect_nodes(best_u.node_id, best_v.node_id)
			visited.append(best_v)
			unvisited.erase(best_v)
			
	# Add extra proximity connections (limit node degree to prevent clutter)
	var prox_limit = 250.0 if is_multiplayer else 160.0
	for u in generated_nodes:
		for v in generated_nodes:
			if u != v:
				var d = u.position.distance_to(v.position)
				if d < prox_limit:
					if not u.connected_node_ids.has(v.node_id):
						if u.connected_node_ids.size() < 3 and v.connected_node_ids.size() < 3:
							connect_nodes(u.node_id, v.node_id)

func add_node(node: GalaxyNode) -> void:
	nodes[node.node_id] = node

func get_node_by_id(node_id: String) -> GalaxyNode:
	return nodes.get(node_id) as GalaxyNode


func connect_nodes(id_a: String, id_b: String) -> void:
	if nodes.has(id_a) and nodes.has(id_b):
		var node_a = nodes[id_a]
		var node_b = nodes[id_b]
		if not node_a.connected_node_ids.has(id_b):
			node_a.connected_node_ids.append(id_b)
		if not node_b.connected_node_ids.has(id_a):
			node_b.connected_node_ids.append(id_a)

func find_shortest_path(start_id: String, end_id: String) -> Array[String]:
	var result: Array[String] = []
	if not nodes.has(start_id) or not nodes.has(end_id):
		return result
	if start_id == end_id:
		return result
		
	var queue = []
	queue.append([start_id])
	var visited = {}
	visited[start_id] = true
	
	while not queue.is_empty():
		var path = queue.pop_front()
		var current = path[-1]
		
		if current == end_id:
			for i in range(1, path.size()):
				result.append(path[i])
			return result
			
		var node = nodes[current]
		for neighbor_id in node.connected_node_ids:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				var new_path = path.duplicate()
				new_path.append(neighbor_id)
				queue.append(new_path)
				
	return result

func _dispatch_next_leg(fleet: Fleet) -> void:
	if fleet.movement_path.is_empty():
		return
		
	var next_target = fleet.movement_path.pop_front()
	var origin_id = fleet.current_node_id
	if not nodes.has(origin_id) or not nodes.has(next_target):
		return
		
	var origin = nodes[origin_id]
	var target = nodes[next_target]
	
	var dist = origin.position.distance_to(target.position)
	var avg_speed = fleet.get_average_speed()
	if avg_speed <= 0:
		avg_speed = 50.0
		
	var total_time = (dist / avg_speed) * 3.0
	
	fleet.is_moving = true
	fleet.target_node_id = next_target
	fleet.travel_total_time = total_time
	fleet.travel_time_remaining = total_time
	fleet.travel_progress = 0.0
	
	origin.remove_fleet(fleet)
	moving_fleets.append(fleet)
	
	fleet_dispatched.emit(fleet)
	print("[GalaxyManager] Fleet continuing journey from %s to %s (ETA: %.1fs). Remaining path: %s" % [origin.node_name, target.node_name, total_time, fleet.movement_path])

func dispatch_fleet(fleet: Fleet, target_id: String) -> bool:
	if fleet.is_moving:
		return false
		
	var origin_id = fleet.current_node_id
	if not nodes.has(origin_id) or not nodes.has(target_id):
		return false
		
	var origin = nodes[origin_id]
	var target = nodes[target_id]
	
	# Verify lane connection (only required for attacks/non-reassignments)
	var target_has_player_planet = false
	for p in target.planets:
		if p.owner_name == fleet.owner_name:
			target_has_player_planet = true
			break
	var is_reassignment = (target.owner_name == fleet.owner_name) or target_has_player_planet
	
	if not is_reassignment and not origin.connected_node_ids.has(target_id):
		print("[GalaxyManager] Cannot dispatch: no lane connects %s to %s." % [origin_id, target_id])
		return false
		
	var path = find_shortest_path(origin_id, target_id)
	if path.is_empty():
		print("[GalaxyManager] Cannot dispatch: no connected path from %s to %s." % [origin_id, target_id])
		return false
		
	if is_reassignment:
		for node_id_step in path:
			if node_id_step != target_id:
				if nodes.has(node_id_step):
					var nd = nodes[node_id_step]
					if nd.owner_name != fleet.owner_name and nd.owner_name != "Neutral" and not nd.owner_name.is_empty():
						print("[GalaxyManager] Cannot dispatch reassignment: path passes through hostile system %s." % node_id_step)
						return false
						
	fleet.movement_path = path
	var next_target = fleet.movement_path.pop_front()
	var next_node = nodes[next_target]
	
	# Calculate travel metrics for first leg
	var dist = origin.position.distance_to(next_node.position)
	var avg_speed = fleet.get_average_speed()
	if avg_speed <= 0:
		avg_speed = 50.0 # Safety default
		
	# Travel time formula: Distance / Speed * scale_factor
	var total_time = (dist / avg_speed) * 3.0 # Scale to seconds for gameplay
	
	# Set movement parameters
	fleet.is_moving = true
	fleet.target_node_id = next_target
	fleet.travel_total_time = total_time
	fleet.travel_time_remaining = total_time
	fleet.travel_progress = 0.0
	
	# Remove from stationed list
	origin.remove_fleet(fleet)
	moving_fleets.append(fleet)
	
	fleet_dispatched.emit(fleet)
	print("[GalaxyManager] Fleet dispatched from %s to %s (ETA: %.1fs). Remaining path: %s" % [origin.node_name, next_node.node_name, total_time, fleet.movement_path])
	return true

func tick(delta: float) -> void:
	var completed = []
	
	# Update moving fleets progress
	for fleet in moving_fleets:
		fleet.travel_time_remaining -= delta
		fleet.travel_progress = clamp(1.0 - (fleet.travel_time_remaining / fleet.travel_total_time), 0.0, 1.0)
		fleet_moved.emit(fleet)
		
		if fleet.travel_time_remaining <= 0.0:
			completed.append(fleet)
			
	# Process arrivals
	for fleet in completed:
		moving_fleets.erase(fleet)
		var target_node = nodes[fleet.target_node_id]
		
		# Update status
		fleet.is_moving = false
		fleet.current_node_id = fleet.target_node_id
		fleet.target_node_id = ""
		fleet.travel_progress = 0.0
		fleet.travel_time_remaining = 0.0
		
		target_node.add_fleet(fleet)
		fleet_arrived.emit(fleet, target_node)
		print("[GalaxyManager] Fleet arrived at system: ", target_node.node_name)
		
		# Check for combat trigger
		_check_and_resolve_combat(target_node, fleet)
		
		# Check if fleet survived and needs to continue along its path
		if target_node.stationed_fleets.has(fleet) and not fleet.movement_path.is_empty():
			_dispatch_next_leg(fleet)

	# Tick all planets for resource generation and queues
	for node_id in nodes:
		var node = nodes[node_id]
		for p in node.planets:
			if p.owner_name == "Neutral":
				continue
			elif p.owner_name == "Player":
				p.tick(delta, 300.0, player_resources)
			elif p.owner_name.begins_with("Enemy"):
				p.tick(delta, 300.0, get_enemy_resource_pool(p.owner_name))
			elif p.owner_name.begins_with("peer_"):
				# Lazy initialize resource pool for peer if needed
				if not player_resources.has(p.owner_name):
					player_resources[p.owner_name] = {
						"metal": 5000.0,
						"crystal": 3000.0,
						"deuterium": 1000.0
					}
				p.tick(delta, 300.0, player_resources[p.owner_name])

	# Accumulate elapsed game time
	game_time_elapsed += delta
	
	# Run Enemy AI (in singleplayer, or server-side in multiplayer)
	var should_run_ai = false
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root and main_loop.root.has_node("NetworkManager"):
		var nm = main_loop.root.get_node("NetworkManager")
		if nm.has_method("is_multiplayer_active") and nm.is_multiplayer_active():
			if nm.get("is_server", false):
				should_run_ai = true
		else:
			should_run_ai = true
	else:
		should_run_ai = true
			
	if should_run_ai:
		ai_tick_timer += delta
		if ai_tick_timer >= 10.0:
			ai_tick_timer = 0.0
			_run_enemy_ai()
			_run_player_auto_manage()

func toggle_node_auto_manage(node_id: String, enabled: bool, target: String) -> void:
	var node = get_node_by_id(node_id)
	if node:
		node.is_auto_managed = enabled
		node.auto_manage_target = target
		print("[GalaxyManager] System %s auto-manage set to: %s, target: %s" % [node.node_name, enabled, target])

func _run_player_auto_manage() -> void:
	# Define default standard ship designs for construction
	var f_design = ShipDesign.new("暴风护卫舰", "frigate")
	f_design.weapons = ["laser_light", "laser_light"]
	f_design.shields = ["deflector_light", "composite_armor_light"]
	f_design.utilities = ["afterburner"]
	
	var d_design = ShipDesign.new("雷霆驱逐舰", "destroyer")
	d_design.weapons = ["missile_launcher", "railgun_light"]
	d_design.shields = ["deflector_light", "composite_armor_light"]
	d_design.utilities = ["cargo_hold", "reactor_booster"]
	
	var c_design = ShipDesign.new("铁星巡洋舰", "cruiser")
	c_design.weapons = ["laser_heavy", "railgun_heavy", "railgun_heavy"]
	c_design.shields = ["deflector_heavy", "composite_armor_heavy", "composite_armor_heavy"]
	c_design.utilities = ["reactor_booster", "reactor_booster", "afterburner"]

	for node_id in nodes:
		var node = nodes[node_id]
		# Only run on nodes that are auto-managed and belong to a player/peer
		if not node.is_auto_managed:
			continue
		var faction_name = node.owner_name
		if faction_name == "Neutral" or faction_name == "Enemy":
			continue
			
		# Get resources for this faction
		var res_pool = null
		if faction_name == "Player":
			res_pool = player_resources
		elif player_resources.has(faction_name):
			res_pool = player_resources[faction_name]
		else:
			continue # Faction resources not initialized yet
			
		var target_mode = node.auto_manage_target # "balanced", "economic", "military"
		
		# 1. Decide priorities
		var build_ships = false
		var upgrade_buildings = false
		
		if target_mode == "economic":
			upgrade_buildings = true
			build_ships = false
		elif target_mode == "military":
			upgrade_buildings = true
			build_ships = true
		else: # "balanced"
			# if ships count in system < 6, prioritize ships, else upgrade
			var total_ships = 0
			for f in node.stationed_fleets:
				if f.owner_name == faction_name:
					for d_name in f.ships:
						total_ships += f.ships[d_name]
			for p in node.planets:
				if p.owner_name == faction_name:
					for d_name in p.hangar:
						total_ships += p.hangar[d_name]
			var prioritize_military = (total_ships < 6)
			if prioritize_military:
				build_ships = true
				upgrade_buildings = true
			else:
				upgrade_buildings = true
				build_ships = true # we run upgrades first, then ships
		
		# 2. Execution functions
		var execute_upgrades = func() -> void:
			for p in node.planets:
				if p.owner_name != faction_name:
					continue
				if p.active_upgrades.size() >= 3:
					continue
					
				var energy_max = p.get_energy_max()
				var energy_used = p.get_energy_used()
				var needs_power = (energy_used + 15 >= energy_max)
				
				var target_building = ""
				if needs_power:
					target_building = "solar_power_plant"
				else:
					var shipyard_lvl = p.get_building_total_level("shipyard")
					if target_mode == "military" and shipyard_lvl == 0:
						target_building = "shipyard"
					else:
						var metal_lvl = p.get_building_total_level("metal_mine")
						var crystal_lvl = p.get_building_total_level("crystal_mine")
						var deut_lvl = p.get_building_total_level("deuterium_synthesizer")
						
						if metal_lvl < crystal_lvl * 1.5:
							target_building = "metal_mine"
						elif crystal_lvl < deut_lvl * 2.0:
							target_building = "crystal_mine"
						elif deut_lvl < 3:
							target_building = "deuterium_synthesizer"
						else:
							var r = randf()
							if r < 0.4:
								target_building = "metal_mine"
							elif r < 0.7:
								target_building = "crystal_mine"
							elif r < 0.85:
								target_building = "deuterium_synthesizer"
							else:
								target_building = "shipyard"
								
				var slot_to_upgrade = -1
				var min_lvl = 99999
				for idx in range(p.buildings.size()):
					if p.buildings[idx]["type"] == target_building:
						var is_upgrading = false
						for upg in p.active_upgrades:
							if upg.get("slot_index", -1) == idx:
								is_upgrading = true
								break
						if not is_upgrading:
							var lvl = p.buildings[idx].get("level", 0)
							if lvl < 20 and lvl < min_lvl:
								min_lvl = lvl
								slot_to_upgrade = idx
								
				if slot_to_upgrade == -1:
					var has_upgradable = false
					for idx in range(p.buildings.size()):
						var b = p.buildings[idx]
						if b["type"] == target_building:
							var pending = 0
							for upg in p.active_upgrades:
								if upg.get("slot_index", -1) == idx:
									pending += 1
							if b["level"] + pending < 20:
								has_upgradable = true
								break
					if not has_upgradable:
						for idx in range(p.buildings.size()):
							if p.buildings[idx]["type"] == "empty":
								slot_to_upgrade = idx
								break
							
				if slot_to_upgrade != -1:
					p.start_building_upgrade(slot_to_upgrade, target_building, res_pool)
		
		var execute_ship_building = func() -> void:
			var system_shipyard_lvl = 0
			for p in node.planets:
				if p.owner_name == faction_name:
					system_shipyard_lvl += p.get_building_total_level("shipyard")
					
			if system_shipyard_lvl > 0:
				for p in node.planets:
					if p.owner_name != faction_name:
						continue
					if p.shipyard_queue.is_empty():
						# Try to find a custom blueprint on the planet first, otherwise use default
						var selected_design = null
						var p_frigate = null
						var p_destroyer = null
						var p_cruiser = null
						for d_name in p.designs:
							var d = p.designs[d_name]
							if d.hull_id == "cruiser":
								p_cruiser = d
							elif d.hull_id == "destroyer":
								p_destroyer = d
							elif d.hull_id == "frigate":
								p_frigate = d
						
						# Determine what we want to build based on resource pools
						var target_c = p_cruiser if p_cruiser else c_design
						var target_d = p_destroyer if p_destroyer else d_design
						var target_f = p_frigate if p_frigate else f_design
						
						var cost_c = target_c.get_total_cost()
						var cost_d = target_d.get_total_cost()
						var cost_f = target_f.get_total_cost()
						
						if p._has_resources(cost_c, res_pool):
							selected_design = target_c
						elif p._has_resources(cost_d, res_pool):
							selected_design = target_d
						elif p._has_resources(cost_f, res_pool):
							selected_design = target_f
							
						if selected_design:
							var cost = selected_design.get_total_cost()
							p.start_ship_construction(selected_design.design_name, selected_design.hull_id, 1, cost, selected_design, res_pool, system_shipyard_lvl)

		# Execute based on target mode and counts
		if build_ships and upgrade_buildings:
			if target_mode == "military":
				execute_ship_building.call()
				execute_upgrades.call()
			else:
				var total_ships = 0
				for f in node.stationed_fleets:
					if f.owner_name == faction_name:
						for d_name in f.ships:
							total_ships += f.ships[d_name]
				for p in node.planets:
					if p.owner_name == faction_name:
						for d_name in p.hangar:
							total_ships += p.hangar[d_name]
				if total_ships < 6:
					execute_ship_building.call()
					execute_upgrades.call()
				else:
					execute_upgrades.call()
					execute_ship_building.call()
		elif upgrade_buildings:
			execute_upgrades.call()

func _run_enemy_ai() -> void:
	# Find all active AI factions
	var ai_factions = []
	for node in nodes.values():
		if node.owner_name.begins_with("Enemy") and not ai_factions.has(node.owner_name):
			ai_factions.append(node.owner_name)
			
	for faction in ai_factions:
		_run_ai_for_faction(faction)

func _run_ai_for_faction(faction_name: String) -> void:
	# Define default enemy ship designs for construction (upgraded to be on par with player/neutral designs)
	var f_design = ShipDesign.new(faction_name + "护卫舰", "frigate")
	f_design.weapons = ["laser_light", "laser_light"]
	f_design.shields = ["deflector_light", "composite_armor_light"]
	f_design.utilities = ["afterburner"]
	
	var d_design = ShipDesign.new(faction_name + "驱逐舰", "destroyer")
	d_design.weapons = ["missile_launcher", "railgun_light"]
	d_design.shields = ["deflector_light", "composite_armor_light"]
	d_design.utilities = ["cargo_hold", "reactor_booster"]
	
	var c_design = ShipDesign.new(faction_name + "巡洋舰", "cruiser")
	c_design.weapons = ["laser_heavy", "railgun_heavy", "railgun_heavy"]
	c_design.shields = ["deflector_heavy", "composite_armor_heavy", "composite_armor_heavy"]
	c_design.utilities = ["reactor_booster", "reactor_booster", "afterburner"]

	var faction_res = get_enemy_resource_pool(faction_name)

	for node_id in nodes:
		var node = nodes[node_id]
		if node.owner_name != faction_name:
			continue
			
		# Calculate total military ship count in the current system (fleets + hangars)
		var total_ships = 0
		for f in node.stationed_fleets:
			if f.owner_name == faction_name:
				for d_name in f.ships:
					total_ships += f.ships[d_name]
		for p in node.planets:
			if p.owner_name == faction_name:
				for d_name in p.hangar:
					total_ships += p.hangar[d_name]
					
		# If we have less than 8 ships, prioritize military construction over economy upgrades
		var prioritize_military = (total_ships < 8)
		
		# Define upgraded callable
		var run_upgrades = func() -> void:
			for p in node.planets:
				if p.owner_name != faction_name:
					continue
				if p.active_upgrades.size() >= 3:
					continue
					
				var energy_max = p.get_energy_max()
				var energy_used = p.get_energy_used()
				var needs_power = (energy_used + 15 >= energy_max)
				
				var target_building = ""
				if needs_power:
					target_building = "solar_power_plant"
				else:
					var shipyard_lvl = p.get_building_total_level("shipyard")
					if shipyard_lvl == 0:
						target_building = "shipyard"
					else:
						var metal_lvl = p.get_building_total_level("metal_mine")
						var crystal_lvl = p.get_building_total_level("crystal_mine")
						var deut_lvl = p.get_building_total_level("deuterium_synthesizer")
						
						if metal_lvl < crystal_lvl * 1.5:
							target_building = "metal_mine"
						elif crystal_lvl < deut_lvl * 2.0:
							target_building = "crystal_mine"
						elif deut_lvl < 3:
							target_building = "deuterium_synthesizer"
						else:
							var r = randf()
							if r < 0.4:
								target_building = "metal_mine"
							elif r < 0.7:
								target_building = "crystal_mine"
							elif r < 0.9:
								target_building = "deuterium_synthesizer"
							else:
								target_building = "shipyard"
								
				var slot_to_upgrade = -1
				var min_lvl = 99999
				for idx in range(p.buildings.size()):
					if p.buildings[idx]["type"] == target_building:
						var is_upgrading = false
						for upg in p.active_upgrades:
							if upg.get("slot_index", -1) == idx:
								is_upgrading = true
								break
						if not is_upgrading:
							var lvl = p.buildings[idx].get("level", 0)
							if lvl < 20 and lvl < min_lvl:
								min_lvl = lvl
								slot_to_upgrade = idx
								
				if slot_to_upgrade == -1:
					var has_upgradable = false
					for idx in range(p.buildings.size()):
						var b = p.buildings[idx]
						if b["type"] == target_building:
							var pending = 0
							for upg in p.active_upgrades:
								if upg.get("slot_index", -1) == idx:
									pending += 1
							if b["level"] + pending < 20:
								has_upgradable = true
								break
					if not has_upgradable:
						for idx in range(p.buildings.size()):
							if p.buildings[idx]["type"] == "empty":
								slot_to_upgrade = idx
								break
							
				if slot_to_upgrade != -1:
					var success = p.start_building_upgrade(slot_to_upgrade, target_building, faction_res)
					if success:
						print("[%s AI] Started building/upgrading %s at planet %s" % [faction_name, target_building, p.planet_name])
		
		# Define ship construction callable
		var run_ship_building = func() -> void:
			var system_shipyard_lvl = 0
			for p in node.planets:
				if p.owner_name == faction_name:
					system_shipyard_lvl += p.get_building_total_level("shipyard")
					
			if system_shipyard_lvl > 0:
				for p in node.planets:
					if p.owner_name != faction_name:
						continue
					if p.shipyard_queue.is_empty():
						var selected_design = null
						var cost_c = c_design.get_total_cost()
						var cost_d = d_design.get_total_cost()
						var cost_f = f_design.get_total_cost()
						
						if p._has_resources(cost_c, faction_res):
							selected_design = c_design
						elif p._has_resources(cost_d, faction_res):
							selected_design = d_design
						elif p._has_resources(cost_f, faction_res):
							selected_design = f_design
							
						if selected_design:
							var cost = selected_design.get_total_cost()
							var success = p.start_ship_construction(selected_design.design_name, selected_design.hull_id, 1, cost, selected_design, faction_res, system_shipyard_lvl)
							if success:
								print("[%s AI] Planet %s started constructing 1x %s with system shipyard lvl %d" % [faction_name, p.planet_name, selected_design.design_name, system_shipyard_lvl])

		# Run based on priorities
		if prioritize_military:
			run_ship_building.call()
			run_upgrades.call()
		else:
			run_upgrades.call()
			run_ship_building.call()

		# 3. Fleet Formation
		for p in node.planets:
			if p.owner_name != faction_name:
				continue
			if not p.hangar.is_empty():
				var ships_to_add = {}
				for d_name in p.hangar:
					var qty = p.hangar[d_name]
					if qty > 0:
						ships_to_add[d_name] = qty
						
				if not ships_to_add.is_empty():
					var target_fleet: Fleet = null
					for f in node.stationed_fleets:
						if f.owner_name == faction_name and not f.is_moving:
							target_fleet = f
							break
					if not target_fleet:
						target_fleet = Fleet.new(faction_name + "联合编队", faction_name)
						target_fleet.current_node_id = node.node_id
						node.add_fleet(target_fleet)
						
					for d_name in ships_to_add:
						var qty = ships_to_add[d_name]
						var design_obj = p.designs.get(d_name)
						if not design_obj:
							if "巡洋" in d_name:
								design_obj = c_design
							elif "驱逐" in d_name:
								design_obj = d_design
							else:
								design_obj = f_design
						target_fleet.add_ships(design_obj, qty)
						p.hangar[d_name] -= qty
						if p.hangar[d_name] <= 0:
							p.hangar.erase(d_name)
					print("[%s AI] Formed/reinforced fleet %s at %s" % [faction_name, target_fleet.fleet_name, node.node_name])

		# 4. Fleet Movement & Aggression
		for fleet in node.stationed_fleets:
			if fleet.owner_name != faction_name or fleet.is_moving:
				continue
				
			var ship_count = 0
			for d_name in fleet.ships:
				ship_count += fleet.ships[d_name]
				
			if ship_count >= 5:
				var target_nodes = []
				var reinforce_nodes = []
				
				for neighbor_id in node.connected_node_ids:
					var neighbor = nodes[neighbor_id]
					if neighbor.owner_name != faction_name:
						# Calculate neighbor defense strength
						var neighbor_defenders = 0
						var has_stationed_defenders = false
						for f in neighbor.stationed_fleets:
							if f.owner_name == neighbor.owner_name:
								has_stationed_defenders = true
								for d in f.ships:
									neighbor_defenders += f.ships[d]
						if not has_stationed_defenders:
							var g_frigates = 3
							var g_destroyers = 0
							var g_cruisers = 0
							if neighbor.owner_name == "Neutral":
								g_frigates = 3 + int(game_time_elapsed / 120.0)
								if game_time_elapsed >= 180.0:
									g_destroyers = 1 + int((game_time_elapsed - 180.0) / 120.0)
								if game_time_elapsed >= 300.0:
									g_cruisers = 1 + int((game_time_elapsed - 300.0) / 180.0)
							else:
								g_frigates = 3 + int(game_time_elapsed / 180.0)
								if game_time_elapsed >= 240.0:
									g_destroyers = 1 + int((game_time_elapsed - 240.0) / 180.0)
							neighbor_defenders = g_frigates + g_destroyers + g_cruisers
						
						var required = max(5, neighbor_defenders + 2)
						if ship_count >= required:
							target_nodes.append(neighbor)
					else:
						reinforce_nodes.append(neighbor)
						
				if not target_nodes.is_empty() and randf() < 0.7:
					var attack_target = target_nodes[randi() % target_nodes.size()]
					dispatch_fleet(fleet, attack_target.node_id)
					print("[%s AI] Dispatched fleet %s (size %d) to attack %s" % [faction_name, fleet.fleet_name, ship_count, attack_target.node_name])
				elif not reinforce_nodes.is_empty() and randf() < 0.3:
					var target_friend = reinforce_nodes[randi() % reinforce_nodes.size()]
					dispatch_fleet(fleet, target_friend.node_id)
					print("[%s AI] Dispatched fleet %s to reinforce %s" % [faction_name, fleet.fleet_name, target_friend.node_name])

func _check_and_resolve_combat(node: GalaxyNode, arrived_fleet: Fleet) -> void:
	if not arrived_fleet:
		return
		
	# Combat triggers if the arrived fleet's owner is different from the node's owner
	if arrived_fleet.owner_name != node.owner_name:
		# Find if there is an opposing fleet stationed at the node
		var defenders = node.stationed_fleets.filter(func(f): return f.owner_name == node.owner_name and f != arrived_fleet)
		
		var defender_fleet: Fleet = null
		var is_temporary_garrison = false
		
		if not defenders.is_empty():
			defender_fleet = defenders[0]
		else:
			# Spawn a temporary garrison fleet representing the planet defenses
			defender_fleet = _create_garrison_fleet(node.owner_name)
			node.add_fleet(defender_fleet)
			is_temporary_garrison = true
			
		print("[GalaxyManager] Battle triggered at %s! Arriving fleet (%s) vs Defender (%s)" % [
			node.node_name, arrived_fleet.owner_name, defender_fleet.owner_name
		])
		
		# Attacker is A (arrived_fleet), Defender is B (defender_fleet)
		var battle_result = BattleSimulator.simulate(
			arrived_fleet, arrived_fleet.commander,
			defender_fleet, defender_fleet.commander,
			10
		)
		
		var winner = battle_result["winner"]
		
		var report = {
			"node_id": node.node_id,
			"system_name": node.node_name,
			"winner": winner,
			"attacker": arrived_fleet.owner_name,
			"defender": defender_fleet.owner_name,
			"logs": battle_result["logs"],
			"salvage": battle_result["salvage"],
			"structured_rounds": battle_result.get("structured_rounds", []),
			"initial_a_ships": battle_result.get("initial_a_ships", []),
			"initial_b_ships": battle_result.get("initial_b_ships", [])
		}
		battle_logs_history.append(report)
		
		if winner == "A": # Attacker wins!
			node.owner_name = arrived_fleet.owner_name
			node.remove_fleet(defender_fleet)
			arrived_fleet.clean_destroyed_ships()
			print("[GalaxyManager] Attacker %s wins! Node %s captured." % [arrived_fleet.owner_name, node.node_name])
		elif winner == "B": # Defender wins!
			node.remove_fleet(arrived_fleet)
			if is_temporary_garrison:
				# Discard temporary garrison
				node.remove_fleet(defender_fleet)
			else:
				defender_fleet.clean_destroyed_ships()
			print("[GalaxyManager] Defender %s wins! Node %s remains unchanged." % [defender_fleet.owner_name, node.node_name])
		else: # Draw
			node.remove_fleet(arrived_fleet)
			node.remove_fleet(defender_fleet)
			print("[GalaxyManager] Draw! Both fleets destroyed at %s." % node.node_name)
			
		# Distribute salvage
		var salvage = battle_result.get("salvage", {"metal": 0, "crystal": 0, "deuterium": 0})
		var winner_owner = ""
		if winner == "A":
			winner_owner = arrived_fleet.owner_name
		elif winner == "B":
			winner_owner = defender_fleet.owner_name
			
		if winner_owner == "Player":
			player_resources["metal"] += salvage.get("metal", 0)
			player_resources["crystal"] += salvage.get("crystal", 0)
			player_resources["deuterium"] += salvage.get("deuterium", 0)
		elif winner_owner.begins_with("Enemy"):
			var pool = get_enemy_resource_pool(winner_owner)
			pool["metal"] += salvage.get("metal", 0)
			pool["crystal"] += salvage.get("crystal", 0)
			pool["deuterium"] += salvage.get("deuterium", 0)
		elif winner_owner.begins_with("peer_"):
			if not player_resources.has(winner_owner):
				player_resources[winner_owner] = {
					"metal": 1000.0,
					"crystal": 1000.0,
					"deuterium": 1000.0
				}
			player_resources[winner_owner]["metal"] += salvage.get("metal", 0)
			player_resources[winner_owner]["crystal"] += salvage.get("crystal", 0)
			player_resources[winner_owner]["deuterium"] += salvage.get("deuterium", 0)
			
		battle_occurred.emit(report)
		var main_loop = Engine.get_main_loop()
		if main_loop and main_loop.root and main_loop.root.has_node("NetworkManager"):
			var nm = main_loop.root.get_node("NetworkManager")
			if nm.is_server:
				nm.broadcast_battle(self, report)

func _create_garrison_fleet(owner_name: String) -> Fleet:
	var f = Fleet.new(owner_name + "守备队")
	f.owner_name = owner_name
	
	# Generate designs
	var frigate_design = ShipDesign.new("守备级护卫舰", "frigate")
	frigate_design.weapons = ["laser_light", "laser_light"]
	frigate_design.shields = ["deflector_light", "composite_armor_light"]
	frigate_design.utilities = ["afterburner"]
	
	var destroyer_design = ShipDesign.new("守备级驱逐舰", "destroyer")
	destroyer_design.weapons = ["missile_launcher", "laser_light"]
	destroyer_design.shields = ["deflector_light", "composite_armor_light"]
	destroyer_design.utilities = ["cargo_hold"]
	
	var cruiser_design = ShipDesign.new("守备级巡洋舰", "cruiser")
	cruiser_design.weapons = ["laser_heavy", "railgun_heavy"]
	cruiser_design.shields = ["deflector_heavy", "composite_armor_heavy"]
	cruiser_design.utilities = ["reactor_booster"]
	
	var frigates_qty = 3
	var destroyers_qty = 0
	var cruisers_qty = 0
	
	if owner_name == "Neutral":
		# Neutral: base 3 frigates. +1 frigate every 2 mins (120s)
		frigates_qty = 3 + int(game_time_elapsed / 120.0)
		# Add 1 destroyer every 2 mins after 3 mins (180s)
		if game_time_elapsed >= 180.0:
			destroyers_qty = 1 + int((game_time_elapsed - 180.0) / 120.0)
		# Add 1 cruiser every 3 mins after 5 mins (300s)
		if game_time_elapsed >= 300.0:
			cruisers_qty = 1 + int((game_time_elapsed - 300.0) / 180.0)
	elif owner_name.begins_with("Enemy"):
		# Enemy: base 5 frigates. +1 frigate every 100s
		frigates_qty = 5 + int(game_time_elapsed / 100.0)
		# Add 1 destroyer every 100s after 2 mins (120s)
		if game_time_elapsed >= 120.0:
			destroyers_qty = 1 + int((game_time_elapsed - 120.0) / 100.0)
		# Add 1 cruiser every 150s after 4 mins (240s)
		if game_time_elapsed >= 240.0:
			cruisers_qty = 1 + int((game_time_elapsed - 240.0) / 150.0)
	else:
		# Player or Peer
		frigates_qty = 3 + int(game_time_elapsed / 180.0)
		if game_time_elapsed >= 240.0:
			destroyers_qty = 1 + int((game_time_elapsed - 240.0) / 180.0)
			
	if frigates_qty > 0:
		f.add_ships(frigate_design, frigates_qty)
	if destroyers_qty > 0:
		f.add_ships(destroyer_design, destroyers_qty)
	if cruisers_qty > 0:
		f.add_ships(cruiser_design, cruisers_qty)
		
	return f

func reconnect_signals() -> void:
	for node_id in nodes:
		var node = nodes[node_id]
		for planet in node.planets:
			for sig in planet.ship_completed.get_connections():
				planet.ship_completed.disconnect(sig.callable)
			planet.ship_completed.connect(func(d_name, _hull_id):
				planet_ship_completed.emit(planet, d_name)
			)
