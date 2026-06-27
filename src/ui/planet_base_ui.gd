extends Control

const Planet = preload("res://src/core/models/planet.gd")

@onready var grid: GridContainer = $MainLayout/ScrollContainer/BuildingsGrid
var queue_items: Array = []

var planet: Planet
var global_resources: Dictionary = {}
var selected_proposed_types: Dictionary = {}

func initialize(p_planet: Planet, p_global_res: Dictionary) -> void:
	if planet and planet.building_completed.is_connected(_on_building_completed):
		planet.building_completed.disconnect(_on_building_completed)
		
	if planet == null or planet.planet_id != p_planet.planet_id:
		selected_proposed_types.clear()
		
	planet = p_planet
	global_resources = p_global_res
	
	if planet:
		planet.building_completed.connect(_on_building_completed)
		
	if is_inside_tree():
		_rebuild_building_cards()

func _ready() -> void:
	# Restructure the UI programmatically to split it into Left (Grid) and Right (Queue) panels
	var main_layout = $MainLayout
	var scroll_container = $MainLayout/ScrollContainer
	var old_queue_panel = $MainLayout/QueuePanel
	
	if scroll_container and old_queue_panel:
		main_layout.remove_child(scroll_container)
		main_layout.remove_child(old_queue_panel)
		old_queue_panel.queue_free()
		
		# Create a horizontal ContentLayout below the Header
		var content_layout = HBoxContainer.new()
		content_layout.name = "ContentLayout"
		content_layout.size_flags_vertical = SIZE_EXPAND_FILL
		content_layout.add_theme_constant_override("separation", 20)
		main_layout.add_child(content_layout)
		
		# Left Column: ScrollContainer (with BuildingsGrid)
		scroll_container.size_flags_horizontal = SIZE_EXPAND_FILL
		content_layout.add_child(scroll_container)
		
		# Set Grid Columns to 2 (每行2个)
		grid.columns = 2
		
		# Right Column: QueuePanel Container
		var queue_side_panel = PanelContainer.new()
		queue_side_panel.custom_minimum_size = Vector2(280, 0)
		queue_side_panel.size_flags_vertical = SIZE_EXPAND_FILL
		
		# High-tech StyleBoxFlat for Queue Side Panel
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.06, 0.08, 0.12, 0.9)
		style_box.border_width_left = 1
		style_box.border_width_top = 1
		style_box.border_width_right = 1
		style_box.border_width_bottom = 1
		style_box.border_color = Color(0.0, 0.6, 0.7, 0.3)
		style_box.corner_radius_top_left = 6
		style_box.corner_radius_top_right = 6
		style_box.corner_radius_bottom_left = 6
		style_box.corner_radius_bottom_right = 6
		style_box.content_margin_left = 12
		style_box.content_margin_top = 12
		style_box.content_margin_right = 12
		style_box.content_margin_bottom = 12
		queue_side_panel.add_theme_stylebox_override("panel", style_box)
		
		content_layout.add_child(queue_side_panel)
		
		var queue_vbox = VBoxContainer.new()
		queue_vbox.add_theme_constant_override("separation", 15)
		queue_side_panel.add_child(queue_vbox)
		
		# Queue Header Title
		var q_title = Label.new()
		q_title.text = "建设进度 (Queue)"
		q_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_title.add_theme_font_size_override("font_size", 13)
		q_title.add_theme_color_override("font_color", Color(0.0, 0.85, 0.95))
		queue_vbox.add_child(q_title)
		
		# Instantiate 3 visual slots in the queue
		queue_items.clear()
		for i in range(3):
			var item_panel = PanelContainer.new()
			item_panel.custom_minimum_size = Vector2(0, 80)
			
			var item_style = StyleBoxFlat.new()
			item_style.bg_color = Color(0.08, 0.12, 0.2, 0.5)
			item_style.border_width_left = 1
			item_style.border_width_top = 1
			item_style.border_width_right = 1
			item_style.border_width_bottom = 1
			item_style.border_color = Color(0.0, 0.6, 0.7, 0.15)
			item_style.corner_radius_top_left = 4
			item_style.corner_radius_top_right = 4
			item_style.corner_radius_bottom_left = 4
			item_style.corner_radius_bottom_right = 4
			item_style.content_margin_left = 10
			item_style.content_margin_top = 10
			item_style.content_margin_right = 10
			item_style.content_margin_bottom = 10
			item_panel.add_theme_stylebox_override("panel", item_style)
			
			var item_vbox = VBoxContainer.new()
			item_vbox.add_theme_constant_override("separation", 6)
			item_panel.add_child(item_vbox)
			
			var item_title = Label.new()
			item_title.text = "队列 #%d: 空闲" % (i + 1)
			item_title.add_theme_font_size_override("font_size", 11)
			item_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
			item_vbox.add_child(item_title)
			
			var item_progress = ProgressBar.new()
			item_progress.custom_minimum_size = Vector2(0, 12)
			item_progress.show_percentage = false
			
			var progress_bg = StyleBoxFlat.new()
			progress_bg.bg_color = Color(0.1, 0.15, 0.25, 0.5)
			progress_bg.corner_radius_top_left = 3
			progress_bg.corner_radius_top_right = 3
			progress_bg.corner_radius_bottom_left = 3
			progress_bg.corner_radius_bottom_right = 3
			
			var progress_fg = StyleBoxFlat.new()
			progress_fg.bg_color = Color(0.0, 0.75, 0.85, 0.8)
			progress_fg.corner_radius_top_left = 3
			progress_fg.corner_radius_top_right = 3
			progress_fg.corner_radius_bottom_left = 3
			progress_fg.corner_radius_bottom_right = 3
			
			item_progress.add_theme_stylebox_override("background", progress_bg)
			item_progress.add_theme_stylebox_override("fill", progress_fg)
			item_vbox.add_child(item_progress)
			
			var item_time = Label.new()
			item_time.text = "0.0s"
			item_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			item_time.add_theme_font_size_override("font_size", 9)
			item_time.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
			item_vbox.add_child(item_time)
			
			queue_vbox.add_child(item_panel)
			queue_items.append({
				"panel": item_panel,
				"title": item_title,
				"progress": item_progress,
				"time": item_time
			})
			
	if planet:
		if not planet.building_completed.is_connected(_on_building_completed):
			planet.building_completed.connect(_on_building_completed)
		_rebuild_building_cards()
		
	NetworkManager.snapshot_received.connect(func():
		if planet:
			for n_id in NetworkManager.galaxy_manager.nodes:
				var node = NetworkManager.galaxy_manager.nodes[n_id]
				for p in node.planets:
					if p.planet_id == planet.planet_id:
						initialize(p, NetworkManager.get_my_resources())
						break
		_rebuild_building_cards()
	)

