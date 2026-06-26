extends Control

const Planet = preload("res://src/core/models/planet.gd")
const ShipDesign = preload("res://src/core/models/ship_design.gd")
const ComponentsData = preload("res://src/core/data/components_data.gd")

@onready var blueprint_list: VBoxContainer = $MainLayout/LeftPanel/Scroll/BlueprintList
@onready var design_name_label: Label = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout/DesignName
@onready var design_stats_label: Label = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout/DesignStats
@onready var cost_text: RichTextLabel = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout/CostText
@onready var quantity_spin: SpinBox = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout/BuildControl/QuantitySpinBox
@onready var total_cost_text: RichTextLabel = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout/BuildControl/TotalCostText
@onready var build_button: Button = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout/BuildControl/BuildButton
@onready var queue_list: VBoxContainer = $MainLayout/RightPanel/QueueBox/Scroll/QueueList
@onready var ship_preview: TextureRect = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout/ShipPreview

var planet: Planet
var global_resources: Dictionary = {}
var blueprints: Dictionary = {}
var selected_bp_name: String = ""
const BLUEPRINTS_SAVE_PATH = "user://ssw_blueprints.json"
var delete_button: Button

func initialize(p_planet: Planet, p_global_res: Dictionary) -> void:
	planet = p_planet
	global_resources = p_global_res
	if is_inside_tree():
		_update_detail_view()

