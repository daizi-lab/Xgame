extends Node

func _ready() -> void:
	var args = OS.get_cmdline_args()
	if args.has("--client-a"):
		_run_client_a()
	elif args.has("--client-b"):
		_run_client_b()
	else:
		_run_server()

func _run_server() -> void:
	print("[Server] Starting host server on port 9999...")
	if not NetworkManager.host_game(9999):
		print("[Server] Failed to start server!")
		get_tree().quit(1)
		return
	print("[Server] Lobby server running. Spawning client A and B...")
	
	# Spawn Client A
	var client_a_args = ["--headless", "res://scratch/test_lobby.tscn", "--client-a"]
	var pid_a = OS.create_process(OS.get_executable_path(), client_a_args)
	
	# Wait for client A to connect and create the room
	await get_tree().create_timer(1.5).timeout
	
	# Spawn Client B
	var client_b_args = ["--headless", "res://scratch/test_lobby.tscn", "--client-b"]
	var pid_b = OS.create_process(OS.get_executable_path(), client_b_args)
	
	# Wait 6 seconds for test completion or timeout
	await get_tree().create_timer(6.0).timeout
	print("[Server] Test timeout. Cleaning up processes.")
	OS.kill(pid_a)
	OS.kill(pid_b)
	get_tree().quit(0)

func _run_client_a() -> void:
	print("[Client A] Starting...")
	NetworkManager.connection_status_changed.connect(func(connected, msg):
		print("[Client A] Status: ", msg)
		if connected:
			print("[Client A] Requesting to create room 'LobbyTest'...")
			NetworkManager.rpc_id(1, "server_request_create_room", "LobbyTest", "", "CommanderA")
	)
	
	NetworkManager.snapshot_received.connect(func():
		print("[Client A] Snapshot received! Game successfully started!")
		print("[Client A] Test Passed!")
		get_tree().quit(0)
	)
	
	_hook_waiting_room()
	
	if not NetworkManager.join_game("127.0.0.1", 9999, "CommanderA"):
		print("[Client A] Connect initialization failed.")
		get_tree().quit(1)

func _run_client_b() -> void:
	print("[Client B] Starting...")
	NetworkManager.connection_status_changed.connect(func(connected, msg):
		print("[Client B] Status: ", msg)
		if connected:
			await get_tree().create_timer(0.5).timeout
			print("[Client B] Requesting to join room 'LobbyTest'...")
			NetworkManager.rpc_id(1, "server_request_join_room", "LobbyTest", "", "CommanderB")
	)
	
	NetworkManager.snapshot_received.connect(func():
		print("[Client B] Snapshot received! Game successfully started!")
		get_tree().quit(0)
	)
	
	_hook_waiting_room()
	
	if not NetworkManager.join_game("127.0.0.1", 9999, "CommanderB"):
		print("[Client B] Connect initialization failed.")
		get_tree().quit(1)

func _hook_waiting_room() -> void:
	var root = get_tree().current_scene
	root.set_script(load("res://scratch/test_lobby_helper.gd"))