func _process(_delta: float) -> void:
	if not planet:
		return
		
	# Update resources reference dynamically to prevent stale dictionaries in multiplayer
	if NetworkManager.is_multiplayer_active():
		global_resources = NetworkManager.get_my_resources()
	elif NetworkManager.galaxy_manager:
		global_resources = NetworkManager.galaxy_manager.player_resources
		
	# 1. Update active upgrade queue display (up to 3 items)
	var active_upgrades = planet.active_upgrades
	for i in range(3):
		if i >= queue_items.size():
			break
		var item = queue_items[i]
		if i < active_upgrades.size():
			var active = active_upgrades[i]
			var slot_idx = active["slot_index"]
			var b_id = active["building_id"]
			var proposed = active["proposed_type"]
			var b_name = _get_building_display_name(b_id)
			var time_left = active["time_remaining"]
			var total_time = active["total_time"]
			
			var b = planet.buildings[slot_idx]
			var level_str = ""
			if b["type"] == "empty":
				level_str = "Lv.1"
			else:
				level_str = "Lv.%d" % (b["level"] + 1)
				
			if i == 0:
				item["title"].text = "正在建造: 插槽 %d - %s (%s)" % [slot_idx + 1, b_name, level_str]
				item["title"].add_theme_color_override("font_color", Color(0.0, 0.85, 0.95))
			else:
				item["title"].text = "排队中: 插槽 %d - %s (%s)" % [slot_idx + 1, b_name, level_str]
				item["title"].add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
				
			item["progress"].max_value = total_time
			item["progress"].value = total_time - time_left
			item["time"].text = "剩余: %.1fs" % time_left
		else:
			# Reset to empty state
			item["title"].text = "队列 #%d: 空闲" % (i + 1)
			item["title"].add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
			item["progress"].value = 0
			item["time"].text = "0.0s"
			
	# 2. Dynamically update buttons based on resources and queue capacity
	for card in grid.get_children():
		var slot_index = card.get_meta("slot_index")
		var b = planet.buildings[slot_index]
		var type = b["type"]
		var btn = card.find_child("UpgradeButton", true, false) as Button
		var demolish_btn = card.find_child("DemolishButton", true, false) as Button
		
		var is_mine = NetworkManager.is_my_faction(planet.owner_name)
		
		if demolish_btn:
			demolish_btn.disabled = not is_mine
			
		if btn:
			if not is_mine:
				btn.disabled = true
				btn.text = "无法建造 (只读)"
				if demolish_btn:
					demolish_btn.visible = (type != "empty")
			else:
				# Check if this specific slot is in the queue
				var in_queue_idx = -1
				for q_idx in range(active_upgrades.size()):
					if active_upgrades[q_idx]["slot_index"] == slot_index:
						in_queue_idx = q_idx
						break
				var is_this_slot_building = in_queue_idx != -1
				
				if is_this_slot_building:
					btn.disabled = true
					if in_queue_idx == 0:
						btn.text = "建造中..." if type == "empty" else "升级中..."
					else:
						btn.text = "已在队列"
					if demolish_btn:
						demolish_btn.visible = false
				else:
					var queue_full = active_upgrades.size() >= 3
					if type == "empty":
						if demolish_btn:
							demolish_btn.visible = false
						var proposed_type = card.get_meta("proposed_type", "")
						if proposed_type.is_empty():
							btn.disabled = true
							btn.text = "选择建筑"
						else:
							var cost = planet.get_slot_upgrade_cost(slot_index, proposed_type)
							var has_res = planet._has_resources(cost, global_resources)
							btn.disabled = not has_res or queue_full
							btn.text = "建造"
					else:
						if demolish_btn:
							demolish_btn.visible = true
						var level = b["level"]
						if level >= 20:
							btn.text = "等级已满"
							btn.disabled = true
						else:
							btn.text = "升级至 Lv.%d" % (level + 1)
							var cost = planet.get_slot_upgrade_cost(slot_index)
							var has_res = planet._has_resources(cost, global_resources)
							btn.disabled = not has_res or queue_full

