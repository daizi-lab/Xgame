extends Control



@onready var map_draw: Control = $MainLayout/MapContainer/MapDraw
@onready var system_name_label: Label = $MainLayout/RightPanel/DetailsPanel/Header/SystemName
@onready var owner_label: Label = $MainLayout/RightPanel/DetailsPanel/InfoBox/Owner
@onready var coords_label: Label = $MainLayout/RightPanel/DetailsPanel/InfoBox/Coordinates
@onready var connections_label: Label = $MainLayout/RightPanel/DetailsPanel/InfoBox/Connections
@onready var fleets_list: VBoxContainer = $MainLayout/RightPanel/DetailsPanel/FleetsScroll/FleetsList

@onready var target_option: OptionButton = $MainLayout/RightPanel/ControlBox/Destination/TargetOption
@onready var send_button: Button = $MainLayout/RightPanel/ControlBox/SendButton
@onready var logs_text: Label = $MainLayout/RightPanel/ConsoleBox/LogsScroll/LogsText
@onready var destination_label: Label = $MainLayout/RightPanel/ControlBox/Destination/Label



var galaxy_manager: GalaxyManager
var selected_node_id: String = "sol"
var selected_fleet: Fleet = null

const HULL_ICONS = {
	"frigate": preload("res://assets/images/hulls/frigate.png"),
	"destroyer": preload("res://assets/images/hulls/destroyer.png"),
	"cruiser": preload("res://assets/images/hulls/cruiser.png"),
	"battleship": preload("res://assets/images/hulls/battleship.png")
}

var planets_header: Label
var planets_list: VBoxContainer
var unassigned_header: Label
var unassigned_list: HBoxContainer
var adjacent_fleets_to_dispatch: Array[Fleet] = []
var planet_details_window: PanelContainer = null
var planet_details_container: PanelContainer = null
var current_det_planet: Planet = null
var form_fleet_window: PanelContainer = null
var form_fleet_container: CenterContainer = null
var form_fleet_spinboxes: Dictionary = {}
var system_popup: PanelContainer = null
var system_popup_container: PanelContainer = null
var console_overlay: PanelContainer = null
var set_birth_btn: Button = null
var view_combat_btn: Button = null
var birth_prompt_panel: PanelContainer = null
var base_popup_container: PanelContainer = null
var base_panel_instance: Control = null
var shipyard_popup_container: PanelContainer = null
var shipyard_panel_instance: Control = null
var current_build_planet: Planet = null
var reassign_container: VBoxContainer = null

var reassign_popup_window: PanelContainer = null
var reassign_popup_container: CenterContainer = null
var reassign_popup_list: VBoxContainer = null
var reassign_confirm_btn: Button = null

var system_selected_planet: Planet = null
var auto_manage_panel: MarginContainer
var auto_manage_check: CheckBox
var auto_manage_target_option: OptionButton
var is_updating_ui: bool = false
var planet_details_panel: VBoxContainer = null
var planet_name_lbl: Label = null
var planet_owner_lbl: Label = null
var planet_yield_metal_val: Label = null
var planet_yield_metal_lvl: Label = null
var planet_yield_crystal_val: Label = null
var planet_yield_crystal_lvl: Label = null
var planet_yield_deut_val: Label = null
var planet_yield_deut_lvl: Label = null

var planet_build_shipyard_val: Label = null
var planet_build_shipyard_lvl: Label = null
var planet_build_solar_val: Label = null
var planet_build_solar_lvl: Label = null
var planet_build_metal_val: Label = null
var planet_build_metal_lvl: Label = null
var planet_build_crystal_val: Label = null
var planet_build_crystal_lvl: Label = null
var planet_build_deut_val: Label = null
var planet_build_deut_lvl: Label = null
var planet_upgrade_lbl: Label = null
var planet_upgrade_bar: ProgressBar = null
var planet_upgrade_time_lbl: Label = null
var planet_actions_box: HBoxContainer = null

func _ready() -> void:
	print("[GalaxyMapUI] Initializing Galaxy Map UI...")
	clip_contents = true
	
	# Load space background
	var bg = get_node_or_null("Background")
	if bg and bg is TextureRect:
		bg.texture = load("res://assets/images/galaxy/bg_space.png")
	
	# Instantiate planets sidebar nodes dynamically
	planets_header = Label.new()
	planets_header.text = "  星系内星球 (Planets):"
	$MainLayout/RightPanel/DetailsPanel.add_child(planets_header)
	$MainLayout/RightPanel/DetailsPanel.move_child(planets_header, 2)
	
	planets_list = VBoxContainer.new()
	$MainLayout/RightPanel/DetailsPanel.add_child(planets_list)
	$MainLayout/RightPanel/DetailsPanel.move_child(planets_list, 3)
	
	unassigned_header = Label.new()
	unassigned_header.text = "  未编队飞船 (Unassigned Ships):"
	$MainLayout/RightPanel/DetailsPanel.add_child(unassigned_header)
	
	unassigned_list = HBoxContainer.new()
	unassigned_list.alignment = BoxContainer.ALIGNMENT_CENTER
	unassigned_list.add_theme_constant_override("separation", 15)
	$MainLayout/RightPanel/DetailsPanel.add_child(unassigned_list)
	
	# Initialize Auto-Manage UI panel as a MarginContainer inside the Header
	auto_manage_panel = MarginContainer.new()
	auto_manage_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	auto_manage_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	auto_manage_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	auto_manage_panel.add_theme_constant_override("margin_right", 8)
	
	# Styled panel container for the auto-management widget box
	var widget_panel = PanelContainer.new()
	var widget_style = StyleBoxFlat.new()
	widget_style.bg_color = Color(0.06, 0.09, 0.15, 0.7) # semi-transparent cockpit dark blue
	widget_style.border_width_left = 1
	widget_style.border_width_top = 1
	widget_style.border_width_right = 1
	widget_style.border_width_bottom = 1
	widget_style.border_color = Color(0.0, 0.75, 0.85, 0.4) # thin glowing cyan border
	widget_style.corner_radius_top_left = 4
	widget_style.corner_radius_top_right = 4
	widget_style.corner_radius_bottom_left = 4
	widget_style.corner_radius_bottom_right = 4
	widget_style.content_margin_left = 8
	widget_style.content_margin_top = 2
	widget_style.content_margin_right = 8
	widget_style.content_margin_bottom = 2
	widget_panel.add_theme_stylebox_override("panel", widget_style)
	auto_manage_panel.add_child(widget_panel)
	
	var auto_hbox = HBoxContainer.new()
	auto_hbox.add_theme_constant_override("separation", 6)
	auto_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	widget_panel.add_child(auto_hbox)
	
	# Generate checkbox textures for auto-management
	var auto_checked_img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	var auto_unchecked_img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	
	var auto_border_color = Color(0.0, 0.75, 0.85, 0.6)
	var auto_checked_border_color = Color(0.0, 0.85, 1.0, 1.0)
	var auto_bg_color = Color(0.05, 0.07, 0.11, 0.8)
	var auto_check_inner_color = Color(0.0, 0.85, 1.0, 1.0)
	
	for y in range(12):
		for x in range(12):
			var is_border = (x == 0 or x == 11 or y == 0 or y == 11)
			if is_border:
				auto_checked_img.set_pixel(x, y, auto_checked_border_color)
				auto_unchecked_img.set_pixel(x, y, auto_border_color)
			else:
				auto_checked_img.set_pixel(x, y, auto_bg_color)
				auto_unchecked_img.set_pixel(x, y, auto_bg_color)
				if x >= 3 and x <= 8 and y >= 3 and y <= 8:
					auto_checked_img.set_pixel(x, y, auto_check_inner_color)
					
	var auto_checked_tex = ImageTexture.create_from_image(auto_checked_img)
	var auto_unchecked_tex = ImageTexture.create_from_image(auto_unchecked_img)
	
	auto_manage_check = CheckBox.new()
	auto_manage_check.text = "托管"
	auto_manage_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	auto_manage_check.add_theme_font_size_override("font_size", 9)
	auto_manage_check.custom_minimum_size = Vector2(0, 18)
	auto_manage_check.add_theme_icon_override("checked", auto_checked_tex)
	auto_manage_check.add_theme_icon_override("unchecked", auto_unchecked_tex)
	auto_manage_check.add_theme_icon_override("checked_disabled", auto_checked_tex)
	auto_manage_check.add_theme_icon_override("unchecked_disabled", auto_unchecked_tex)
	auto_manage_check.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	auto_manage_check.add_theme_color_override("font_pressed_color", Color(0.0, 0.85, 1.0))
	auto_manage_check.add_theme_color_override("font_hover_color", Color(0.3, 0.95, 1.0))
	auto_manage_check.add_theme_color_override("font_hover_pressed_color", Color(0.3, 0.95, 1.0))
	auto_hbox.add_child(auto_manage_check)
	
	var target_label = Label.new()
	target_label.text = "目标:"
	target_label.add_theme_font_size_override("font_size", 9)
	target_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	auto_hbox.add_child(target_label)
	
	auto_manage_target_option = OptionButton.new()
	auto_manage_target_option.add_theme_font_size_override("font_size", 9)
	auto_manage_target_option.custom_minimum_size = Vector2(55, 18)
	auto_manage_target_option.add_item("均衡", 0)
	auto_manage_target_option.set_item_metadata(0, "balanced")
	auto_manage_target_option.add_item("经济", 1)
	auto_manage_target_option.set_item_metadata(1, "economic")
	auto_manage_target_option.add_item("军事", 2)
	auto_manage_target_option.set_item_metadata(2, "military")
	auto_manage_target_option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var opt_style_normal = StyleBoxFlat.new()
	opt_style_normal.bg_color = Color(0.08, 0.12, 0.18, 0.8)
	opt_style_normal.border_width_left = 1
	opt_style_normal.border_width_top = 1
	opt_style_normal.border_width_right = 1
	opt_style_normal.border_width_bottom = 1
	opt_style_normal.border_color = Color(0.0, 0.75, 0.85, 0.5)
	opt_style_normal.corner_radius_top_left = 3
	opt_style_normal.corner_radius_top_right = 3
	opt_style_normal.corner_radius_bottom_left = 3
	opt_style_normal.corner_radius_bottom_right = 3
	opt_style_normal.content_margin_left = 6
	opt_style_normal.content_margin_right = 6
	
	var opt_style_hover = opt_style_normal.duplicate()
	opt_style_hover.bg_color = Color(0.12, 0.18, 0.25, 0.9)
	opt_style_hover.border_color = Color(0.0, 0.85, 1.0, 1.0)
	
	var opt_style_pressed = opt_style_normal.duplicate()
	opt_style_pressed.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	opt_style_pressed.border_color = Color(0.0, 0.85, 1.0, 1.0)
	
	auto_manage_target_option.add_theme_stylebox_override("normal", opt_style_normal)
	auto_manage_target_option.add_theme_stylebox_override("hover", opt_style_hover)
	auto_manage_target_option.add_theme_stylebox_override("pressed", opt_style_pressed)
	auto_manage_target_option.add_theme_stylebox_override("focus", opt_style_normal)
	auto_manage_target_option.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	auto_manage_target_option.add_theme_color_override("font_hover_color", Color(0.3, 0.95, 1.0))
	
	var popup = auto_manage_target_option.get_popup()
	if popup:
		var popup_style = StyleBoxFlat.new()
		popup_style.bg_color = Color(0.05, 0.07, 0.11, 0.95)
		popup_style.border_width_left = 1
		popup_style.border_width_top = 1
		popup_style.border_width_right = 1
		popup_style.border_width_bottom = 1
		popup_style.border_color = Color(0.0, 0.75, 0.85, 0.7)
		popup_style.corner_radius_top_left = 4
		popup_style.corner_radius_top_right = 4
		popup_style.corner_radius_bottom_left = 4
		popup_style.corner_radius_bottom_right = 4
		popup.add_theme_stylebox_override("panel", popup_style)
		popup.add_theme_font_size_override("font_size", 10)
		popup.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		popup.add_theme_color_override("font_hover_color", Color(0.0, 0.85, 1.0))
	
	auto_hbox.add_child(auto_manage_target_option)
	
	# Connect signals for auto-management
	auto_manage_check.toggled.connect(_on_auto_manage_toggled)
	auto_manage_target_option.item_selected.connect(_on_auto_manage_target_selected)
	

	# Instantiate manager if not already injected
	if not galaxy_manager:
		if NetworkManager.is_multiplayer_active() and NetworkManager.galaxy_manager != null:
			galaxy_manager = NetworkManager.galaxy_manager
		else:
			galaxy_manager = GalaxyManager.new()
			galaxy_manager.generate_galaxy()
			if NetworkManager.is_multiplayer_active():
				_seed_game_data()
	else:
		# If singleplayer and home node already chosen, fleets are already loaded from save.
		# In multiplayer, server handles seeding.
		pass
			
	map_draw.manager = galaxy_manager
			
	NetworkManager.snapshot_received.connect(func():
		if NetworkManager.galaxy_manager != null:
			galaxy_manager = NetworkManager.galaxy_manager
			map_draw.manager = galaxy_manager
			_connect_galaxy_manager_signals()
			_on_node_selected(selected_node_id, false)
	)
	
	# Connect signals
	map_draw.node_selected.connect(func(n_id): _on_node_selected(n_id, true))
	_connect_galaxy_manager_signals()
	send_button.pressed.connect(_on_send_pressed)
	
	# Reparent panels into centered popup and bottom overlay
	_setup_dynamic_popups()
	
	# Default selection
	var starting_node = "sol"
	if NetworkManager.is_multiplayer_active():
		if not NetworkManager.allocated_home_node_id.is_empty():
			starting_node = NetworkManager.allocated_home_node_id
	else:
		if galaxy_manager and not galaxy_manager.singleplayer_home_node_id.is_empty():
			starting_node = galaxy_manager.singleplayer_home_node_id
	if not galaxy_manager.nodes.has(starting_node) and not galaxy_manager.nodes.is_empty():
		starting_node = galaxy_manager.nodes.keys()[0]
		
	selected_node_id = starting_node
	map_draw.selected_node_id = selected_node_id
	_on_node_selected(selected_node_id, false)
	
	_update_birth_setup_ui()
	
	get_viewport().size_changed.connect(_resize_top_level_panels)
	_resize_top_level_panels()
	
	call_deferred("_center_map_on_starting_node", selected_node_id)

func _center_map_on_starting_node(node_id: String) -> void:
	if map_draw.has_method("center_on_node"):
		map_draw.center_on_node(node_id)

var _last_popup_visible: bool = false

func _process(_delta: float) -> void:
	if galaxy_manager:
		# If a fleet is selected, keep its moving status updated in the UI
		if selected_fleet and selected_fleet.is_moving:
			_update_fleets_list()
	if system_popup_container:
		if system_popup_container.visible != _last_popup_visible:
			_last_popup_visible = system_popup_container.visible
			if _last_popup_visible:
				get_tree().process_frame.connect(func():
					print("[Deferred Debug] GalaxyMapUI size: ", size, " pos: ", position)
					print("[Deferred Debug] system_popup_container size: ", system_popup_container.size, " pos: ", system_popup_container.position, " gpos: ", system_popup_container.global_position)
				, CONNECT_ONE_SHOT)
		if system_popup_container.visible and system_selected_planet:
			_update_selected_planet_details_view()
		if system_popup_container.visible and view_combat_btn and not selected_node_id.is_empty():
			view_combat_btn.visible = NetworkManager.active_combats.has(selected_node_id)

func _seed_game_data(player_node_id: String = "sol") -> void:
	# 1. Create standard ship blueprints
	var f_design = ShipDesign.new("暴风护卫舰", "frigate")
	f_design.weapons = ["laser_light", "laser_light"]
	f_design.shields = ["deflector_light", "composite_armor_light"]
	f_design.utilities = ["afterburner"]
	
	var d_design = ShipDesign.new("雷霆驱逐舰", "destroyer")
	d_design.weapons = ["missile_launcher", "railgun_light"]
	d_design.shields = ["deflector_light", "composite_armor_light"]
	d_design.utilities = ["cargo_hold", "reactor_booster"]
	
	var c_design = ShipDesign.new("铁星巡洋舰", "cruiser")
	c_design.weapons = ["laser_heavy", "railgun_heavy", "railgun_heavy"]
	c_design.shields = ["deflector_heavy", "composite_armor_heavy", "composite_armor_heavy"]
	c_design.utilities = ["reactor_booster", "reactor_booster", "afterburner"]
	
	# 2. Build Player Fleet at the selected node
	var p_fleet = Fleet.new("皇家第一巡洋编队")
	p_fleet.owner_name = "Player"
	p_fleet.add_ships(f_design, 10)
	p_fleet.add_ships(c_design, 2)
	p_fleet.commander = Commander.new("夏亚上尉", 1.20, 1.15, 1.05, 1.0)
	
	var player_node = galaxy_manager.get_node_by_id(player_node_id)
	if player_node:
		# Check if already has a player fleet to prevent duplicates
		var has_player_fleet = false
		for f in player_node.stationed_fleets:
			if f.owner_name == "Player":
				has_player_fleet = true
				break
		if not has_player_fleet:
			player_node.add_fleet(p_fleet)
	
	# 3. Build Enemy Fleet at Arcturus (Enemy home)
	var e_fleet_arcturus = Fleet.new("反抗军防御舰队")
	e_fleet_arcturus.owner_name = "Enemy"
	e_fleet_arcturus.add_ships(d_design, 6)
	e_fleet_arcturus.commander = Commander.new("哈曼少尉", 1.05, 1.05, 1.30, 1.1)
	
	var arcturus_node = galaxy_manager.get_node_by_id("arcturus")
	if arcturus_node:
		var has_enemy_fleet = false
		for f in arcturus_node.stationed_fleets:
			if f.owner_name == "Enemy":
				has_enemy_fleet = true
				break
		if not has_enemy_fleet:
			arcturus_node.add_fleet(e_fleet_arcturus)
	
	# 4. Build small Enemy picket fleet at sys_2
	var picket_fleet = Fleet.new("前哨警备编队")
	picket_fleet.owner_name = "Enemy"
	picket_fleet.add_ships(f_design, 4)
	
	var picket_node = galaxy_manager.get_node_by_id("sys_2")
	if picket_node:
		var has_picket = false
		for f in picket_node.stationed_fleets:
			if f.owner_name == "Enemy":
				has_picket = true
				break
		if not has_picket:
			picket_node.add_fleet(picket_fleet)
			picket_node.owner_name = "Enemy"

