extends Control

@onready var continue_btn: Button = $Center/VBox/ContinueButton
const SAVE_PATH = "user://savegame.dat"

func _ready() -> void:
	# Hide default plain background
	$Background.visible = false
	
	# 1. Add Space Background Texture
	var bg_texture = TextureRect.new()
	bg_texture.texture = load("res://assets/images/galaxy/bg_space.png")
	bg_texture.stretch_mode = TextureRect.STRETCH_TILE
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
	# Delete old save to start fresh
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		
	# Set load flag and change scene
	var hub_script = load("res://src/ui/main_game_hub.gd")
	hub_script.should_load_save = false
	get_tree().change_scene_to_file("res://src/ui/main_game_hub.tscn")

func _on_continue_pressed() -> void:
	# Set load flag and change scene
	var hub_script = load("res://src/ui/main_game_hub.gd")
	hub_script.should_load_save = true
	get_tree().change_scene_to_file("res://src/ui/main_game_hub.tscn")

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/network_lobby.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