func _rebuild_building_cards() -> void:
	# Clear previous immediately from the tree to avoid stale child indexes
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
		
	if not planet:
		return
		
	# Define a premium high-tech StyleBoxFlat
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.06, 0.1, 0.18, 0.75)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.0, 0.75, 0.85, 0.4)
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6
	style_box.shadow_color = Color(0, 0.5, 0.8, 0.08)
	style_box.shadow_size = 4
	
	for i in range(10):
		var slot_index = i
		var b = planet.buildings[slot_index]
		var type = b["type"]
		var level = b["level"]
		
		# Check if this slot is currently being built/upgraded
		var is_upgrading_this_slot = false
		var proposed_type_for_this_slot = ""
		var slot_queue_idx = -1
		for q_idx in range(planet.active_upgrades.size()):
			if planet.active_upgrades[q_idx]["slot_index"] == slot_index:
				is_upgrading_this_slot = true
				proposed_type_for_this_slot = planet.active_upgrades[q_idx].get("proposed_type", "")
				slot_queue_idx = q_idx
				break
			
		# Create PanelContainer Card
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(260, 90)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.set_meta("slot_index", slot_index)
		card.add_theme_stylebox_override("panel", style_box)
		
		# Main horizontal layout
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)
		
		# Left side: TextureRect
		var tex_rect = TextureRect.new()
		
		# Decide icon path
		var display_type = type
		if is_upgrading_this_slot:
			display_type = proposed_type_for_this_slot if type == "empty" else type
			
		var tex_path = "res://assets/images/buildings/empty.png"
		if display_type != "empty" and not display_type.is_empty():
			tex_path = "res://assets/images/buildings/%s.png" % display_type
			
		if ResourceLoader.exists(tex_path):
			tex_rect.texture = load(tex_path)
		else:
			# Fallback if png is not found
			tex_path = "res://assets/images/buildings/shipyard.png" # default icon fallback
			if ResourceLoader.exists(tex_path):
				tex_rect.texture = load(tex_path)
				
		tex_rect.custom_minimum_size = Vector2(56, 56)
		tex_rect.size_flags_vertical = SIZE_SHRINK_CENTER
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		# Wrap the texture in a margin or pad it slightly
		var tex_container = MarginContainer.new()
		tex_container.add_theme_constant_override("margin_left", 8)
		tex_container.add_theme_constant_override("margin_top", 6)
		tex_container.add_theme_constant_override("margin_bottom", 6)
		tex_container.add_child(tex_rect)
		hbox.add_child(tex_container)
		
		# Middle: Information VBox
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.size_flags_vertical = SIZE_SHRINK_CENTER
		hbox.add_child(vbox)
		
		# Right side: Upgrade & Demolish Button Container
		var btn_container = MarginContainer.new()
		btn_container.add_theme_constant_override("margin_right", 8)
		btn_container.add_theme_constant_override("margin_left", 4)
		btn_container.add_theme_constant_override("margin_top", 6)
		btn_container.add_theme_constant_override("margin_bottom", 6)
		btn_container.size_flags_vertical = SIZE_FILL
		
		var btn_vbox = VBoxContainer.new()
		btn_vbox.size_flags_vertical = SIZE_FILL
		btn_vbox.add_theme_constant_override("separation", 0)
		btn_container.add_child(btn_vbox)
		
		var demolish_btn = Button.new()
		demolish_btn.name = "DemolishButton"
		demolish_btn.text = "拆除"
		demolish_btn.custom_minimum_size = Vector2(55, 22)
		demolish_btn.size_flags_horizontal = SIZE_SHRINK_END
		demolish_btn.add_theme_font_size_override("font_size", 9)
		demolish_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var dem_style = StyleBoxFlat.new()
		dem_style.bg_color = Color(0.3, 0.08, 0.08, 0.7)
		dem_style.border_width_left = 1
		dem_style.border_width_top = 1
		dem_style.border_width_right = 1
		dem_style.border_width_bottom = 1
		dem_style.border_color = Color(0.8, 0.2, 0.2, 0.6)
		dem_style.corner_radius_top_left = 3
		dem_style.corner_radius_top_right = 3
		dem_style.corner_radius_bottom_left = 3
		dem_style.corner_radius_bottom_right = 3
		demolish_btn.add_theme_stylebox_override("normal", dem_style)
		
		var dem_style_hover = dem_style.duplicate()
		dem_style_hover.bg_color = Color(0.45, 0.12, 0.12, 0.9)
		dem_style_hover.border_color = Color(1.0, 0.3, 0.3, 0.9)
		demolish_btn.add_theme_stylebox_override("hover", dem_style_hover)
		
		demolish_btn.pressed.connect(_on_demolish_pressed.bind(slot_index))
		btn_vbox.add_child(demolish_btn)
		
		# Spacer to push buttons apart vertically and avoid accidental clicks
		var spacer = Control.new()
		spacer.size_flags_vertical = SIZE_EXPAND_FILL
		btn_vbox.add_child(spacer)
		
		var btn = Button.new()
		btn.name = "UpgradeButton"
		btn.custom_minimum_size = Vector2(85, 26)
		btn.size_flags_horizontal = SIZE_SHRINK_END
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_upgrade_pressed.bind(slot_index))
		btn_vbox.add_child(btn)
		
		if is_upgrading_this_slot:
			# State 1: Slot is actively constructing or upgrading or in queue
			var b_name = _get_building_display_name(proposed_type_for_this_slot if type == "empty" else type)
			var lbl_title = Label.new()
			
			if slot_queue_idx == 0:
				if type == "empty":
					lbl_title.text = "%s (建造中...)" % b_name
					lbl_title.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
				else:
					lbl_title.text = "%s  (Lv.%d) 升级中..." % [b_name, level]
					lbl_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			else:
				if type == "empty":
					lbl_title.text = "%s (排队中...)" % b_name
					lbl_title.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
				else:
					lbl_title.text = "%s  (Lv.%d) 等待中..." % [b_name, level]
					lbl_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
					
			lbl_title.add_theme_font_size_override("font_size", 12)
			vbox.add_child(lbl_title)
			
			var lbl_status = Label.new()
			if slot_queue_idx == 0:
				lbl_status.text = "正在施工中，请稍候..."
			else:
				lbl_status.text = "已在队列第 %d 位等待" % (slot_queue_idx + 1)
			lbl_status.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
			lbl_status.add_theme_font_size_override("font_size", 9)
			vbox.add_child(lbl_status)
			
			var cost = planet.get_slot_upgrade_cost(slot_index, proposed_type_for_this_slot)
			var lbl_cost = RichTextLabel.new()
			lbl_cost.bbcode_enabled = true
			lbl_cost.fit_content = true
			lbl_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
			lbl_cost.text = "消耗: [img=12]res://assets/images/resources/metal.png[/img]%d [img=12]res://assets/images/resources/crystal.png[/img]%d" % [cost.get("metal", 0), cost.get("crystal", 0)]
			lbl_cost.add_theme_color_override("default_color", Color(0.9, 0.78, 0.35))
			lbl_cost.add_theme_font_size_override("normal_font_size", 9)
			vbox.add_child(lbl_cost)
			
			card.set_meta("proposed_type", proposed_type_for_this_slot)
			if slot_queue_idx == 0:
				btn.text = "建造中..." if type == "empty" else "升级中..."
			else:
				btn.text = "已在队列"
			btn.disabled = true
			
		elif type == "empty":
			# State 2: Slot is empty and idle
			var saved_selection = selected_proposed_types.get(slot_index, "")
			card.set_meta("proposed_type", saved_selection)
			
			if saved_selection.is_empty():
				# State A: No building selected yet. Show 5 small icons in a row.
				var lbl_title = Label.new()
				lbl_title.text = "选择建筑 (插槽 %d)" % (slot_index + 1)
				lbl_title.add_theme_font_size_override("font_size", 11)
				lbl_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
				vbox.add_child(lbl_title)
				
				# Row of 5 small icons
				var icons_hbox = HBoxContainer.new()
				icons_hbox.add_theme_constant_override("separation", 6)
				vbox.add_child(icons_hbox)
				
				var build_options = [
					{"id": "metal_mine", "name": "金属矿场", "icon": "res://assets/images/buildings/metal_mine.png"},
					{"id": "crystal_mine", "name": "晶体矿场", "icon": "res://assets/images/buildings/crystal_mine.png"},
					{"id": "deuterium_synthesizer", "name": "重氢合成器", "icon": "res://assets/images/buildings/deuterium_synthesizer.png"},
					{"id": "solar_power_plant", "name": "太阳能电站", "icon": "res://assets/images/buildings/solar_power_plant.png"},
					{"id": "shipyard", "name": "太空造船厂", "icon": "res://assets/images/buildings/shipyard.png"}
				]
				
				for opt in build_options:
					var opt_btn = Button.new()
					opt_btn.custom_minimum_size = Vector2(28, 28)
					opt_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					opt_btn.tooltip_text = opt["name"]
					
					if ResourceLoader.exists(opt["icon"]):
						opt_btn.icon = load(opt["icon"])
						opt_btn.expand_icon = true
						
					var opt_style = StyleBoxFlat.new()
					opt_style.bg_color = Color(0.1, 0.15, 0.25, 0.6)
					opt_style.border_width_left = 1
					opt_style.border_width_top = 1
					opt_style.border_width_right = 1
					opt_style.border_width_bottom = 1
					opt_style.border_color = Color(0.0, 0.75, 0.85, 0.2)
					opt_style.corner_radius_top_left = 4
					opt_style.corner_radius_top_right = 4
					opt_style.corner_radius_bottom_left = 4
					opt_style.corner_radius_bottom_right = 4
					opt_btn.add_theme_stylebox_override("normal", opt_style)
					
					var opt_style_hover = opt_style.duplicate()
					opt_style_hover.bg_color = Color(0.15, 0.22, 0.35, 0.8)
					opt_style_hover.border_color = Color(0.0, 0.85, 0.95, 0.6)
					opt_btn.add_theme_stylebox_override("hover", opt_style_hover)
					
					opt_btn.pressed.connect(func():
						selected_proposed_types[slot_index] = opt["id"]
						_rebuild_building_cards()
					)
					icons_hbox.add_child(opt_btn)
					
				var lbl_cost = RichTextLabel.new()
				lbl_cost.bbcode_enabled = true
				lbl_cost.fit_content = true
				lbl_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
				lbl_cost.text = "消耗: [img=12]res://assets/images/resources/metal.png[/img]- [img=12]res://assets/images/resources/crystal.png[/img]-"
				lbl_cost.add_theme_color_override("default_color", Color(0.5, 0.5, 0.5))
				lbl_cost.add_theme_font_size_override("normal_font_size", 9)
				vbox.add_child(lbl_cost)
				
				btn.text = "选择建筑"
				btn.disabled = true
				
				if ResourceLoader.exists("res://assets/images/buildings/empty.png"):
					tex_rect.texture = load("res://assets/images/buildings/empty.png")
					
			else:
				# State B: A building is selected!
				var b_id = saved_selection
				var b_name = _get_building_display_name(b_id)
				
				var title_hbox = HBoxContainer.new()
				title_hbox.add_theme_constant_override("separation", 8)
				vbox.add_child(title_hbox)
				
				var lbl_title = Label.new()
				lbl_title.text = "%s (建)" % b_name
				lbl_title.add_theme_font_size_override("font_size", 12)
				lbl_title.add_theme_color_override("font_color", Color(0.0, 0.85, 0.95))
				title_hbox.add_child(lbl_title)
				
				var reset_btn = Button.new()
				reset_btn.text = "重选"
				reset_btn.custom_minimum_size = Vector2(36, 18)
				reset_btn.add_theme_font_size_override("font_size", 8)
				reset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				
				var reset_style = StyleBoxFlat.new()
				reset_style.bg_color = Color(0.25, 0.1, 0.1, 0.6)
				reset_style.corner_radius_top_left = 3
				reset_style.corner_radius_top_right = 3
				reset_style.corner_radius_bottom_left = 3
				reset_style.corner_radius_bottom_right = 3
				reset_btn.add_theme_stylebox_override("normal", reset_style)
				
				reset_btn.pressed.connect(func():
					selected_proposed_types.erase(slot_index)
					_rebuild_building_cards()
				)
				title_hbox.add_child(reset_btn)
				
				# Stats description of level 1
				var lbl_stats = Label.new()
				lbl_stats.text = _get_building_stats_text(b_id, 1)
				lbl_stats.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
				lbl_stats.add_theme_font_size_override("font_size", 9)
				vbox.add_child(lbl_stats)
				
				# Costs
				var cost = planet.get_building_upgrade_cost_for_level(b_id, 0)
				var lbl_cost = RichTextLabel.new()
				lbl_cost.bbcode_enabled = true
				lbl_cost.fit_content = true
				lbl_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
				lbl_cost.text = "消耗: [img=12]res://assets/images/resources/metal.png[/img]%d [img=12]res://assets/images/resources/crystal.png[/img]%d" % [cost.get("metal", 0), cost.get("crystal", 0)]
				lbl_cost.add_theme_color_override("default_color", Color(0.9, 0.78, 0.35))
				lbl_cost.add_theme_font_size_override("normal_font_size", 9)
				vbox.add_child(lbl_cost)
				
				# Set left thumbnail preview
				var preview_path = "res://assets/images/buildings/%s.png" % b_id
				if ResourceLoader.exists(preview_path):
					tex_rect.texture = load(preview_path)
					
				# Left thumbnail is also clickable to reset selection!
				tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
				tex_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				tex_rect.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						selected_proposed_types.erase(slot_index)
						_rebuild_building_cards()
				)
				
				# Upgrade Button
				btn.text = "建造"
				
				var queue_full = planet.active_upgrades.size() >= 3
				var has_res = planet._has_resources(cost, global_resources)
				btn.disabled = not has_res or queue_full
			
		else:
			# State 3: Slot is occupied and idle
			var b_name = _get_building_display_name(type)
			var lbl_title = Label.new()
			lbl_title.text = "%s  (Lv.%d)" % [b_name, level]
			lbl_title.add_theme_font_size_override("font_size", 12)
			lbl_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			vbox.add_child(lbl_title)
			
			# Stats specs description
			var lbl_stats = Label.new()
			lbl_stats.text = _get_building_stats_text(type, level)
			lbl_stats.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
			lbl_stats.add_theme_font_size_override("font_size", 9)
			lbl_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(lbl_stats)
			
			# Costs
			var lbl_cost = RichTextLabel.new()
			lbl_cost.bbcode_enabled = true
			lbl_cost.fit_content = true
			lbl_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
			if level >= 20:
				lbl_cost.text = "已达最高等级"
				lbl_cost.add_theme_color_override("default_color", Color(0.65, 0.72, 0.85))
				btn.text = "等级已满"
				btn.disabled = true
			else:
				var cost = planet.get_slot_upgrade_cost(slot_index)
				lbl_cost.text = "消耗: [img=12]res://assets/images/resources/metal.png[/img]%d [img=12]res://assets/images/resources/crystal.png[/img]%d" % [cost.get("metal", 0), cost.get("crystal", 0)]
				lbl_cost.add_theme_color_override("default_color", Color(0.9, 0.78, 0.35))
				btn.text = "升级至 Lv.%d" % (level + 1)
			lbl_cost.add_theme_font_size_override("normal_font_size", 9)
			vbox.add_child(lbl_cost)
			
		hbox.add_child(btn_container)
		grid.add_child(card)