func _on_node_selected(node_id: String, force_show_popup: bool = false) -> void:
	if node_id.is_empty():
		return
	if not galaxy_manager:
		return
	var node = galaxy_manager.get_node_by_id(node_id)
	if not node:
		return
		
	selected_node_id = node_id
	selected_fleet = null
	
	# Update popup title dynamically and show popup if explicitly clicked
	if system_popup:
		var title_lbl = system_popup.find_child("PopupTitle", true, false) as Label
		if title_lbl:
			title_lbl.text = "星系控制中心 - " + node.node_name
		if force_show_popup and system_popup_container:
			system_popup_container.visible = true
			print("[Debug] GalaxyMapUI size: ", size, " pos: ", position, " gpos: ", global_position)
			print("[Debug] system_popup_container size: ", system_popup_container.size, " pos: ", system_popup_container.position, " gpos: ", system_popup_container.global_position)
			print("[Debug] Parent size: ", get_parent().size if get_parent() else "no parent")
			
	# Update sidebar text
	system_name_label.text = node.node_name
	owner_label.text = "控制势力: %s" % NetworkManager.get_faction_display_name(node.owner_name)
	coords_label.text = "星区坐标: (%d, %d)" % [int(node.position.x), int(node.position.y)]
	
	# Update Auto-Manage UI visibility and state
	var is_mine = NetworkManager.is_my_faction(node.owner_name)
	if auto_manage_panel:
		auto_manage_panel.visible = is_mine
		if is_mine:
			is_updating_ui = true
			auto_manage_check.button_pressed = node.is_auto_managed
			
			var target = node.auto_manage_target
			var index_to_select = 0
			if target == "economic":
				index_to_select = 1
			elif target == "military":
				index_to_select = 2
			auto_manage_target_option.select(index_to_select)
			is_updating_ui = false
	
	# Show connections names
	var conn_names = []
	for conn_id in node.connected_node_ids:
		var c_node = galaxy_manager.get_node_by_id(conn_id)
		if c_node:
			conn_names.append(c_node.node_name)
	connections_label.text = "连通星路: %s" % (", ".join(conn_names) if not conn_names.is_empty() else "孤立星系")
	
	# Rebuild Planets List as a horizontal orbits layout
	if planets_list:
		for child in planets_list.get_children():
			child.queue_free()
			
		var orbits_hbox = HBoxContainer.new()
		orbits_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		orbits_hbox.add_theme_constant_override("separation", 0)
		planets_list.add_child(orbits_hbox)
		
		# 1. Add Sun on the left
		var sun_vbox = VBoxContainer.new()
		sun_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var sun_tex = TextureRect.new()
		sun_tex.texture = load("res://assets/images/galaxy/sun.png")
		sun_tex.custom_minimum_size = Vector2(64, 64)
		sun_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sun_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sun_vbox.add_child(sun_tex)
		
		var sun_lbl = Label.new()
		sun_lbl.text = "恒星"
		sun_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sun_lbl.add_theme_font_size_override("font_size", 11)
		sun_lbl.add_theme_color_override("font_color", Color.GOLD)
		sun_vbox.add_child(sun_lbl)
		
		orbits_hbox.add_child(sun_vbox)
		
		# 2. Add orbits and planets
		var roman_numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
		
		# Resolve selected planet reference stability on snapshot reload
		var matched_planet: Planet = null
		if system_selected_planet:
			for p in node.planets:
				if p.planet_id == system_selected_planet.planet_id:
					matched_planet = p
					break
		if matched_planet:
			system_selected_planet = matched_planet
		elif not node.planets.is_empty():
			system_selected_planet = node.planets[0]
			
		for idx in range(node.planets.size()):
			var planet = node.planets[idx]
			
			# Orbit connector line
			var orbit_line = Control.new()
			orbit_line.custom_minimum_size = Vector2(40, 64)
			orbit_line.draw.connect(func():
				var center_y = orbit_line.size.y / 2
				orbit_line.draw_line(Vector2(0, center_y), Vector2(orbit_line.size.x, center_y), Color(0.3, 0.4, 0.5, 0.6), 2.0)
			)
			orbits_hbox.add_child(orbit_line)
			
			# Planet box
			var p_vbox = VBoxContainer.new()
			p_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			
			# Planet button wrapper
			var p_btn = Button.new()
			p_btn.custom_minimum_size = Vector2(60, 60)
			
			var style_normal = StyleBoxFlat.new()
			style_normal.bg_color = Color(0, 0, 0, 0)
			style_normal.corner_radius_top_left = 30
			style_normal.corner_radius_top_right = 30
			style_normal.corner_radius_bottom_left = 30
			style_normal.corner_radius_bottom_right = 30
			style_normal.border_width_left = 0
			style_normal.border_width_right = 0
			style_normal.border_width_top = 0
			style_normal.border_width_bottom = 0
			
			if system_selected_planet == planet:
				style_normal.border_width_left = 3
				style_normal.border_width_right = 3
				style_normal.border_width_top = 3
				style_normal.border_width_bottom = 3
				style_normal.border_color = Color(0.0, 0.85, 1.0, 1.0)
				style_normal.shadow_color = Color(0.0, 0.85, 1.0, 0.3)
				style_normal.shadow_size = 6
				
			p_btn.add_theme_stylebox_override("normal", style_normal)
			p_btn.add_theme_stylebox_override("hover", style_normal)
			p_btn.add_theme_stylebox_override("pressed", style_normal)
			p_btn.add_theme_stylebox_override("focus", style_normal)
			
			var p_tex = TextureRect.new()
			p_tex.texture = load(_get_planet_texture_path(planet))
			p_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
			p_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			p_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			p_tex.offset_left = 4
			p_tex.offset_right = -4
			p_tex.offset_top = 4
			p_tex.offset_bottom = -4
			p_btn.add_child(p_tex)
			
			p_btn.pressed.connect(func():
				system_selected_planet = planet
				_on_node_selected(selected_node_id, false)
			)
			p_vbox.add_child(p_btn)
			
			# Roman numeral label
			var p_lbl = Label.new()
			var suffix = roman_numerals[idx] if idx < roman_numerals.size() else str(idx + 1)
			p_lbl.text = "星球 " + suffix
			p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			p_lbl.add_theme_font_size_override("font_size", 11)
			p_lbl.add_theme_color_override("font_color", NetworkManager.get_faction_color(planet.owner_name))
			p_vbox.add_child(p_lbl)
			
			orbits_hbox.add_child(p_vbox)

	# Update the right side selected planet details immediately
	_update_selected_planet_details_view()

	# Rebuild fleets list for dispatch based on target ownership (Deploy vs Attack)
	target_option.clear()
	adjacent_fleets_to_dispatch.clear()
	
	var is_target_player_owned = false
	if system_selected_planet:
		is_target_player_owned = NetworkManager.is_my_faction(system_selected_planet.owner_name)
	else:
		is_target_player_owned = NetworkManager.is_my_faction(node.owner_name)
		
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	
	if is_target_player_owned:
		destination_label.text = "调动目的地: %s" % node.node_name
		
		# Glowing neon cyan style for Deploy
		style_normal.bg_color = Color(0.0, 0.5, 0.6, 0.8)
		style_normal.border_width_left = 1
		style_normal.border_width_top = 1
		style_normal.border_width_right = 1
		style_normal.border_width_bottom = 1
		style_normal.border_color = Color(0.0, 0.9, 1.0, 1.0)
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.corner_radius_bottom_right = 4
		style_normal.shadow_color = Color(0.0, 0.8, 0.9, 0.25)
		style_normal.shadow_size = 5
		
		style_hover.bg_color = Color(0.0, 0.65, 0.75, 0.9)
		style_hover.border_width_left = 1
		style_hover.border_width_top = 1
		style_hover.border_width_right = 1
		style_hover.border_width_bottom = 1
		style_hover.border_color = Color(0.3, 0.95, 1.0, 1.0)
		style_hover.corner_radius_top_left = 4
		style_hover.corner_radius_top_right = 4
		style_hover.corner_radius_bottom_left = 4
		style_hover.corner_radius_bottom_right = 4
		style_hover.shadow_color = Color(0.0, 0.8, 0.9, 0.4)
		style_hover.shadow_size = 8
		
		style_pressed.bg_color = Color(0.0, 0.4, 0.5, 0.9)
		style_pressed.border_width_left = 1
		style_pressed.border_width_top = 1
		style_pressed.border_width_right = 1
		style_pressed.border_width_bottom = 1
		style_pressed.border_color = Color(0.0, 0.8, 0.9, 1.0)
		style_pressed.corner_radius_top_left = 4
		style_pressed.corner_radius_top_right = 4
		style_pressed.corner_radius_bottom_left = 4
		style_pressed.corner_radius_bottom_right = 4
		
		var control_box = send_button.get_parent()
		var dest_node = control_box.get_node("Destination")
		if dest_node:
			dest_node.visible = true
		target_option.visible = false
		if reassign_container:
			reassign_container.visible = false
			
		# Count available fleets to reassign
		var reassignable_count = 0
		for other_id in galaxy_manager.nodes:
			if other_id == selected_node_id:
				continue
			var other_node = galaxy_manager.get_node_by_id(other_id)
			if other_node:
				for fleet in other_node.stationed_fleets:
					if NetworkManager.is_my_faction(fleet.owner_name) and not fleet.is_moving:
						reassignable_count += 1
						
		if reassignable_count == 0:
			send_button.disabled = true
			send_button.text = "其他星系无可用舰队"
		else:
			send_button.disabled = false
			send_button.text = "选择并调动舰队"
	else:
		destination_label.text = "选择攻击舰队 (邻近星系):"
		send_button.text = "发起攻击"
		target_option.visible = true
		if reassign_container:
			reassign_container.visible = false
		
		# Glowing fiery orange/red style for Attack
		style_normal.bg_color = Color(0.7, 0.25, 0.0, 0.8)
		style_normal.border_width_left = 1
		style_normal.border_width_top = 1
		style_normal.border_width_right = 1
		style_normal.border_width_bottom = 1
		style_normal.border_color = Color(1.0, 0.5, 0.0, 1.0)
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.corner_radius_bottom_right = 4
		style_normal.shadow_color = Color(1.0, 0.4, 0.0, 0.25)
		style_normal.shadow_size = 5
		
		style_hover.bg_color = Color(0.8, 0.35, 0.0, 0.9)
		style_hover.border_width_left = 1
		style_hover.border_width_top = 1
		style_hover.border_width_right = 1
		style_hover.border_width_bottom = 1
		style_hover.border_color = Color(1.0, 0.65, 0.3, 1.0)
		style_hover.corner_radius_top_left = 4
		style_hover.corner_radius_top_right = 4
		style_hover.corner_radius_bottom_left = 4
		style_hover.corner_radius_bottom_right = 4
		style_hover.shadow_color = Color(1.0, 0.4, 0.0, 0.4)
		style_hover.shadow_size = 8
		
		style_pressed.bg_color = Color(0.55, 0.15, 0.0, 0.9)
		style_pressed.border_width_left = 1
		style_pressed.border_width_top = 1
		style_pressed.border_width_right = 1
		style_pressed.border_width_bottom = 1
		style_pressed.border_color = Color(1.0, 0.5, 0.0, 1.0)
		style_pressed.corner_radius_top_left = 4
		style_pressed.corner_radius_top_right = 4
		style_pressed.corner_radius_bottom_left = 4
		style_pressed.corner_radius_bottom_right = 4
		
		var control_box = send_button.get_parent()
		var dest_node = control_box.get_node("Destination")
		if dest_node:
			dest_node.visible = true
			
		var fleet_idx = 0
		for conn_id in node.connected_node_ids:
			var conn_node = galaxy_manager.get_node_by_id(conn_id)
			if conn_node:
				for fleet in conn_node.stationed_fleets:
					if NetworkManager.is_my_faction(fleet.owner_name) and not fleet.is_moving:
						var ships_desc = []
						for d_name in fleet.ships:
							ships_desc.append("%s x%d" % [d_name, fleet.ships[d_name]])
						var details = ", ".join(ships_desc)
						
						var item_text = "[%s] %s (%s)" % [conn_node.node_name.split(" ")[0], fleet.fleet_name, details]
						target_option.add_item(item_text, fleet_idx)
						target_option.set_item_metadata(fleet_idx, {"fleet": fleet, "origin_id": conn_id})
						adjacent_fleets_to_dispatch.append(fleet)
						fleet_idx += 1
						
		if target_option.item_count > 0:
			target_option.select(0)
			send_button.disabled = false
		else:
			target_option.add_item("邻近星系无可用舰队")
			send_button.disabled = true
			
	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.12, 0.15, 0.2, 0.6)
	style_disabled.border_width_left = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_bottom = 1
	style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
	style_disabled.corner_radius_top_left = 4
	style_disabled.corner_radius_top_right = 4
	style_disabled.corner_radius_bottom_left = 4
	style_disabled.corner_radius_bottom_right = 4
	style_disabled.shadow_size = 0
	
	send_button.add_theme_stylebox_override("normal", style_normal)
	send_button.add_theme_stylebox_override("hover", style_hover)
	send_button.add_theme_stylebox_override("pressed", style_pressed)
	send_button.add_theme_stylebox_override("disabled", style_disabled)
	send_button.add_theme_color_override("font_color", Color(1, 1, 1))
	send_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	send_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	send_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	_update_fleets_list()
	_update_birth_setup_ui()

func _update_fleets_list() -> void:
	# Clear list
	for child in fleets_list.get_children():
		child.queue_free()
		
	if not galaxy_manager:
		return
	var node = galaxy_manager.get_node_by_id(selected_node_id)
	if not node:
		return
	
	# 1. Stationed Fleets
	for fleet in node.stationed_fleets:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 45)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Build ships list string
		var ships_str = []
		for d_name in fleet.ships:
			ships_str.append("%s x%d" % [d_name, fleet.ships[d_name]])
			
		var owner_color = NetworkManager.get_faction_color(fleet.owner_name)
		var display_name = NetworkManager.get_faction_display_name(fleet.owner_name)
		btn.text = " [%s] %s\n - %s" % [display_name, fleet.fleet_name if NetworkManager.is_my_faction(fleet.owner_name) else display_name + "舰队", ", ".join(ships_str)]
		btn.modulate = owner_color
		
		# Highlight selected fleet
		if selected_fleet == fleet:
			btn.flat = false
			btn.theme_type_variation = "ButtonActive"
		else:
			btn.flat = true
			
		btn.pressed.connect(func():
			selected_fleet = fleet
			_update_fleets_list()
		)
		fleets_list.add_child(btn)
		
	# 2. Add moving fleets arriving at this node
	for fleet in galaxy_manager.moving_fleets:
		if fleet.target_node_id == selected_node_id:
			var lbl = Label.new()
			lbl.text = " [航行中] %s -> %.1fs (进度: %d%%)" % [
				fleet.fleet_name, 
				fleet.travel_time_remaining, 
				int(fleet.travel_progress * 100)
			]
			lbl.modulate = Color(1, 1, 0, 0.8)
			fleets_list.add_child(lbl)
			
	_update_unassigned_ships()

func _update_unassigned_ships() -> void:
	if not unassigned_list:
		return
		
	# Clear the list first
	for child in unassigned_list.get_children():
		child.queue_free()
		
	if not galaxy_manager:
		return
	var node = galaxy_manager.get_node_by_id(selected_node_id)
	if not node:
		return
		
	# We want to count unassigned ships in this system (across all planets)
	var counts = {
		"frigate": 0,
		"destroyer": 0,
		"cruiser": 0,
		"battleship": 0
	}
	
	# Sum up hangar quantities for each planet in the selected node
	for planet in node.planets:
		for design_name in planet.hangar:
			var qty = planet.hangar[design_name]
			if qty <= 0:
				continue
			var design = planet.designs.get(design_name)
			if design and counts.has(design.hull_id):
				counts[design.hull_id] += qty
				
	# Check if there are any unassigned ships
	var total_unassigned = 0
	for hull_id in counts:
		total_unassigned += counts[hull_id]
		
	if total_unassigned == 0:
		var lbl = Label.new()
		lbl.text = "暂无未编队飞船"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lbl.add_theme_font_size_override("font_size", 11)
		unassigned_list.add_child(lbl)
		return
		
	# Show icons and counts for each hull type that has a count > 0
	for hull_id in ["frigate", "destroyer", "cruiser", "battleship"]:
		var qty = counts[hull_id]
		if qty <= 0:
			continue
			
		var item_box = HBoxContainer.new()
		item_box.alignment = BoxContainer.ALIGNMENT_CENTER
		item_box.add_theme_constant_override("separation", 4)
		unassigned_list.add_child(item_box)
		
		var tex_rect = TextureRect.new()
		tex_rect.texture = HULL_ICONS.get(hull_id)
		tex_rect.custom_minimum_size = Vector2(24, 24)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.flip_h = true
		item_box.add_child(tex_rect)
		
		var count_lbl = Label.new()
		var hull_name = ""
		match hull_id:
			"frigate": hull_name = "护卫"
			"destroyer": hull_name = "驱逐"
			"cruiser": hull_name = "巡洋"
			"battleship": hull_name = "战列"
		count_lbl.text = "%s x%d" % [hull_name, qty]
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		item_box.add_child(count_lbl)

