extends Node

func update_waiting_room(room_name: String, host_id: int, peers_dict: Dictionary, ready_states: Dictionary) -> void:
	var my_id = NetworkManager.multiplayer.get_unique_id()
	var is_me_host = (my_id == host_id)
	
	if is_me_host:
		print("[Client A (Host)] Received room state update.")
		print("  - Peers: ", peers_dict)
		print("  - Ready States: ", ready_states)
		
		var everyone_ready = true
		for pid in peers_dict:
			if pid != host_id and not ready_states.get(pid, false):
				everyone_ready = false
				break
				
		if everyone_ready and peers_dict.size() > 1:
			print("[Client A (Host)] Everyone is ready! Requesting to start game...")
			NetworkManager.rpc_id(1, "server_request_start_game")
		else:
			print("[Client A (Host)] Waiting for other players to ready up...")
	else:
		print("[Client B] Received room state update.")
		print("  - Peers: ", peers_dict)
		print("  - Ready States: ", ready_states)
		
		var my_ready = ready_states.get(my_id, false)
		if not my_ready:
			print("[Client B] I am not ready. Requesting to toggle ready...")
			NetworkManager.rpc_id(1, "server_request_toggle_ready")
		else:
			print("[Client B] I am ready. Waiting for host to start game...")