func _ready() -> void:
	# Configure layout properties to prevent vertical stretching and text wrapping issues
	cost_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	quantity_spin.max_value = 9999
	
	# Restructure details panel programmatically: Left: Ship icon preview, Right: Specifications
	var detail_layout = $MainLayout/RightPanel/BuildBox/Panel/DetailLayout
	if detail_layout:
		var name_lbl = design_name_label
		var preview_tex = ship_preview
		var stats_lbl = design_stats_label
		
		# Remove from parent VBox
		detail_layout.remove_child(name_lbl)
		detail_layout.remove_child(preview_tex)
		detail_layout.remove_child(stats_lbl)
		
		# Create HBox container
		var info_hbox = HBoxContainer.new()
		info_hbox.name = "ShipInfoHBox"
		info_hbox.add_theme_constant_override("separation", 20)
		info_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
		detail_layout.add_child(info_hbox)
		detail_layout.move_child(info_hbox, 1) # Put after first Spacer
		
		# Left side: Ship Preview wrapped in a panel with cyan border
		preview_tex.custom_minimum_size = Vector2(150, 115)
		preview_tex.size_flags_vertical = SIZE_SHRINK_CENTER
		preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var preview_panel = PanelContainer.new()
		var preview_style = StyleBoxFlat.new()
		preview_style.bg_color = Color(0.06, 0.1, 0.18, 0.5)
		preview_style.border_width_left = 1
		preview_style.border_width_top = 1
		preview_style.border_width_right = 1
		preview_style.border_width_bottom = 1
		preview_style.border_color = Color(0.0, 0.75, 0.85, 0.3)
		preview_style.corner_radius_top_left = 4
		preview_style.corner_radius_top_right = 4
		preview_style.corner_radius_bottom_left = 4
		preview_style.corner_radius_bottom_right = 4
		preview_panel.add_theme_stylebox_override("panel", preview_style)
		preview_panel.add_child(preview_tex)
		info_hbox.add_child(preview_panel)
		
		# Right side: Specs ScrollContainer & VBox
		var specs_scroll = ScrollContainer.new()
		specs_scroll.name = "SpecsScrollContainer"
		specs_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
		specs_scroll.size_flags_vertical = SIZE_EXPAND_FILL
		specs_scroll.custom_minimum_size = Vector2(0, 115)
		specs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		specs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		info_hbox.add_child(specs_scroll)
		
		var specs_vbox = VBoxContainer.new()
		specs_vbox.name = "SpecsVBox"
		specs_vbox.add_theme_constant_override("separation", 6)
		specs_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		specs_vbox.size_flags_vertical = SIZE_EXPAND_FILL
		specs_scroll.add_child(specs_vbox)
		
		# Add labels
		specs_vbox.add_child(name_lbl)
		specs_vbox.add_child(stats_lbl)
		
		# Polish font size and styles
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 0.95))
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		stats_lbl.custom_minimum_size = Vector2(200, 0)
		
		# Programmatically rebuild BuildControl with cyberpunk styled panel and quick buttons
		var build_control = detail_layout.get_node_or_null("BuildControl")
		if build_control:
			var build_panel = PanelContainer.new()
			build_panel.name = "BuildPanel"
			
			# Cyan-bordered glassmorphism style
			var panel_style = StyleBoxFlat.new()
			panel_style.bg_color = Color(0.06, 0.1, 0.18, 0.6)
			panel_style.border_width_left = 1
			panel_style.border_width_top = 1
			panel_style.border_width_right = 1
			panel_style.border_width_bottom = 1
			panel_style.border_color = Color(0.0, 0.85, 0.95, 0.5)
			panel_style.corner_radius_top_left = 6
			panel_style.corner_radius_top_right = 6
			panel_style.corner_radius_bottom_left = 6
			panel_style.corner_radius_bottom_right = 6
			panel_style.content_margin_left = 15
			panel_style.content_margin_top = 12
			panel_style.content_margin_right = 15
			panel_style.content_margin_bottom = 12
			build_panel.add_theme_stylebox_override("panel", panel_style)
			
			var main_vbox = VBoxContainer.new()
			main_vbox.add_theme_constant_override("separation", 10)
			main_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
			build_panel.add_child(main_vbox)
			
			# Row 1: Quantity control HBox
			var qty_hbox = HBoxContainer.new()
			qty_hbox.add_theme_constant_override("separation", 6)
			qty_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
			qty_hbox.size_flags_vertical = SIZE_SHRINK_CENTER
			main_vbox.add_child(qty_hbox)
			
			var qty_lbl = Label.new()
			qty_lbl.text = "建造数量:"
			qty_lbl.add_theme_font_size_override("font_size", 12)
			qty_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
			qty_hbox.add_child(qty_lbl)
			
			# Reparent quantity spinbox
			quantity_spin.get_parent().remove_child(quantity_spin)
			qty_hbox.add_child(quantity_spin)
			quantity_spin.custom_minimum_size = Vector2(80, 28)
			quantity_spin.size_flags_vertical = SIZE_SHRINK_CENTER
			
			# Add quick action buttons: +1, +5, +10, Max
			var btn_values = [1, 5, 10, -1]
			var btn_texts = ["+1", "+5", "+10", "最大"]
			
			var qk_normal = StyleBoxFlat.new()
			qk_normal.bg_color = Color(0.08, 0.15, 0.25, 0.6)
			qk_normal.border_width_left = 1
			qk_normal.border_width_top = 1
			qk_normal.border_width_right = 1
			qk_normal.border_width_bottom = 1
			qk_normal.border_color = Color(0.0, 0.6, 0.7, 0.4)
			qk_normal.corner_radius_top_left = 3
			qk_normal.corner_radius_top_right = 3
			qk_normal.corner_radius_bottom_left = 3
			qk_normal.corner_radius_bottom_right = 3
			
			var qk_hover = StyleBoxFlat.new()
			qk_hover.bg_color = Color(0.12, 0.22, 0.35, 0.8)
			qk_hover.border_width_left = 1
			qk_hover.border_width_top = 1
			qk_hover.border_width_right = 1
			qk_hover.border_width_bottom = 1
			qk_hover.border_color = Color(0.0, 0.85, 0.95, 0.8)
			qk_hover.corner_radius_top_left = 3
			qk_hover.corner_radius_top_right = 3
			qk_hover.corner_radius_bottom_left = 3
			qk_hover.corner_radius_bottom_right = 3
			
			var qk_pressed = StyleBoxFlat.new()
			qk_pressed.bg_color = Color(0.05, 0.1, 0.18, 0.8)
			qk_pressed.border_width_left = 1
			qk_pressed.border_width_top = 1
			qk_pressed.border_width_right = 1
			qk_pressed.border_width_bottom = 1
			qk_pressed.border_color = Color(0.0, 0.5, 0.6, 0.8)
			qk_pressed.corner_radius_top_left = 3
			qk_pressed.corner_radius_top_right = 3
			qk_pressed.corner_radius_bottom_left = 3
			qk_pressed.corner_radius_bottom_right = 3
			
			for i in range(btn_values.size()):
				var val = btn_values[i]
				var txt = btn_texts[i]
				var qbtn = Button.new()
				qbtn.text = txt
				qbtn.custom_minimum_size = Vector2(40, 26)
				qbtn.add_theme_font_size_override("font_size", 10)
				qbtn.add_theme_stylebox_override("normal", qk_normal)
				qbtn.add_theme_stylebox_override("hover", qk_hover)
				qbtn.add_theme_stylebox_override("pressed", qk_pressed)
				qbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				qbtn.size_flags_vertical = SIZE_SHRINK_CENTER
				
				qbtn.pressed.connect(func():
					if val == -1:
						var max_aff = _calculate_max_affordable()
						quantity_spin.value = max(1, max_aff)
					else:
						quantity_spin.value += val
				)
				qty_hbox.add_child(qbtn)
				
			# Spacer to push quick buttons to the left
			var qty_spacer = Control.new()
			qty_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
			qty_hbox.add_child(qty_spacer)
			
			# Horizontal separator line
			var divider = HSeparator.new()
			main_vbox.add_child(divider)
			
			# Row 2: Cost & Buttons HBox
			var right_hbox = HBoxContainer.new()
			right_hbox.add_theme_constant_override("separation", 15)
			right_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
			right_hbox.size_flags_vertical = SIZE_SHRINK_CENTER
			main_vbox.add_child(right_hbox)
			
			# Reparent cost text
			total_cost_text.get_parent().remove_child(total_cost_text)
			right_hbox.add_child(total_cost_text)
			total_cost_text.custom_minimum_size = Vector2(250, 24)
			total_cost_text.size_flags_vertical = SIZE_SHRINK_CENTER
			total_cost_text.autowrap_mode = TextServer.AUTOWRAP_OFF
			
			# Spacer to push buttons to the right
			var btn_spacer = Control.new()
			btn_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
			right_hbox.add_child(btn_spacer)
			
			# Reparent build button
			build_button.get_parent().remove_child(build_button)
			right_hbox.add_child(build_button)
			build_button.custom_minimum_size = Vector2(110, 30)
			build_button.size_flags_vertical = SIZE_SHRINK_CENTER
			
			# Glowing neon cyan styleboxes for the build button
			var btn_normal = StyleBoxFlat.new()
			btn_normal.bg_color = Color(0.0, 0.5, 0.6, 0.8)
			btn_normal.border_width_left = 1
			btn_normal.border_width_top = 1
			btn_normal.border_width_right = 1
			btn_normal.border_width_bottom = 1
			btn_normal.border_color = Color(0.0, 0.9, 1.0, 1.0)
			btn_normal.corner_radius_top_left = 4
			btn_normal.corner_radius_top_right = 4
			btn_normal.corner_radius_bottom_left = 4
			btn_normal.corner_radius_bottom_right = 4
			btn_normal.shadow_color = Color(0.0, 0.8, 0.9, 0.25)
			btn_normal.shadow_size = 5
			
			var btn_hover = StyleBoxFlat.new()
			btn_hover.bg_color = Color(0.0, 0.65, 0.75, 0.9)
			btn_hover.border_width_left = 1
			btn_hover.border_width_top = 1
			btn_hover.border_width_right = 1
			btn_hover.border_width_bottom = 1
			btn_hover.border_color = Color(0.3, 0.95, 1.0, 1.0)
			btn_hover.corner_radius_top_left = 4
			btn_hover.corner_radius_top_right = 4
			btn_hover.corner_radius_bottom_left = 4
			btn_hover.corner_radius_bottom_right = 4
			btn_hover.shadow_color = Color(0.0, 0.8, 0.9, 0.4)
			btn_hover.shadow_size = 8
			
			var btn_pressed = StyleBoxFlat.new()
			btn_pressed.bg_color = Color(0.0, 0.4, 0.5, 0.9)
			btn_pressed.border_width_left = 1
			btn_pressed.border_width_top = 1
			btn_pressed.border_width_right = 1
			btn_pressed.border_width_bottom = 1
			btn_pressed.border_color = Color(0.0, 0.8, 0.9, 1.0)
			btn_pressed.corner_radius_top_left = 4
			btn_pressed.corner_radius_top_right = 4
			btn_pressed.corner_radius_bottom_left = 4
			btn_pressed.corner_radius_bottom_right = 4
			
			var btn_disabled = StyleBoxFlat.new()
			btn_disabled.bg_color = Color(0.12, 0.15, 0.2, 0.6)
			btn_disabled.border_width_left = 1
			btn_disabled.border_width_top = 1
			btn_disabled.border_width_right = 1
			btn_disabled.border_width_bottom = 1
			btn_disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
			btn_disabled.corner_radius_top_left = 4
			btn_disabled.corner_radius_top_right = 4
			btn_disabled.corner_radius_bottom_left = 4
			btn_disabled.corner_radius_bottom_right = 4
			btn_disabled.shadow_size = 0
			
			build_button.add_theme_stylebox_override("normal", btn_normal)
			build_button.add_theme_stylebox_override("hover", btn_hover)
			build_button.add_theme_stylebox_override("pressed", btn_pressed)
			build_button.add_theme_stylebox_override("disabled", btn_disabled)
			build_button.add_theme_color_override("font_color", Color(1, 1, 1))
			build_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
			build_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
			build_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			# Create delete blueprint button programmatically
			delete_button = Button.new()
			delete_button.name = "DeleteBlueprintButton"
			delete_button.text = "删除蓝图"
			delete_button.custom_minimum_size = Vector2(85, 30)
			delete_button.size_flags_vertical = SIZE_SHRINK_CENTER
			right_hbox.add_child(delete_button)
			
			# Red warning stylebox for delete button
			var del_normal = StyleBoxFlat.new()
			del_normal.bg_color = Color(0.35, 0.12, 0.12, 0.8)
			del_normal.border_width_left = 1
			del_normal.border_width_top = 1
			del_normal.border_width_right = 1
			del_normal.border_width_bottom = 1
			del_normal.border_color = Color(1.0, 0.3, 0.2, 1.0)
			del_normal.corner_radius_top_left = 4
			del_normal.corner_radius_top_right = 4
			del_normal.corner_radius_bottom_left = 4
			del_normal.corner_radius_bottom_right = 4
			del_normal.shadow_color = Color(1.0, 0.3, 0.2, 0.25)
			del_normal.shadow_size = 5
			
			var del_hover = StyleBoxFlat.new()
			del_hover.bg_color = Color(0.45, 0.15, 0.15, 0.9)
			del_hover.border_width_left = 1
			del_hover.border_width_top = 1
			del_hover.border_width_right = 1
			del_hover.border_width_bottom = 1
			del_hover.border_color = Color(1.0, 0.45, 0.35, 1.0)
			del_hover.corner_radius_top_left = 4
			del_hover.corner_radius_top_right = 4
			del_hover.corner_radius_bottom_left = 4
			del_hover.corner_radius_bottom_right = 4
			del_hover.shadow_color = Color(1.0, 0.3, 0.2, 0.4)
			del_hover.shadow_size = 8
			
			var del_pressed = StyleBoxFlat.new()
			del_pressed.bg_color = Color(0.28, 0.08, 0.08, 0.9)
			del_pressed.border_width_left = 1
			del_pressed.border_width_top = 1
			del_pressed.border_width_right = 1
			del_pressed.border_width_bottom = 1
			del_pressed.border_color = Color(1.0, 0.3, 0.2, 1.0)
			del_pressed.corner_radius_top_left = 4
			del_pressed.corner_radius_top_right = 4
			del_pressed.corner_radius_bottom_left = 4
			del_pressed.corner_radius_bottom_right = 4
			
			var del_disabled = StyleBoxFlat.new()
			del_disabled.bg_color = Color(0.15, 0.12, 0.12, 0.5)
			del_disabled.border_width_left = 1
			del_disabled.border_width_top = 1
			del_disabled.border_width_right = 1
			del_disabled.border_width_bottom = 1
			del_disabled.border_color = Color(0.3, 0.2, 0.2, 0.5)
			del_disabled.corner_radius_top_left = 4
			del_disabled.corner_radius_top_right = 4
			del_disabled.corner_radius_bottom_left = 4
			del_disabled.corner_radius_bottom_right = 4
			del_disabled.shadow_size = 0
			
			delete_button.add_theme_stylebox_override("normal", del_normal)
			delete_button.add_theme_stylebox_override("hover", del_hover)
			delete_button.add_theme_stylebox_override("pressed", del_pressed)
			delete_button.add_theme_stylebox_override("disabled", del_disabled)
			delete_button.add_theme_stylebox_override("focus", del_normal)
			delete_button.add_theme_color_override("font_color", Color(1, 1, 1))
			delete_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
			delete_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
			delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			delete_button.pressed.connect(_on_delete_blueprint_pressed)
			
			# Swap build_control layout node with the new panel
			var idx = build_control.get_index()
			detail_layout.remove_child(build_control)
			build_control.queue_free()
			
			detail_layout.add_child(build_panel)
			detail_layout.move_child(build_panel, idx)
			
	if not build_button.pressed.is_connected(_on_build_pressed):
		build_button.pressed.connect(_on_build_pressed)
	if not quantity_spin.value_changed.is_connected(_on_quantity_changed):
		quantity_spin.value_changed.connect(_on_quantity_changed)
		
	_reload_blueprints()
	_update_detail_view()
	
	NetworkManager.snapshot_received.connect(func():
		if planet:
			for n_id in NetworkManager.galaxy_manager.nodes:
				var node = NetworkManager.galaxy_manager.nodes[n_id]
				for p in node.planets:
					if p.planet_id == planet.planet_id:
						initialize(p, NetworkManager.get_my_resources())
						break
		_reload_blueprints()
		_update_detail_view()
	)

