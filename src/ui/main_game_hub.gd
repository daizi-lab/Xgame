extends Control

const Planet = preload("res://src/core/models/planet.gd")
const GalaxyManager = preload("res://src/core/managers/galaxy_manager.gd")
const ShipDesign = preload("res://src/core/models/ship_design.gd")
const Fleet = preload("res://src/core/models/fleet.gd")

@onready var metal_label: Label = $VBox/TopBar/Layout/MetalLabel
@onready var crystal_label: Label = $VBox/TopBar/Layout/CrystalLabel
@onready var deut_label: Label = $VBox/TopBar/Layout/DeutLabel
@onready var energy_label: Label = $VBox/TopBar/Layout/EnergyLabel

@onready var tab_map: Button = $VBox/NavigationPanel/TabsLayout/TabMap
@onready var tab_base: Button = $VBox/NavigationPanel/TabsLayout/TabBase
@onready var tab_designer: Button = $VBox/NavigationPanel/TabsLayout/TabDesigner
@onready var tab_shipyard: Button = $VBox/NavigationPanel/TabsLayout/TabTabShipyard if has_node("VBox/NavigationPanel/TabsLayout/TabTabShipyard") else $VBox/NavigationPanel/TabsLayout/TabShipyard
@onready var content_container: PanelContainer = $VBox/ContentContainer

static var should_load_save: bool = false
static var custom_faction_count: int = 1
static var custom_map_size: String = "medium"
var galaxy_manager: GalaxyManager
var autosave_timer: float = 0.0
const SAVE_PATH = "user://savegame.dat"

# Preloaded sub-view scenes
var view_map_scene = preload("res://src/ui/galaxy_map_ui.tscn")
var view_base_scene = preload("res://src/ui/planet_base_ui.tscn")
var view_designer_scene = preload("res://src/ui/ship_designer_ui.tscn")
var view_shipyard_scene = preload("res://src/ui/shipyard_ui.tscn")

# Instantiated panels
var panel_map: Control
var panel_base: Control
var panel_designer: Control
var panel_shipyard: Control

var current_tab_name: String = ""
var esc_menu: PanelContainer
var save_status_lbl: Label
var save_btn: Button

func _ready() -> void:
	print("[MainGameHub] Initializing Game Hub...")
	
	# Fix TabShipyard reference if needed
	if not tab_shipyard:
		tab_shipyard = $VBox/NavigationPanel/TabsLayout/TabShipyard
		
	# Hide base construction and shipyard tabs since they are now popups inside the galaxy map
	tab_base.visible = false
	tab_shipyard.visible = false
	energy_label.visible = false
	
	# 1. Instantiate or load managers
	if NetworkManager.is_multiplayer_active() and NetworkManager.galaxy_manager != null:
		galaxy_manager = NetworkManager.galaxy_manager
	elif should_load_save and FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			galaxy_manager = file.get_var(true) as GalaxyManager
			file.close()
			if galaxy_manager:
				galaxy_manager.reconnect_signals()
				print("[MainGameHub] Loaded game state from save file.")
			else:
				print("[MainGameHub] Failed to deserialize save file. Starting fresh.")
				galaxy_manager = GalaxyManager.new()
				galaxy_manager.generate_galaxy(custom_faction_count, custom_map_size)
		else:
			print("[MainGameHub] Failed to open save file. Starting fresh.")
			galaxy_manager = GalaxyManager.new()
			galaxy_manager.generate_galaxy(custom_faction_count, custom_map_size)
	else:
		galaxy_manager = GalaxyManager.new()
		galaxy_manager.generate_galaxy(custom_faction_count, custom_map_size)
		
	# Synchronize local galaxy manager reference to NetworkManager autoload for global access in UI
	if not NetworkManager.is_multiplayer_active():
		NetworkManager.galaxy_manager = galaxy_manager
		
	NetworkManager.snapshot_received.connect(func():
		galaxy_manager = NetworkManager.galaxy_manager
	)
	
	# 2. Instantiate all panels with expand size flags to ensure they fill the hub content area
	panel_map = view_map_scene.instantiate()
	panel_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_map.galaxy_manager = galaxy_manager
	
	panel_base = view_base_scene.instantiate()
	panel_base.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_base.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if galaxy_manager and galaxy_manager.selected_planet:
		panel_base.initialize(galaxy_manager.selected_planet, _get_current_resources())
		
	panel_designer = view_designer_scene.instantiate()
	panel_designer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_designer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	panel_shipyard = view_shipyard_scene.instantiate()
	panel_shipyard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_shipyard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if galaxy_manager and galaxy_manager.selected_planet:
		panel_shipyard.initialize(galaxy_manager.selected_planet, _get_current_resources())
	
	# 3. Setup Tab Buttons
	tab_map.pressed.connect(_on_tab_pressed.bind("Map"))
	tab_base.pressed.connect(_on_tab_pressed.bind("Base"))
	tab_designer.pressed.connect(_on_tab_pressed.bind("Designer"))
	tab_shipyard.pressed.connect(_on_tab_pressed.bind("Shipyard"))
	
	# Setup segmented navigation bar styling
	_setup_navigation_style()
	
	# Load default tab
	_on_tab_pressed("Map")
	
	# Instantiate system Escape menu overlay
	_create_esc_menu()

