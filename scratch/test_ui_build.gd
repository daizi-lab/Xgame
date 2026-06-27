extends Node

const MainGameHub = preload("res://src/ui/main_game_hub.gd")

var NetworkManager

func _enter_tree() -> void:
	if not get_tree().root.has_node("NetworkManager"):
		var nm_script = load("res://src/core/managers/network_manager.gd")
		NetworkManager = nm_script.new()
		NetworkManager.name = "NetworkManager"
		get_tree().root.add_child(NetworkManager)
	else:
		NetworkManager = get_tree().root.get_node("NetworkManager")

func _ready() -> void:
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
	print("[Server] Server running and listening...")
	# Run for 20 seconds
	await get_tree().create_timer(20.0).timeout
	print("[Server] Exiting.")
	get_tree().quit(0)

func _run_client() -> void:
	print("[Client] Starting client...")
	NetworkManager.snapshot_received.connect(func():
		print("[Client] Snapshot received! Instantiating MainGameHub...")
		var hub = load("res://src/ui/main_game_hub.tscn").instantiate()
		add_child(hub)
		
		# Give one frame for UI ready to run
		await get_tree().process_frame
		
		print("[Client] Inspecting panel_base resources and buttons:")
		var panel_base = hub.panel_base
		
		print("DEBUG INFO:")
		print("  - NetworkManager.my_peer_id = ", NetworkManager.my_peer_id)
		print("  - NetworkManager.galaxy_manager.player_resources = ", NetworkManager.galaxy_manager.player_resources)
		print("  - NetworkManager.get_my_resources() = ", NetworkManager.get_my_resources())
		print("  - hub._get_current_resources() = ", hub._get_current_resources())
		print("  - panel_base.global_resources = ", panel_base.global_resources)
		
		get_tree().quit(0)
	)
	
	if not NetworkManager.join_game("127.0.0.1", 9999, "TestCommander"):
		print("[Client] Failed to join.")
		get_tree().quit(1)
