extends Control

@onready var connect_panel: VBoxContainer = $Panel/ConnectPanel
@onready var name_input: LineEdit = $Panel/ConnectPanel/Grid/NameInput
@onready var room_input: LineEdit = $Panel/ConnectPanel/Grid/RoomInput
@onready var password_input: LineEdit = $Panel/ConnectPanel/Grid/PasswordInput
@onready var status_lbl: Label = $Panel/ConnectPanel/StatusLabel

@onready var create_btn: Button = $Panel/ConnectPanel/Buttons/CreateButton
@onready var join_btn: Button = $Panel/ConnectPanel/Buttons/JoinButton
@onready var back_btn: Button = $Panel/ConnectPanel/Buttons/BackButton

@onready var waiting_room: VBoxContainer = $Panel/WaitingRoom
@onready var room_title: Label = $Panel/WaitingRoom/RoomTitle
@onready var player_list: VBoxContainer = $Panel/WaitingRoom/Scroll/PlayerList

@onready var ready_btn: Button = $Panel/WaitingRoom/LobbyButtons/ReadyButton
@onready var start_btn: Button = $Panel/WaitingRoom/LobbyButtons/StartButton
@onready var exit_btn: Button = $Panel/WaitingRoom/LobbyButtons/ExitButton

func _ready() -> void:
	# Load default configurations or random names
	name_input.text = "指挥官_" + str(randi_range(100, 999))
	room_input.text = "战略星域"
	password_input.text = ""
	
	# Connect local UI events
	create_btn.pressed.connect(_on_create_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	# Connect network manager events
	NetworkManager.connection_status_changed.connect(_on_connection_status_changed)
	NetworkManager.snapshot_received.connect(_on_snapshot_received)
	
	# Automatically initiate connection to central lobby server
	if not NetworkManager.is_multiplayer_active():
		status_lbl.text = "正在连接大厅服务器..."
		_disable_connect_buttons(true)
		if not NetworkManager.join_game("8.215.89.194", 9999, name_input.text):
			status_lbl.text = "连接大厅服务器失败！"
			_disable_connect_buttons(false)
	elif NetworkManager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		status_lbl.text = "正在连接大厅服务器..."
		_disable_connect_buttons(true)
	else:
		status_lbl.text = "大厅服务器已连接。"
		_disable_connect_buttons(false)
		
	_apply_hud_lobby_styling()

func _on_create_pressed() -> void:
	var r_name = room_input.text.strip_edges()
	var r_pass = password_input.text
	var p_name = name_input.text.strip_edges()
	
	if r_name.is_empty() or p_name.is_empty():
		status_lbl.text = "错误：姓名和房间名不能为空！"
		return
		
	status_lbl.text = "正在向大厅注册房间..."
	NetworkManager.rpc_id(1, "server_request_create_room", r_name, r_pass, p_name)

func _on_join_pressed() -> void:
	var r_name = room_input.text.strip_edges()
	var r_pass = password_input.text
	var p_name = name_input.text.strip_edges()
	
	if r_name.is_empty() or p_name.is_empty():
		status_lbl.text = "错误：姓名和房间名不能为空！"
		return
		
	status_lbl.text = "正在尝试加入房间..."
	NetworkManager.rpc_id(1, "server_request_join_room", r_name, r_pass, p_name)

func _on_ready_pressed() -> void:
	NetworkManager.rpc_id(1, "server_request_toggle_ready")

func _on_start_pressed() -> void:
	NetworkManager.rpc_id(1, "server_request_start_game")

func _on_exit_pressed() -> void:
	status_lbl.text = "正在退出房间..."
	NetworkManager.rpc_id(1, "server_request_exit_room")

func _on_back_pressed() -> void:
	NetworkManager.stop_game()
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

func _on_connection_status_changed(connected: bool, msg: String) -> void:
	status_lbl.text = msg
	_disable_connect_buttons(not connected)

func _on_snapshot_received() -> void:
	status_lbl.text = "数据同步成功！正在进入星系..."
	var hub_script = load("res://src/ui/main_game_hub.gd")
	hub_script.should_load_save = false
	get_tree().change_scene_to_file("res://src/ui/main_game_hub.tscn")

func _disable_connect_buttons(disabled: bool) -> void:
	create_btn.disabled = disabled
	join_btn.disabled = disabled

# Callback invoked via Server RPCs to update waiting room UI
func update_waiting_room(room_name: String, host_id: int, peers_dict: Dictionary, ready_states: Dictionary) -> void:
	connect_panel.visible = false
	waiting_room.visible = true
	
	room_title.text = "等待房间: " + room_name
	
	# Clear children list
	for child in player_list.get_children():
		child.queue_free()
		
	# Rebuild player items list
	for pid in peers_dict:
		var p_name = peers_dict[pid]
		var is_host = (pid == host_id)
		var is_ready = ready_states.get(pid, false)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 15)
		
		var lbl_name = Label.new()
		var display_text = "  " + p_name
		if is_host:
			display_text += " [房主]"
		lbl_name.text = display_text
		lbl_name.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl_name.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		lbl_name.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lbl_name)
		
		var lbl_status = Label.new()
		lbl_status.add_theme_font_size_override("font_size", 13)
		if is_host:
			lbl_status.text = "就绪 "
			lbl_status.add_theme_color_override("font_color", Color(0.0, 0.85, 0.2))
		else:
			lbl_status.text = "已准备 " if is_ready else "未准备 "
			lbl_status.add_theme_color_override("font_color", Color(0.0, 0.85, 0.2) if is_ready else Color(0.85, 0.3, 0.3))
		hbox.add_child(lbl_status)
		
		player_list.add_child(hbox)
		
	# Determine Host vs Client controls
	var my_id = NetworkManager.multiplayer.get_unique_id()
	var is_me_host = (my_id == host_id)
	
	start_btn.visible = is_me_host
	ready_btn.visible = not is_me_host
	
	if is_me_host:
		var everyone_ready = true
		for pid in peers_dict:
			if pid != host_id and not ready_states.get(pid, false):
				everyone_ready = false
				break
		start_btn.disabled = not everyone_ready
	else:
		var my_ready = ready_states.get(my_id, false)
		ready_btn.text = "取消准备" if my_ready else "准备"