var resource_refresh_timer: float = 5.0

func _process(delta: float) -> void:
	if galaxy_manager:
		# Tick the entire universe continuously (only in Singleplayer)
		if not NetworkManager.is_multiplayer_active():
			galaxy_manager.tick(delta)
			
			# Autosave every 5.0 seconds
			autosave_timer += delta
			if autosave_timer >= 5.0:
				autosave_timer = 0.0
				save_game()
		
		# Update Top Bar UI resources every frame
		var my_res = NetworkManager.get_my_resources() if NetworkManager.is_multiplayer_active() else galaxy_manager.player_resources
		metal_label.text = _format_large_number(my_res.get("metal", 0))
		crystal_label.text = _format_large_number(my_res.get("crystal", 0))
		deut_label.text = _format_large_number(my_res.get("deuterium", 0))
		

func _on_tab_pressed(tab_name: String) -> void:
	if current_tab_name == tab_name:
		return
		
	current_tab_name = tab_name
	
	# Set toggle button states
	tab_map.button_pressed = (tab_name == "Map")
	tab_base.button_pressed = (tab_name == "Base")
	tab_designer.button_pressed = (tab_name == "Designer")
	tab_shipyard.button_pressed = (tab_name == "Shipyard")
	
	_update_nav_button_visuals()
	
	# Remove old active view
	for child in content_container.get_children():
		content_container.remove_child(child)
		
	# Mount new active view
	var target_panel: Control
	match tab_name:
		"Map":
			target_panel = panel_map
		"Base":
			target_panel = panel_base
			if galaxy_manager and galaxy_manager.selected_planet:
				panel_base.initialize(galaxy_manager.selected_planet, _get_current_resources())
		"Designer":
			target_panel = panel_designer
		"Shipyard":
			target_panel = panel_shipyard
			if galaxy_manager and galaxy_manager.selected_planet:
				panel_shipyard.initialize(galaxy_manager.selected_planet, _get_current_resources())
				
	if target_panel:
		content_container.add_child(target_panel)
		
	# Setup/Refresh panels after they are inside the scene tree (and their _ready is called)
	match tab_name:
		"Map":
			# Call refresh on map details sidebar
			if panel_map.has_method("_on_node_selected"):
				panel_map._on_node_selected(panel_map.selected_node_id)
		"Base":
			if panel_base.has_method("_rebuild_building_cards"):
				panel_base._rebuild_building_cards()
		"Shipyard":
			# Reload saved blueprints dynamically in case designer added new ones
			if panel_shipyard.has_method("_reload_blueprints"):
				panel_shipyard._reload_blueprints()
			if panel_shipyard.has_method("_update_detail_view"):
				panel_shipyard._update_detail_view()

