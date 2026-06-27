extends SceneTree

var Planet = load("res://src/core/models/planet.gd")
var PlanetState = load("res://src/core/models/planet_state.gd")
var ShipDesign = load("res://src/core/models/ship_design.gd")
var Fleet = load("res://src/core/models/fleet.gd")
var GalaxyManager = load("res://src/core/managers/galaxy_manager.gd")
var GalaxyNode = load("res://src/core/models/galaxy_node.gd")
var NetworkManager = load("res://src/core/managers/network_manager.gd")

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
	print("            SSW ADVERSARIAL TEST SUITE - TIER 5 (CHALLENGER 2)   ")
	print("=================================================================")
	
	test_large_delta_exhaustion_planet()
	test_large_delta_exhaustion_planet_state()
	test_infinite_level_upgrades_planet_state()
	test_post_construction_shipyard_demolition()
	test_network_manager_room_leak()
	
	print("\n=================================================================")
	print("                 ADVERSARIAL TEST 2 SUMMARY                      ")
	print("=================================================================")
	print("Total Assertions Run : %d" % assertion_counter)
	print("Passed Assertions    : %d" % pass_counter)
	print("Failed Assertions    : %d" % fail_counter)
	print("=================================================================")
	
	if fail_counter > 0:
		print("Adversarial tests completed with %d failures." % fail_counter)
		quit(1)
	else:
		print("All Challenger 2 adversarial tests passed successfully!")
		quit(0)

func test_large_delta_exhaustion_planet() -> void:
	print("\n--- Test 1: Large Delta Iteration Limit Exhaustion (Planet.gd) ---")
	var p = Planet.new("adv_p1", "Adv Planet 1", "Player")
	p.buildings[0] = {"type": "shipyard", "level": 1}
	p.buildings[9] = {"type": "solar_power_plant", "level": 20} # high energy
	
	var wallet = {"metal": 1000000.0, "crystal": 1000000.0, "deuterium": 1000000.0}
	var design = ShipDesign.new("Fighter", "frigate")
	design.weapons = ["laser_light"]
	
	# Override cost to exactly 1000 metal, ensuring 1.0 second per ship
	var cost = {"metal": 1000, "crystal": 0, "deuterium": 0}
	
	# Start construction of 150 ships (each takes exactly 1.0 second)
	var qty = 150
	var ok = p.start_ship_construction("Fighter", "frigate", qty, cost, design, wallet, 1)
	assert_true("ADV2.1.1", "Ship construction started successfully", ok)
	
	# Tick with delta = 150.0. Since max_iterations = 10000, it should complete all 150 ships!
	p.tick(150.0, 1.0, wallet)
	
	var completed = p.hangar.get("Fighter", 0)
	var queued = p.shipyard_queue[0]["quantity"] if not p.shipyard_queue.is_empty() else 0
	
	# Secure check:
	assert_eq("ADV2.1.2", "Hangar contains exactly 150 completed ships", completed, 150)
	assert_eq("ADV2.1.3", "Queue is empty", queued, 0)

func test_large_delta_exhaustion_planet_state() -> void:
	print("\n--- Test 2: Large Delta Iteration Limit Exhaustion (PlanetState.gd) ---")
	var ps = PlanetState.new()
	ps.buildings["shipyard"] = 1
	ps.buildings["solar_power_plant"] = 20
	ps.metal = 1000000.0
	ps.crystal = 1000000.0
	ps.deuterium = 1000000.0
	
	var cost_per_ship = {"metal": 1000.0, "crystal": 0.0, "deuterium": 0.0}
	
	# Start construction of 150 ships (takes 150s total)
	var ok = ps.start_ship_construction("Fighter", "frigate", 150, cost_per_ship)
	assert_true("ADV2.2.1", "PlanetState ship construction started successfully", ok)
	
	# Tick with delta = 150.0. Since max_iterations = 10000, it should complete all 150 ships!
	ps.tick(150.0)
	
	var queued = ps.shipyard_queue[0]["quantity"] if not ps.shipyard_queue.is_empty() else 0
	assert_eq("ADV2.2.2", "PlanetState queue is empty", queued, 0)