func _on_send_pressed() -> void:
	var target_node = galaxy_manager.get_node_by_id(selected_node_id)
	if not target_node:
		return
		
	var is_reassignment = false
	if system_selected_planet:
		is_reassignment = NetworkManager.is_my_faction(system_selected_planet.owner_name)
	else:
		is_reassignment = NetworkManager.is_my_faction(target_node.owner_name)
		
	if is_reassignment:
		_open_reassign_popup()
		return
	else:
		# Attack mode (single selection from target_option OptionButton)
		var target_index = target_option.selected
		if target_index < 0 or adjacent_fleets_to_dispatch.is_empty():
			_write_log("* 错误: 无可用舰队可派遣。")
			return
			
		var metadata = target_option.get_item_metadata(target_index)
		if not metadata:
			return
			
		var fleet = metadata.get("fleet") as Fleet
		var origin_id = metadata.get("origin_id") as String
		
		if not fleet:
			return
			
		if fleet.is_moving:
			_write_log("* 错误: 选中的舰队已经在航行中。")
			return
			
		if not NetworkManager.is_multiplayer_active():
			var success = galaxy_manager.dispatch_fleet(fleet, selected_node_id)
			if success:
				_write_log("[舰队攻击]: 成功派遣舰队 %s 前往 %s 星系发起攻击！" % [fleet.fleet_name, target_node.node_name])
				_on_node_selected(selected_node_id) # Refresh UI
		else:
			NetworkManager.rpc_id(1, "server_request_dispatch_fleet", fleet.fleet_name, origin_id, selected_node_id)
			_write_log("[攻击指令]: 已向服务器发送发起攻击请求。")
			_on_node_selected(selected_node_id) # Refresh UI

func _create_planet_details_ui() -> void:
	if planet_details_container:
		return
		
	# Create full-screen PanelContainer to serve as the "new page"
	planet_details_container = PanelContainer.new()
	planet_details_container.top_level = true
	planet_details_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	planet_details_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	planet_details_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	planet_details_container.mouse_filter = Control.MOUSE_FILTER_STOP
	planet_details_container.visible = false
	
	# Premium dark sci-fi background for the details page
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 1.0) # Dark sci-fi backdrop
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.0, 0.75, 0.85, 0.6) # Cyan accent border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	planet_details_container.add_theme_stylebox_override("panel", style)
	
	# Assign container to window to satisfy visibility checks in other components
	planet_details_window = planet_details_container
	
	var main_margin = MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 30)
	main_margin.add_theme_constant_override("margin_top", 30)
	main_margin.add_theme_constant_override("margin_right", 30)
	main_margin.add_theme_constant_override("margin_bottom", 30)
	planet_details_container.add_child(main_margin)
	
	var page_vbox = VBoxContainer.new()
	page_vbox.add_theme_constant_override("separation", 24)
	main_margin.add_child(page_vbox)
	
	# --- 1. Page Header ---
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	page_vbox.add_child(header)
	
	# Back Button
	var back_btn = Button.new()
	back_btn.text = " ⬅ 返回星区图 "
	back_btn.custom_minimum_size = Vector2(140, 40)
	back_btn.pressed.connect(func(): planet_details_container.visible = false)
	header.add_child(back_btn)
	
	# Title
	var title = Label.new()
	title.name = "Title"
	title.text = "星球详情"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	header.add_child(title)
	
	# --- 2. Page Body (Split Layout) ---
	var body_hbox = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 30)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_vbox.add_child(body_hbox)
	
	# Left Column: Info & Buildings
	var left_column = PanelContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_stretch_ratio = 1.0
	
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.11, 0.16, 0.8)
	left_style.corner_radius_top_left = 6
	left_style.corner_radius_top_right = 6
	left_style.corner_radius_bottom_left = 6
	left_style.corner_radius_bottom_right = 6
	left_column.add_theme_stylebox_override("panel", left_style)
	
	var left_margin = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 20)
	left_margin.add_theme_constant_override("margin_top", 20)
	left_margin.add_theme_constant_override("margin_right", 20)
	left_margin.add_theme_constant_override("margin_bottom", 20)
	left_column.add_child(left_margin)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 16)
	left_margin.add_child(left_vbox)
	
	# Owner & Info
	var info_lbl = Label.new()
	info_lbl.name = "OwnerInfo"
	info_lbl.text = "控制势力: -"
	info_lbl.add_theme_font_size_override("font_size", 12)
	left_vbox.add_child(info_lbl)
	
	# Buildings section
	var b_section = VBoxContainer.new()
	b_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var b_title = Label.new()
	b_title.text = "基础设施清单 (Infrastructure Summary):"
	b_title.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
	b_title.add_theme_font_size_override("font_size", 11)
	b_section.add_child(b_title)
	
	var b_scroll = ScrollContainer.new()
	b_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var b_grid = GridContainer.new()
	b_grid.name = "BuildingsGrid"
	b_grid.columns = 1 # List layout looks much cleaner in full screen
	b_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_grid.add_theme_constant_override("h_separation", 20)
	b_grid.add_theme_constant_override("v_separation", 10)
	b_scroll.add_child(b_grid)
	b_section.add_child(b_scroll)
	left_vbox.add_child(b_section)
	
	# Navigation Buttons
	var nav_box = HBoxContainer.new()
	nav_box.name = "NavBox"
	nav_box.add_theme_constant_override("separation", 16)
	
	var go_base = Button.new()
	go_base.text = "进行基地建设 (Base Build)"
	go_base.custom_minimum_size = Vector2(0, 40)
	go_base.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_base.pressed.connect(func():
		if current_det_planet:
			_open_base_construction(current_det_planet)
	)
	nav_box.add_child(go_base)
	
	var go_shipyard = Button.new()
	go_shipyard.text = "进行战舰制造 (Shipyard)"
	go_shipyard.custom_minimum_size = Vector2(0, 40)
	go_shipyard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_shipyard.pressed.connect(func():
		if current_det_planet:
			_open_shipyard(current_det_planet)
	)
	nav_box.add_child(go_shipyard)
	left_vbox.add_child(nav_box)
	
	body_hbox.add_child(left_column)
	
	# Right Column: Hangar & Fleet Management
	var right_column = PanelContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 1.0
	
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.08, 0.11, 0.16, 0.8)
	right_style.corner_radius_top_left = 6
	right_style.corner_radius_top_right = 6
	right_style.corner_radius_bottom_left = 6
	right_style.corner_radius_bottom_right = 6
	right_column.add_theme_stylebox_override("panel", right_style)
	
	var right_margin = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 20)
	right_margin.add_theme_constant_override("margin_top", 20)
	right_margin.add_theme_constant_override("margin_right", 20)
	right_margin.add_theme_constant_override("margin_bottom", 20)
	right_column.add_child(right_margin)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 16)
	right_margin.add_child(right_vbox)
	
	# Hangar section
	var h_section = VBoxContainer.new()
	h_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var h_title = Label.new()
	h_title.text = "机库储备 (Local Hangar):"
	h_title.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
	h_title.add_theme_font_size_override("font_size", 11)
	h_section.add_child(h_title)
	
	var h_scroll = ScrollContainer.new()
	h_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var h_list = VBoxContainer.new()
	h_list.name = "HangarList"
	h_scroll.add_child(h_list)
	h_section.add_child(h_scroll)
	
	var form_fleet_btn = Button.new()
	form_fleet_btn.name = "FormFleetBtn"
	form_fleet_btn.text = "编组舰队 (Form Fleet)"
	form_fleet_btn.custom_minimum_size = Vector2(0, 40)
	form_fleet_btn.pressed.connect(_on_form_fleet_clicked)
	h_section.add_child(form_fleet_btn)
	right_vbox.add_child(h_section)
	
	body_hbox.add_child(right_column)
	
	add_child(planet_details_container)
	
	# Explicitly set full screen bounds after adding to tree
	planet_details_container.anchor_left = 0.0
	planet_details_container.anchor_top = 0.0
	planet_details_container.anchor_right = 1.0
	planet_details_container.anchor_bottom = 1.0
	planet_details_container.offset_left = 0
	planet_details_container.offset_top = 0
	planet_details_container.offset_right = 0
	planet_details_container.offset_bottom = 0
	_resize_top_level_panels()
	
	# Close on right click anywhere on the page
	var close_pd = func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			planet_details_container.visible = false
			get_viewport().set_input_as_handled()
	planet_details_container.gui_input.connect(close_pd)

func _show_planet_details(planet: Planet) -> void:
	current_det_planet = planet
	_create_planet_details_ui()
	
	var vbox = planet_details_container
	var title = vbox.find_child("Title", true, false) as Label
	title.text = "星球详情 - " + planet.planet_name
	
	var info_lbl = vbox.find_child("OwnerInfo", true, false) as Label
	info_lbl.text = "控制势力: " + NetworkManager.get_faction_display_name(planet.owner_name)
	
	# Update Buildings Grid
	var b_grid = vbox.find_child("BuildingsGrid", true, false) as GridContainer
	for child in b_grid.get_children():
		child.queue_free()
		
	var names_map = {
		"metal_mine": "金属矿场",
		"crystal_mine": "晶体矿场",
		"deuterium_synthesizer": "重氢合成器",
		"solar_power_plant": "太阳能电站",
		"shipyard": "太空造船厂"
	}
	var counts = {
		"metal_mine": 0,
		"crystal_mine": 0,
		"deuterium_synthesizer": 0,
		"solar_power_plant": 0,
		"shipyard": 0
	}
	for b in planet.buildings:
		var type = b.get("type", "empty")
		if counts.has(type):
			counts[type] += 1
			
	for b_id in ["metal_mine", "crystal_mine", "deuterium_synthesizer", "solar_power_plant", "shipyard"]:
		var count = counts.get(b_id, 0)
		var lvl = planet.get_building_total_level(b_id)
		if count > 0:
			var lbl = Label.new()
			lbl.text = " - %s: %d 个 (总等级: Lv.%d)" % [names_map.get(b_id, b_id), count, lvl]
			lbl.add_theme_font_size_override("font_size", 11)
			b_grid.add_child(lbl)
		
	# Update Hangar List
	var h_list = vbox.find_child("HangarList", true, false) as VBoxContainer
	for child in h_list.get_children():
		child.queue_free()
		
	var has_ships = false
	if planet.hangar.is_empty():
		var lbl = Label.new()
		lbl.text = "机库无空闲飞船"
		lbl.modulate = Color.GRAY
		lbl.add_theme_font_size_override("font_size", 11)
		h_list.add_child(lbl)
	else:
		for d_name in planet.hangar:
			var qty = planet.hangar[d_name]
			if qty > 0:
				var lbl = Label.new()
				lbl.text = " - %s x%d" % [d_name, qty]
				lbl.add_theme_font_size_override("font_size", 11)
				h_list.add_child(lbl)
				has_ships = true
		if not has_ships:
			var lbl = Label.new()
			lbl.text = "机库无空闲飞船"
			lbl.modulate = Color.GRAY
			lbl.add_theme_font_size_override("font_size", 11)
			h_list.add_child(lbl)
			
	# Check if system has any idle player ships
	var has_system_ships = false
	var parent_node: GalaxyNode = null
	for n_id in galaxy_manager.nodes:
		var n = galaxy_manager.nodes[n_id]
		if n.planets.has(planet):
			parent_node = n
			break
	if parent_node:
		for p in parent_node.planets:
			if NetworkManager.is_my_faction(p.owner_name):
				for d_name in p.hangar:
					if p.hangar[d_name] > 0:
						has_system_ships = true
						break
			if has_system_ships:
				break

	# Update form fleet and navigation button visibility
	var form_fleet_btn = vbox.find_child("FormFleetBtn", true, false) as Button
	if form_fleet_btn:
		form_fleet_btn.visible = NetworkManager.is_my_faction(planet.owner_name)
		form_fleet_btn.disabled = (not has_system_ships)
		
	var nav_box = vbox.find_child("NavBox", true, false) as HBoxContainer
	if nav_box:
		nav_box.visible = NetworkManager.is_my_faction(planet.owner_name)
		
	planet_details_container.visible = true

func _create_form_fleet_ui() -> void:
	if form_fleet_window:
		return
		
	form_fleet_container = CenterContainer.new()
	form_fleet_container.top_level = true
	form_fleet_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	form_fleet_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	form_fleet_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	form_fleet_container.mouse_filter = Control.MOUSE_FILTER_STOP
	form_fleet_container.visible = false
	
	form_fleet_window = PanelContainer.new()
	form_fleet_window.custom_minimum_size = Vector2(600, 420)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.20, 0.95) # Premium deep space dark blue
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.85, 0.95, 0.8) # Glowing neon cyan
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	form_fleet_window.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_child(vbox)
	form_fleet_window.add_child(margin)
	
	# Title Header HBox with an obvious close Button
	var header_hbox = HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title = Label.new()
	title.text = "编组新舰队 (Form Fleet)"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = " X "
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var cls_normal = StyleBoxFlat.new()
	cls_normal.bg_color = Color(0, 0, 0, 0)
	cls_normal.border_width_left = 1
	cls_normal.border_width_top = 1
	cls_normal.border_width_right = 1
	cls_normal.border_width_bottom = 1
	cls_normal.border_color = Color(0.6, 0.7, 0.8, 0.2)
	cls_normal.corner_radius_top_left = 3
	cls_normal.corner_radius_top_right = 3
	cls_normal.corner_radius_bottom_left = 3
	cls_normal.corner_radius_bottom_right = 3
	close_btn.add_theme_stylebox_override("normal", cls_normal)
	
	var cls_hover = StyleBoxFlat.new()
	cls_hover.bg_color = Color(0.4, 0.1, 0.15, 0.8)
	cls_hover.border_width_left = 1
	cls_hover.border_width_top = 1
	cls_hover.border_width_right = 1
	cls_hover.border_width_bottom = 1
	cls_hover.border_color = Color(0.9, 0.2, 0.3, 0.8)
	cls_hover.corner_radius_top_left = 3
	cls_hover.corner_radius_top_right = 3
	cls_hover.corner_radius_bottom_left = 3
	cls_hover.corner_radius_bottom_right = 3
	close_btn.add_theme_stylebox_override("hover", cls_hover)
	
	close_btn.pressed.connect(func(): form_fleet_container.visible = false)
	header_hbox.add_child(close_btn)
	vbox.add_child(header_hbox)
	
	# Fleet name input
	var name_box = HBoxContainer.new()
	name_box.add_theme_constant_override("separation", 10)
	var name_lbl = Label.new()
	name_lbl.text = "舰队名称:"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_box.add_child(name_lbl)
	
	var name_input = LineEdit.new()
	name_input.name = "FleetNameInput"
	name_input.placeholder_text = "输入舰队名称..."
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(name_input)
	vbox.add_child(name_box)
	
	# Ship list selection scroll
	var s_title = Label.new()
	s_title.text = "选择要编入的飞船数量:"
	s_title.add_theme_font_size_override("font_size", 11)
	s_title.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
	vbox.add_child(s_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list = VBoxContainer.new()
	list.name = "SelectShipList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	vbox.add_child(scroll)
	
	# Action buttons
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 15)
	
	var confirm = Button.new()
	confirm.text = "确认编队"
	confirm.custom_minimum_size = Vector2(0, 36)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_on_confirm_form_fleet)
	actions.add_child(confirm)
	
	var cancel = Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(0, 36)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): form_fleet_container.visible = false)
	actions.add_child(cancel)
	vbox.add_child(actions)
	
	# Custom visual styles for confirm & cancel buttons
	var confirm_style_normal = StyleBoxFlat.new()
	confirm_style_normal.bg_color = Color(0.0, 0.5, 0.6, 0.8) # neon cyan
	confirm_style_normal.border_width_left = 1
	confirm_style_normal.border_width_top = 1
	confirm_style_normal.border_width_right = 1
	confirm_style_normal.border_width_bottom = 1
	confirm_style_normal.border_color = Color(0.0, 0.9, 1.0, 1.0)
	confirm_style_normal.corner_radius_top_left = 4
	confirm_style_normal.corner_radius_top_right = 4
	confirm_style_normal.corner_radius_bottom_left = 4
	confirm_style_normal.corner_radius_bottom_right = 4
	confirm_style_normal.shadow_color = Color(0.0, 0.8, 0.9, 0.25)
	confirm_style_normal.shadow_size = 5
	
	var confirm_style_hover = StyleBoxFlat.new()
	confirm_style_hover.bg_color = Color(0.0, 0.65, 0.75, 0.9)
	confirm_style_hover.border_width_left = 1
	confirm_style_hover.border_width_top = 1
	confirm_style_hover.border_width_right = 1
	confirm_style_hover.border_width_bottom = 1
	confirm_style_hover.border_color = Color(0.3, 0.95, 1.0, 1.0)
	confirm_style_hover.corner_radius_top_left = 4
	confirm_style_hover.corner_radius_top_right = 4
	confirm_style_hover.corner_radius_bottom_left = 4
	confirm_style_hover.corner_radius_bottom_right = 4
	confirm_style_hover.shadow_color = Color(0.0, 0.8, 0.9, 0.4)
	confirm_style_hover.shadow_size = 8
	
	var confirm_style_pressed = StyleBoxFlat.new()
	confirm_style_pressed.bg_color = Color(0.0, 0.4, 0.5, 0.9)
	confirm_style_pressed.border_width_left = 1
	confirm_style_pressed.border_width_top = 1
	confirm_style_pressed.border_width_right = 1
	confirm_style_pressed.border_width_bottom = 1
	confirm_style_pressed.border_color = Color(0.0, 0.8, 0.9, 1.0)
	confirm_style_pressed.corner_radius_top_left = 4
	confirm_style_pressed.corner_radius_top_right = 4
	confirm_style_pressed.corner_radius_bottom_left = 4
	confirm_style_pressed.corner_radius_bottom_right = 4
	
	confirm.add_theme_stylebox_override("normal", confirm_style_normal)
	confirm.add_theme_stylebox_override("hover", confirm_style_hover)
	confirm.add_theme_stylebox_override("pressed", confirm_style_pressed)
	confirm.add_theme_color_override("font_color", Color(1, 1, 1))
	confirm.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var cancel_style_normal = StyleBoxFlat.new()
	cancel_style_normal.bg_color = Color(0.18, 0.1, 0.12, 0.8) # muted dark red
	cancel_style_normal.border_width_left = 1
	cancel_style_normal.border_width_top = 1
	cancel_style_normal.border_width_right = 1
	cancel_style_normal.border_width_bottom = 1
	cancel_style_normal.border_color = Color(0.7, 0.2, 0.3, 0.6)
	cancel_style_normal.corner_radius_top_left = 4
	cancel_style_normal.corner_radius_top_right = 4
	cancel_style_normal.corner_radius_bottom_left = 4
	cancel_style_normal.corner_radius_bottom_right = 4
	
	var cancel_style_hover = StyleBoxFlat.new()
	cancel_style_hover.bg_color = Color(0.24, 0.12, 0.15, 0.9)
	cancel_style_hover.border_width_left = 1
	cancel_style_hover.border_width_top = 1
	cancel_style_hover.border_width_right = 1
	cancel_style_hover.border_width_bottom = 1
	cancel_style_hover.border_color = Color(0.9, 0.3, 0.4, 0.9)
	cancel_style_hover.corner_radius_top_left = 4
	cancel_style_hover.corner_radius_top_right = 4
	cancel_style_hover.corner_radius_bottom_left = 4
	cancel_style_hover.corner_radius_bottom_right = 4
	
	var cancel_style_pressed = StyleBoxFlat.new()
	cancel_style_pressed.bg_color = Color(0.14, 0.08, 0.1, 0.9)
	cancel_style_pressed.border_width_left = 1
	cancel_style_pressed.border_width_top = 1
	cancel_style_pressed.border_width_right = 1
	cancel_style_pressed.border_width_bottom = 1
	cancel_style_pressed.border_color = Color(0.6, 0.15, 0.25, 0.9)
	cancel_style_pressed.corner_radius_top_left = 4
	cancel_style_pressed.corner_radius_top_right = 4
	cancel_style_pressed.corner_radius_bottom_left = 4
	cancel_style_pressed.corner_radius_bottom_right = 4
	
	cancel.add_theme_stylebox_override("normal", cancel_style_normal)
	cancel.add_theme_stylebox_override("hover", cancel_style_hover)
	cancel.add_theme_stylebox_override("pressed", cancel_style_pressed)
	cancel.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	cancel.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	form_fleet_container.add_child(form_fleet_window)
	add_child(form_fleet_container)
	_resize_top_level_panels()
	
	# Close on right click
	var close_ff = func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			form_fleet_container.visible = false
			get_viewport().set_input_as_handled()
	form_fleet_container.gui_input.connect(close_ff)
	form_fleet_window.gui_input.connect(close_ff)