func save_game() -> void:
	if not galaxy_manager:
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(galaxy_manager, true)
		file.close()
		print("[MainGameHub] Game autosaved successfully.")

func _get_current_resources() -> Dictionary:
	if NetworkManager.is_multiplayer_active():
		return NetworkManager.get_my_resources()
	else:
		return galaxy_manager.player_resources

func _create_esc_menu() -> void:
	esc_menu = PanelContainer.new()
	esc_menu.name = "EscapeMenu"
	esc_menu.visible = false
	esc_menu.top_level = true
	esc_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	esc_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	
	esc_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	esc_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var backdrop_style = StyleBoxFlat.new()
	backdrop_style.bg_color = Color(0.04, 0.05, 0.07, 0.75)
	esc_menu.add_theme_stylebox_override("panel", backdrop_style)
	
	var center = CenterContainer.new()
	esc_menu.add_child(center)
	
	var menu_box = PanelContainer.new()
	menu_box.custom_minimum_size = Vector2(280, 240)
	
	var box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0.08, 0.12, 0.20, 0.96)
	box_style.border_width_left = 2
	box_style.border_width_top = 2
	box_style.border_width_right = 2
	box_style.border_width_bottom = 2
	box_style.border_color = Color(0.0, 0.75, 0.85, 0.8)
	box_style.corner_radius_top_left = 8
	box_style.corner_radius_top_right = 8
	box_style.corner_radius_bottom_left = 8
	box_style.corner_radius_bottom_right = 8
	menu_box.add_theme_stylebox_override("panel", box_style)
	center.add_child(menu_box)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	menu_box.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "系统菜单 (System Menu)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)
	
	var resume_btn = Button.new()
	resume_btn.text = "继续游戏 (Resume)"
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.pressed.connect(func(): _toggle_esc_menu(false))
	vbox.add_child(resume_btn)
	
	save_btn = Button.new()
	save_btn.text = "保存游戏 (Save Game)"
	save_btn.custom_minimum_size = Vector2(200, 40)
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)
	
	var exit_btn = Button.new()
	exit_btn.text = "退出游戏 (Exit)"
	exit_btn.custom_minimum_size = Vector2(200, 40)
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)
	
	save_status_lbl = Label.new()
	save_status_lbl.text = ""
	save_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_status_lbl.add_theme_font_size_override("font_size", 10)
	save_status_lbl.add_theme_color_override("font_color", Color.GREEN)
	vbox.add_child(save_status_lbl)
	
	add_child(esc_menu)

func _toggle_esc_menu(show: bool) -> void:
	if esc_menu:
		esc_menu.visible = show
		if show:
			save_status_lbl.text = ""
			save_btn.visible = not NetworkManager.is_multiplayer_active()
			if not NetworkManager.is_multiplayer_active():
				get_tree().paused = true
		else:
			if not NetworkManager.is_multiplayer_active():
				get_tree().paused = false

func _on_save_pressed() -> void:
	save_game()
	save_status_lbl.text = "游戏进度已保存！"
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if save_status_lbl:
			save_status_lbl.text = ""
	)

func _on_exit_pressed() -> void:
	get_tree().paused = false
	if NetworkManager.is_multiplayer_active():
		print("[MainGameHub] Stopping multiplayer before exit...")
		NetworkManager.stop_game()
	print("[MainGameHub] Exiting to Main Menu...")
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		# If we are in Map tab and any map popup is open, don't open the Escape menu
		if current_tab_name == "Map" and panel_map and panel_map.has_method("is_any_popup_open") and panel_map.is_any_popup_open():
			return
		
		# Toggle the system escape menu overlay
		_toggle_esc_menu(not esc_menu.visible)
		get_viewport().set_input_as_handled()

