extends Control

@onready var continue_btn: Button = $Center/VBox/ContinueButton
const SAVE_PATH = "user://savegame.dat"

var faction_count_val: int = 1
var map_size_val: String = "medium"

func _ready() -> void:
	# Hide default plain background
	$Background.visible = false
	
	# 1. Add Space Background Texture
	var bg_texture = TextureRect.new()
	bg_texture.texture = load("res://assets/images/galaxy/main_menu_bg.png")
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_texture)
	move_child(bg_texture, 0)
	
	# 2. Add Dark Semi-transparent Overlay
	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0.03, 0.04, 0.06, 0.75)
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_overlay)
	move_child(bg_overlay, 1)
	
	# Check if save file exists
	if FileAccess.file_exists(SAVE_PATH):
		continue_btn.disabled = false
		continue_btn.text = "继续游戏 (Continue)"
	else:
		continue_btn.disabled = true
		continue_btn.text = "继续游戏 (无存档)"
		
	# Connect button signals
	$Center/VBox/StartButton.pressed.connect(_on_start_pressed)
	$Center/VBox/ContinueButton.pressed.connect(_on_continue_pressed)
	$Center/VBox/MultiplayerButton.pressed.connect(_on_multiplayer_pressed)
	$Center/VBox/ExitButton.pressed.connect(_on_exit_pressed)

	# 3. Reparent VBox into a premium glassmorphism PanelContainer
	var vbox = $Center/VBox
	$Center.remove_child(vbox)
	
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.8) # Premium translucent deep blue
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.0, 0.75, 0.85, 0.5) # Glowing cyan border
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(0.0, 0.75, 0.85, 0.15)
	panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 45)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_right", 45)
	margin.add_theme_constant_override("margin_bottom", 35)
	
	panel.add_child(margin)
	margin.add_child(vbox)
	$Center.add_child(panel)
	
	# 4. Style Title
	var title = vbox.get_node("Title") as Label
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0)) # Neon cyan
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add a HSeparator under title
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.0, 0.75, 0.85, 0.3)
	sep_style.grow_begin = 10.0
	sep_style.grow_end = 10.0
	sep.add_theme_stylebox_override("line", sep_style)
	vbox.add_child(sep)
	vbox.move_child(sep, 1)
	
	# 5. Style Action Buttons
	_style_menu_button(vbox.get_node("StartButton"), Color(0.0, 0.75, 0.85))
	_style_menu_button(vbox.get_node("ContinueButton"), Color(0.0, 0.75, 0.85))
	_style_menu_button(vbox.get_node("MultiplayerButton"), Color(0.0, 0.75, 0.85))
	_style_menu_button(vbox.get_node("ExitButton"), Color(0.7, 0.25, 0.25))

func _style_menu_button(btn: Button, color_base: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(color_base.r * 0.08, color_base.g * 0.08, color_base.b * 0.08, 0.6)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(color_base.r * 0.7, color_base.g * 0.7, color_base.b * 0.7, 0.4)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.content_margin_left = 15
	style_normal.content_margin_right = 15
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(color_base.r * 0.15, color_base.g * 0.15, color_base.b * 0.15, 0.75)
	style_hover.border_width_left = 1
	style_hover.border_width_top = 1
	style_hover.border_width_right = 1
	style_hover.border_width_bottom = 1
	style_hover.border_color = Color(color_base.r, color_base.g, color_base.b, 0.8)
	style_hover.corner_radius_top_left = 6
	style_hover.corner_radius_top_right = 6
	style_hover.corner_radius_bottom_left = 6
	style_hover.corner_radius_bottom_right = 6
	style_hover.shadow_color = Color(color_base.r, color_base.g, color_base.b, 0.2)
	style_hover.shadow_size = 6
	style_hover.content_margin_left = 15
	style_hover.content_margin_right = 15
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(color_base.r * 0.05, color_base.g * 0.05, color_base.b * 0.05, 0.9)
	style_pressed.border_width_left = 1
	style_pressed.border_width_top = 1
	style_pressed.border_width_right = 1
	style_pressed.border_width_bottom = 1
	style_pressed.border_color = Color(color_base.r * 0.8, color_base.g * 0.8, color_base.b * 0.8, 0.9)
	style_pressed.corner_radius_top_left = 6
	style_pressed.corner_radius_top_right = 6
	style_pressed.corner_radius_bottom_left = 6
	style_pressed.corner_radius_bottom_right = 6
	style_pressed.content_margin_left = 15
	style_pressed.content_margin_right = 15
	
	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.12, 0.15, 0.2, 0.3)
	style_disabled.border_width_left = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_bottom = 1
	style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.2)
	style_disabled.corner_radius_top_left = 6
	style_disabled.corner_radius_top_right = 6
	style_disabled.corner_radius_bottom_left = 6
	style_disabled.corner_radius_bottom_right = 6
	style_disabled.content_margin_left = 15
	style_disabled.content_margin_right = 15
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_stylebox_override("focus", style_normal)
	btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_start_pressed() -> void:
	_show_settings_popup()

