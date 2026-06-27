extends SceneTree

var Planet = load("res://src/core/models/planet.gd")
var PlanetState = load("res://src/core/models/planet_state.gd")
var ShipDesign = load("res://src/core/models/ship_design.gd")
var Fleet = load("res://src/core/models/fleet.gd")
var GalaxyManager = load("res://src/core/managers/galaxy_manager.gd")
var GalaxyNode = load("res://src/core/models/galaxy_node.gd")
var BattleSimulator = load("res://src/core/simulator/battle_simulator.gd")

var assertion_counter = 0
var pass_counter = 0
var fail_counter = 0
var test_results = []

func run_assert(id: String, desc: String, passed: bool, actual_val = null, expected_val = null, extra_info: String = "") -> void:
	assertion_counter += 1
	if passed:
		pass_counter += 1
		test_results.append({"id": id, "desc": desc, "status": "PASS", "actual": actual_val, "expected": expected_val, "info": extra_info})
		print("[%s] [PASS] %s" % [id, desc])
	else:
		fail_counter += 1
		test_results.append({"id": id, "desc": desc, "status": "FAIL", "actual": actual_val, "expected": expected_val, "info": extra_info})
		print("[%s] [FAIL] %s | Expected: %s, Actual: %s | %s" % [id, desc, str(expected_val), str(actual_val), extra_info])

func assert_eq(id: String, desc: String, actual, expected, info: String = "") -> void:
	var passed = (actual == expected)
	run_assert(id, desc, passed, actual, expected, info)

func assert_true(id: String, desc: String, condition: bool, info: String = "") -> void:
	run_assert(id, desc, condition, condition, true, info)

func _init() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	print("=================================================================")
	print("            SSW ADVERSARIAL COVERAGE HARDENING SUITE              ")
	print("=================================================================")
	
	test_mismatched_building_types()
	test_integer_overflow_exploit()
	test_planet_state_hijack()
	test_galaxy_node_side_effects()
	test_empty_fleet_form()
	test_dispatch_fleet_pathfinding()
	
	print("\n=================================================================")
	print("                 ADVERSARIAL TEST SUMMARY                        ")
	print("=================================================================")
	print("Total Assertions Run : %d" % assertion_counter)
	print("Passed Assertions    : %d" % pass_counter)
	print("Failed Assertions    : %d" % fail_counter)
	print("=================================================================")
	
	if fail_counter > 0:
		print("Adversarial tests completed with %d failures." % fail_counter)
		quit(1)
	else:
		print("All adversarial tests passed successfully!")
		quit(0)

func test_mismatched_building_types() -> void:
	print("\n--- Test 1: Mismatched proposed_type for existing building (Planet.gd) ---")
	var p = Planet.new("adv_p1", "Adv Planet 1", "Player")
	p.buildings[0] = {"type": "metal_mine", "level": 1}
	
	var wallet = {"metal": 10000.0, "crystal": 10000.0, "deuterium": 10000.0}
	
	# Action: start upgrade proposing "crystal_mine" for a slot containing "metal_mine"
	var ok = p.start_building_upgrade(0, "crystal_mine", wallet)
	
	# We observe: start_building_upgrade is blocked
	assert_eq("ADV.1.1", "Model blocks start_building_upgrade with mismatched type", ok, false)
	
	# Tick to complete
	p.tick(10.0, 1.0, wallet)
	
	# Check the result: the level of the existing type "metal_mine" was not incremented
	assert_eq("ADV.1.2", "Existing building type is still metal_mine", p.buildings[0]["type"], "metal_mine")
	assert_eq("ADV.1.3", "Existing building level remains 1", p.buildings[0]["level"], 1)
	
	# Action 2: start upgrade proposing "" (empty string) for "metal_mine" slot
	var ok2 = p.start_building_upgrade(0, "", wallet)
	assert_eq("ADV.1.4", "Model blocks start_building_upgrade with empty proposed_type on non-empty slot", ok2, false)
	
	p.tick(10.0, 1.0, wallet)
	assert_eq("ADV.1.5", "Building level remains 1 with empty proposed_type", p.buildings[0]["level"], 1)

func test_integer_overflow_exploit() -> void:
	print("\n--- Test 2: Integer Overflow in Ship Construction (Planet.gd) ---")
	var p = Planet.new("adv_p2", "Adv Planet 2", "Player")
	p.buildings[0] = {"type": "shipyard", "level": 1}
	
	# Initial wallet with enough crystal to cover the positive cost, but 100 metal
	var wallet = {"metal": 100.0, "crystal": 1e20, "deuterium": 100.0}
	
	var design = ShipDesign.new("HeavyFighter", "frigate")
	design.weapons = ["laser_light"] # Validates design
	var cost = design.get_total_cost()
	
	print("Single ship cost: ", cost)
	
	# Q * 1000 (metal cost) > INT64_MAX
	# INT64_MAX is 9223372036854775807
	var qty = 9223372036854777
	
	var ok = p.start_ship_construction("HeavyFighter", "frigate", qty, cost, design, wallet, 1)
	
	assert_eq("ADV.2.1", "Ship construction blocks overflow qty", ok, false)
	
	print("Wallet after construction: ", wallet)
	assert_eq("ADV.2.2", "Wallet metal remains 100.0", wallet["metal"], 100.0)