func _format_large_number(val: float) -> String:
	if val <= 0.0:
		return "0"
	if val < 1000.0:
		return str(roundi(val))
	elif val < 1000000.0:
		var k_val = val / 1000.0
		if k_val >= 100.0:
			return "%.0fK" % k_val
		else:
			return "%.1fK" % k_val
	else:
		var m_val = val / 1000000.0
		if m_val >= 100.0:
			return "%.0fM" % m_val
		else:
			return "%.2fM" % m_val

func _setup_navigation_style() -> void:
	var nav_panel = $VBox/NavigationPanel
	var tabs_layout = $VBox/NavigationPanel/TabsLayout
	var top_layout = $VBox/TopBar/Layout
	
	# Hide the separate NavigationPanel completely to eliminate the solid black bar
	nav_panel.visible = false
	
	# Style the TopBar background to be premium translucent glass dark color
	var top_bar = $VBox/TopBar
	top_bar.custom_minimum_size = Vector2(0, 60) # increase height to give breathing room for cards and capsule
	var top_bar_color = top_bar.get_node_or_null("ColorRect")
	if top_bar_color:
		top_bar_color.visible = false # hide default flat background
	top_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new()) # make PanelContainer transparent
		
	# Add the custom top bar frame drawer
	var top_frame = TopBarFrame.new()
	top_frame.name = "TopBarFrame"
	top_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_frame)
	top_bar.move_child(top_frame, 0) # behind layout
	
	# Style the Game Title: Main cyan title on left, small grey subtitle next to it
	var game_title = $VBox/TopBar/Layout/GameTitle
	if game_title:
		var title_parent = game_title.get_parent()
		var title_idx = game_title.get_index()
		title_parent.remove_child(game_title)
		
		var title_hbox = HBoxContainer.new()
		title_hbox.name = "TitleHBox"
		title_hbox.add_theme_constant_override("separation", 6)
		title_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var main_title = Label.new()
		main_title.name = "MainTitle"
		main_title.text = "战略家"
		main_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
		main_title.add_theme_font_size_override("font_size", 18)
		title_hbox.add_child(main_title)
		
		var sub_title = Label.new()
		sub_title.name = "SubTitle"
		sub_title.text = " - SSW Remake"
		sub_title.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		sub_title.add_theme_font_size_override("font_size", 11)
		title_hbox.add_child(sub_title)
		
		var title_margin = MarginContainer.new()
		title_margin.name = "TitleMargin"
		title_margin.add_theme_constant_override("margin_top", 6)
		title_margin.add_theme_constant_override("margin_bottom", 20)
		title_margin.add_child(title_hbox)
		
		title_parent.add_child(title_margin)
		title_parent.move_child(title_margin, title_idx)
		game_title.queue_free()
		
	# Style the resources into individual color-coded cards matching mockup colors exactly
	var my_res_labels = [
		{"node": metal_label, "color": Color(0.82, 0.66, 0.25), "name": "metal", "icon": "res://assets/images/resources/metal.png"}, # Gold/Yellow
		{"node": crystal_label, "color": Color(0.85, 0.25, 0.85), "name": "crystal", "icon": "res://assets/images/resources/crystal.png"}, # Pink/Purple
		{"node": deut_label, "color": Color(0.0, 0.75, 0.85), "name": "deuterium", "icon": "res://assets/images/resources/deuterium.png"} # Cyan/Teal
	]
	
	for item in my_res_labels:
		var lbl = item["node"]
		var color = item["color"]
		var res_name = item["name"]
		var icon_path = item["icon"]
		
		# Strip prefix text
		if lbl.text.contains(":"):
			lbl.text = lbl.text.split(":")[1].strip_edges()
			
		var parent = lbl.get_parent()
		var idx = lbl.get_index()
		parent.remove_child(lbl)
		
		var card = PanelContainer.new()
		card.name = lbl.name + "Card"
		
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(color.r, color.g, color.b, 0.08) # richer background
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(color.r, color.g, color.b, 0.55) # distinct outline opacity
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card.add_theme_stylebox_override("panel", card_style)
		
		var margin_c = MarginContainer.new()
		margin_c.add_theme_constant_override("margin_left", 6)
		margin_c.add_theme_constant_override("margin_top", 1)
		margin_c.add_theme_constant_override("margin_right", 8)
		margin_c.add_theme_constant_override("margin_bottom", 1)
		card.add_child(margin_c)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		margin_c.add_child(hbox)
		
		var icon_rect = TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		hbox.add_child(icon_rect)
		
		var text_vbox = VBoxContainer.new()
		text_vbox.add_theme_constant_override("separation", -3)
		text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(text_vbox)
		
		# Value
		text_vbox.add_child(lbl)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		# Name Label
		var name_lbl = Label.new()
		name_lbl.name = "ResourceName"
		name_lbl.text = res_name
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", color)
		name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		text_vbox.add_child(name_lbl)
		
		# Wrap in margin container to align vertically within Y = 8 to 36
		var card_margin = MarginContainer.new()
		card_margin.name = lbl.name + "Margin"
		card_margin.add_theme_constant_override("margin_top", 8)
		card_margin.add_theme_constant_override("margin_bottom", 24)
		card_margin.add_child(card)
		
		parent.add_child(card_margin)
		parent.move_child(card_margin, idx)
	
	# Create a wrapper PanelContainer for tabs_layout so that it has a border and capsule background
	var wrapper = PanelContainer.new()
	wrapper.name = "NavCapsule"
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var capsule_style = StyleBoxFlat.new()
	capsule_style.bg_color = Color(0.05, 0.08, 0.12, 0.7) # deep dark translucent capsule
	capsule_style.border_width_left = 1
	capsule_style.border_width_top = 1
	capsule_style.border_width_right = 1
	capsule_style.border_width_bottom = 1
	capsule_style.border_color = Color(0.0, 0.75, 0.85, 0.2) # soft cyan border
	capsule_style.corner_radius_top_left = 20
	capsule_style.corner_radius_top_right = 20
	capsule_style.corner_radius_bottom_left = 20
	capsule_style.corner_radius_bottom_right = 20
	wrapper.add_theme_stylebox_override("panel", capsule_style)
	
	# Margin container inside wrapper to give breathing room for buttons
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	wrapper.add_child(margin)
	
	# Reparent tabs_layout into the wrapper
	nav_panel.remove_child(tabs_layout)
	margin.add_child(tabs_layout)
	
	# Wrap in CapsuleContainer MarginContainer to push the capsule down into the dipped top bar area
	var capsule_container = MarginContainer.new()
	capsule_container.name = "CapsuleContainer"
	capsule_container.add_theme_constant_override("margin_top", 6)
	capsule_container.add_child(wrapper)
	
	# Align CapsuleContainer to the exact horizontal center of the TopBar PanelContainer
	capsule_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	capsule_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_bar.add_child(capsule_container)
	
	# Style the buttons inside TabsLayout to look like premium segmented tabs
	tabs_layout.add_theme_constant_override("separation", 6)
	
	for btn in [tab_map, tab_base, tab_designer, tab_shipyard]:
		btn.custom_minimum_size = Vector2(130, 40) # taller button for two lines of text
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.text = "" # clear default text
		
		# Clear any existing child controls if re-initialized
		for child in btn.get_children():
			child.queue_free()
			
		var vbox = VBoxContainer.new()
		vbox.name = "TextVBox"
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", -1)
		btn.add_child(vbox)
		
		var l1 = Label.new()
		l1.name = "MainLabel"
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l1.add_theme_font_size_override("font_size", 12)
		l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(l1)
		
		var l2 = Label.new()
		l2.name = "SubLabel"
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.add_theme_font_size_override("font_size", 8)
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(l2)
		
		if btn == tab_map:
			l1.text = "星区图"
			l2.text = "(Galaxy Map)"
		elif btn == tab_base:
			l1.text = "基地建设"
			l2.text = "(Base Construction)"
		elif btn == tab_designer:
			l1.text = "战舰设计"
			l2.text = "(Designer)"
		elif btn == tab_shipyard:
			l1.text = "飞船建造"
			l2.text = "(Shipyard)"
		
	_update_nav_button_visuals()

