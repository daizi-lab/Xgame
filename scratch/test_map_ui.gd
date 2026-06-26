extends SceneTree

func _init() -> void:
	var log_lines = []
	log_lines.append("=== Verification Test: GalaxyMapUI Instantiation ===")
	
	var scene_path = "res://src/ui/galaxy_map_ui.tscn"
	var scene = load(scene_path)
	if not scene:
		log_lines.append("ERROR: Failed to load scene")
		_write_logs(log_lines)
		quit(1)
		return
		
	var inst = scene.instantiate()
	if not inst:
		log_lines.append("ERROR: Failed to instantiate scene")
		_write_logs(log_lines)
		quit(1)
		return
		
	# Add child so ready functions run
	root.add_child(inst)
	
	log_lines.append("SUCCESS: GalaxyMapUI instantiated and added to root successfully!")
	_write_logs(log_lines)
	quit(0)

func _write_logs(lines: Array) -> void:
	var file = FileAccess.open("C:/Users/54321/.gemini/antigravity/brain/5370392a-8085-4566-81d8-4774c50094f2/scratch/test_map_ui_output.txt", FileAccess.WRITE)
	if file:
		for line in lines:
			file.store_line(line)
		file.close()