func _show_settings_popup() -> void:
	# Hide main menu panel
	var main_panel = $Center.get_child(0)
	main_panel.visible = false
	
	var settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	
	# Reuse the same stylebox flat for glassmorphism
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.85) # Premium translucent deep blue
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.0, 0.75, 0.85, 0.5) # Glowing cyan border
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(0.0, 0.75, 0.85, 0.15)
	panel_style.shadow_size = 12
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 45)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_right", 45)
	margin.add_theme_constant_override("margin_bottom", 35)
	settings_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "单人探索设置 (Game Settings)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0)) # Neon cyan
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.0, 0.75, 0.85, 0.3)
	sep_style.grow_begin = 10.0
	sep_style.grow_end = 10.0
	sep.add_theme_stylebox_override("line", sep_style)
	vbox.add_child(sep)
	
	# --- Faction Count Setting ---
	var faction_hbox = HBoxContainer.new()
	faction_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(faction_hbox)
	
	var faction_label = Label.new()
	faction_label.text = "本局阵营数量 (AI Factions): "
	faction_label.add_theme_font_size_override("font_size", 14)
	faction_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	faction_hbox.add_child(faction_label)
	
	# Spacer
	var f_spacer = Control.new()
	f_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_hbox.add_child(f_spacer)
	
	var minus_btn = Button.new()
	minus_btn.text = " - "
	minus_btn.custom_minimum_size = Vector2(35, 30)
	faction_hbox.add_child(minus_btn)
	
	var count_label = Label.new()
	count_label.text = str(faction_count_val)
	count_label.add_theme_font_size_override("font_size", 15)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	faction_hbox.add_child(count_label)
	
	var plus_btn = Button.new()
	plus_btn.text = " + "
	plus_btn.custom_minimum_size = Vector2(35, 30)
	faction_hbox.add_child(plus_btn)
	
	# Connect Faction Count button signals
	minus_btn.pressed.connect(func():
		if faction_count_val > 0:
			faction_count_val -= 1
			count_label.text = str(faction_count_val)
	)
	plus_btn.pressed.connect(func():
		if faction_count_val < 8:
			faction_count_val += 1
			count_label.text = str(faction_count_val)
	)
	
	# Style minus/plus buttons
	_style_menu_button(minus_btn, Color(0.0, 0.75, 0.85))
	_style_menu_button(plus_btn, Color(0.0, 0.75, 0.85))
	
	# --- Map Size Setting ---
	var map_label = Label.new()
	map_label.text = "初始地图大小 (Initial Map Size):"
	map_label.add_theme_font_size_override("font_size", 14)
	map_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(map_label)
	
	var map_hbox = HBoxContainer.new()
	map_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(map_hbox)
	
	var btn_small = Button.new()
	btn_small.text = "小 (Small)"
	btn_small.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_small.custom_minimum_size = Vector2(0, 35)
	map_hbox.add_child(btn_small)
	
	var btn_medium = Button.new()
	btn_medium.text = "中 (Medium)"
	btn_medium.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_medium.custom_minimum_size = Vector2(0, 35)
	map_hbox.add_child(btn_medium)
	
	var btn_large = Button.new()
	btn_large.text = "大 (Large)"
	btn_large.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_large.custom_minimum_size = Vector2(0, 35)
	map_hbox.add_child(btn_large)
	
	var update_map_size_visuals = func():
		_style_selected_button(btn_small, map_size_val == "small", Color(0.0, 0.75, 0.85))
		_style_selected_button(btn_medium, map_size_val == "medium", Color(0.0, 0.75, 0.85))
		_style_selected_button(btn_large, map_size_val == "large", Color(0.0, 0.75, 0.85))
		
	btn_small.pressed.connect(func():
		map_size_val = "small"
		update_map_size_visuals.call()
	)
	btn_medium.pressed.connect(func():
		map_size_val = "medium"
		update_map_size_visuals.call()
	)
	btn_large.pressed.connect(func():
		map_size_val = "large"
		update_map_size_visuals.call()
	)
	
	# Initial style
	update_map_size_visuals.call()
	
	# Spacer
	var s_spacer = Control.new()
	s_spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(s_spacer)
	
	# --- Action Buttons ---
	var actions_hbox = HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(actions_hbox)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "返回 (Back)"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 40)
	actions_hbox.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "开始探索 (Start)"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size = Vector2(0, 40)
	actions_hbox.add_child(confirm_btn)
	
	_style_menu_button(cancel_btn, Color(0.7, 0.25, 0.25))
	_style_menu_button(confirm_btn, Color(0.0, 0.75, 0.85))
	
	cancel_btn.pressed.connect(func():
		settings_panel.queue_free()
		main_panel.visible = true
	)
	
	confirm_btn.pressed.connect(func():
		# Delete old save to start fresh
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(SAVE_PATH)
			
		# Save selections to static properties of MainGameHub
		var hub_script = load("res://src/ui/main_game_hub.gd")
		hub_script.should_load_save = false
		hub_script.custom_faction_count = faction_count_val
		hub_script.custom_map_size = map_size_val
		
		# Change scene
		get_tree().change_scene_to_file("res://src/ui/main_game_hub.tscn")
	)
	
	$Center.add_child(settings_panel)

