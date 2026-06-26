extends Control

const GalaxyManager = preload("res://src/core/managers/galaxy_manager.gd")
const GalaxyNode = preload("res://src/core/models/galaxy_node.gd")

signal node_selected(node_id: String)
signal node_hovered(node_id: String)

var manager: GalaxyManager
var selected_node_id: String = ""
var hovered_node_id: String = ""
var node_radius: float = 22.0

# Panning Offset variables
var map_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start: Vector2

func _ready() -> void:
	# Enable mouse filter to receive gui inputs
	mouse_filter = MOUSE_FILTER_PASS
	set_process(true)

func _process(_delta: float) -> void:
	if not manager:
		return
		
	# Handle mouse hover detection (offset by map_offset)
	var mouse_pos = get_local_mouse_position() - map_offset
	var new_hover_id = ""
	
	for node_id in manager.nodes:
		var node = manager.get_node_by_id(node_id)
		if mouse_pos.distance_to(node.position) <= node_radius:
			new_hover_id = node_id
			break
			
	if new_hover_id != hovered_node_id:
		hovered_node_id = new_hover_id
		node_hovered.emit(hovered_node_id)
		queue_redraw()
		
	# Redraw to update fleet movement positions and active combat flashes in real-time
	if not manager.moving_fleets.is_empty() or not NetworkManager.active_combats.is_empty():
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not manager:
		return
		
	# Panning drag handling (Right Mouse Button or Middle Mouse Button)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start = event.position
				accept_event()
			else:
				is_dragging = false
				accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Left click selection (offset by map_offset)
			var mouse_pos = event.position - map_offset
			for node_id in manager.nodes:
				var node = manager.get_node_by_id(node_id)
				if mouse_pos.distance_to(node.position) <= node_radius:
					selected_node_id = node_id
					node_selected.emit(node_id)
					queue_redraw()
					accept_event()
					return
					
	elif event is InputEventMouseMotion and is_dragging:
		var diff = event.position - drag_start
		map_offset += diff
		drag_start = event.position
		queue_redraw()
		accept_event()