func _on_upgrade_pressed(slot_index: int) -> void:
	if not planet:
		return
		
	# Safely retrieve proposed type from cache first, fallback to card metadata
	var proposed_type = selected_proposed_types.get(slot_index, "")
	if proposed_type.is_empty() and slot_index < grid.get_child_count():
		var card = grid.get_child(slot_index)
		proposed_type = card.get_meta("proposed_type", "")
		
	# Safety check: prevent upgrading an empty slot with an empty proposed type
	if planet.buildings[slot_index]["type"] == "empty" and proposed_type.is_empty():
		push_error("[PlanetBaseUI] Cannot build: proposed type is empty!")
		return
		
	selected_proposed_types.erase(slot_index)
	
	if NetworkManager.is_multiplayer_active():
		NetworkManager.rpc_id(1, "server_request_upgrade_building", planet.planet_id, slot_index, proposed_type)
	else:
		var success = planet.start_building_upgrade(slot_index, proposed_type, global_resources)
		if success:
			_rebuild_building_cards()

func _on_building_completed(_b_id: String, _new_level: int) -> void:
	_rebuild_building_cards()

func _get_building_display_name(b_id: String) -> String:
	match b_id:
		"metal_mine": return "金属矿场"
		"crystal_mine": return "晶体矿场"
		"deuterium_synthesizer": return "重氢合成器"
		"solar_power_plant": return "太阳能电站"
		"shipyard": return "太空造船厂"
	return b_id