func _update_nav_button_visuals() -> void:
	for btn in [tab_map, tab_base, tab_designer, tab_shipyard]:
		if not btn:
			continue
		var is_active = btn.button_pressed
		var vbox = btn.get_node_or_null("TextVBox")
		var l1: Label = vbox.get_node("MainLabel") if vbox else null
		var l2: Label = vbox.get_node("SubLabel") if vbox else null
		
		var style_normal = StyleBoxFlat.new()
		style_normal.corner_radius_top_left = 18
		style_normal.corner_radius_top_right = 18
		style_normal.corner_radius_bottom_left = 18
		style_normal.corner_radius_bottom_right = 18
		
		var style_hover = style_normal.duplicate()
		
		if is_active:
			# Active Selected Style: Glowing flat cyan
			style_normal.bg_color = Color(0.0, 0.5, 0.6, 0.2) # glass cyan tint
			style_normal.border_width_left = 1
			style_normal.border_width_top = 1
			style_normal.border_width_right = 1
			style_normal.border_width_bottom = 1
			style_normal.border_color = Color(0.0, 0.85, 1.0, 0.9) # bright cyan border
			style_normal.shadow_color = Color(0.0, 0.85, 1.0, 0.25)
			style_normal.shadow_size = 5
			
			if l1:
				l1.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
			if l2:
				l2.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85))
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_normal)
			btn.add_theme_stylebox_override("pressed", style_normal)
			btn.add_theme_stylebox_override("focus", style_normal)
		else:
			# Inactive Normal Style: Completely transparent
			style_normal.bg_color = Color(0, 0, 0, 0)
			style_normal.border_width_left = 0
			style_normal.border_width_top = 0
			style_normal.border_width_right = 0
			style_normal.border_width_bottom = 0
			style_normal.shadow_size = 0
			
			# Inactive Hover Style: Soft highlight
			style_hover.bg_color = Color(0.0, 0.75, 0.85, 0.08)
			style_hover.border_width_left = 0
			style_hover.border_width_top = 0
			style_hover.border_width_right = 0
			style_hover.border_width_bottom = 0
			style_hover.shadow_size = 0
			
			if l1:
				l1.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
			if l2:
				l2.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_normal)
			btn.add_theme_stylebox_override("focus", style_normal)