func _draw() -> void:
	if not manager:
		return
		
	# Apply panning offset to the canvas coordinate system
	draw_set_transform(map_offset, 0.0, Vector2.ONE)
	
	var font = get_theme_font("font", "Label")
	var font_size = get_theme_font_size("font_size", "Label")
	
	# 1. Draw connections (Star Lanes)
	var drawn_lanes = []
	for node_id in manager.nodes:
		var node = manager.get_node_by_id(node_id)
		for conn_id in node.connected_node_ids:
			# Prevent drawing the same line twice
			var pair = [node_id, conn_id]
			pair.sort()
			var key = "%s-%s" % [pair[0], pair[1]]
			if not drawn_lanes.has(key):
				drawn_lanes.append(key)
				var target_node = manager.get_node_by_id(conn_id)
				draw_line(node.position, target_node.position, Color(0.18, 0.24, 0.35, 0.8), 3.0, true)
				
	# 2. Draw moving fleets
	for fleet in manager.moving_fleets:
		var origin = manager.get_node_by_id(fleet.current_node_id)
		var target = manager.get_node_by_id(fleet.target_node_id)
		
		# Interpolate fleet position
		var fleet_pos = origin.position.lerp(target.position, fleet.travel_progress)
		var dir = (target.position - origin.position).normalized()
		var perp = Vector2(-dir.y, dir.x)
		
		# Draw a triangle pointing towards target
		var fleet_color = NetworkManager.get_faction_color(fleet.owner_name)
		var pt_front = fleet_pos + dir * 10
		var pt_left = fleet_pos - dir * 8 + perp * 6
		var pt_right = fleet_pos - dir * 8 - perp * 6
		
		draw_colored_polygon([pt_front, pt_left, pt_right], fleet_color)
		
		# Draw travel progress percentage text
		var progress_text = "%d%%" % int(fleet.travel_progress * 100)
		draw_string(font, fleet_pos + Vector2(-12, -14), progress_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size - 4, Color.WHITE)

	# 3. Draw star nodes
	var node_color: Color = Color.WHITE
	for node_id in manager.nodes:
		var node = manager.get_node_by_id(node_id)
		node_color = NetworkManager.get_faction_color(node.owner_name)
		var is_home = false
		if NetworkManager.is_multiplayer_active():
			is_home = (node_id == NetworkManager.allocated_home_node_id)
		else:
			is_home = (manager and node_id == manager.singleplayer_home_node_id)

		# Ring indicators
		if node_id == selected_node_id:
			# Glowing selection ring
			draw_circle(node.position, node_radius + 6.0, Color(0.82, 0.66, 0.23, 0.4))
			draw_arc(node.position, node_radius + 6.0, 0, TAU, 32, Color(0.82, 0.66, 0.23, 0.9), 2.0)
		elif node_id == hovered_node_id:
			# Hover ring
			draw_circle(node.position, node_radius + 4.0, Color(1, 1, 1, 0.15))
			draw_arc(node.position, node_radius + 4.0, 0, TAU, 32, Color(1, 1, 1, 0.6), 1.5)
			
		# Draw special home system frame
		if is_home:
			var pts = [
				node.position + Vector2(0, -node_radius - 6),
				node.position + Vector2(node_radius + 6, 0),
				node.position + Vector2(0, node_radius + 6),
				node.position + Vector2(-node_radius - 6, 0)
			]
			draw_polyline(pts + [pts[0]], Color(0.9, 0.78, 0.3, 0.8), 2.0, true)
			
		# Fill system circle
		draw_circle(node.position, node_radius, Color(0.08, 0.1, 0.13))
		draw_circle(node.position, node_radius - 4.0, node_color)
		
		# Inner core reflection
		draw_circle(node.position - Vector2(4, 4), 3.0, Color(1, 1, 1, 0.7))
		
		# Draw active construction indicator
		var is_building = false
		for p in node.planets:
			if not p.active_upgrades.is_empty() or not p.shipyard_queue.is_empty():
				is_building = true
				break
		if is_building:
			var pulse = (sin(Time.get_ticks_msec() / 200.0) + 1.0) / 2.0
			var indicator_color = Color(0.0, 0.85, 0.95, 0.4 + pulse * 0.6)
			var pos_offset = node.position + Vector2(-node_radius, -node_radius)
			draw_circle(pos_offset, 5.0, Color.BLACK)
			draw_circle(pos_offset, 4.0, indicator_color)
			draw_circle(pos_offset, 2.0, Color.WHITE)
			
		# Draw conflict warning indicator
		var factions_present = []
		if node.owner_name != "Neutral":
			factions_present.append(node.owner_name)
		for fleet in node.stationed_fleets:
			if not factions_present.has(fleet.owner_name):
				factions_present.append(fleet.owner_name)
		var is_conflict = factions_present.size() > 1
		
		if is_conflict:
			var pulse = (sin(Time.get_ticks_msec() / 150.0) + 1.0) / 2.0
			var danger_color = Color(1.0, 0.15, 0.15, 0.5 + pulse * 0.5)
			var pos_offset = node.position + Vector2(node_radius, -node_radius)
			var pt_top = pos_offset + Vector2(0, -6)
			var pt_left = pos_offset + Vector2(-6, 5)
			var pt_right = pos_offset + Vector2(6, 5)
			draw_colored_polygon([pt_top, pt_left, pt_right], danger_color)
			draw_circle(pos_offset + Vector2(0, 1), 1.5, Color.BLACK)
		
		# Draw stationed fleets as small triangles around the node
		var fleet_idx = 0
		for fleet in node.stationed_fleets:
			var angle = fleet_idx * (TAU / 8.0) - PI/2
			var distance = node_radius + 12.0
			var offset = Vector2(cos(angle), sin(angle)) * distance
			var fleet_pos = node.position + offset
			
			var fleet_color = NetworkManager.get_faction_color(fleet.owner_name)
			var dir = offset.normalized()
			var perp = Vector2(-dir.y, dir.x)
			
			var pt_front = fleet_pos + dir * 6
			var pt_left = fleet_pos - dir * 4 + perp * 3
			var pt_right = fleet_pos - dir * 4 - perp * 3
			
			draw_colored_polygon([pt_front, pt_left, pt_right], fleet_color)
			fleet_idx += 1
		
		# Node Label Text
		var text_color = Color.WHITE if node_id == selected_node_id else Color(0.7, 0.75, 0.8)
		var display_name = node.node_name
		if NetworkManager.active_combats.has(node_id):
			display_name = "⚔️ " + display_name
			var pulse = (sin(Time.get_ticks_msec() / 100.0) + 1.0) / 2.0
			text_color = Color(1.0, 0.3, 0.3).lerp(Color.WHITE, pulse * 0.4)
			
			# Also draw a pulsing red ring around the node
			var combat_ring_color = Color(1.0, 0.15, 0.15, 0.4 + pulse * 0.6)
			draw_arc(node.position, node_radius + 8.0, 0, TAU, 32, combat_ring_color, 2.5)
			
		draw_string(
			font, 
			node.position + Vector2(-60, node_radius + 18), 
			display_name, 
			HORIZONTAL_ALIGNMENT_CENTER, 
			120, 
			font_size - 1, 
			text_color
		)
		
		# Stationed fleets counter badge
		if not node.stationed_fleets.is_empty():
			var count_text = str(node.stationed_fleets.size())
			draw_circle(node.position + Vector2(14, -14), 8.0, Color.DARK_SLATE_GRAY)
			draw_string(
				font, 
				node.position + Vector2(7, -8), 
				count_text, 
				HORIZONTAL_ALIGNMENT_CENTER, 
				14, 
				font_size - 4, 
				Color.WHITE
			)

	# 4. Draw HUD Tooltip for hovered node on top of everything
	if hovered_node_id != "" and hovered_node_id != selected_node_id:
		var hovered_node = manager.get_node_by_id(hovered_node_id)
		var tooltip_pos = hovered_node.position + Vector2(node_radius + 10.0, -45.0)
		
		# Draw tooltip card background and border
		draw_rect(Rect2(tooltip_pos, Vector2(160, 64)), Color(0.05, 0.08, 0.13, 0.9), true)
		draw_rect(Rect2(tooltip_pos, Vector2(160, 64)), Color(0, 0.8, 1, 0.5), false, 1.5)
		
		# Draw node name
		draw_string(font, tooltip_pos + Vector2(10, 18), hovered_node.node_name, HORIZONTAL_ALIGNMENT_LEFT, 140, font_size - 1, Color.WHITE)
		
		# Draw owner name
		var owner_text = "控制: " + NetworkManager.get_faction_display_name(hovered_node.owner_name)
		var faction_color = NetworkManager.get_faction_color(hovered_node.owner_name)
		draw_string(font, tooltip_pos + Vector2(10, 36), owner_text, HORIZONTAL_ALIGNMENT_LEFT, 140, font_size - 3, faction_color)
		
		# Draw planets and fleets count
		var info_text = "星球: %d  |  驻扎舰队: %d" % [hovered_node.planets.size(), hovered_node.stationed_fleets.size()]
		draw_string(font, tooltip_pos + Vector2(10, 52), info_text, HORIZONTAL_ALIGNMENT_LEFT, 140, font_size - 3, Color(0.65, 0.72, 0.85))

func center_on_node(node_id: String) -> void:
	if not manager:
		return
	var node = manager.get_node_by_id(node_id)
	if node:
		map_offset = (size / 2.0) - node.position
		queue_redraw()