func _on_form_fleet_clicked() -> void:
	if not current_det_planet:
		return
		
	_create_form_fleet_ui()
	form_fleet_spinboxes.clear()
	
	var vbox = form_fleet_window.get_child(0).get_child(0) as VBoxContainer
	var name_input = vbox.find_child("FleetNameInput", true, false) as LineEdit
	var base_system_name = current_det_planet.planet_name
	name_input.text = base_system_name + "第一分舰队"
	
	var list = vbox.find_child("SelectShipList", true, false) as VBoxContainer
	for child in list.get_children():
		child.queue_free()
		
	# Common styleboxes for quick buttons in the ship rows
	var qbtn_style_normal = StyleBoxFlat.new()
	qbtn_style_normal.bg_color = Color(0.12, 0.16, 0.24, 0.7)
	qbtn_style_normal.border_width_left = 1
	qbtn_style_normal.border_width_top = 1
	qbtn_style_normal.border_width_right = 1
	qbtn_style_normal.border_width_bottom = 1
	qbtn_style_normal.border_color = Color(0.0, 0.75, 0.85, 0.3)
	qbtn_style_normal.corner_radius_top_left = 3
	qbtn_style_normal.corner_radius_top_right = 3
	qbtn_style_normal.corner_radius_bottom_left = 3
	qbtn_style_normal.corner_radius_bottom_right = 3
	qbtn_style_normal.content_margin_left = 6
	qbtn_style_normal.content_margin_right = 6
	qbtn_style_normal.content_margin_top = 2
	qbtn_style_normal.content_margin_bottom = 2

	var qbtn_style_hover = StyleBoxFlat.new()
	qbtn_style_hover.bg_color = Color(0.15, 0.22, 0.32, 0.85)
	qbtn_style_hover.border_width_left = 1
	qbtn_style_hover.border_width_top = 1
	qbtn_style_hover.border_width_right = 1
	qbtn_style_hover.border_width_bottom = 1
	qbtn_style_hover.border_color = Color(0.0, 0.85, 0.95, 0.8)
	qbtn_style_hover.corner_radius_top_left = 3
	qbtn_style_hover.corner_radius_top_right = 3
	qbtn_style_hover.corner_radius_bottom_left = 3
	qbtn_style_hover.corner_radius_bottom_right = 3
	qbtn_style_hover.content_margin_left = 6
	qbtn_style_hover.content_margin_right = 6
	qbtn_style_hover.content_margin_top = 2
	qbtn_style_hover.content_margin_bottom = 2

	var qbtn_style_pressed = StyleBoxFlat.new()
	qbtn_style_pressed.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	qbtn_style_pressed.border_width_left = 1
	qbtn_style_pressed.border_width_top = 1
	qbtn_style_pressed.border_width_right = 1
	qbtn_style_pressed.border_width_bottom = 1
	qbtn_style_pressed.border_color = Color(0.0, 0.65, 0.75, 1.0)
	qbtn_style_pressed.corner_radius_top_left = 3
	qbtn_style_pressed.corner_radius_top_right = 3
	qbtn_style_pressed.corner_radius_bottom_left = 3
	qbtn_style_pressed.corner_radius_bottom_right = 3
	qbtn_style_pressed.content_margin_left = 6
	qbtn_style_pressed.content_margin_right = 6
	qbtn_style_pressed.content_margin_top = 2
	qbtn_style_pressed.content_margin_bottom = 2
		
	# Find parent node to pool hangars
	var parent_node: GalaxyNode = null
	for n_id in galaxy_manager.nodes:
		var n = galaxy_manager.nodes[n_id]
		if n.planets.has(current_det_planet):
			parent_node = n
			break
			
	var pooled_hangar = {}
	var pooled_designs = {}
	if parent_node:
		for p in parent_node.planets:
			if NetworkManager.is_my_faction(p.owner_name):
				for d_name in p.hangar:
					var qty = p.hangar[d_name]
					if qty > 0:
						pooled_hangar[d_name] = pooled_hangar.get(d_name, 0) + qty
						if p.designs.has(d_name):
							pooled_designs[d_name] = p.designs[d_name]

	for d_name in pooled_hangar:
		var qty = pooled_hangar[d_name]
		if qty > 0:
			# Create card panel container
			var card = PanelContainer.new()
			card.custom_minimum_size = Vector2(0, 75)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var card_style = StyleBoxFlat.new()
			card_style.bg_color = Color(0.1, 0.15, 0.25, 0.4)
			card_style.border_width_left = 1
			card_style.border_width_top = 1
			card_style.border_width_right = 1
			card_style.border_width_bottom = 1
			card_style.border_color = Color(0.0, 0.75, 0.85, 0.15)
			card_style.corner_radius_top_left = 4
			card_style.corner_radius_top_right = 4
			card_style.corner_radius_bottom_left = 4
			card_style.corner_radius_bottom_right = 4
			card_style.content_margin_left = 8
			card_style.content_margin_top = 8
			card_style.content_margin_right = 8
			card_style.content_margin_bottom = 8
			card.add_theme_stylebox_override("panel", card_style)
			
			var card_hbox = HBoxContainer.new()
			card_hbox.add_theme_constant_override("separation", 10)
			card.add_child(card_hbox)
			
			# Left: TextureRect (ship icon)
			var tex_rect = TextureRect.new()
			var hull_id = "frigate"
			if pooled_designs.has(d_name):
				var design = pooled_designs[d_name]
				if design:
					hull_id = design.hull_id
			else:
				var lower_name = d_name.to_lower()
				if "battleship" in lower_name:
					hull_id = "battleship"
				elif "cruiser" in lower_name:
					hull_id = "cruiser"
				elif "destroyer" in lower_name:
					hull_id = "destroyer"
			
			var icon_path = "res://assets/images/hulls/%s.png" % hull_id
			if ResourceLoader.exists(icon_path):
				tex_rect.texture = load(icon_path)
			
			tex_rect.custom_minimum_size = Vector2(54, 30)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			card_hbox.add_child(tex_rect)
			
			# Right: VBoxContainer for details
			var item_vbox = VBoxContainer.new()
			item_vbox.add_theme_constant_override("separation", 4)
			item_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			card_hbox.add_child(item_vbox)
			
			# Row 1: Label for design name & count
			var lbl = Label.new()
			lbl.text = "%s (可用: %d)" % [d_name, qty]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			item_vbox.add_child(lbl)
			
			# Row 2: HBoxContainer for sliders & buttons
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_vbox.add_child(row)
			
			var max_selectable = min(qty, 999)
			
			var slider = HSlider.new()
			slider.min_value = 0
			slider.max_value = max_selectable
			slider.value = 0
			slider.step = 1
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(slider)
			
			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = max_selectable
			spin.value = 0
			spin.step = 1
			spin.custom_minimum_size = Vector2(75, 24)
			spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(spin)
			
			# Sync bidirectionally
			slider.value_changed.connect(func(val):
				spin.value = val
			)
			spin.value_changed.connect(func(val):
				slider.value = val
			)
			
			# Quick buttons: -, +, max, clear
			var dec_btn = Button.new()
			dec_btn.text = "-"
			dec_btn.custom_minimum_size = Vector2(24, 24)
			dec_btn.add_theme_font_size_override("font_size", 10)
			dec_btn.add_theme_stylebox_override("normal", qbtn_style_normal)
			dec_btn.add_theme_stylebox_override("hover", qbtn_style_hover)
			dec_btn.add_theme_stylebox_override("pressed", qbtn_style_pressed)
			dec_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			dec_btn.pressed.connect(func():
				slider.value = max(0, slider.value - 1)
			)
			row.add_child(dec_btn)
			
			var inc_btn = Button.new()
			inc_btn.text = "+"
			inc_btn.custom_minimum_size = Vector2(24, 24)
			inc_btn.add_theme_font_size_override("font_size", 10)
			inc_btn.add_theme_stylebox_override("normal", qbtn_style_normal)
			inc_btn.add_theme_stylebox_override("hover", qbtn_style_hover)
			inc_btn.add_theme_stylebox_override("pressed", qbtn_style_pressed)
			inc_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			inc_btn.pressed.connect(func():
				slider.value = min(max_selectable, slider.value + 1)
			)
			row.add_child(inc_btn)
			
			var max_btn = Button.new()
			max_btn.text = "最大"
			max_btn.custom_minimum_size = Vector2(36, 24)
			max_btn.add_theme_font_size_override("font_size", 10)
			max_btn.add_theme_stylebox_override("normal", qbtn_style_normal)
			max_btn.add_theme_stylebox_override("hover", qbtn_style_hover)
			max_btn.add_theme_stylebox_override("pressed", qbtn_style_pressed)
			max_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			max_btn.pressed.connect(func():
				slider.value = max_selectable
			)
			row.add_child(max_btn)
			
			var clr_btn = Button.new()
			clr_btn.text = "清空"
			clr_btn.custom_minimum_size = Vector2(36, 24)
			clr_btn.add_theme_font_size_override("font_size", 10)
			clr_btn.add_theme_stylebox_override("normal", qbtn_style_normal)
			clr_btn.add_theme_stylebox_override("hover", qbtn_style_hover)
			clr_btn.add_theme_stylebox_override("pressed", qbtn_style_pressed)
			clr_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			clr_btn.pressed.connect(func():
				slider.value = 0
			)
			row.add_child(clr_btn)
			
			list.add_child(card)
			form_fleet_spinboxes[d_name] = spin
			
	form_fleet_container.visible = true

func _on_confirm_form_fleet() -> void:
	if not current_det_planet:
		return
		
	var vbox = form_fleet_window.get_child(0).get_child(0) as VBoxContainer
	var name_input = vbox.find_child("FleetNameInput", true, false) as LineEdit
	var fleet_name = name_input.text.strip_edges()
	if fleet_name.is_empty():
		fleet_name = current_det_planet.planet_name + "守备队"
		
	# Gather chosen ships
	var chosen_ships = {}
	var has_ships = false
	for d_name in form_fleet_spinboxes:
		var spin = form_fleet_spinboxes[d_name] as SpinBox
		var qty = int(spin.value)
		if qty > 0:
			chosen_ships[d_name] = qty
			has_ships = true
			
	if not has_ships:
		_write_log("* 错误: 编队中必须至少包含一艘飞船！")
		return
		
	# Find parent node
	var parent_node: GalaxyNode = null
	for n_id in galaxy_manager.nodes:
		var n = galaxy_manager.nodes[n_id]
		if n.planets.has(current_det_planet):
			parent_node = n
			break
			
	if not parent_node:
		push_error("Could not find parent node for planet: " + current_det_planet.planet_name)
		return
		
	if not NetworkManager.is_multiplayer_active():
		# Deduct ships from system's planets sequentially
		for d_name in chosen_ships:
			var qty_to_deduct = chosen_ships[d_name]
			for p in parent_node.planets:
				if NetworkManager.is_my_faction(p.owner_name) and p.hangar.has(d_name):
					var available = p.hangar[d_name]
					var deduct = min(available, qty_to_deduct)
					p.hangar[d_name] -= deduct
					qty_to_deduct -= deduct
					if p.hangar[d_name] <= 0:
						p.hangar.erase(d_name)
					if qty_to_deduct <= 0:
						break
			
		var new_fleet = Fleet.new(fleet_name)
		new_fleet.owner_name = "Player"
		
		# Add ships
		for d_name in chosen_ships:
			var qty = chosen_ships[d_name]
			var design_obj = null
			for p in parent_node.planets:
				if NetworkManager.is_my_faction(p.owner_name) and p.designs.has(d_name):
					design_obj = p.designs[d_name]
					break
			if design_obj:
				new_fleet.add_ships(design_obj, qty)
			else:
				var temp_design = ShipDesign.new(d_name, "frigate")
				new_fleet.add_ships(temp_design, qty)
				
		# Add to node
		parent_node.add_fleet(new_fleet)
		_write_log("[舰队编成]: 成功在 %s 编成新舰队: %s！" % [parent_node.node_name, fleet_name])
	else:
		NetworkManager.rpc_id(1, "server_request_form_fleet", current_det_planet.planet_id, fleet_name, chosen_ships)
		_write_log("[联机同步]: 已向服务器发送舰队编成请求。")
		
	# Close windows and refresh
	form_fleet_container.visible = false
	if planet_details_container != null:
		planet_details_container.visible = false
	_on_node_selected(selected_node_id)

func _on_fleet_dispatched(fleet: Fleet) -> void:
	if not galaxy_manager:
		return
	var dest_node = galaxy_manager.get_node_by_id(fleet.target_node_id)
	var origin_node = galaxy_manager.get_node_by_id(fleet.current_node_id)
	var dest_name = dest_node.node_name if dest_node else "未知"
	var origin_name = origin_node.node_name if origin_node else "未知"
	
	if NetworkManager.is_my_faction(fleet.owner_name):
		_write_log("[航行指令]: 派遣舰队从 %s 前往 %s (航程预计 %.1f 秒)" % [origin_name, dest_name, fleet.travel_total_time])
	elif dest_node and NetworkManager.is_my_faction(dest_node.owner_name):
		var enemy_name = NetworkManager.get_faction_display_name(fleet.owner_name)
		_write_log("⚠️ [红色警报]: 侦测到 %s 的舰队从 %s 出发前往您控制的 %s 星系，疑似发起攻击！" % [enemy_name, origin_name, dest_name])