# Custom Control to draw the custom-shaped top bar background and glowing bottom border
class TopBarFrame extends Control:
	func _draw() -> void:
		var s = size
		var H1 = 44.0
		var H2 = 56.0
		var mid_x = s.x / 2.0
		var cap_half = 142.0 # wraps around the capsule
		var bevel = 12.0
		
		# Define background polygon
		var bg_pts = PackedVector2Array([
			Vector2(0, 0),
			Vector2(s.x, 0),
			Vector2(s.x, H1),
			Vector2(mid_x + cap_half + bevel, H1),
			Vector2(mid_x + cap_half, H2),
			Vector2(mid_x - cap_half, H2),
			Vector2(mid_x - cap_half - bevel, H1),
			Vector2(0, H1)
		])
		draw_polygon(bg_pts, PackedColorArray([Color(0.04, 0.05, 0.08, 0.85)]))
		
		# Define bottom border line
		var border_pts = PackedVector2Array([
			Vector2(0, H1),
			Vector2(mid_x - cap_half - bevel, H1),
			Vector2(mid_x - cap_half, H2),
			Vector2(mid_x + cap_half, H2),
			Vector2(mid_x + cap_half + bevel, H1),
			Vector2(s.x, H1)
		])
		
		# Draw outer soft glow passes
		draw_polyline(border_pts, Color(0.0, 0.85, 1.0, 0.05), 8.0, true)
		draw_polyline(border_pts, Color(0.0, 0.85, 1.0, 0.15), 4.0, true)
		# Draw core neon cyan line
		draw_polyline(border_pts, Color(0.0, 0.85, 1.0, 0.65), 1.5, true)
