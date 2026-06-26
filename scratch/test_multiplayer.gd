extends Node

const Planet = preload("res://src/core/models/planet.gd")

func _ready() -> void:
	print("====================================================")
	print("--- Running Multiplayer Synchronization Test ---")
	print("====================================================")
	
	var args = OS.get_cmdline_args()
	if args.has("--client"):
		_run_client()
	else:
		_run_server()

func _run_server() -> void:
	print("[Server] Starting host server on port 9999...")
	if not NetworkManager.host_game(9999):
		print("[Server] Failed to start server!")
		get_tree().quit(1)
		return
		
	# Spawn client process
	var self_args = [
		"--headless",
		"res://scratch/test_multiplayer.tscn",
		"--client"
	]
	var client_pid = OS.create_process(OS.get_executable_path(), self_args)
	print("[Server] Spawned client subprocess (PID: %d)" % client_pid)
	
	# Wait for connection and complete the test after a timeout
	await get_tree().create_timer(6.0).timeout
	print("[Server] Test timeout reached. Server exiting.")
	
	# Kill client if it is still running
	OS.kill(client_pid)
	
	print("====================================================")
	print("--- Multiplayer Synchronization Test Completed ---")
	print("====================================================")
	get_tree().quit(0)

func _run_client() -> void:
	print("[Client] Starting client connection...")
	NetworkManager.connection_status_changed.connect(func(connected, msg):
		print("[Client] Connection status: ", msg)
	)
	
	NetworkManager.snapshot_received.connect(_on_client_snapshot_received)
	
	if not NetworkManager.join_game("127.0.0.1", 9999, "TestCommander"):
		print("[Client] Failed to initialize client!")
		get_tree().quit(1)

func _on_client_snapshot_received() -> void:
	print("[Client] Universe snapshot successfully synchronized.")
	
	var manager = NetworkManager.galaxy_manager
	assert(manager != null, "GalaxyManager should not be null")
	
	# Check allocated home node
	var home_id = NetworkManager.allocated_home_node_id
	print("[Client] My allocated home system ID: ", home_id)
	assert(not home_id.is_empty(), "Home node ID should be allocated")
	
	var node = manager.get_node_by_id(home_id)
	assert(node != null, "Home node should exist in map")
	
	# Attempt to upgrade a building (which sends RPC to server)
	var planet = node.planets[0]
	print("[Client] Home planet: ", planet.planet_name, " | Owner: ", planet.owner_name)
	
	var initial_metal_mine_level = planet.buildings.get("metal_mine", 0)
	print("[Client] Initial Metal Mine Level: ", initial_metal_mine_level)
	
	print("[Client] Sending building upgrade request RPC to server...")
	NetworkManager.rpc_id(1, "server_request_upgrade_building", planet.planet_id, "metal_mine")
	
	# Wait for server to process and sync the state back
	await get_tree().create_timer(1.5).timeout
	
	# Re-verify upgrade status on the client (synced state)
	# On success, active_upgrade queue should now be populated
	if not planet.active_upgrade.is_empty():
		print("[Client] Synced Success! Active upgrade queue found on client: ", planet.active_upgrade)
		print("[Client] Test Passed!")
		get_tree().quit(0)
	else:
		print("[Client] Error: Upgrade queue is empty! Server failed to process or sync the upgrade.")
		get_tree().quit(1)