func _on_fleet_arrived(fleet: Fleet, node: GalaxyNode) -> void:
	if NetworkManager.is_my_faction(fleet.owner_name):
		_write_log("[星际广播]: 您的舰队已抵达 %s 星系。" % node.node_name)
	elif NetworkManager.is_my_faction(node.owner_name):
		var enemy_name = NetworkManager.get_faction_display_name(fleet.owner_name)
		_write_log("⚠️ [防守警报]: %s 的舰队已抵达您控制的 %s 星系！" % [enemy_name, node.node_name])
		
	if selected_node_id == node.node_id:
		_on_node_selected(selected_node_id) # Refresh sidebar if arrived at current view

func _on_battle_occurred(report: Dictionary) -> void:
	var involves_player = NetworkManager.is_my_faction(report["attacker"]) or NetworkManager.is_my_faction(report["defender"])
	var attacker_name = NetworkManager.get_faction_display_name(report["attacker"])
	var defender_name = NetworkManager.get_faction_display_name(report["defender"])
	var system_name = report["system_name"]
	
	if involves_player:
		var flash_log = "\n=========================================\n"
		flash_log += "🔥 【遭遇战战报警报】 🔥\n"
		flash_log += "位置: %s 星系\n" % system_name
		flash_log += "红方 (进攻): %s  vs  蓝方 (防守): %s\n" % [attacker_name, defender_name]
		flash_log += "交战回合数: %d 回合\n" % report["logs"].size()
		
		# Show winner
		var winner_name = attacker_name if report["winner"] == "A" else defender_name
		if report["winner"] == "Draw":
			winner_name = "同归于尽 (平局)"
		flash_log += "👉 最终胜者: %s 👈\n" % winner_name
		
		if report["winner"] == "A":
			flash_log += "🚩 [星系易主]: %s 成功占领了 %s 星系！\n" % [attacker_name, system_name]
		elif report["winner"] == "B":
			flash_log += "🛡️ [防御成功]: %s 成功守住了 %s 星系！\n" % [defender_name, system_name]
			
		flash_log += "战后物资回收: 金属 %d, 晶体 %d, 重氢 %d\n" % [
			report["salvage"]["metal"],
			report["salvage"]["crystal"],
			report["salvage"]["deuterium"]
		]
		
		# Include quick combat log summary
		flash_log += "\n[精简回合记录]:\n"
		var combat_lines = report["logs"]
		if combat_lines.size() > 8:
			# Show first 3 and last 3 lines
			for i in range(min(4, combat_lines.size())):
				flash_log += "  " + combat_lines[i] + "\n"
			flash_log += "  ...... (省略中间战斗过程) ......\n"
			for i in range(combat_lines.size() - 4, combat_lines.size()):
				flash_log += "  " + combat_lines[i] + "\n"
		else:
			for line in combat_lines:
				flash_log += "  " + line + "\n"
				
		flash_log += "=========================================\n"
		_write_log(flash_log)
	else:
		# Concise 1-line summary for non-player battles (Attack / Occupy news)
		var log_msg = ""
		if report["winner"] == "A":
			log_msg = "⚔️ [战事广播]: %s 发起攻击并成功占领了 %s 星系（防守方: %s）！" % [attacker_name, system_name, defender_name]
		elif report["winner"] == "B":
			log_msg = "⚔️ [战事广播]: %s 试图攻击 %s 星系，但被 %s 成功击退！" % [attacker_name, system_name, defender_name]
		else:
			log_msg = "⚔️ [战事广播]: %s 与 %s 在 %s 星系发生激战，双方同归于尽！" % [attacker_name, defender_name, system_name]
		_write_log(log_msg)
	
	# Register active combat in NetworkManager
	var node_id = report.get("node_id", "")
	if node_id != "":
		# Flatten structured rounds to count total event queue size
		var events_count = 0
		for r in report.get("structured_rounds", []):
			events_count += r.get("events", []).size()
		var duration = 0.5 + events_count * 0.95 + 2.5
		
		NetworkManager.active_combats[node_id] = {
			"node_id": node_id,
			"system_name": report["system_name"],
			"report": report,
			"elapsed": 0.0,
			"duration": duration
		}
	
	# Refresh map selection
	_on_node_selected(selected_node_id)
	
	# Only show interactive combat animation view overlay if it involves player
	if involves_player:
		var was_popup_visible = false
		if system_popup_container and system_popup_container.visible:
			was_popup_visible = true
			system_popup_container.visible = false
			
		var combat_view_scene = preload("res://src/ui/combat_view_ui.tscn")
		var combat_view = combat_view_scene.instantiate()
		add_child(combat_view)
		combat_view.initialize(report, 0)
		
		combat_view.tree_exited.connect(func():
			if was_popup_visible and is_inside_tree():
				system_popup_container.visible = true
				_on_node_selected(selected_node_id, false)
		)

func _on_view_combat_pressed() -> void:
	if selected_node_id.is_empty():
		return
	if not NetworkManager.active_combats.has(selected_node_id):
		return
		
	var combat = NetworkManager.active_combats[selected_node_id]
	var report = combat["report"]
	var elapsed = combat["elapsed"]
	var current_event_index = int(max(0.0, elapsed - 0.5) / 0.95)
	
	var was_popup_visible = false
	if system_popup_container and system_popup_container.visible:
		was_popup_visible = true
		system_popup_container.visible = false
		
	var combat_view_scene = preload("res://src/ui/combat_view_ui.tscn")
	var combat_view = combat_view_scene.instantiate()
	add_child(combat_view)
	combat_view.initialize(report, current_event_index)
	
	combat_view.tree_exited.connect(func():
		if was_popup_visible and is_inside_tree():
			system_popup_container.visible = true
			_on_node_selected(selected_node_id, false)
	)

func _connect_galaxy_manager_signals() -> void:
	if not galaxy_manager:
		return
	if not galaxy_manager.fleet_dispatched.is_connected(_on_fleet_dispatched):
		galaxy_manager.fleet_dispatched.connect(_on_fleet_dispatched)
	if not galaxy_manager.fleet_arrived.is_connected(_on_fleet_arrived):
		galaxy_manager.fleet_arrived.connect(_on_fleet_arrived)
	if not galaxy_manager.battle_occurred.is_connected(_on_battle_occurred):
		galaxy_manager.battle_occurred.connect(_on_battle_occurred)
	if not galaxy_manager.planet_ship_completed.is_connected(_on_planet_ship_completed):
		galaxy_manager.planet_ship_completed.connect(_on_planet_ship_completed)

func _on_planet_ship_completed(planet: Planet, d_name: String) -> void:
	if NetworkManager.is_my_faction(planet.owner_name):
		_write_log("🔧 [造船厂广播]: 1 艘新造的 [%s] 已交付至 [%s] 的机库！" % [d_name, planet.planet_name])
	if planet_details_window and planet_details_window.visible and current_det_planet == planet:
		_show_planet_details(planet)

func _write_log(text: String) -> void:
	logs_text.text += "\n" + text
	
	# Simple auto-scroll
	var scroll = logs_text.get_parent() as ScrollContainer
	if scroll and is_inside_tree():
		# Defer to wait for label size updates
		get_tree().process_frame.connect(func():
			scroll.scroll_vertical = int(logs_text.size.y)
		, CONNECT_ONE_SHOT)