func _process(_delta: float) -> void:
	if not planet:
		return
		
	# Update resources reference dynamically to prevent stale dictionaries in multiplayer
	if NetworkManager.is_multiplayer_active():
		global_resources = NetworkManager.get_my_resources()
	elif NetworkManager.galaxy_manager:
		global_resources = NetworkManager.galaxy_manager.player_resources
		
	# 1. Update Build button status dynamically
	if selected_bp_name != "" and blueprints.has(selected_bp_name):
		var bp = blueprints[selected_bp_name]
		var temp_design = _create_temp_design(bp)
		var cost_per_ship = temp_design.get_total_cost()
		
		var qty = int(quantity_spin.value)
		var total_cost = {}
		for res in ["metal", "crystal", "deuterium"]:
			total_cost[res] = cost_per_ship.get(res, 0) * qty
			
		var has_res = planet._has_resources(total_cost, global_resources)
		var shipyard_level = _get_system_shipyard_level()
		
		if not NetworkManager.is_my_faction(planet.owner_name):
			build_button.disabled = true
			total_cost_text.text = "[color=#ff5555]无法在非我方星球制造飞船！[/color]"
		else:
			build_button.disabled = not has_res or shipyard_level == 0
			if shipyard_level == 0:
				total_cost_text.text = "[color=#ffaa00]需要本星系内拥有太空造船厂！[/color]"
	else:
		build_button.disabled = true
		
	# 2. Rebuild shipyard queue visual list
	_update_queue_list()