func test_infinite_level_upgrades_planet_state() -> void:
	print("\n--- Test 3: Infinite Building Level Upgrades (PlanetState.gd) ---")
	var ps = PlanetState.new()
	ps.metal = 1000000.0
	ps.crystal = 1000000.0
	ps.deuterium = 1000000.0
	
	# Set a building level to 20 (max limit in Planet.gd)
	ps.buildings["metal_mine"] = 20
	
	# Request upgrade
	var ok = ps.start_building_upgrade("metal_mine")
	assert_eq("ADV2.3.1", "PlanetState blocks starting upgrade when building is at level 20", ok, false)
	
	# Tick to complete
	ps.tick(10.0)
	
	assert_eq("ADV2.3.2", "PlanetState metal_mine level remains 20", ps.buildings["metal_mine"], 20)

func test_post_construction_shipyard_demolition() -> void:
	print("\n--- Test 4: Post-Construction Shipyard Demolition (Planet.gd) ---")
	var p = Planet.new("adv_p4", "Adv Planet 4", "Player")
	p.buildings[0] = {"type": "shipyard", "level": 1}
	p.buildings[9] = {"type": "solar_power_plant", "level": 20}
	
	var wallet = {"metal": 100000.0, "crystal": 100000.0, "deuterium": 10000.0}
	var design = ShipDesign.new("Fighter", "frigate")
	design.weapons = ["laser_light"]
	
	# Override cost to exactly 1000 metal, ensuring 1.0 second per ship
	var cost = {"metal": 1000, "crystal": 0, "deuterium": 0}
	
	# Start construction
	var ok_build = p.start_ship_construction("Fighter", "frigate", 5, cost, design, wallet, 1)
	assert_true("ADV2.4.1", "Construction of 5 ships started successfully", ok_build)
	
	# Demolish shipyard slot while queue is active - should fail
	var ok_demolish = p.demolish_building(0)
	assert_eq("ADV2.4.2", "Shipyard demolition is blocked while queue is active", ok_demolish, false)
	assert_eq("ADV2.4.3", "Shipyard slot type is still shipyard", p.buildings[0]["type"], "shipyard")
	
	# Tick to complete construction (5 ships take 5.0 seconds)
	p.tick(5.0, 1.0, wallet)
	
	# Verify that ships were still constructed
	var completed = p.hangar.get("Fighter", 0)
	assert_eq("ADV2.4.4", "Hangar contains all 5 completed ships", completed, 5)

func test_network_manager_room_leak() -> void:
	print("\n--- Test 5: NetworkManager Room Leak via Duplicate Joins ---")
	var nm_script = load("res://src/core/managers/network_manager.gd")
	var nm = nm_script.new()
	get_root().add_child(nm)
	
	nm.is_server = true
	
	# Default peer_id is 0 when running locally offline.
	# Create Room A for peer 0
	nm.server_request_create_room("Room A", "", "Player_0")
	
	assert_true("ADV2.5.1", "Room A exists", nm.rooms.has("Room A"))
	assert_eq("ADV2.5.2", "Peer 0 mapped to Room A", nm.peer_to_room.get(0), "Room A")
	
	# Peer 0 joins Room B without exiting Room A
	nm.rooms["Room B"] = {
		"room_name": "Room B",
		"password": "",
		"host_id": 3,
		"peers": {3: "Player_3"},
		"ready_states": {3: true},
		"galaxy_manager": null,
		"game_started": false
	}
	nm.peer_to_room[3] = "Room B"
	
	nm.server_request_join_room("Room B", "", "Player_0")
	
	assert_eq("ADV2.5.3", "Peer 0 mapped to Room B", nm.peer_to_room.get(0), "Room B")
	
	# LEAK VERIFICATION: Peer 0 is no longer in Room A's peers list!
	if nm.rooms.has("Room A"):
		var room_a_peers = nm.rooms["Room A"]["peers"]
		assert_eq("ADV2.5.4", "Room A no longer contains Peer 0", room_a_peers.has(0), false)
	else:
		assert_eq("ADV2.5.4", "Room A is deleted (no leak)", nm.rooms.has("Room A"), false)
	
	nm.queue_free()