func _setup_dynamic_popups() -> void:
	# Remove 20px offsets from MainLayout to make star map fill the entire screen (tiled fullscreen)
	$MainLayout.offset_left = 0
	$MainLayout.offset_top = 0
	$MainLayout.offset_right = 0
	$MainLayout.offset_bottom = 0
	
	# Override MapContainer stylebox to empty to remove the grey "black box" borders
	var empty_style = StyleBoxEmpty.new()
	$MainLayout/MapContainer.add_theme_stylebox_override("panel", empty_style)
	$MainLayout/MapContainer.clip_contents = true

	# 1. Create console overlay at the bottom of MapContainer
	console_overlay = PanelContainer.new()
	console_overlay.custom_minimum_size = Vector2(0, 130)
	console_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.06, 0.08, 0.12, 0.8)
	c_style.border_width_left = 1
	c_style.border_width_top = 1
	c_style.border_width_right = 1
	c_style.border_width_bottom = 1
	c_style.border_color = Color(0.0, 0.75, 0.85, 0.4)
	c_style.corner_radius_top_left = 8
	c_style.corner_radius_top_right = 8
	c_style.corner_radius_bottom_left = 8
	c_style.corner_radius_bottom_right = 8
	c_style.shadow_color = Color(0.0, 0.75, 0.85, 0.1)
	c_style.shadow_size = 6
	console_overlay.add_theme_stylebox_override("panel", c_style)
	
	# Move ConsoleBox from RightPanel to console overlay
	var console_box = $MainLayout/RightPanel/ConsoleBox
	$MainLayout/RightPanel.remove_child(console_box)
	_clean_and_style_hud_header(console_box, "星际广播与战报 (Combat Broadcast)")
	
	# Margin around console box inside overlay
	var c_margin = MarginContainer.new()
	c_margin.add_theme_constant_override("margin_left", 10)
	c_margin.add_theme_constant_override("margin_top", 5)
	c_margin.add_theme_constant_override("margin_right", 10)
	c_margin.add_theme_constant_override("margin_bottom", 10)
	
	console_overlay.add_child(console_box)
	c_margin.add_child(console_overlay)
	
	# Create a VBox to hold MapDraw and ConsoleOverlay vertically inside MapContainer
	var map_container = $MainLayout/MapContainer
	var map_vbox = VBoxContainer.new()
	map_vbox.add_theme_constant_override("separation", 0)
	
	var map_draw_node = $MainLayout/MapContainer/MapDraw
	map_container.remove_child(map_draw_node)
	map_draw_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	map_vbox.add_child(map_draw_node)
	map_vbox.add_child(c_margin)
	map_container.add_child(map_vbox)
	
	# 2. Create the full-screen System Details Panel
	system_popup_container = PanelContainer.new()
	system_popup_container.top_level = true
	system_popup_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	system_popup_container.anchor_left = 0.0
	system_popup_container.anchor_top = 0.0
	system_popup_container.anchor_right = 1.0
	system_popup_container.anchor_bottom = 1.0
	system_popup_container.offset_left = 0
	system_popup_container.offset_top = 0
	system_popup_container.offset_right = 0
	system_popup_container.offset_bottom = 0
	system_popup_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	system_popup_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	system_popup_container.mouse_filter = Control.MOUSE_FILTER_STOP
	system_popup_container.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 1.0) # Dark sci-fi backdrop
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.0, 0.75, 0.85, 0.6) # Cyan accent border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	system_popup_container.add_theme_stylebox_override("panel", style)
	
	system_popup = PanelContainer.new()
	system_popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_popup.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var transparent_style = StyleBoxEmpty.new()
	system_popup.add_theme_stylebox_override("panel", transparent_style)
	
	var popup_margin = MarginContainer.new()
	popup_margin.add_theme_constant_override("margin_left", 20)
	popup_margin.add_theme_constant_override("margin_top", 20)
	popup_margin.add_theme_constant_override("margin_right", 20)
	popup_margin.add_theme_constant_override("margin_bottom", 20)
	system_popup.add_child(popup_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	popup_margin.add_child(main_vbox)
	
	# Title bar with Back button
	var title_bar = HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 20)
	
	var close_btn = Button.new()
	close_btn.text = " ⬅ 返回星区图 "
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.pressed.connect(func(): system_popup_container.visible = false)
	_style_action_button(close_btn, Color(0.0, 0.75, 0.85))
	title_bar.add_child(close_btn)
	
	var title_lbl = Label.new()
	title_lbl.name = "PopupTitle"
	title_lbl.text = "星系控制中心"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)
	
	set_birth_btn = Button.new()
	set_birth_btn.text = " 🚀 设置为出生位置 "
	set_birth_btn.custom_minimum_size = Vector2(180, 40)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.0, 0.45, 0.55, 0.9)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.0, 0.85, 1.0, 0.8)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.0, 0.55, 0.65, 0.95)
	
	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	btn_disabled.border_color = Color(0.4, 0.4, 0.4, 0.5)
	
	set_birth_btn.add_theme_stylebox_override("normal", btn_style)
	set_birth_btn.add_theme_stylebox_override("hover", btn_hover)
	set_birth_btn.add_theme_stylebox_override("disabled", btn_disabled)
	set_birth_btn.add_theme_color_override("font_color", Color.WHITE)
	set_birth_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	
	set_birth_btn.pressed.connect(_on_set_birth_pressed)
	set_birth_btn.visible = false
	title_bar.add_child(set_birth_btn)
	
	view_combat_btn = Button.new()
	view_combat_btn.text = " ⚔️ 正在交战 (继续查看) "
	view_combat_btn.custom_minimum_size = Vector2(180, 40)
	
	var btn_style_combat = StyleBoxFlat.new()
	btn_style_combat.bg_color = Color(0.7, 0.2, 0.2, 0.9)
	btn_style_combat.border_width_left = 2
	btn_style_combat.border_width_top = 2
	btn_style_combat.border_width_right = 2
	btn_style_combat.border_width_bottom = 2
	btn_style_combat.border_color = Color(1.0, 0.4, 0.4, 0.8)
	btn_style_combat.corner_radius_top_left = 6
	btn_style_combat.corner_radius_top_right = 6
	btn_style_combat.corner_radius_bottom_left = 6
	btn_style_combat.corner_radius_bottom_right = 6
	
	var btn_hover_combat = btn_style_combat.duplicate()
	btn_hover_combat.bg_color = Color(0.8, 0.3, 0.3, 0.95)
	
	view_combat_btn.add_theme_stylebox_override("normal", btn_style_combat)
	view_combat_btn.add_theme_stylebox_override("hover", btn_hover_combat)
	view_combat_btn.add_theme_color_override("font_color", Color.WHITE)
	
	view_combat_btn.pressed.connect(_on_view_combat_pressed)
	view_combat_btn.visible = false
	title_bar.add_child(view_combat_btn)
	
	main_vbox.add_child(title_bar)
	
	# Horizontal columns layout inside popup
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 30)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)
	
	var details_panel = $MainLayout/RightPanel/DetailsPanel
	var control_box = $MainLayout/RightPanel/ControlBox
	
	$MainLayout/RightPanel.remove_child(details_panel)
	$MainLayout/RightPanel.remove_child(control_box)
	
	# Adjust separation inside inner containers to reduce minimum height
	details_panel.add_theme_constant_override("separation", 8)
	control_box.add_theme_constant_override("separation", 8)
	
	# Create a ScrollContainer for details_panel middle contents to prevent vertical overflow
	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var left_scroll_vbox = VBoxContainer.new()
	left_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll_vbox.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left_scroll_vbox)
	
	# Reparent details contents (excluding header/title which we clean up)
	var scroll_nodes = [
		details_panel.get_node("InfoBox"),
		planets_header,
		planets_list,
		details_panel.get_node("FleetsHeader"),
		details_panel.get_node("FleetsScroll"),
		unassigned_header,
		unassigned_list
	]
	for snode in scroll_nodes:
		if snode:
			snode.get_parent().remove_child(snode)
			left_scroll_vbox.add_child(snode)
			
	# Clean and style header
	_clean_and_style_hud_header(details_panel, "星系详情 (Star System)", true, auto_manage_panel)
	_clean_and_style_hud_header(control_box, "航行指令 (Navigation Command)")
	
	# Add the scroll container to details_panel
	details_panel.add_child(left_scroll)
	
	var f_scroll = fleets_list.get_parent() as ScrollContainer
	if f_scroll:
		f_scroll.custom_minimum_size = Vector2(0, 80)
	
	# Distribute columns evenly using PanelContainers
	var left_col_panel = PanelContainer.new()
	left_col_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var col_style = StyleBoxFlat.new()
	col_style.bg_color = Color(0.06, 0.08, 0.12, 0.8) # Premium translucent deep blue background
	col_style.border_width_left = 1
	col_style.border_width_top = 1
	col_style.border_width_right = 1
	col_style.border_width_bottom = 1
	col_style.border_color = Color(0.0, 0.75, 0.85, 0.4)
	col_style.corner_radius_top_left = 8
	col_style.corner_radius_top_right = 8
	col_style.corner_radius_bottom_left = 8
	col_style.corner_radius_bottom_right = 8
	col_style.shadow_color = Color(0.0, 0.75, 0.85, 0.1)
	col_style.shadow_size = 6
	
	left_col_panel.add_theme_stylebox_override("panel", col_style)
	
	var left_margin = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 12)
	left_margin.add_theme_constant_override("margin_top", 12)
	left_margin.add_theme_constant_override("margin_right", 12)
	left_margin.add_theme_constant_override("margin_bottom", 12)
	left_col_panel.add_child(left_margin)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 15)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left_vbox)
	
	# Make sure details_panel itself takes the full container size
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(details_panel)
	
	# Add the relocated control_box (Navigation Command) at the bottom of Left Column
	control_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_box.size_flags_vertical = Control.SIZE_SHRINK_END
	left_vbox.add_child(control_box)
	
	var right_col_panel = PanelContainer.new()
	right_col_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col_panel.add_theme_stylebox_override("panel", col_style)
	
	var right_margin = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	right_col_panel.add_child(right_margin)
	
	# Construct the Right-Side selected planet details panel
	planet_details_panel = VBoxContainer.new()
	planet_details_panel.add_theme_constant_override("separation", 10)
	planet_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_child(planet_details_panel)
	
	# Planet management title block (clean text Label + HSeparator)
	var p_title_lbl = Label.new()
	p_title_lbl.text = "星球管理 (Planet Management)"
	p_title_lbl.add_theme_font_size_override("font_size", 12)
	p_title_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	p_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	p_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	planet_details_panel.add_child(p_title_lbl)
	
	var p_sep = HSeparator.new()
	var p_sep_style = StyleBoxLine.new()
	p_sep_style.color = Color(0.0, 0.75, 0.85, 0.3)
	p_sep_style.grow_begin = 4.0
	p_sep_style.grow_end = 4.0
	p_sep.add_theme_stylebox_override("line", p_sep_style)
	planet_details_panel.add_child(p_sep)
	
	# ScrollContainer for the middle contents (Name, Owner, Yields, Infrastructure, Queue)
	var details_scroll = ScrollContainer.new()
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	planet_details_panel.add_child(details_scroll)
	
	var details_scroll_vbox = VBoxContainer.new()
	details_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll_vbox.add_theme_constant_override("separation", 12)
	details_scroll.add_child(details_scroll_vbox)
	
	# Planet Name
	planet_name_lbl = Label.new()
	planet_name_lbl.text = "请选择星球"
	planet_name_lbl.add_theme_font_size_override("font_size", 14)
	planet_name_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	details_scroll_vbox.add_child(planet_name_lbl)
	
	# Planet Owner
	planet_owner_lbl = Label.new()
	planet_owner_lbl.text = "控制势力: -"
	planet_owner_lbl.add_theme_font_size_override("font_size", 11)
	details_scroll_vbox.add_child(planet_owner_lbl)
	
	# Resource Yields Block (Card)
	var yield_section = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.12, 0.18, 0.5)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.0, 0.75, 0.85, 0.25)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 10
	card_style.content_margin_top = 10
	card_style.content_margin_right = 10
	card_style.content_margin_bottom = 10
	yield_section.add_theme_stylebox_override("panel", card_style)
	
	var yield_vbox = VBoxContainer.new()
	yield_vbox.add_theme_constant_override("separation", 6)
	yield_section.add_child(yield_vbox)
	
	var yield_title = Label.new()
	yield_title.text = "资源产出 (Hourly Yield)"
	yield_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	yield_title.add_theme_font_size_override("font_size", 11)
	yield_vbox.add_child(yield_title)
	
	var yield_grid = GridContainer.new()
	yield_grid.columns = 3
	yield_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yield_grid.add_theme_constant_override("h_separation", 15)
	yield_grid.add_theme_constant_override("v_separation", 6)
	yield_vbox.add_child(yield_grid)
	
	# Metal Row
	var metal_icon = TextureRect.new()
	metal_icon.texture = load("res://assets/images/resources/metal.png")
	metal_icon.custom_minimum_size = Vector2(16, 16)
	metal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	metal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	metal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	yield_grid.add_child(metal_icon)
	
	planet_yield_metal_val = Label.new()
	planet_yield_metal_val.text = "金属矿砂: +0/小时"
	planet_yield_metal_val.add_theme_font_size_override("font_size", 11)
	planet_yield_metal_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_yield_metal_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yield_grid.add_child(planet_yield_metal_val)
	
	planet_yield_metal_lvl = Label.new()
	planet_yield_metal_lvl.text = "Lv.0"
	planet_yield_metal_lvl.add_theme_font_size_override("font_size", 10)
	planet_yield_metal_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	yield_grid.add_child(planet_yield_metal_lvl)
	
	# Crystal Row
	var crystal_icon = TextureRect.new()
	crystal_icon.texture = load("res://assets/images/resources/crystal.png")
	crystal_icon.custom_minimum_size = Vector2(16, 16)
	crystal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crystal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crystal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	yield_grid.add_child(crystal_icon)
	
	planet_yield_crystal_val = Label.new()
	planet_yield_crystal_val.text = "晶体矿脉: +0/小时"
	planet_yield_crystal_val.add_theme_font_size_override("font_size", 11)
	planet_yield_crystal_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_yield_crystal_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yield_grid.add_child(planet_yield_crystal_val)
	
	planet_yield_crystal_lvl = Label.new()
	planet_yield_crystal_lvl.text = "Lv.0"
	planet_yield_crystal_lvl.add_theme_font_size_override("font_size", 10)
	planet_yield_crystal_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	yield_grid.add_child(planet_yield_crystal_lvl)
	
	# Deuterium Row
	var deut_icon = TextureRect.new()
	deut_icon.texture = load("res://assets/images/resources/deuterium.png")
	deut_icon.custom_minimum_size = Vector2(16, 16)
	deut_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	deut_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	deut_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	yield_grid.add_child(deut_icon)
	
	planet_yield_deut_val = Label.new()
	planet_yield_deut_val.text = "重氢气体: +0/小时"
	planet_yield_deut_val.add_theme_font_size_override("font_size", 11)
	planet_yield_deut_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_yield_deut_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yield_grid.add_child(planet_yield_deut_val)
	
	planet_yield_deut_lvl = Label.new()
	planet_yield_deut_lvl.text = "Lv.0"
	planet_yield_deut_lvl.add_theme_font_size_override("font_size", 10)
	planet_yield_deut_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	yield_grid.add_child(planet_yield_deut_lvl)
	
	details_scroll_vbox.add_child(yield_section)
	
	# Buildings Summary Block (Card)
	var build_section = PanelContainer.new()
	build_section.add_theme_stylebox_override("panel", card_style)
	
	var build_vbox = VBoxContainer.new()
	build_vbox.add_theme_constant_override("separation", 6)
	build_section.add_child(build_vbox)
	
	var build_title = Label.new()
	build_title.text = "基础设施 (Infrastructure)"
	build_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	build_title.add_theme_font_size_override("font_size", 11)
	build_vbox.add_child(build_title)
	
	var build_grid = GridContainer.new()
	build_grid.columns = 3
	build_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_grid.add_theme_constant_override("h_separation", 15)
	build_grid.add_theme_constant_override("v_separation", 6)
	build_vbox.add_child(build_grid)
	
	# Metal Mine
	var b_metal_icon = TextureRect.new()
	b_metal_icon.texture = load("res://assets/images/buildings/metal_mine.png")
	b_metal_icon.custom_minimum_size = Vector2(16, 16)
	b_metal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b_metal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b_metal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_grid.add_child(b_metal_icon)
	
	planet_build_metal_val = Label.new()
	planet_build_metal_val.text = "金属采矿场: 0 个"
	planet_build_metal_val.add_theme_font_size_override("font_size", 11)
	planet_build_metal_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_build_metal_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_grid.add_child(planet_build_metal_val)
	
	planet_build_metal_lvl = Label.new()
	planet_build_metal_lvl.text = "Lv.0"
	planet_build_metal_lvl.add_theme_font_size_override("font_size", 10)
	planet_build_metal_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	build_grid.add_child(planet_build_metal_lvl)
	
	# Crystal Mine
	var b_crystal_icon = TextureRect.new()
	b_crystal_icon.texture = load("res://assets/images/buildings/crystal_mine.png")
	b_crystal_icon.custom_minimum_size = Vector2(16, 16)
	b_crystal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b_crystal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b_crystal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_grid.add_child(b_crystal_icon)
	
	planet_build_crystal_val = Label.new()
	planet_build_crystal_val.text = "晶体采矿场: 0 个"
	planet_build_crystal_val.add_theme_font_size_override("font_size", 11)
	planet_build_crystal_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_build_crystal_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_grid.add_child(planet_build_crystal_val)
	
	planet_build_crystal_lvl = Label.new()
	planet_build_crystal_lvl.text = "Lv.0"
	planet_build_crystal_lvl.add_theme_font_size_override("font_size", 10)
	planet_build_crystal_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	build_grid.add_child(planet_build_crystal_lvl)
	
	# Deuterium Synthesizer
	var b_deut_icon = TextureRect.new()
	b_deut_icon.texture = load("res://assets/images/buildings/deuterium_synthesizer.png")
	b_deut_icon.custom_minimum_size = Vector2(16, 16)
	b_deut_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b_deut_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b_deut_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_grid.add_child(b_deut_icon)
	
	planet_build_deut_val = Label.new()
	planet_build_deut_val.text = "重氢合成器: 0 个"
	planet_build_deut_val.add_theme_font_size_override("font_size", 11)
	planet_build_deut_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_build_deut_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_grid.add_child(planet_build_deut_val)
	
	planet_build_deut_lvl = Label.new()
	planet_build_deut_lvl.text = "Lv.0"
	planet_build_deut_lvl.add_theme_font_size_override("font_size", 10)
	planet_build_deut_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	build_grid.add_child(planet_build_deut_lvl)
	
	# Solar Power Plant
	var b_solar_icon = TextureRect.new()
	b_solar_icon.texture = load("res://assets/images/buildings/solar_power_plant.png")
	b_solar_icon.custom_minimum_size = Vector2(16, 16)
	b_solar_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b_solar_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b_solar_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_grid.add_child(b_solar_icon)
	
	planet_build_solar_val = Label.new()
	planet_build_solar_val.text = "太阳能电站: 0 个"
	planet_build_solar_val.add_theme_font_size_override("font_size", 11)
	planet_build_solar_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_build_solar_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_grid.add_child(planet_build_solar_val)
	
	planet_build_solar_lvl = Label.new()
	planet_build_solar_lvl.text = "Lv.0"
	planet_build_solar_lvl.add_theme_font_size_override("font_size", 10)
	planet_build_solar_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	build_grid.add_child(planet_build_solar_lvl)
	
	# Space Shipyard
	var b_shipyard_icon = TextureRect.new()
	b_shipyard_icon.texture = load("res://assets/images/buildings/shipyard.png")
	b_shipyard_icon.custom_minimum_size = Vector2(16, 16)
	b_shipyard_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b_shipyard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b_shipyard_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_grid.add_child(b_shipyard_icon)
	
	planet_build_shipyard_val = Label.new()
	planet_build_shipyard_val.text = "太空造船厂: 0 个"
	planet_build_shipyard_val.add_theme_font_size_override("font_size", 11)
	planet_build_shipyard_val.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	planet_build_shipyard_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_grid.add_child(planet_build_shipyard_val)
	
	planet_build_shipyard_lvl = Label.new()
	planet_build_shipyard_lvl.text = "Lv.0"
	planet_build_shipyard_lvl.add_theme_font_size_override("font_size", 10)
	planet_build_shipyard_lvl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	build_grid.add_child(planet_build_shipyard_lvl)
	
	details_scroll_vbox.add_child(build_section)
	
	# Upgrade Queue Progress Block
	var queue_section = VBoxContainer.new()
	queue_section.add_theme_constant_override("separation", 6)
	var queue_title = Label.new()
	queue_title.text = "建造队列 (Construction Queue):"
	queue_title.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
	queue_title.add_theme_font_size_override("font_size", 11)
	queue_section.add_child(queue_title)
	
	planet_upgrade_lbl = Label.new()
	planet_upgrade_lbl.text = "当前无施工项目"
	planet_upgrade_lbl.add_theme_font_size_override("font_size", 10)
	planet_upgrade_lbl.add_theme_color_override("font_color", Color.GRAY)
	queue_section.add_child(planet_upgrade_lbl)
	
	var progress_hbox = HBoxContainer.new()
	progress_hbox.add_theme_constant_override("separation", 10)
	
	planet_upgrade_bar = ProgressBar.new()
	planet_upgrade_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_upgrade_bar.custom_minimum_size = Vector2(0, 14)
	planet_upgrade_bar.show_percentage = false
	progress_hbox.add_child(planet_upgrade_bar)
	
	planet_upgrade_time_lbl = Label.new()
	planet_upgrade_time_lbl.text = "0.0s"
	planet_upgrade_time_lbl.add_theme_font_size_override("font_size", 10)
	progress_hbox.add_child(planet_upgrade_time_lbl)
	
	queue_section.add_child(progress_hbox)
	details_scroll_vbox.add_child(queue_section)
	
	# Action Buttons Box (Fixed at the bottom of planet_details_panel)
	planet_actions_box = HBoxContainer.new()
	planet_actions_box.add_theme_constant_override("separation", 10)
	
	var act_build = Button.new()
	act_build.name = "BtnBuild"
	act_build.text = " 进行建设 "
	act_build.custom_minimum_size = Vector2(0, 42)
	act_build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_build.pressed.connect(func():
		if system_selected_planet:
			galaxy_manager.selected_planet = system_selected_planet
			_open_base_construction(system_selected_planet)
	)
	planet_actions_box.add_child(act_build)
	
	var act_yard = Button.new()
	act_yard.name = "BtnYard"
	act_yard.text = " 战舰制造 "
	act_yard.custom_minimum_size = Vector2(0, 42)
	act_yard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_yard.pressed.connect(func():
		if system_selected_planet:
			galaxy_manager.selected_planet = system_selected_planet
			_open_shipyard(system_selected_planet)
	)
	planet_actions_box.add_child(act_yard)
	
	var act_fleet = Button.new()
	act_fleet.name = "BtnFleet"
	act_fleet.text = " 组建舰队 "
	act_fleet.custom_minimum_size = Vector2(0, 42)
	act_fleet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_fleet.pressed.connect(func():
		if system_selected_planet:
			_open_form_fleet(system_selected_planet)
	)
	planet_actions_box.add_child(act_fleet)
	
	_style_action_button(act_build, Color(0.85, 0.55, 0.15))
	_style_action_button(act_yard, Color(0.0, 0.75, 0.85))
	_style_action_button(act_fleet, Color(0.15, 0.8, 0.5))
	
	planet_details_panel.add_child(planet_actions_box)
	
	content_hbox.add_child(left_col_panel)
	content_hbox.add_child(right_col_panel)
	
	# Expand the fleets scroll list to fill the available space dynamically
	var fleets_scroll = fleets_list.get_parent() as ScrollContainer
	if fleets_scroll:
		fleets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Hide the empty RightPanel sidebar
	$MainLayout/RightPanel.visible = false
	
	system_popup_container.add_child(system_popup)
	add_child(system_popup_container)
	
	# Configure anchors for full-screen PanelContainer overlay
	system_popup_container.anchor_left = 0.0
	system_popup_container.anchor_top = 0.0
	system_popup_container.anchor_right = 1.0
	system_popup_container.anchor_bottom = 1.0
	system_popup_container.offset_left = 0
	system_popup_container.offset_top = 0
	system_popup_container.offset_right = 0
	system_popup_container.offset_bottom = 0
	_resize_top_level_panels()
	
	# Close on right click
	var close_sp = func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			system_popup_container.visible = false
			get_viewport().set_input_as_handled()
	system_popup_container.gui_input.connect(close_sp)
	system_popup.gui_input.connect(close_sp)

func _resize_top_level_panels() -> void:
	var vp_size = get_viewport_rect().size
	if system_popup_container:
		system_popup_container.size = vp_size
		system_popup_container.position = Vector2.ZERO
		system_popup_container.custom_minimum_size = vp_size
	if planet_details_container:
		planet_details_container.size = vp_size
		planet_details_container.position = Vector2.ZERO
		planet_details_container.custom_minimum_size = vp_size
	if form_fleet_container:
		form_fleet_container.size = vp_size
		form_fleet_container.position = Vector2.ZERO
		form_fleet_container.custom_minimum_size = vp_size
	if base_popup_container:
		base_popup_container.size = vp_size
		base_popup_container.position = Vector2.ZERO
		base_popup_container.custom_minimum_size = vp_size
	if shipyard_popup_container:
		shipyard_popup_container.size = vp_size
		shipyard_popup_container.position = Vector2.ZERO
		shipyard_popup_container.custom_minimum_size = vp_size
	if reassign_popup_container:
		reassign_popup_container.size = vp_size
		reassign_popup_container.position = Vector2.ZERO
		reassign_popup_container.custom_minimum_size = vp_size

func _open_base_construction(p_planet: Planet) -> void:
	if not base_popup_container:
		_create_base_popup_ui()
		
	current_build_planet = p_planet
	
	var resources = {}
	if NetworkManager.is_multiplayer_active():
		resources = NetworkManager.get_my_resources()
	else:
		resources = galaxy_manager.player_resources
		
	base_panel_instance.initialize(p_planet, resources)
	base_popup_container.visible = true
	_resize_top_level_panels()

func _open_shipyard(p_planet: Planet) -> void:
	if not shipyard_popup_container:
		_create_shipyard_popup_ui()
		
	current_build_planet = p_planet
	
	var resources = {}
	if NetworkManager.is_multiplayer_active():
		resources = NetworkManager.get_my_resources()
	else:
		resources = galaxy_manager.player_resources
		
	shipyard_panel_instance.initialize(p_planet, resources)
	shipyard_popup_container.visible = true
	_resize_top_level_panels()

func _create_base_popup_ui() -> void:
	if base_popup_container:
		return
		
	base_popup_container = PanelContainer.new()
	base_popup_container.top_level = true
	base_popup_container.anchor_left = 0.0
	base_popup_container.anchor_top = 0.0
	base_popup_container.anchor_right = 1.0
	base_popup_container.anchor_bottom = 1.0
	base_popup_container.offset_left = 0
	base_popup_container.offset_top = 0
	base_popup_container.offset_right = 0
	base_popup_container.offset_bottom = 0
	base_popup_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	base_popup_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	base_popup_container.mouse_filter = Control.MOUSE_FILTER_STOP
	base_popup_container.visible = false
	
	# Styling: Dark glassmorphic background with orange/gold accent border for base building
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.85, 0.65, 0.13, 0.7) # Gold/Orange accent
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	base_popup_container.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 20)
	base_popup_container.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	# Header with title and back button
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)
	
	var back_btn = Button.new()
	back_btn.text = " ⬅ 返回星球页面 "
	back_btn.custom_minimum_size = Vector2(140, 40)
	back_btn.pressed.connect(func(): base_popup_container.visible = false)
	header.add_child(back_btn)
	
	var title = Label.new()
	title.text = "基地建设管理 (Infrastructure)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.13))
	header.add_child(title)
	
	# Instantiate base UI scene
	var base_scene = preload("res://src/ui/planet_base_ui.tscn")
	base_panel_instance = base_scene.instantiate()
	base_panel_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_panel_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(base_panel_instance)
	
	add_child(base_popup_container)
	
	# Close on right click
	var close_bp = func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			base_popup_container.visible = false
			get_viewport().set_input_as_handled()
	base_popup_container.gui_input.connect(close_bp)
	base_panel_instance.gui_input.connect(close_bp)

