extends SceneTree

func _init() -> void:
	var log_lines = []
	log_lines.append("=== Verification Test: ShipDesignerUI Instantiation ===")
	
	var scene_path = "res://src/ui/ship_designer_ui.tscn"
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
		
	root.add_child(inst)
	process_frame.connect(_on_process_frame.bind(inst, log_lines))

func _on_process_frame(inst: Node, log_lines: Array) -> void:
	process_frame.disconnect(_on_process_frame)
	
	log_lines.append("\n=== LAYOUT DEEP DEBUG ===")
	
	var main_layout = inst.get_node("MainLayout")
	log_lines.append("MainLayout size: " + str(main_layout.size) + " position: " + str(main_layout.position))
	
	for child in main_layout.get_children():
		log_lines.append("MainLayout Child: " + child.name + " class: " + child.get_class() + " size: " + str(child.size) + " position: " + str(child.position))
		if child is PanelContainer:
			if child.get_child_count() > 0:
				var margin = child.get_child(0)
				log_lines.append("  MarginContainer size: " + str(margin.size) + " position: " + str(margin.position))
				if margin.get_child_count() > 0:
					var content = margin.get_child(0)
					log_lines.append("    Content node: " + content.name + " size: " + str(content.size) + " position: " + str(content.position))
					log_lines.append("    Content anchors: left=" + str(content.anchor_left) + " right=" + str(content.anchor_right))
					log_lines.append("    Content offsets: left=" + str(content.offset_left) + " right=" + str(content.offset_right))
					
					for content_child in content.get_children():
						log_lines.append("      Content Child: " + content_child.name + " class: " + content_child.get_class() + " size: " + str(content_child.size) + " position: " + str(content_child.position))
						if content_child is TabBar:
							log_lines.append("        TabBar layout_mode: " + str(content_child.layout_mode))
							log_lines.append("        TabBar offsets: left=" + str(content_child.offset_left) + " right=" + str(content_child.offset_right))
						if content_child is Label:
							log_lines.append("        Label offsets: left=" + str(content_child.offset_left) + " right=" + str(content_child.offset_right))
							
	_write_logs(log_lines)
	quit(0)

func _write_logs(lines: Array) -> void:
	var file = FileAccess.open("res://scratch/test_designer_ui_output.txt", FileAccess.WRITE)
	if file:
		for line in lines:
			file.store_line(line)
		file.close()