func test_planet_state_hijack() -> void:
	print("\n--- Test 3: Client PlanetState Custom Building Hijack (PlanetState.gd) ---")
	var ps = PlanetState.new()
	
	var ok = ps.start_building_upgrade("super_weapon")
	assert_eq("ADV.3.1", "PlanetState blocks starting upgrade of invalid building type", ok, false)
	
	ps.tick(4.0)
	
	var has_super_weapon = ps.buildings.has("super_weapon")
	assert_eq("ADV.3.2", "PlanetState buildings dictionary does not contain hijacked building type", has_super_weapon, false)

func test_galaxy_node_side_effects() -> void:
	print("\n--- Test 4: GalaxyNode owner_name setter side-effects (GalaxyNode.gd) ---")
	var node = GalaxyNode.new("node_adv4", "Adv Node 4", Vector2(0,0), "Neutral")
	var p1 = Planet.new("p_adv4_1", "Planet 4-1", "Neutral")
	var p2 = Planet.new("p_adv4_2", "Planet 4-2", "Neutral")
	node.planets.append(p1)
	node.planets.append(p2)
	
	p1.owner_name = "Player"
	assert_eq("ADV.4.1", "Direct setting of planet owner works", p1.owner_name, "Player")
	
	node.owner_name = "Enemy"
	
	assert_eq("ADV.4.2", "Node setter overrides first planet owner to Enemy", p1.owner_name, "Enemy")
	assert_eq("ADV.4.3", "Node setter overrides second planet owner to Enemy", p2.owner_name, "Enemy")
	
	var p3 = Planet.new("p_adv4_3", "Planet 4-3", "Player")
	node.planets.append(p3)
	
	# Accessing node.planets will trigger the getter and synchronize p3
	var _sync = node.planets
	
	assert_eq("ADV.4.4", "Newly appended planet owner is synchronized to node's owner", p3.owner_name, "Enemy")
	assert_eq("ADV.4.5", "Node owner is still Enemy", node.owner_name, "Enemy")

func test_empty_fleet_form() -> void:
	print("\n--- Test 5: Emulating server_request_form_fleet in NetworkManager ---")
	var nm_script = load("res://src/core/managers/network_manager.gd")
	var nm = nm_script.new()
	get_root().add_child(nm)
	
	var gm = GalaxyManager.new()
	var node = GalaxyNode.new("node_adv5", "System 5", Vector2(0,0), "peer_0")
	var p = Planet.new("p_adv5", "Planet 5", "peer_0")
	node.planets.append(p)
	gm.add_node(node)
	
	nm.is_server = true
	nm.peer_to_room[0] = "test_room"
	nm.rooms["test_room"] = {
		"galaxy_manager": gm,
		"peers": {0: "Player_0"},
		"ready_states": {0: true}
	}
	
	nm.server_request_form_fleet("p_adv5", "EmptyFleet", {})
	
	assert_eq("ADV.5.1", "Node stationed fleets size is 0", node.stationed_fleets.size(), 0)
	
	nm.queue_free()

func test_dispatch_fleet_pathfinding() -> void:
	print("\n--- Test 6: Dispatch Fleet Reassignment Pathfinding (GalaxyManager.gd) ---")
	var gm = GalaxyManager.new()
	
	var node_a = GalaxyNode.new("A", "Node A", Vector2(0,0), "Player")
	var node_b = GalaxyNode.new("B", "Node B", Vector2(100,0), "Enemy")
	var node_c = GalaxyNode.new("C", "Node C", Vector2(200,0), "Player")
	
	gm.add_node(node_a)
	gm.add_node(node_b)
	gm.add_node(node_c)
	
	gm.connect_nodes("A", "B")
	gm.connect_nodes("B", "C")
	
	var fleet = Fleet.new("ReassignFleet")
	fleet.owner_name = "Player"
	var design = ShipDesign.new("Fighter", "frigate")
	design.weapons = ["laser_light"]
	fleet.add_ships(design, 1)
	node_a.add_fleet(fleet)
	
	var ok = gm.dispatch_fleet(fleet, "C")
	
	assert_eq("ADV.6.1", "Fleet dispatch fails to non-connected player node through hostile systems", ok, false)
	assert_eq("ADV.6.2", "Fleet is not moving", fleet.is_moving, false)