func _create_shipyard_popup_ui() -> void:
	if shipyard_popup_container:
		return
		
	shipyard_popup_container = PanelContainer.new()
	shipyard_popup_container.top_level = true
	shipyard_popup_container.anchor_left = 0.0
	shipyard_popup_container.anchor_top = 0.0
	shipyard_popup_container.anchor_right = 1.0
	shipyard_popup_container.anchor_bottom = 1.0
	shipyard_popup_container.offset_left = 0
	shipyard_popup_container.offset_top = 0
	shipyard_popup_container.offset_right = 0
	shipyard_popup_container.offset_bottom = 0
	shipyard_popup_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shipyard_popup_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	shipyard_popup_container.mouse_filter = Control.MOUSE_FILTER_STOP
	shipyard_popup_container.visible = false
	
	# Styling: Dark glassmorphic background with cyan accent border for shipyard
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.0, 0.75, 0.85, 0.7) # Cyan accent
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	shipyard_popup_container.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 20)
	shipyard_popup_container.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	# Header with title and back button
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)
	
	var back_btn = Button.new()
	back_btn.text = " ⬅ 返回星球页面 "
	back_btn.custom_minimum_size = Vector2(140, 40)
	back_btn.pressed.connect(func(): shipyard_popup_container.visible = false)
	header.add_child(back_btn)
	
	var title = Label.new()
	title.text = "太空造船厂管理 (Shipyard)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
	header.add_child(title)
	
	# Instantiate shipyard UI scene
	var shipyard_scene = preload("res://src/ui/shipyard_ui.tscn")
	shipyard_panel_instance = shipyard_scene.instantiate()
	shipyard_panel_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shipyard_panel_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(shipyard_panel_instance)
	
	add_child(shipyard_popup_container)
	
	# Close on right click
	var close_sy = func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			shipyard_popup_container.visible = false
			get_viewport().set_input_as_handled()
	shipyard_popup_container.gui_input.connect(close_sy)
	shipyard_panel_instance.gui_input.connect(close_sy)

func _setup_birth_prompt_panel() -> void:
	if birth_prompt_panel:
		return
	
	birth_prompt_panel = PanelContainer.new()
	birth_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	birth_prompt_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.20, 0.95) # Premium deep sci-fi blue
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.75, 0.85, 0.8) # Glowing cyan border
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	birth_prompt_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 10)
	birth_prompt_panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)
	
	var label = Label.new()
	label.text = "🚀 【新手指引】请在星图中选择一个星系，并在控制中心面板中点击『设置为出生位置』开始游戏。"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	hbox.add_child(label)
	
	add_child(birth_prompt_panel)
	
	# Position at top center
	birth_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	birth_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	birth_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	birth_prompt_panel.offset_top = 115 # Below top bar and nav tabs
	birth_prompt_panel.offset_left = -300
	birth_prompt_panel.offset_right = 300
	birth_prompt_panel.custom_minimum_size = Vector2(600, 40)

func _update_birth_setup_ui() -> void:
	if not galaxy_manager:
		return
		
	var is_singleplayer = not NetworkManager.is_multiplayer_active()
	var needs_birth = is_singleplayer and galaxy_manager.singleplayer_home_node_id.is_empty()
	
	# Show/hide prompt panel
	if needs_birth:
		_setup_birth_prompt_panel()
		if birth_prompt_panel:
			birth_prompt_panel.visible = true
	else:
		if birth_prompt_panel:
			birth_prompt_panel.visible = false
			
	# Update "Set Birth" button visibility in details popup
	if set_birth_btn:
		set_birth_btn.visible = needs_birth
		if needs_birth:
			var node = galaxy_manager.get_node_by_id(selected_node_id)
			if node:
				if node.owner_name == "Enemy":
					set_birth_btn.disabled = true
					set_birth_btn.text = " 🚫 敌对星系不可选 "
				else:
					set_birth_btn.disabled = false
					set_birth_btn.text = " 🚀 设置为出生位置 "

func _on_set_birth_pressed() -> void:
	if not galaxy_manager or selected_node_id.is_empty():
		return
		
	var node = galaxy_manager.get_node_by_id(selected_node_id)
	if not node or node.owner_name == "Enemy":
		return
		
	# 1. Update ownership to Player
	node.owner_name = "Player"
	for p in node.planets:
		p.owner_name = "Player"
		
	# Set selected planet
	if not node.planets.is_empty():
		galaxy_manager.selected_planet = node.planets[0]
		
	# 2. Set the single player home node ID
	galaxy_manager.singleplayer_home_node_id = selected_node_id
	
	# 3. Seed starting fleet and other factions
	_seed_game_data(selected_node_id)
	
	# 4. Save game immediately
	var p = get_parent()
	while p and not p.has_method("save_game"):
		p = p.get_parent()
	if p:
		p.save_game()
		
	# 5. UI Updates
	_write_log("🎉 [基地建立]: 成功将 [%s] 设置为您的首发出生位置！" % node.node_name)
	system_popup_container.visible = false
	
	_on_node_selected(selected_node_id)
	_update_birth_setup_ui()
	map_draw.queue_redraw()

func _change_tab(tab_name: String) -> void:
	var p = get_parent()
	while p and not p.has_method("_on_tab_pressed"):
		p = p.get_parent()
	if p:
		p._on_tab_pressed(tab_name)
	else:
		push_error("[GalaxyMapUI] Could not find MainGameHub ancestor to change tab to: " + tab_name)

func is_any_popup_open() -> bool:
	return (
		(shipyard_popup_container != null and shipyard_popup_container.visible) or
		(base_popup_container != null and base_popup_container.visible) or
		(form_fleet_container != null and form_fleet_container.visible) or
		(planet_details_container != null and planet_details_container.visible) or
		(system_popup_container != null and system_popup_container.visible) or
		(reassign_popup_container != null and reassign_popup_container.visible)
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		# Priority order (innermost/topmost popups first)
		if reassign_popup_container != null and reassign_popup_container.visible:
			reassign_popup_container.visible = false
			get_viewport().set_input_as_handled()
			return
		if shipyard_popup_container != null and shipyard_popup_container.visible:
			shipyard_popup_container.visible = false
			get_viewport().set_input_as_handled()
			return
		if base_popup_container != null and base_popup_container.visible:
			base_popup_container.visible = false
			get_viewport().set_input_as_handled()
			return
		if form_fleet_container != null and form_fleet_container.visible:
			form_fleet_container.visible = false
			get_viewport().set_input_as_handled()
			return
		if planet_details_container != null and planet_details_container.visible:
			planet_details_container.visible = false
			get_viewport().set_input_as_handled()
			return
		if system_popup_container != null and system_popup_container.visible:
			system_popup_container.visible = false
			get_viewport().set_input_as_handled()
			return

func _open_form_fleet(p_planet: Planet) -> void:
	current_det_planet = p_planet
	_on_form_fleet_clicked()

func _get_planet_texture_path(p_planet: Planet) -> String:
	var val = abs(p_planet.planet_id.hash()) % 5
	return "res://assets/images/galaxy/planet_%d.png" % (val + 1)

func _style_action_button(btn: Button, color_base: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(color_base.r * 0.1, color_base.g * 0.1, color_base.b * 0.1, 0.6)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(color_base.r * 0.8, color_base.g * 0.8, color_base.b * 0.8, 0.8)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.shadow_color = Color(color_base.r, color_base.g, color_base.b, 0.15)
	style_normal.shadow_size = 4
	style_normal.content_margin_left = 10
	style_normal.content_margin_right = 10
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(color_base.r * 0.2, color_base.g * 0.2, color_base.b * 0.2, 0.8)
	style_hover.border_width_left = 1
	style_hover.border_width_top = 1
	style_hover.border_width_right = 1
	style_hover.border_width_bottom = 1
	style_hover.border_color = Color(color_base.r, color_base.g, color_base.b, 1.0)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	style_hover.shadow_color = Color(color_base.r, color_base.g, color_base.b, 0.3)
	style_hover.shadow_size = 6
	style_hover.content_margin_left = 10
	style_hover.content_margin_right = 10
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(color_base.r * 0.05, color_base.g * 0.05, color_base.b * 0.05, 0.9)
	style_pressed.border_width_left = 1
	style_pressed.border_width_top = 1
	style_pressed.border_width_right = 1
	style_pressed.border_width_bottom = 1
	style_pressed.border_color = Color(color_base.r * 0.9, color_base.g * 0.9, color_base.b * 0.9, 1.0)
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_left = 4
	style_pressed.corner_radius_bottom_right = 4
	style_pressed.content_margin_left = 10
	style_pressed.content_margin_right = 10
	
	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.12, 0.15, 0.2, 0.4)
	style_disabled.border_width_left = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_bottom = 1
	style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.3)
	style_disabled.corner_radius_top_left = 4
	style_disabled.corner_radius_top_right = 4
	style_disabled.corner_radius_bottom_left = 4
	style_disabled.corner_radius_bottom_right = 4
	style_disabled.shadow_size = 0
	style_disabled.content_margin_left = 10
	style_disabled.content_margin_right = 10
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _update_selected_planet_details_view() -> void:
	if not planet_details_panel:
		return
		
	var btn_build = planet_actions_box.get_node("BtnBuild") as Button
	var btn_yard = planet_actions_box.get_node("BtnYard") as Button
	var btn_fleet = planet_actions_box.get_node("BtnFleet") as Button
	
	if not system_selected_planet:
		planet_name_lbl.text = "请选择星球"
		planet_owner_lbl.text = "控制势力: -"
		planet_yield_metal_val.text = "金属矿砂: +0/小时"
		planet_yield_metal_lvl.text = "Lv.0"
		planet_yield_crystal_val.text = "晶体矿脉: +0/小时"
		planet_yield_crystal_lvl.text = "Lv.0"
		planet_yield_deut_val.text = "重氢气体: +0/小时"
		planet_yield_deut_lvl.text = "Lv.0"
		
		planet_build_shipyard_val.text = "太空造船厂: 0 个"
		planet_build_shipyard_lvl.text = "Lv.0"
		planet_build_solar_val.text = "太阳能电站: 0 个"
		planet_build_solar_lvl.text = "Lv.0"
		planet_build_metal_val.text = "金属采矿场: 0 个"
		planet_build_metal_lvl.text = "Lv.0"
		planet_build_crystal_val.text = "晶体采矿场: 0 个"
		planet_build_crystal_lvl.text = "Lv.0"
		planet_build_deut_val.text = "重氢合成器: 0 个"
		planet_build_deut_lvl.text = "Lv.0"
		planet_upgrade_lbl.text = "当前无施工项目"
		planet_upgrade_bar.value = 0
		planet_upgrade_time_lbl.text = "0.0s"
		
		btn_build.disabled = true
		btn_yard.disabled = true
		btn_fleet.disabled = true
		return
		
	var p = system_selected_planet
	
	var owner_name = p.owner_name
	var faction_display = NetworkManager.get_faction_display_name(owner_name)
	planet_name_lbl.text = p.planet_name
	planet_name_lbl.add_theme_color_override("font_color", NetworkManager.get_faction_color(owner_name))
	planet_owner_lbl.text = "控制势力: %s" % faction_display
	
	# Calculate counts of each building type
	var counts = {
		"shipyard": 0,
		"solar_power_plant": 0,
		"metal_mine": 0,
		"crystal_mine": 0,
		"deuterium_synthesizer": 0
	}
	for b in p.buildings:
		var type = b.get("type", "empty")
		if counts.has(type):
			counts[type] += 1
			
	var metal_lvl = p.get_building_total_level("metal_mine")
	var crystal_lvl = p.get_building_total_level("crystal_mine")
	var deut_lvl = p.get_building_total_level("deuterium_synthesizer")
	var solar_lvl = p.get_building_total_level("solar_power_plant")
	var shipyard_lvl = p.get_building_total_level("shipyard")
	
	var metal_yield = p.BASE_METAL_HOUR + (metal_lvl * 30.0)
	var crystal_yield = p.BASE_CRYSTAL_HOUR + (crystal_lvl * 20.0)
	var deut_yield = p.BASE_DEUTERIUM_HOUR + (deut_lvl * 10.0)
	
	planet_yield_metal_val.text = "金属矿砂: +%d/小时" % int(metal_yield)
	planet_yield_metal_lvl.text = "Lv.%d" % metal_lvl
	planet_yield_crystal_val.text = "晶体矿脉: +%d/小时" % int(crystal_yield)
	planet_yield_crystal_lvl.text = "Lv.%d" % crystal_lvl
	planet_yield_deut_val.text = "重氢气体: +%d/小时" % int(deut_yield)
	planet_yield_deut_lvl.text = "Lv.%d" % deut_lvl
	
	planet_build_shipyard_val.text = "太空造船厂: %d 个" % counts["shipyard"]
	planet_build_shipyard_lvl.text = "Lv.%d" % shipyard_lvl
	planet_build_solar_val.text = "太阳能电站: %d 个" % counts["solar_power_plant"]
	planet_build_solar_lvl.text = "Lv.%d" % solar_lvl
	planet_build_metal_val.text = "金属采矿场: %d 个" % counts["metal_mine"]
	planet_build_metal_lvl.text = "Lv.%d" % metal_lvl
	planet_build_crystal_val.text = "晶体采矿场: %d 个" % counts["crystal_mine"]
	planet_build_crystal_lvl.text = "Lv.%d" % crystal_lvl
	planet_build_deut_val.text = "重氢合成器: %d 个" % counts["deuterium_synthesizer"]
	planet_build_deut_lvl.text = "Lv.%d" % deut_lvl
	
	var active = p.active_upgrades[0] if not p.active_upgrades.is_empty() else {}
	if not active.is_empty():
		var b_id = active["building_id"]
		var b_name = "未知建筑"
		var names_map = {
			"metal_mine": "金属矿场",
			"crystal_mine": "晶体矿场",
			"deuterium_synthesizer": "重氢合成器",
			"solar_power_plant": "太阳能电站",
			"shipyard": "太空造船厂"
		}
		b_name = names_map.get(b_id, b_id)
		var time_left = active["time_remaining"]
		var total_time = active["total_time"]
		
		planet_upgrade_lbl.text = "%s 正在施工中..." % b_name
		planet_upgrade_bar.max_value = total_time
		planet_upgrade_bar.value = total_time - time_left
		planet_upgrade_time_lbl.text = "%.1fs" % time_left
	else:
		planet_upgrade_lbl.text = "当前无施工项目"
		planet_upgrade_bar.value = 0
		planet_upgrade_time_lbl.text = "0.0s"
		
	var is_mine = NetworkManager.is_my_faction(owner_name)
	btn_build.disabled = not is_mine
	
	# Find parent node
	var parent_node: GalaxyNode = null
	for n_id in galaxy_manager.nodes:
		var n = galaxy_manager.nodes[n_id]
		if n.planets.has(p):
			parent_node = n
			break
			
	# Sum shipyard levels across all planets in this system owned by the same owner
	var system_shipyard_lvl = 0
	if parent_node:
		for planet in parent_node.planets:
			if planet.owner_name == owner_name:
				system_shipyard_lvl += planet.get_building_total_level("shipyard")
				
	btn_yard.disabled = not is_mine or system_shipyard_lvl <= 0
	var has_system_ships = false
	if parent_node:
		for planet in parent_node.planets:
			if NetworkManager.is_my_faction(planet.owner_name):
				for d_name in planet.hangar:
					if planet.hangar[d_name] > 0:
						has_system_ships = true
						break
			if has_system_ships:
				break
	
	btn_fleet.disabled = not is_mine or not has_system_ships



