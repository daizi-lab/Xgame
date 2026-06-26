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
		hbox.add_child(lbl_name)
		
		var lbl_status = Label.new()
		if is_host:
			lbl_status.text = "就绪 "
			lbl_status.add_theme_color_override("font_color", Color.GREEN)
		else:
			lbl_status.text = "已准备 " if is_ready else "未准备 "
			lbl_status.add_theme_color_override("font_color", Color.GREEN if is_ready else Color.RED)
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