func _reload_blueprints() -> void:
	blueprints.clear()
	selected_bp_name = ""
	
	# Load from file
	if FileAccess.file_exists(BLUEPRINTS_SAVE_PATH):
		var file = FileAccess.open(BLUEPRINTS_SAVE_PATH, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_str) == OK:
				if json.data is Dictionary:
					blueprints = json.data
					
	# Clear UI list
	for child in blueprint_list.get_children():
		child.queue_free()
		
	# Populate UI list
	for bp_name in blueprints:
		var bp = blueprints[bp_name]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.text = "  %s  (%s)" % [bp_name, bp.get("hull_id", "未知船体")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Set small icon
		var hull_id = bp.get("hull_id", "frigate")
		var icon_path = "res://assets/images/hulls/%s.png" % hull_id
		if ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true
		
		btn.pressed.connect(func():
			selected_bp_name = bp_name
			_update_detail_view()
		)
		blueprint_list.add_child(btn)

func _update_detail_view() -> void:
	if selected_bp_name == "" or not blueprints.has(selected_bp_name):
		design_name_label.text = "  请选择左侧蓝图进行建造..."
		design_stats_label.text = "  - 船体: 无\n  - 武器配置: 无\n  - 护盾装甲: 无"
		cost_text.text = "  [img=12]res://assets/images/resources/metal.png[/img]-  [img=12]res://assets/images/resources/crystal.png[/img]-  [img=12]res://assets/images/resources/deuterium.png[/img]-"
		total_cost_text.text = "总价: [img=12]res://assets/images/resources/metal.png[/img]-  [img=12]res://assets/images/resources/crystal.png[/img]-  [img=12]res://assets/images/resources/deuterium.png[/img]-"
		quantity_spin.editable = false
		if ship_preview:
			ship_preview.texture = null
			ship_preview.visible = false
		if delete_button:
			delete_button.disabled = true
		return
		
	var bp = blueprints[selected_bp_name]
	var temp_design = _create_temp_design(bp)
	var static_hull_data = temp_design.get_hull_data()
	
	design_name_label.text = "  蓝图: %s" % selected_bp_name
	
	# Load ship preview
	var hull_id = bp.get("hull_id", "frigate")
	var tex_path = "res://assets/images/hulls/%s.png" % hull_id
	if ship_preview:
		if ResourceLoader.exists(tex_path):
			ship_preview.texture = load(tex_path)
			ship_preview.visible = true
		else:
			ship_preview.texture = null
			ship_preview.visible = false
	
	var weapons_names = []
	for w_id in temp_design.weapons:
		if ComponentsData.WEAPONS.has(w_id):
			weapons_names.append(ComponentsData.WEAPONS[w_id].get("name"))
			
	var shields_names = []
	for s_id in temp_design.shields:
		if ComponentsData.SHIELDS.has(s_id):
			shields_names.append(ComponentsData.SHIELDS[s_id].get("name"))
			
	var utils_names = []
	for u_id in temp_design.utilities:
		if ComponentsData.UTILITIES.has(u_id):
			utils_names.append(ComponentsData.UTILITIES[u_id].get("name"))
			
	design_stats_label.text = "  - 船体类型: %s\n  - 武器装备: %s\n  - 防御护甲: %s\n  - 辅助设备: %s" % [
		static_hull_data.get("name", bp.get("hull_id")),
		", ".join(weapons_names) if not weapons_names.is_empty() else "无",
		", ".join(shields_names) if not shields_names.is_empty() else "无",
		", ".join(utils_names) if not utils_names.is_empty() else "无"
	]
	
	var cost_per_ship = temp_design.get_total_cost()
	cost_text.text = "  [img=12]res://assets/images/resources/metal.png[/img]%d  [img=12]res://assets/images/resources/crystal.png[/img]%d  [img=12]res://assets/images/resources/deuterium.png[/img]%d" % [
		cost_per_ship.get("metal", 0),
		cost_per_ship.get("crystal", 0),
		cost_per_ship.get("deuterium", 0)
	]
	
	quantity_spin.editable = true
	if delete_button:
		delete_button.disabled = false
	_on_quantity_changed(quantity_spin.value)

func _on_quantity_changed(value: float) -> void:
	if selected_bp_name == "" or not blueprints.has(selected_bp_name):
		return
		
	var bp = blueprints[selected_bp_name]
	var temp_design = _create_temp_design(bp)
	var cost_per_ship = temp_design.get_total_cost()
	
	var qty = int(value)
	var tot_metal = cost_per_ship.get("metal", 0) * qty
	var tot_crystal = cost_per_ship.get("crystal", 0) * qty
	var tot_deut = cost_per_ship.get("deuterium", 0) * qty
	
	total_cost_text.text = "总价: [img=12]res://assets/images/resources/metal.png[/img]%d  [img=12]res://assets/images/resources/crystal.png[/img]%d  [img=12]res://assets/images/resources/deuterium.png[/img]%d" % [tot_metal, tot_crystal, tot_deut]

func _calculate_max_affordable() -> int:
	if selected_bp_name == "" or not blueprints.has(selected_bp_name):
		return 0
	var bp = blueprints[selected_bp_name]
	var temp_design = _create_temp_design(bp)
	var cost_per_ship = temp_design.get_total_cost()
	
	var max_ships = 9999
	for res in ["metal", "crystal", "deuterium"]:
		var cost = cost_per_ship.get(res, 0)
		if cost > 0:
			var available = global_resources.get(res, 0.0)
			var affordable = int(available / cost)
			if affordable < max_ships:
				max_ships = affordable
				
	if max_ships == 9999:
		return 0
	return max(0, max_ships)

func _on_build_pressed() -> void:
	if selected_bp_name == "" or not blueprints.has(selected_bp_name):
		return
		
	var bp = blueprints[selected_bp_name]
	var temp_design = _create_temp_design(bp)
	var cost_per_ship = temp_design.get_total_cost()
	var qty = int(quantity_spin.value)
	
	if not NetworkManager.is_multiplayer_active():
		var success = planet.start_ship_construction(
			selected_bp_name,
			bp["hull_id"],
			qty,
			cost_per_ship,
			temp_design,
			global_resources,
			_get_system_shipyard_level()
		)
		if success:
			print("[ShipyardUI] Build batch started: ", selected_bp_name, " x", qty)
			quantity_spin.value = 1
			_update_detail_view()
	else:
		var design_dict = {
			"design_name": selected_bp_name,
			"hull_id": bp["hull_id"],
			"weapons": bp.get("weapons", []),
			"shields": bp.get("shields", []),
			"utilities": bp.get("utilities", [])
		}
		NetworkManager.rpc_id(1, "server_request_ship_construction_with_design", planet.planet_id, selected_bp_name, qty, design_dict)
		quantity_spin.value = 1

func _update_queue_list() -> void:
	# Clear previous list
	for child in queue_list.get_children():
		child.queue_free()
		
	if not planet or planet.shipyard_queue.is_empty():
		var lbl = Label.new()
		lbl.text = "  当前没有建造项目。"
		lbl.add_theme_color_override("font_color", Color.GRAY)
		lbl.add_theme_font_size_override("font_size", 11)
		queue_list.add_child(lbl)
		return
		
	# Rebuild list
	for batch in planet.shipyard_queue:
		var panel = PanelContainer.new()
		
		# Define a clean high-tech StyleBoxFlat for each queue item
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.08, 0.12, 0.2, 0.6)
		style_box.border_width_left = 1
		style_box.border_width_top = 1
		style_box.border_width_right = 1
		style_box.border_width_bottom = 1
		style_box.border_color = Color(0.0, 0.6, 0.7, 0.3)
		style_box.corner_radius_top_left = 4
		style_box.corner_radius_top_right = 4
		style_box.corner_radius_bottom_left = 4
		style_box.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", style_box)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		panel.add_child(hbox)
		
		# Spacer padding left
		var space_l = Control.new()
		space_l.custom_minimum_size = Vector2(4, 0)
		hbox.add_child(space_l)
		
		# 1. Left: Ship hull icon thumbnail (64x36)
		var tex_rect = TextureRect.new()
		var hull_id = batch.get("hull_id", "frigate")
		var icon_path = "res://assets/images/hulls/%s.png" % hull_id
		if ResourceLoader.exists(icon_path):
			tex_rect.texture = load(icon_path)
		tex_rect.custom_minimum_size = Vector2(64, 36)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_vertical = SIZE_SHRINK_CENTER
		hbox.add_child(tex_rect)
		
		# 2. Center: VBox containing batch name and progress bar
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.size_flags_vertical = SIZE_SHRINK_CENTER
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)
		
		# Name & Quantity Label
		var lbl_name = Label.new()
		lbl_name.text = "%s  x%d" % [batch.get("design_name", "未命名"), batch.get("quantity", 1)]
		lbl_name.add_theme_font_size_override("font_size", 11)
		lbl_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		vbox.add_child(lbl_name)
		
		# Progress Bar
		var progress = ProgressBar.new()
		progress.custom_minimum_size = Vector2(0, 12)
		progress.size_flags_horizontal = SIZE_EXPAND_FILL
		
		# Calculate progress ratio
		var time_total = batch.get("time_per_ship", 1.0)
		var time_rem = batch.get("time_remaining_this_ship", 0.0)
		if time_total <= 0.0:
			time_total = 1.0
		var ratio = (1.0 - time_rem / time_total) * 100.0
		progress.value = clamp(ratio, 0.0, 100.0)
		
		# Progress bar styling
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.15, 0.25, 0.5)
		bg_style.corner_radius_top_left = 3
		bg_style.corner_radius_top_right = 3
		bg_style.corner_radius_bottom_left = 3
		bg_style.corner_radius_bottom_right = 3
		
		var fg_style = StyleBoxFlat.new()
		fg_style.bg_color = Color(0.0, 0.75, 0.85, 0.8) # cyan progress
		fg_style.corner_radius_top_left = 3
		fg_style.corner_radius_top_right = 3
		fg_style.corner_radius_bottom_left = 3
		fg_style.corner_radius_bottom_right = 3
		
		progress.add_theme_stylebox_override("background", bg_style)
		progress.add_theme_stylebox_override("fill", fg_style)
		progress.show_percentage = false
		vbox.add_child(progress)
		
		# 3. Right: Countdown timer label
		var lbl_timer = Label.new()
		lbl_timer.text = "%.1fs" % time_rem
		lbl_timer.add_theme_font_size_override("font_size", 10)
		lbl_timer.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
		lbl_timer.custom_minimum_size = Vector2(50, 0)
		lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_timer.size_flags_vertical = SIZE_SHRINK_CENTER
		hbox.add_child(lbl_timer)
		
		# Spacer padding right
		var space_r = Control.new()
		space_r.custom_minimum_size = Vector2(4, 0)
		hbox.add_child(space_r)
		
		queue_list.add_child(panel)