func _get_building_stats_text(b_id: String, lvl: int) -> String:
	if lvl == 0:
		return "未建成 (未产出)"
		
	match b_id:
		"metal_mine":
			var prod = 30 * lvl * pow(1.1, lvl)
			var energy = 10 * lvl * pow(1.1, lvl)
			return "产量: +%.1f 金属/小时\n耗能: -%d 能量" % [prod, int(energy)]
		"crystal_mine":
			var prod = 20 * lvl * pow(1.1, lvl)
			var energy = 10 * lvl * pow(1.1, lvl)
			return "产量: +%.1f 晶体/小时\n耗能: -%d 能量" % [prod, int(energy)]
		"deuterium_synthesizer":
			var prod = 10 * lvl * pow(1.1, lvl)
			var energy = 20 * lvl * pow(1.1, lvl)
			return "产量: +%.1f 重氢/小时\n耗能: -%d 能量" % [prod, int(energy)]
		"solar_power_plant":
			var energy = 30 * lvl * pow(1.15, lvl)
			return "发电力: +%d 能量\n消耗: 无" % int(energy)
		"shipyard":
			return "支持建造轻重型战斗飞船\n造船速度加成: x%d" % lvl
	return ""

func _on_demolish_pressed(slot_index: int) -> void:
	if not planet or not NetworkManager.is_my_faction(planet.owner_name):
		return
		
	var b = planet.buildings[slot_index]
	var b_name = _get_building_display_name(b["type"])
	
	var overlay = ColorRect.new()
	overlay.name = "DemolishConfirmationOverlay"
	overlay.color = Color(0.04, 0.05, 0.07, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 140)
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	panel.size_flags_vertical = SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.2, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.2, 0.2, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 15
	style.content_margin_top = 15
	style.content_margin_right = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(center)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚠️ 确认拆除建筑"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(title)
	
	var msg = Label.new()
	msg.text = "确定要拆除插槽 %d 上的 %s (Lv.%d) 吗？\n拆除后该插槽将恢复为空白，且不退还任何资源！" % [slot_index + 1, b_name, b["level"]]
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 10)
	msg.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(msg)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var btn_ok = Button.new()
	btn_ok.text = "确认拆除"
	btn_ok.custom_minimum_size = Vector2(90, 26)
	btn_ok.add_theme_font_size_override("font_size", 10)
	btn_ok.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ok_style = StyleBoxFlat.new()
	ok_style.bg_color = Color(0.4, 0.08, 0.08, 0.8)
	ok_style.border_width_left = 1
	ok_style.border_width_top = 1
	ok_style.border_width_right = 1
	ok_style.border_width_bottom = 1
	ok_style.border_color = Color(1.0, 0.2, 0.2, 0.8)
	ok_style.corner_radius_top_left = 4
	ok_style.corner_radius_top_right = 4
	ok_style.corner_radius_bottom_left = 4
	ok_style.corner_radius_bottom_right = 4
	btn_ok.add_theme_stylebox_override("normal", ok_style)
	
	btn_ok.pressed.connect(func():
		overlay.queue_free()
		_execute_demolish(slot_index)
	)
	hbox.add_child(btn_ok)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "取消"
	btn_cancel.custom_minimum_size = Vector2(90, 26)
	btn_cancel.add_theme_font_size_override("font_size", 10)
	btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cc_style = StyleBoxFlat.new()
	cc_style.bg_color = Color(0.12, 0.18, 0.28, 0.8)
	cc_style.border_width_left = 1
	cc_style.border_width_top = 1
	cc_style.border_width_right = 1
	cc_style.border_width_bottom = 1
	cc_style.border_color = Color(0.0, 0.7, 0.8, 0.5)
	cc_style.corner_radius_top_left = 4
	cc_style.corner_radius_top_right = 4
	cc_style.corner_radius_bottom_left = 4
	cc_style.corner_radius_bottom_right = 4
	btn_cancel.add_theme_stylebox_override("normal", cc_style)
	
	btn_cancel.pressed.connect(func():
		overlay.queue_free()
	)
	hbox.add_child(btn_cancel)

func _execute_demolish(slot_index: int) -> void:
	if not planet:
		return
		
	if NetworkManager.is_multiplayer_active():
		NetworkManager.rpc_id(1, "server_request_demolish_building", planet.planet_id, slot_index)
	else:
		var success = planet.demolish_building(slot_index)
		if success:
			_rebuild_building_cards()