func show_connect_panel() -> void:
	connect_panel.visible = true
	waiting_room.visible = false
	status_lbl.text = "就绪"
	_disable_connect_buttons(false)

var loading_overlay: PanelContainer = null

func show_loading_screen(msg: String) -> void:
	if loading_overlay:
		loading_overlay.queue_free()
		
	loading_overlay = PanelContainer.new()
	loading_overlay.name = "LoadingOverlay"
	loading_overlay.top_level = true
	loading_overlay.anchor_left = 0.0
	loading_overlay.anchor_top = 0.0
	loading_overlay.anchor_right = 1.0
	loading_overlay.anchor_bottom = 1.0
	loading_overlay.offset_left = 0
	loading_overlay.offset_top = 0
	loading_overlay.offset_right = 0
	loading_overlay.offset_bottom = 0
	loading_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Solid dark backdrop with glowing cyan border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.85, 0.95, 0.6)
	loading_overlay.add_theme_stylebox_override("panel", style)
	
	var center = CenterContainer.new()
	loading_overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)
	
	var icon = Label.new()
	icon.text = "⏳"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 32)
	icon.add_theme_color_override("font_color", Color(0.0, 0.85, 0.95))
	vbox.add_child(icon)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "正在构建星系地图和行星基础设施，请稍候..."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(sub_lbl)
	
	add_child(loading_overlay)

func _apply_hud_lobby_styling() -> void:
	# 1. Background Nebula and dark filter overlay
	var bg_texture = TextureRect.new()
	bg_texture.texture = load("res://assets/images/galaxy/main_menu_bg.png")
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_texture)
	move_child(bg_texture, 0)
	
	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0.03, 0.04, 0.06, 0.75)
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_overlay)
	move_child(bg_overlay, 1)

	# 2. Main panel styling (glassmorphism)
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
	$Panel.add_theme_stylebox_override("panel", panel_style)
	
	# ConnectPanel Title
	var title = $Panel/ConnectPanel/Title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0)) # Neon cyan
	
	# ConnectPanel Title Separator
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.0, 0.75, 0.85, 0.3)
	sep_style.grow_begin = 10.0
	sep_style.grow_end = 10.0
	sep.add_theme_stylebox_override("line", sep_style)
	connect_panel.add_child(sep)
	connect_panel.move_child(sep, 1)
	
	# ConnectPanel Labels
	for child in $Panel/ConnectPanel/Grid.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			child.add_theme_font_size_override("font_size", 13)
			
	# ConnectPanel Inputs
	_style_line_edit(name_input)
	_style_line_edit(room_input)
	_style_line_edit(password_input)
	
	# ConnectPanel Buttons
	_style_menu_button(create_btn, Color(0.0, 0.75, 0.85))
	_style_menu_button(join_btn, Color(0.0, 0.75, 0.85))
	_style_menu_button(back_btn, Color(0.7, 0.25, 0.25))
	
	# ConnectPanel Status Label
	status_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0, 0.8))
	status_lbl.add_theme_font_size_override("font_size", 12)
	
	# WaitingRoom Title
	var room_title = $Panel/WaitingRoom/RoomTitle
	room_title.add_theme_font_size_override("font_size", 18)
	room_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	
	# WaitingRoom Title Separator
	var wr_sep = HSeparator.new()
	wr_sep.add_theme_stylebox_override("line", sep_style)
	waiting_room.add_child(wr_sep)
	waiting_room.move_child(wr_sep, 1)
	
	# WaitingRoom Labels
	var list_lbl = $Panel/WaitingRoom/PlayerListLabel
	list_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	list_lbl.add_theme_font_size_override("font_size", 13)
	
	# ScrollContainer panel styling
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0.04, 0.05, 0.08, 0.5)
	scroll_style.border_width_left = 1
	scroll_style.border_width_top = 1
	scroll_style.border_width_right = 1
	scroll_style.border_width_bottom = 1
	scroll_style.border_color = Color(0.0, 0.75, 0.85, 0.2)
	scroll_style.corner_radius_top_left = 6
	scroll_style.corner_radius_top_right = 6
	scroll_style.corner_radius_bottom_left = 6
	scroll_style.corner_radius_bottom_right = 6
	$Panel/WaitingRoom/Scroll.add_theme_stylebox_override("panel", scroll_style)
	
	# WaitingRoom Buttons
	_style_menu_button(ready_btn, Color(0.0, 0.75, 0.85))
	_style_menu_button(start_btn, Color(0.0, 0.75, 0.85))
	_style_menu_button(exit_btn, Color(0.7, 0.25, 0.25))

func _style_line_edit(line_edit: LineEdit) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.6)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.75, 0.85, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	
	var style_focus = style.duplicate()
	style_focus.border_color = Color(0.0, 0.75, 0.85, 0.8)
	style_focus.shadow_color = Color(0.0, 0.75, 0.85, 0.1)
	style_focus.shadow_size = 4
	
	line_edit.add_theme_stylebox_override("normal", style)
	line_edit.add_theme_stylebox_override("focus", style_focus)
	line_edit.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	line_edit.add_theme_color_override("placeholder_color", Color(0.4, 0.5, 0.6))

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