func _style_selected_button(btn: Button, is_selected: bool, color_base: Color) -> void:
	if is_selected:
		var style_selected = StyleBoxFlat.new()
		style_selected.bg_color = Color(color_base.r * 0.15, color_base.g * 0.15, color_base.b * 0.15, 0.75)
		style_selected.border_width_left = 2
		style_selected.border_width_top = 2
		style_selected.border_width_right = 2
		style_selected.border_width_bottom = 2
		style_selected.border_color = Color(color_base.r, color_base.g, color_base.b, 0.8)
		style_selected.corner_radius_top_left = 6
		style_selected.corner_radius_top_right = 6
		style_selected.corner_radius_bottom_left = 6
		style_selected.corner_radius_bottom_right = 6
		style_selected.shadow_color = Color(color_base.r, color_base.g, color_base.b, 0.3)
		style_selected.shadow_size = 6
		style_selected.content_margin_left = 15
		style_selected.content_margin_right = 15
		
		btn.add_theme_stylebox_override("normal", style_selected)
		btn.add_theme_stylebox_override("hover", style_selected)
		btn.add_theme_stylebox_override("pressed", style_selected)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		_style_menu_button(btn, color_base)

func _on_continue_pressed() -> void:
	# Set load flag and change scene
	var hub_script = load("res://src/ui/main_game_hub.gd")
	hub_script.should_load_save = true
	get_tree().change_scene_to_file("res://src/ui/main_game_hub.tscn")

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/network_lobby.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