func _create_temp_design(bp: Dictionary) -> ShipDesign:
	var temp = ShipDesign.new(bp.get("design_name", "temp"), bp.get("hull_id", "frigate"))
	
	var cast_array = func(source_val) -> Array[String]:
		var arr: Array[String] = []
		if source_val is Array:
			for item in source_val:
				arr.append(str(item))
		return arr
		
	temp.weapons = cast_array.call(bp.get("weapons", []))
	temp.shields = cast_array.call(bp.get("shields", []))
	temp.utilities = cast_array.call(bp.get("utilities", []))
	return temp

func _get_system_shipyard_level() -> int:
	if not planet:
		return 0
	var galaxy_mgr = NetworkManager.galaxy_manager
	if not galaxy_mgr:
		return 0
	
	var target_node = null
	for node_id in galaxy_mgr.nodes:
		var node = galaxy_mgr.nodes[node_id]
		for p in node.planets:
			if p.planet_id == planet.planet_id:
				target_node = node
				break
		if target_node:
			break
			
	if not target_node:
		return 0
		
	var total_lvl = 0
	for p in target_node.planets:
		if p.owner_name == planet.owner_name:
			total_lvl += p.get_building_total_level("shipyard")
	return total_lvl

func _on_delete_blueprint_pressed() -> void:
	if selected_bp_name == "" or not blueprints.has(selected_bp_name):
		return
		
	# Create a dim background overlay to block input
	var overlay = ColorRect.new()
	overlay.name = "ConfirmOverlay"
	overlay.color = Color(0.04, 0.05, 0.07, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# CenterContainer to center the dialog panel perfectly
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(center)
	
	# Create a styled panel for the dialog box
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 160)
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	panel.size_flags_vertical = SIZE_SHRINK_CENTER
	center.add_child(panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.0, 0.75, 0.85, 0.8) # Neon cyan border
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0.0, 0.75, 0.85, 0.15)
	panel_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Layout inside the panel
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	var title_lbl = Label.new()
	title_lbl.text = "确认删除"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)
	
	# Message
	var msg_lbl = Label.new()
	msg_lbl.text = "您确定要删除蓝图“%s”吗？\n删除后将无法恢复。" % selected_bp_name
	msg_lbl.add_theme_font_size_override("font_size", 11)
	msg_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	vbox.add_child(msg_lbl)
	
	# Buttons HBox
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	# Cancel Button
	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.12, 0.15, 0.2, 0.8)
	c_style.border_width_left = 1
	c_style.border_width_top = 1
	c_style.border_width_right = 1
	c_style.border_width_bottom = 1
	c_style.border_color = Color(0.4, 0.45, 0.5, 0.6)
	c_style.corner_radius_top_left = 4
	c_style.corner_radius_top_right = 4
	c_style.corner_radius_bottom_left = 4
	c_style.corner_radius_bottom_right = 4
	cancel_btn.add_theme_stylebox_override("normal", c_style)
	cancel_btn.add_theme_stylebox_override("hover", c_style.duplicate())
	cancel_btn.get_theme_stylebox("hover").bg_color = Color(0.18, 0.22, 0.28, 0.9)
	cancel_btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	
	# Confirm Button
	var confirm_btn = Button.new()
	confirm_btn.text = "确认"
	confirm_btn.custom_minimum_size = Vector2(80, 28)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ok_style = StyleBoxFlat.new()
	ok_style.bg_color = Color(0.35, 0.12, 0.12, 0.8)
	ok_style.border_width_left = 1
	ok_style.border_width_top = 1
	ok_style.border_width_right = 1
	ok_style.border_width_bottom = 1
	ok_style.border_color = Color(1.0, 0.3, 0.2, 1.0)
	ok_style.corner_radius_top_left = 4
	ok_style.corner_radius_top_right = 4
	ok_style.corner_radius_bottom_left = 4
	ok_style.corner_radius_bottom_right = 4
	confirm_btn.add_theme_stylebox_override("normal", ok_style)
	confirm_btn.add_theme_stylebox_override("hover", ok_style.duplicate())
	confirm_btn.get_theme_stylebox("hover").bg_color = Color(0.45, 0.15, 0.15, 0.9)
	confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	
	btn_hbox.add_child(cancel_btn)
	btn_hbox.add_child(confirm_btn)
	
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
	)
	
	confirm_btn.pressed.connect(func():
		blueprints.erase(selected_bp_name)
		
		# Save updated blueprints to local file
		var file = FileAccess.open(BLUEPRINTS_SAVE_PATH, FileAccess.WRITE)
		if file:
			var json_str = JSON.stringify(blueprints)
			file.store_string(json_str)
			file.close()
			print("[ShipyardUI] Blueprint deleted successfully, updated: ", BLUEPRINTS_SAVE_PATH)
			
		selected_bp_name = ""
		_reload_blueprints()
		_update_detail_view()
		overlay.queue_free()
	)