func _create_reassign_popup_ui() -> void:
	if reassign_popup_container:
		return
		
	reassign_popup_container = CenterContainer.new()
	reassign_popup_container.top_level = true
	reassign_popup_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	reassign_popup_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	reassign_popup_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	reassign_popup_container.mouse_filter = Control.MOUSE_FILTER_STOP
	reassign_popup_container.visible = false
	
	reassign_popup_window = PanelContainer.new()
	reassign_popup_window.custom_minimum_size = Vector2(650, 450)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.20, 0.95) # Premium deep space dark blue
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.85, 0.95, 0.8) # Glowing neon cyan
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	reassign_popup_window.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_child(vbox)
	reassign_popup_window.add_child(margin)
	
	# Title Header HBox with an obvious close Button
	var header_hbox = HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title = Label.new()
	title.text = "选择调动舰队 (Reassign Fleets)"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = " X "
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var cls_normal = StyleBoxFlat.new()
	cls_normal.bg_color = Color(0, 0, 0, 0)
	cls_normal.border_width_left = 1
	cls_normal.border_width_top = 1
	cls_normal.border_width_right = 1
	cls_normal.border_width_bottom = 1
	cls_normal.border_color = Color(0.6, 0.7, 0.8, 0.2)
	cls_normal.corner_radius_top_left = 3
	cls_normal.corner_radius_top_right = 3
	cls_normal.corner_radius_bottom_left = 3
	cls_normal.corner_radius_bottom_right = 3
	close_btn.add_theme_stylebox_override("normal", cls_normal)
	
	var cls_hover = StyleBoxFlat.new()
	cls_hover.bg_color = Color(0.4, 0.1, 0.15, 0.8)
	cls_hover.border_width_left = 1
	cls_hover.border_width_top = 1
	cls_hover.border_width_right = 1
	cls_hover.border_width_bottom = 1
	cls_hover.border_color = Color(0.9, 0.2, 0.3, 0.8)
	cls_hover.corner_radius_top_left = 3
	cls_hover.corner_radius_top_right = 3
	cls_hover.corner_radius_bottom_left = 3
	cls_hover.corner_radius_bottom_right = 3
	close_btn.add_theme_stylebox_override("hover", cls_hover)
	
	close_btn.pressed.connect(func(): reassign_popup_container.visible = false)
	header_hbox.add_child(close_btn)
	vbox.add_child(header_hbox)
	
	# Scroll area for cards
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	
	reassign_popup_list = VBoxContainer.new()
	reassign_popup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reassign_popup_list.add_theme_constant_override("separation", 10)
	scroll.add_child(reassign_popup_list)
	vbox.add_child(scroll)
	
	# Action buttons
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 15)
	
	reassign_confirm_btn = Button.new()
	reassign_confirm_btn.text = "确认调动"
	reassign_confirm_btn.custom_minimum_size = Vector2(0, 36)
	reassign_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reassign_confirm_btn.pressed.connect(_on_confirm_reassign_popup)
	actions.add_child(reassign_confirm_btn)
	
	var cancel = Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(0, 36)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): reassign_popup_container.visible = false)
	actions.add_child(cancel)
	vbox.add_child(actions)
	
	# Button styling
	var confirm_style_normal = StyleBoxFlat.new()
	confirm_style_normal.bg_color = Color(0.0, 0.5, 0.6, 0.8) # neon cyan
	confirm_style_normal.border_width_left = 1
	confirm_style_normal.border_width_top = 1
	confirm_style_normal.border_width_right = 1
	confirm_style_normal.border_width_bottom = 1
	confirm_style_normal.border_color = Color(0.0, 0.9, 1.0, 1.0)
	confirm_style_normal.corner_radius_top_left = 4
	confirm_style_normal.corner_radius_top_right = 4
	confirm_style_normal.corner_radius_bottom_left = 4
	confirm_style_normal.corner_radius_bottom_right = 4
	confirm_style_normal.shadow_color = Color(0.0, 0.8, 0.9, 0.25)
	confirm_style_normal.shadow_size = 5
	
	var confirm_style_hover = StyleBoxFlat.new()
	confirm_style_hover.bg_color = Color(0.0, 0.65, 0.75, 0.9)
	confirm_style_hover.border_width_left = 1
	confirm_style_hover.border_width_top = 1
	confirm_style_hover.border_width_right = 1
	confirm_style_hover.border_width_bottom = 1
	confirm_style_hover.border_color = Color(0.3, 0.95, 1.0, 1.0)
	confirm_style_hover.corner_radius_top_left = 4
	confirm_style_hover.corner_radius_top_right = 4
	confirm_style_hover.corner_radius_bottom_left = 4
	confirm_style_hover.corner_radius_bottom_right = 4
	confirm_style_hover.shadow_color = Color(0.0, 0.8, 0.9, 0.4)
	confirm_style_hover.shadow_size = 8
	
	var confirm_style_pressed = StyleBoxFlat.new()
	confirm_style_pressed.bg_color = Color(0.0, 0.4, 0.5, 0.9)
	confirm_style_pressed.border_width_left = 1
	confirm_style_pressed.border_width_top = 1
	confirm_style_pressed.border_width_right = 1
	confirm_style_pressed.border_width_bottom = 1
	confirm_style_pressed.border_color = Color(0.0, 0.8, 0.9, 1.0)
	confirm_style_pressed.corner_radius_top_left = 4
	confirm_style_pressed.corner_radius_top_right = 4
	confirm_style_pressed.corner_radius_bottom_left = 4
	confirm_style_pressed.corner_radius_bottom_right = 4
	
	var confirm_style_disabled = StyleBoxFlat.new()
	confirm_style_disabled.bg_color = Color(0.12, 0.15, 0.2, 0.6)
	confirm_style_disabled.border_width_left = 1
	confirm_style_disabled.border_width_top = 1
	confirm_style_disabled.border_width_right = 1
	confirm_style_disabled.border_width_bottom = 1
	confirm_style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
	confirm_style_disabled.corner_radius_top_left = 4
	confirm_style_disabled.corner_radius_top_right = 4
	confirm_style_disabled.corner_radius_bottom_left = 4
	confirm_style_disabled.corner_radius_bottom_right = 4
	confirm_style_disabled.shadow_size = 0
	
	reassign_confirm_btn.add_theme_stylebox_override("normal", confirm_style_normal)
	reassign_confirm_btn.add_theme_stylebox_override("hover", confirm_style_hover)
	reassign_confirm_btn.add_theme_stylebox_override("pressed", confirm_style_pressed)
	reassign_confirm_btn.add_theme_stylebox_override("disabled", confirm_style_disabled)
	reassign_confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	reassign_confirm_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	reassign_confirm_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	reassign_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var cancel_style_normal = StyleBoxFlat.new()
	cancel_style_normal.bg_color = Color(0.18, 0.1, 0.12, 0.8) # muted dark red
	cancel_style_normal.border_width_left = 1
	cancel_style_normal.border_width_top = 1
	cancel_style_normal.border_width_right = 1
	cancel_style_normal.border_width_bottom = 1
	cancel_style_normal.border_color = Color(0.7, 0.2, 0.3, 0.6)
	cancel_style_normal.corner_radius_top_left = 4
	cancel_style_normal.corner_radius_top_right = 4
	cancel_style_normal.corner_radius_bottom_left = 4
	cancel_style_normal.corner_radius_bottom_right = 4
	
	var cancel_style_hover = StyleBoxFlat.new()
	cancel_style_hover.bg_color = Color(0.24, 0.12, 0.15, 0.9)
	cancel_style_hover.border_width_left = 1
	cancel_style_hover.border_width_top = 1
	cancel_style_hover.border_width_right = 1
	cancel_style_hover.border_width_bottom = 1
	cancel_style_hover.border_color = Color(0.9, 0.3, 0.4, 0.9)
	cancel_style_hover.corner_radius_top_left = 4
	cancel_style_hover.corner_radius_top_right = 4
	cancel_style_hover.corner_radius_bottom_left = 4
	cancel_style_hover.corner_radius_bottom_right = 4
	
	var cancel_style_pressed = StyleBoxFlat.new()
	cancel_style_pressed.bg_color = Color(0.14, 0.08, 0.1, 0.9)
	cancel_style_pressed.border_width_left = 1
	cancel_style_pressed.border_width_top = 1
	cancel_style_pressed.border_width_right = 1
	cancel_style_pressed.border_width_bottom = 1
	cancel_style_pressed.border_color = Color(0.6, 0.15, 0.25, 0.9)
	cancel_style_pressed.corner_radius_top_left = 4
	cancel_style_pressed.corner_radius_top_right = 4
	cancel_style_pressed.corner_radius_bottom_left = 4
	cancel_style_pressed.corner_radius_bottom_right = 4
	
	cancel.add_theme_stylebox_override("normal", cancel_style_normal)
	cancel.add_theme_stylebox_override("hover", cancel_style_hover)
	cancel.add_theme_stylebox_override("pressed", cancel_style_pressed)
	cancel.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	cancel.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	reassign_popup_container.add_child(reassign_popup_window)
	add_child(reassign_popup_container)
	_resize_top_level_panels()
	
	# Close on right click
	var close_rp = func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			reassign_popup_container.visible = false
			get_viewport().set_input_as_handled()
	reassign_popup_container.gui_input.connect(close_rp)
	reassign_popup_window.gui_input.connect(close_rp)

func _open_reassign_popup() -> void:
	_create_reassign_popup_ui()
	
	# Clear list
	for child in reassign_popup_list.get_children():
		child.queue_free()
		
	# Populate list
	var count = 0
	
	# Generate checkbox textures for high contrast
	var checked_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var unchecked_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	
	var border_color = Color(0.0, 0.85, 1.0, 1.0)
	var bg_color = Color(0.08, 0.12, 0.20, 1.0)
	var check_inner_color = Color(0.0, 0.9, 1.0, 1.0)
	
	for y in range(16):
		for x in range(16):
			var is_border = (x == 0 or x == 15 or y == 0 or y == 15)
			if is_border:
				checked_img.set_pixel(x, y, border_color)
				unchecked_img.set_pixel(x, y, border_color)
			else:
				checked_img.set_pixel(x, y, bg_color)
				unchecked_img.set_pixel(x, y, bg_color)
				
				# Inside check area
				if x >= 4 and x <= 11 and y >= 4 and y <= 11:
					checked_img.set_pixel(x, y, check_inner_color)
					
	var checked_tex = ImageTexture.create_from_image(checked_img)
	var unchecked_tex = ImageTexture.create_from_image(unchecked_img)
	
	# Styles setup
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.11, 0.16, 0.5)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.0, 0.75, 0.85, 0.2)
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	normal_style.content_margin_left = 12
	normal_style.content_margin_top = 10
	normal_style.content_margin_right = 12
	normal_style.content_margin_bottom = 10

	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.0, 0.15, 0.22, 0.75)
	selected_style.border_width_left = 2
	selected_style.border_width_top = 2
	selected_style.border_width_right = 2
	selected_style.border_width_bottom = 2
	selected_style.border_color = Color(0.0, 0.9, 1.0, 1.0) # glowing neon-cyan
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.corner_radius_bottom_left = 4
	selected_style.corner_radius_bottom_right = 4
	selected_style.shadow_color = Color(0.0, 0.9, 1.0, 0.25)
	selected_style.shadow_size = 6
	selected_style.content_margin_left = 12
	selected_style.content_margin_top = 10
	selected_style.content_margin_right = 12
	selected_style.content_margin_bottom = 10

	for other_id in galaxy_manager.nodes:
		if other_id == selected_node_id:
			continue
		var other_node = galaxy_manager.get_node_by_id(other_id)
		if other_node:
			for fleet in other_node.stationed_fleets:
				if NetworkManager.is_my_faction(fleet.owner_name) and not fleet.is_moving:
					# Create card PanelContainer
					var card = PanelContainer.new()
					card.custom_minimum_size = Vector2(0, 60)
					card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					card.add_theme_stylebox_override("panel", normal_style)
					card.mouse_filter = Control.MOUSE_FILTER_STOP
					card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					
					var card_hbox = HBoxContainer.new()
					card_hbox.add_theme_constant_override("separation", 15)
					card.add_child(card_hbox)
					
					# Checkbox for multiselect
					var cb = CheckBox.new()
					cb.set_meta("fleet", fleet)
					cb.set_meta("origin_id", other_id)
					cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					cb.custom_minimum_size = Vector2(24, 24)
					cb.add_theme_icon_override("checked", checked_tex)
					cb.add_theme_icon_override("unchecked", unchecked_tex)
					cb.add_theme_icon_override("checked_disabled", checked_tex)
					cb.add_theme_icon_override("unchecked_disabled", unchecked_tex)
					card_hbox.add_child(cb)
					
					# Details VBox
					var det_vbox = VBoxContainer.new()
					det_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					det_vbox.add_theme_constant_override("separation", 2)
					card_hbox.add_child(det_vbox)
					
					# Title (fleet name + source star system)
					var title_lbl = Label.new()
					title_lbl.text = "%s (来自: %s)" % [fleet.fleet_name, other_node.node_name]
					title_lbl.add_theme_font_size_override("font_size", 12)
					title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
					det_vbox.add_child(title_lbl)
					
					# Ship counts details
					var ships_desc = []
					for d_name in fleet.ships:
						ships_desc.append("%s x%d" % [d_name, fleet.ships[d_name]])
					var details_lbl = Label.new()
					details_lbl.text = "编制: %s" % (", ".join(ships_desc) if not ships_desc.is_empty() else "无战舰")
					details_lbl.add_theme_font_size_override("font_size", 10)
					details_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
					det_vbox.add_child(details_lbl)
					
					# Connect toggle to style updates
					cb.toggled.connect(func(pressed):
						if pressed:
							card.add_theme_stylebox_override("panel", selected_style)
						else:
							card.add_theme_stylebox_override("panel", normal_style)
						_update_reassign_popup_confirm_button_state()
					)
					
					# Allow clicking anywhere on the card to toggle selection
					card.gui_input.connect(func(event):
						if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
							cb.button_pressed = not cb.button_pressed
							get_viewport().set_input_as_handled()
					)
					
					reassign_popup_list.add_child(card)
					count += 1
					
	if count == 0:
		var no_fleet_lbl = Label.new()
		no_fleet_lbl.text = "己方其他星系无空闲舰队可供调动。"
		no_fleet_lbl.add_theme_font_size_override("font_size", 12)
		no_fleet_lbl.modulate = Color.GRAY
		reassign_popup_list.add_child(no_fleet_lbl)
		
	_update_reassign_popup_confirm_button_state()
	reassign_popup_container.visible = true
	_resize_top_level_panels()

func _update_reassign_popup_confirm_button_state() -> void:
	if not reassign_popup_container or not reassign_popup_container.visible:
		return
	var any_checked = false
	for card in reassign_popup_list.get_children():
		if card is PanelContainer:
			var hbox = card.get_child(0)
			if hbox and hbox is HBoxContainer:
				var cb = hbox.get_child(0)
				if cb and cb is CheckBox and cb.button_pressed:
					any_checked = true
					break
	reassign_confirm_btn.disabled = not any_checked

func _on_confirm_reassign_popup() -> void:
	var target_node = galaxy_manager.get_node_by_id(selected_node_id)
	if not target_node:
		return
		
	var selected_items = []
	for card in reassign_popup_list.get_children():
		if card is PanelContainer:
			var hbox = card.get_child(0)
			if hbox and hbox is HBoxContainer:
				var cb = hbox.get_child(0)
				if cb and cb is CheckBox and cb.button_pressed:
					selected_items.append({
						"fleet": cb.get_meta("fleet") as Fleet,
						"origin_id": cb.get_meta("origin_id") as String
					})
					
	if selected_items.is_empty():
		_write_log("* 错误: 请选择至少一支需要调动的舰队。")
		return
		
	var dispatched_any = false
	for item in selected_items:
		var fleet = item.fleet
		var origin_id = item.origin_id
		if fleet.is_moving:
			continue
			
		if not NetworkManager.is_multiplayer_active():
			var success = galaxy_manager.dispatch_fleet(fleet, selected_node_id)
			if success:
				_write_log("[舰队调动]: 成功调动舰队 %s 前往己方星系 %s。" % [fleet.fleet_name, target_node.node_name])
				dispatched_any = true
		else:
			NetworkManager.rpc_id(1, "server_request_dispatch_fleet", fleet.fleet_name, origin_id, selected_node_id)
			_write_log("[调动指令]: 已向服务器发送舰队调动请求 (%s)。" % fleet.fleet_name)
			dispatched_any = true
			
	if dispatched_any:
		reassign_popup_container.visible = false
		_on_node_selected(selected_node_id) # Refresh UI

func _on_auto_manage_toggled(button_pressed: bool) -> void:
	if is_updating_ui:
		return
	_send_auto_manage_update()

func _on_auto_manage_target_selected(index: int) -> void:
	if is_updating_ui:
		return
	_send_auto_manage_update()

func _send_auto_manage_update() -> void:
	if selected_node_id.is_empty():
		return
	var enabled = auto_manage_check.button_pressed
	var target_idx = auto_manage_target_option.selected
	var target = auto_manage_target_option.get_item_metadata(target_idx)
	
	if NetworkManager.is_multiplayer_active():
		NetworkManager.rpc_id(1, "server_request_toggle_auto_manage", selected_node_id, enabled, target)
		_write_log("[星系托管]: 已向服务器发送托管同步请求。")
	else:
		galaxy_manager.toggle_node_auto_manage(selected_node_id, enabled, target)
		_write_log("[星系托管]: 成功配置托管状态为：%s，目标：%s。" % ["开启" if enabled else "关闭", "均衡发展" if target == "balanced" else ("经济优先" if target == "economic" else "军事战备")])
		_on_node_selected(selected_node_id, false)

func _clean_and_style_hud_header(panel: VBoxContainer, title_text: String, is_details: bool = false, extra_widget: Control = null) -> void:
	var header = panel.get_node_or_null("Header")
	if header:
		var label = header.get_node_or_null("SystemName")
		if not label:
			label = header.get_node_or_null("Label")
			
		if label:
			header.remove_child(label)
			
			var title_hbox = HBoxContainer.new()
			title_hbox.name = "TitleHBox"
			title_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_hbox.add_theme_constant_override("separation", 10)
			
			title_hbox.add_child(label)
			label.text = title_text
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			if extra_widget:
				if extra_widget.get_parent():
					extra_widget.get_parent().remove_child(extra_widget)
				title_hbox.add_child(extra_widget)
				
			panel.add_child(title_hbox)
			panel.move_child(title_hbox, 0)
			
			var sep = HSeparator.new()
			var sep_style = StyleBoxLine.new()
			sep_style.color = Color(0.0, 0.75, 0.85, 0.3)
			sep_style.grow_begin = 4.0
			sep_style.grow_end = 4.0
			sep.add_theme_stylebox_override("line", sep_style)
			panel.add_child(sep)
			panel.move_child(sep, 1)
			
			header.queue_free()
