extends Control

const ComponentsData = preload("res://src/core/data/components_data.gd")

const SHIP_TEXTURES = {
	"frigate": preload("res://assets/images/hulls/frigate.png"),
	"destroyer": preload("res://assets/images/hulls/destroyer.png"),
	"cruiser": preload("res://assets/images/hulls/cruiser.png"),
	"battleship": preload("res://assets/images/hulls/battleship.png")
}

@onready var background_dim: ColorRect = $BackgroundDim
@onready var visualizer: Control = $Battlefield/Visualizer
@onready var dialog_text: RichTextLabel = $DialogBox/Margin/HBox/LogsScroll/DialogText

@onready var attacker_box: PanelContainer = $Battlefield/AttackerHPBox
@onready var attacker_name_lbl: Label = $Battlefield/AttackerHPBox/Margin/Layout/Name
@onready var attacker_shield_bar: ProgressBar = $Battlefield/AttackerHPBox/Margin/Layout/ShieldBar
@onready var attacker_armor_bar: ProgressBar = $Battlefield/AttackerHPBox/Margin/Layout/ArmorBar
@onready var attacker_hp_bar: ProgressBar = $Battlefield/AttackerHPBox/Margin/Layout/HPBar
@onready var attacker_count_lbl: Label = $Battlefield/AttackerHPBox/Margin/Layout/CountLabel

@onready var defender_box: PanelContainer = $Battlefield/DefenderHPBox
@onready var defender_name_lbl: Label = $Battlefield/DefenderHPBox/Margin/Layout/Name
@onready var defender_shield_bar: ProgressBar = $Battlefield/DefenderHPBox/Margin/Layout/ShieldBar
@onready var defender_armor_bar: ProgressBar = $Battlefield/DefenderHPBox/Margin/Layout/ArmorBar
@onready var defender_hp_bar: ProgressBar = $Battlefield/DefenderHPBox/Margin/Layout/HPBar
@onready var defender_count_lbl: Label = $Battlefield/DefenderHPBox/Margin/Layout/CountLabel

@onready var skip_btn: Button = $DialogBox/Margin/HBox/ControlButtons/SkipButton
@onready var close_btn: Button = $DialogBox/Margin/HBox/ControlButtons/CloseButton

# Grid configurations
var grid_center_a = Vector2(290, 240)
var grid_center_b = Vector2(862, 240)

# Map ship instance ID -> grid slot index (0 to 8)
var ship_slots: Dictionary = {}

# Battle report variables
var report_data: Dictionary = {}
var initial_a_ships: Dictionary = {}
var initial_b_ships: Dictionary = {}
var current_a_ships: Dictionary = {}
var current_b_ships: Dictionary = {}

var total_a_initial_count: int = 0
var total_b_initial_count: int = 0
var active_a_count: int = 0
var active_b_count: int = 0

# Event playback
var event_queue: Array = []
var playback_timer: float = 0.0
var delay_between_events: float = 0.95
var is_playing: bool = false
var is_skipped: bool = false

# Visuals state
var active_attacker_id: int = 0
var active_attacker_name: String = ""
var active_attacker_hull: String = "frigate"

var active_defender_id: int = 0
var active_defender_name: String = ""
var active_defender_hull: String = "frigate"

# Offsets for animation
var attacker_pos_offset: Vector2 = Vector2.ZERO
var defender_pos_offset: Vector2 = Vector2.ZERO

var attacker_shake_offset: Vector2 = Vector2.ZERO
var defender_shake_offset: Vector2 = Vector2.ZERO

var attacker_fade: float = 1.0
var defender_fade: float = 1.0

# Active projectile drawing
var active_projectile: Dictionary = {} # type, start, end, progress, color
var active_explosions: Array = [] # position, radius, max_radius, color, lifetime
var damage_popups: Array = [] # position, text, color, lifetime

# Stars for background
var stars: Array = []

# Premium Styleboxes for Visualizer Drawing
var header_style_a: StyleBoxFlat
var header_style_b: StyleBoxFlat
var slot_style_a: StyleBoxFlat
var slot_style_b: StyleBoxFlat

func _ready() -> void:
	# 1. Bypassing parent container sizing by setting size to viewport size
	top_level = true
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0
	offset_top = 0
	
	_resize_to_viewport()
	get_tree().root.size_changed.connect(_resize_to_viewport)
	
	dialog_text.scroll_following = true
	
	# Hide skip button and enable close button by default
	skip_btn.visible = false
	close_btn.disabled = false
	
	# Style the ProgressBar components
	_style_bar(attacker_shield_bar, Color.CYAN)
	_style_bar(attacker_armor_bar, Color.GOLDENROD)
	_style_bar(attacker_hp_bar, Color.GREEN)
	
	_style_bar(defender_shield_bar, Color.CYAN)
	_style_bar(defender_armor_bar, Color.GOLDENROD)
	_style_bar(defender_hp_bar, Color.GREEN)
	
	# Style the panels with translucent dark glassmorphism styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.16, 0.85) # Translucent dark background
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.0, 0.75, 0.85, 0.8) # Cyan border for attacker
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.shadow_color = Color(0.0, 0.75, 0.85, 0.15) # Neon cyan shadow glow
	panel_style.shadow_size = 8
	
	attacker_box.add_theme_stylebox_override("panel", panel_style)
	
	var defender_panel_style = panel_style.duplicate()
	defender_panel_style.border_color = Color(1.0, 0.3, 0.2, 0.8) # Red border for defender
	defender_panel_style.shadow_color = Color(1.0, 0.3, 0.2, 0.15) # Neon red shadow glow
	defender_box.add_theme_stylebox_override("panel", defender_panel_style)
	
	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.04, 0.06, 0.10, 0.85) # Translucent dark log box background
	dialog_style.border_width_left = 1
	dialog_style.border_width_top = 1
	dialog_style.border_width_right = 1
	dialog_style.border_width_bottom = 1
	dialog_style.border_color = Color(0.15, 0.25, 0.35, 0.6)
	dialog_style.corner_radius_top_left = 6
	dialog_style.corner_radius_top_right = 6
	dialog_style.corner_radius_bottom_left = 6
	dialog_style.corner_radius_bottom_right = 6
	dialog_style.shadow_color = Color(0, 0, 0, 0.3)
	dialog_style.shadow_size = 10
	
	var dialog_box = $DialogBox
	if dialog_box:
		dialog_box.add_theme_stylebox_override("panel", dialog_style)
		
	# Initialize top header styleboxes for Visualizer drawing
	header_style_a = StyleBoxFlat.new()
	header_style_a.bg_color = Color(0.06, 0.09, 0.16, 0.85)
	header_style_a.border_width_left = 2
	header_style_a.border_width_top = 2
	header_style_a.border_width_right = 2
	header_style_a.border_width_bottom = 2
	header_style_a.border_color = Color(0.0, 0.75, 0.85, 0.8) # Cyan border
	header_style_a.corner_radius_top_left = 6
	header_style_a.corner_radius_top_right = 6
	header_style_a.corner_radius_bottom_left = 6
	header_style_a.corner_radius_bottom_right = 6
	header_style_a.shadow_color = Color(0.0, 0.75, 0.85, 0.15)
	header_style_a.shadow_size = 8
	
	header_style_b = header_style_a.duplicate()
	header_style_b.bg_color = Color(0.15, 0.04, 0.04, 0.85)
	header_style_b.border_color = Color(1.0, 0.3, 0.2, 0.8) # Red border
	header_style_b.shadow_color = Color(1.0, 0.3, 0.2, 0.15) # Red shadow
	
	# Initialize weapon slots styleboxes for Visualizer drawing
	slot_style_a = StyleBoxFlat.new()
	slot_style_a.bg_color = Color(0.06, 0.09, 0.16, 0.85)
	slot_style_a.border_width_left = 1
	slot_style_a.border_width_top = 1
	slot_style_a.border_width_right = 1
	slot_style_a.border_width_bottom = 1
	slot_style_a.border_color = Color(0.0, 0.75, 0.85, 0.5) # Glowing cyan
	slot_style_a.corner_radius_top_left = 3
	slot_style_a.corner_radius_top_right = 3
	slot_style_a.corner_radius_bottom_left = 3
	slot_style_a.corner_radius_bottom_right = 3
	
	slot_style_b = slot_style_a.duplicate()
	slot_style_b.bg_color = Color(0.15, 0.04, 0.04, 0.85)
	slot_style_b.border_color = Color(1.0, 0.3, 0.2, 0.5) # Glowing red
	
	# Style the dialogue control buttons
	_style_action_button(skip_btn, Color(0.85, 0.55, 0.15))
	_style_action_button(close_btn, Color(0.0, 0.75, 0.85))
		
	# Reposition HP boxes to bottom-left and bottom-right above the logs terminal
	# Giving them a compact 260x95px size to prevent covering the grid cells
	attacker_box.custom_minimum_size = Vector2(260, 95)
	attacker_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	attacker_box.offset_left = 30
	attacker_box.offset_top = -290
	attacker_box.offset_right = 290
	attacker_box.offset_bottom = -195
	
	defender_box.custom_minimum_size = Vector2(260, 95)
	defender_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	defender_box.offset_left = -290
	defender_box.offset_top = -290
	defender_box.offset_right = -30
	defender_box.offset_bottom = -195
	
	# Apply compact margin overrides
	var attacker_margin = attacker_box.get_node("Margin") as MarginContainer
	if attacker_margin:
		attacker_margin.add_theme_constant_override("margin_left", 10)
		attacker_margin.add_theme_constant_override("margin_top", 6)
		attacker_margin.add_theme_constant_override("margin_right", 10)
		attacker_margin.add_theme_constant_override("margin_bottom", 6)
		
	var defender_margin = defender_box.get_node("Margin") as MarginContainer
	if defender_margin:
		defender_margin.add_theme_constant_override("margin_left", 10)
		defender_margin.add_theme_constant_override("margin_top", 6)
		defender_margin.add_theme_constant_override("margin_right", 10)
		defender_margin.add_theme_constant_override("margin_bottom", 6)
		
	# Apply compact separation overrides
	var attacker_layout = attacker_box.get_node("Margin/Layout") as VBoxContainer
	if attacker_layout:
		attacker_layout.add_theme_constant_override("separation", 2)
		
	var defender_layout = defender_box.get_node("Margin/Layout") as VBoxContainer
	if defender_layout:
		defender_layout.add_theme_constant_override("separation", 2)
		
	# Apply compact font overrides
	attacker_name_lbl.add_theme_font_size_override("font_size", 13)
	attacker_name_lbl.visible = false
	attacker_box.get_node("Margin/Layout/ShieldLabel").add_theme_font_size_override("font_size", 10)
	attacker_box.get_node("Margin/Layout/ArmorLabel").add_theme_font_size_override("font_size", 10)
	attacker_box.get_node("Margin/Layout/HPLabel").add_theme_font_size_override("font_size", 10)
	attacker_count_lbl.add_theme_font_size_override("font_size", 11)
	
	defender_name_lbl.add_theme_font_size_override("font_size", 13)
	defender_name_lbl.visible = false
	defender_box.get_node("Margin/Layout/ShieldLabel").add_theme_font_size_override("font_size", 10)
	defender_box.get_node("Margin/Layout/ArmorLabel").add_theme_font_size_override("font_size", 10)
	defender_box.get_node("Margin/Layout/HPLabel").add_theme_font_size_override("font_size", 10)
	defender_count_lbl.add_theme_font_size_override("font_size", 11)
	
	# Apply compact progress bar heights
	attacker_shield_bar.custom_minimum_size.y = 4
	attacker_armor_bar.custom_minimum_size.y = 4
	attacker_hp_bar.custom_minimum_size.y = 4
	defender_shield_bar.custom_minimum_size.y = 4
	defender_armor_bar.custom_minimum_size.y = 4
	defender_hp_bar.custom_minimum_size.y = 4
	
	# Generate background stars covering any display resolution
	for i in range(120):
		stars.append({
			"pos": Vector2(randf_range(0, 2560), randf_range(0, 1600)),
			"size": randf_range(1, 3.5),
			"alpha": randf_range(0.2, 0.9)
		})
		
	# Wire up buttons
	skip_btn.pressed.connect(_on_skip_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	
	# Connect draw calls
	visualizer.draw.connect(_on_visualizer_draw)
	
	# Make HP panels visible
	attacker_box.show()
	defender_box.show()

func _resize_to_viewport() -> void:
	var vp_size = get_viewport_rect().size
	size = vp_size
	global_position = Vector2.ZERO
	
	# Update grid centers dynamically based on viewport size
	var grid_y = 240.0
	if vp_size.y > 648.0:
		grid_y = 90.0 + (vp_size.y - 340.0 - 90.0) / 2.0
	grid_center_a = Vector2(290.0, grid_y)
	grid_center_b = Vector2(vp_size.x - 290.0, grid_y)
	
	if background_dim:
		background_dim.anchor_left = 0.0
		background_dim.anchor_top = 0.0
		background_dim.anchor_right = 0.0
		background_dim.anchor_bottom = 0.0
		background_dim.offset_left = 0
		background_dim.offset_top = 0
		background_dim.size = vp_size
		
	var nebula = get_node_or_null("NebulaEffect") as ColorRect
	if nebula:
		nebula.anchor_left = 0.0
		nebula.anchor_top = 0.0
		nebula.anchor_right = 0.0
		nebula.anchor_bottom = 0.0
		nebula.offset_left = 0
		nebula.offset_top = 0
		nebula.size = vp_size

func initialize(report: Dictionary, start_event_index: int = 0) -> void:
	report_data = report
	
	# DEBUG LOG REPORT TO FILE
	var file = FileAccess.open("user://last_battle_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		
	var dbg = FileAccess.open("user://combat_debug.log", FileAccess.WRITE)
	if dbg:
		dbg.store_line("=== combat_view_ui initialize ===")
		dbg.store_line("initial_a_ships size: " + str(report.get("initial_a_ships", []).size()))
		for s in report.get("initial_a_ships", []):
			dbg.store_line("  ship: id=%s (type=%d), name=%s" % [str(s.get("id")), typeof(s.get("id")), s.get("name")])
		dbg.store_line("structured_rounds events:")
		for r in report.get("structured_rounds", []):
			for ev in r.get("events", []):
				dbg.store_line("  event: def_id=%s (type=%d), att_id=%s (type=%d)" % [
					str(ev.get("defender_id")), typeof(ev.get("defender_id")),
					str(ev.get("attacker_id")), typeof(ev.get("attacker_id"))
				])
		dbg.close()
		
	ship_slots.clear()
	initial_a_ships.clear()
	initial_b_ships.clear()
	current_a_ships.clear()
	current_b_ships.clear()
	
	# Group ships by ID for quick stats reference
	var idx_a = 0
	for s in report.get("initial_a_ships", []):
		initial_a_ships[s["id"]] = s
		var cur = s.duplicate()
		cur["current_hp"] = s.get("max_hp", 100.0)
		cur["current_shield"] = s.get("max_shield", 100.0)
		cur["current_armor"] = s.get("max_armor", 100.0)
		current_a_ships[s["id"]] = cur
		# Map to grid slot
		ship_slots[s["id"]] = idx_a % 9
		idx_a += 1
		
	var idx_b = 0
	for s in report.get("initial_b_ships", []):
		initial_b_ships[s["id"]] = s
		var cur = s.duplicate()
		cur["current_hp"] = s.get("max_hp", 100.0)
		cur["current_shield"] = s.get("max_shield", 100.0)
		cur["current_armor"] = s.get("max_armor", 100.0)
		current_b_ships[s["id"]] = cur
		# Map to grid slot
		ship_slots[s["id"]] = idx_b % 9
		idx_b += 1
		
	total_a_initial_count = initial_a_ships.size()
	total_b_initial_count = initial_b_ships.size()
	
	# Set count labels
	active_a_count = total_a_initial_count
	active_b_count = total_b_initial_count
	
	# Flatten structured rounds into a clean sequence of actions
	event_queue.clear()
	for r in report.get("structured_rounds", []):
		for ev in r.get("events", []):
			event_queue.append(ev)
			
	dialog_text.text = "[color=yellow]⚔️ 探测到敌对目标，战斗警报！ ⚔️[/color]\n[color=gray]%s 星系战区[/color]\n\n" % report.get("system_name", "星际")
	dialog_text.text += "红方: %s (进攻)  vs  蓝方: %s (防守)\n" % [report.get("attacker"), report.get("defender")]
	dialog_text.text += "[color=cyan]双方进入战术对抗轨道。播放交火记录...[/color]\n"
	
	if start_event_index > 0:
		var popped_count = min(start_event_index, event_queue.size())
		var destroyed_a = 0
		var destroyed_b = 0
		var fast_forward_logs = ""
		
		for i in range(popped_count):
			var ev = event_queue[i]
			# Update real-time health dictionary for fast-forwarded items
			var side = ev["attacker_side"]
			if side == "A":
				var target = current_b_ships.get(ev["defender_id"])
				if target:
					target["current_shield"] = ev["new_shield"]
					target["current_armor"] = ev["new_armor"]
					target["current_hp"] = ev["new_hp"]
			else:
				var target = current_a_ships.get(ev["defender_id"])
				if target:
					target["current_shield"] = ev["new_shield"]
					target["current_armor"] = ev["new_armor"]
					target["current_hp"] = ev["new_hp"]
					
			if ev.get("is_destroyed", false):
				if ev["attacker_side"] == "A":
					destroyed_b += 1
				else:
					destroyed_a += 1
					
			# Generate log line
			var weapon_tag = "[color=yellow][%s][/color]" % ev["weapon_name"]
			var attacker_tag = "[color=cyan]%s[/color]" % ev["attacker_name"]
			var defender_tag = "[color=red]%s[/color]" % ev["defender_name"]
			var log_line = ""
			if ev["hit"]:
				var dmg_val = ev["damage"]
				log_line = "* %s 使用 %s 轰击 %s，造成 [color=orange]%.1f[/color] 点伤害" % [attacker_tag, weapon_tag, defender_tag, dmg_val]
				if ev["is_destroyed"]:
					log_line += " [color=red][ 击毁 !!! ][/color]"
			else:
				log_line = "* %s 使用 %s 射击 %s，[color=gray]未能命中 (Miss)[/color]" % [attacker_tag, weapon_tag, defender_tag]
			fast_forward_logs += log_line + "\n"
			
		# Remove the popped events from the queue
		for i in range(popped_count):
			event_queue.pop_front()
			
		active_a_count = max(0, total_a_initial_count - destroyed_a)
		active_b_count = max(0, total_b_initial_count - destroyed_b)
		dialog_text.text += fast_forward_logs
		dialog_text.text += "[color=gray]... 以上为已跳过的交战记录 ...[/color]\n"
		
	_update_fleet_hp_bars()
	
	is_playing = true
	is_skipped = false
	playback_timer = 0.5 # Start playback shortly

func _update_count_labels() -> void:
	attacker_count_lbl.text = "存活舰船: %d / %d" % [active_a_count, total_a_initial_count]
	defender_count_lbl.text = "存活舰船: %d / %d" % [active_b_count, total_b_initial_count]

func _get_fleet_totals(side: String) -> Dictionary:
	var cur_sh = 0.0
	var cur_ar = 0.0
	var cur_hp = 0.0
	var max_sh = 0.0
	var max_ar = 0.0
	var max_hp = 0.0
	
	var initial_ships = initial_a_ships if side == "A" else initial_b_ships
	var current_ships = current_a_ships if side == "A" else current_b_ships
	
	for id in initial_ships:
		var init = initial_ships[id]
		var cur = current_ships.get(id, {})
		max_sh += init.get("max_shield", 100.0)
		max_ar += init.get("max_armor", 100.0)
		max_hp += init.get("max_hp", 100.0)
		if not cur.is_empty():
			cur_sh += cur.get("current_shield", 0.0)
			cur_ar += cur.get("current_armor", 0.0)
			cur_hp += cur.get("current_hp", 0.0)
			
	return {
		"cur_shield": cur_sh, "max_shield": max_sh,
		"cur_armor": cur_ar, "max_armor": max_ar,
		"cur_hp": cur_hp, "max_hp": max_hp
	}

func _update_fleet_hp_bars() -> void:
	var stats_a = _get_fleet_totals("A")
	attacker_shield_bar.max_value = stats_a["max_shield"]
	attacker_shield_bar.value = stats_a["cur_shield"]
	attacker_armor_bar.max_value = stats_a["max_armor"]
	attacker_armor_bar.value = stats_a["cur_armor"]
	attacker_hp_bar.max_value = stats_a["max_hp"]
	attacker_hp_bar.value = stats_a["cur_hp"]
	
	attacker_name_lbl.text = "我方防御状态 (Defenses)"
	
	var stats_b = _get_fleet_totals("B")
	defender_shield_bar.max_value = stats_b["max_shield"]
	defender_shield_bar.value = stats_b["cur_shield"]
	defender_armor_bar.max_value = stats_b["max_armor"]
	defender_armor_bar.value = stats_b["cur_armor"]
	defender_hp_bar.max_value = stats_b["max_hp"]
	defender_hp_bar.value = stats_b["cur_hp"]
	
	defender_name_lbl.text = "敌方防御状态 (Defenses)"
	
	_update_count_labels()

func _style_bar(bar: ProgressBar, color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", sb)
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.18, 0.6) # Sleek translucent dark blue/gray
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)

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

func _process(delta: float) -> void:
	_update_visual_effects(delta)
	
	if not is_playing:
		return
		
	playback_timer -= delta
	if playback_timer <= 0.0:
		if not event_queue.is_empty():
			_play_next_event()
			playback_timer = delay_between_events
		else:
			_end_combat()

func _update_visual_effects(delta: float) -> void:
	attacker_pos_offset = attacker_pos_offset.lerp(Vector2.ZERO, delta * 8.0)
	defender_pos_offset = defender_pos_offset.lerp(Vector2.ZERO, delta * 8.0)
	
	attacker_shake_offset = attacker_shake_offset.lerp(Vector2.ZERO, delta * 12.0)
	defender_shake_offset = defender_shake_offset.lerp(Vector2.ZERO, delta * 12.0)
	
	if not active_projectile.is_empty():
		active_projectile["progress"] += delta * 4.0
		if active_projectile["progress"] >= 1.0:
			active_projectile.clear()
			
	var remaining_exp = []
	for exp in active_explosions:
		exp["lifetime"] -= delta
		exp["radius"] = lerp(0.0, exp["max_radius"], 1.0 - exp["lifetime"] / 0.4)
		if exp["lifetime"] > 0:
			remaining_exp.append(exp)
	active_explosions = remaining_exp
	
	var remaining_popups = []
	for pop in damage_popups:
		pop["lifetime"] -= delta
		pop["pos"].y -= delta * 50.0
		if pop["lifetime"] > 0:
			remaining_popups.append(pop)
	damage_popups = remaining_popups
	
	visualizer.queue_redraw()

func _play_next_event() -> void:
	var ev = event_queue.pop_front()
	var is_attacker_a = (ev["attacker_side"] == "A")
	
	# Update active HP values of targets
	_update_hp_bar_values(ev)
	
	# Setup active ship variables
	if is_attacker_a:
		_set_active_ship("A", ev["attacker_id"], ev["attacker_name"])
		_set_active_ship("B", ev["defender_id"], ev["defender_name"])
	else:
		_set_active_ship("B", ev["attacker_id"], ev["attacker_name"])
		_set_active_ship("A", ev["defender_id"], ev["defender_name"])
		
	# Find target slot positions on grids
	var slot_a = ship_slots.get(ev["attacker_id"] if is_attacker_a else ev["defender_id"], 4)
	var slot_b = ship_slots.get(ev["defender_id"] if is_attacker_a else ev["attacker_id"], 4)
	
	var fire_start = _get_cell_center(grid_center_a, slot_a) if is_attacker_a else _get_cell_center(grid_center_b, slot_b)
	var fire_end = _get_cell_center(grid_center_b, slot_b) if is_attacker_a else _get_cell_center(grid_center_a, slot_a)
	
	var dir = (fire_end - fire_start).normalized()
	if is_attacker_a:
		attacker_pos_offset = dir * -15.0 # Recoil backward
	else:
		defender_pos_offset = dir * -15.0
		
	var proj_color = Color.CYAN if is_attacker_a else Color.RED
	active_projectile = {
		"type": ev["weapon_type"],
		"start": fire_start,
		"end": fire_end,
		"progress": 0.0,
		"color": proj_color
	}
	
	var log_line = ""
	var weapon_tag = "[color=yellow][%s][/color]" % ev["weapon_name"]
	var attacker_tag = "[color=cyan]%s[/color]" % ev["attacker_name"]
	var defender_tag = "[color=red]%s[/color]" % ev["defender_name"]
	
	if ev["hit"]:
		var dmg_val = ev["damage"]
		log_line = "* %s 使用 %s 轰击 %s，造成 [color=orange]%.1f[/color] 点伤害" % [attacker_tag, weapon_tag, defender_tag, dmg_val]
		
		get_tree().create_timer(0.2).timeout.connect(func():
			if is_attacker_a:
				defender_shake_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
				active_explosions.append({
					"pos": fire_end,
					"radius": 0.0,
					"max_radius": 35.0,
					"color": Color.ORANGE_RED,
					"lifetime": 0.4
				})
				damage_popups.append({
					"pos": fire_end + Vector2(-20, -35),
					"text": "-%d" % int(dmg_val),
					"color": Color(0.2, 1.0, 0.2), # Green damage popups matching the design
					"lifetime": 0.8
				})
			else:
				attacker_shake_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
				active_explosions.append({
					"pos": fire_end,
					"radius": 0.0,
					"max_radius": 35.0,
					"color": Color.ORANGE_RED,
					"lifetime": 0.4
				})
				damage_popups.append({
					"pos": fire_end + Vector2(-20, -35),
					"text": "-%d" % int(dmg_val),
					"color": Color(0.2, 1.0, 0.2),
					"lifetime": 0.8
				})
		)
		
		if ev["is_destroyed"]:
			log_line += " [color=red][ 击毁 !!! ][/color]"
			get_tree().create_timer(0.3).timeout.connect(func():
				if is_attacker_a:
					active_b_count = max(0, active_b_count - 1)
					defender_fade = 0.0
					active_explosions.append({
						"pos": fire_end,
						"radius": 0.0,
						"max_radius": 60.0,
						"color": Color.YELLOW,
						"lifetime": 0.6
					})
				else:
					active_a_count = max(0, active_a_count - 1)
					attacker_fade = 0.0
					active_explosions.append({
						"pos": fire_end,
						"radius": 0.0,
						"max_radius": 60.0,
						"color": Color.YELLOW,
						"lifetime": 0.6
					})
				_update_fleet_hp_bars()
			)
	else:
		log_line = "* %s 使用 %s 射击 %s，[color=gray]未能命中 (Miss)[/color]" % [attacker_tag, weapon_tag, defender_tag]
		get_tree().create_timer(0.2).timeout.connect(func():
			damage_popups.append({
				"pos": fire_end + Vector2(-15, -35),
				"text": "MISS",
				"color": Color.LIGHT_GRAY,
				"lifetime": 0.8
			})
		)
		
	dialog_text.text += log_line + "\n"
	
	# Autoscroll
	var scroll = dialog_text.get_parent() as ScrollContainer
	if scroll and is_inside_tree():
		get_tree().process_frame.connect(func():
			scroll.scroll_vertical = int(dialog_text.size.y)
		, CONNECT_ONE_SHOT)

func _set_active_ship(side: String, id: int, ship_name: String) -> void:
	if side == "A":
		if active_attacker_id != id:
			active_attacker_id = id
			active_attacker_name = ship_name
			attacker_fade = 1.0
			var ship_info = initial_a_ships.get(id, {})
			active_attacker_hull = ship_info.get("hull_id", "frigate")
	else:
		if active_defender_id != id:
			active_defender_id = id
			active_defender_name = ship_name
			defender_fade = 1.0
			var ship_info = initial_b_ships.get(id, {})
			active_defender_hull = ship_info.get("hull_id", "frigate")

func _update_hp_bar_values(ev: Dictionary) -> void:
	var is_attacker_a = (ev["attacker_side"] == "A")
	if is_attacker_a:
		var def_id = ev["defender_id"]
		var ship_b = current_b_ships.get(def_id, {})
		if not ship_b.is_empty():
			ship_b["current_shield"] = ev["new_shield"]
			ship_b["current_armor"] = ev["new_armor"]
			ship_b["current_hp"] = ev["new_hp"]
	else:
		var def_id = ev["defender_id"]
		var ship_a = current_a_ships.get(def_id, {})
		if not ship_a.is_empty():
			ship_a["current_shield"] = ev["new_shield"]
			ship_a["current_armor"] = ev["new_armor"]
			ship_a["current_hp"] = ev["new_hp"]
			
	# Update database stats
	var stats_a = _get_fleet_totals("A")
	var stats_b = _get_fleet_totals("B")
	
	# Trigger HP progress bars slide down smoothly
	if is_attacker_a:
		var t = create_tween().set_parallel(true)
		t.tween_property(defender_shield_bar, "value", stats_b["cur_shield"], 0.4)
		t.tween_property(defender_armor_bar, "value", stats_b["cur_armor"], 0.4)
		t.tween_property(defender_hp_bar, "value", stats_b["cur_hp"], 0.4)
	else:
		var t = create_tween().set_parallel(true)
		t.tween_property(attacker_shield_bar, "value", stats_a["cur_shield"], 0.4)
		t.tween_property(attacker_armor_bar, "value", stats_a["cur_armor"], 0.4)
		t.tween_property(attacker_hp_bar, "value", stats_a["cur_hp"], 0.4)

func _end_combat() -> void:
	is_playing = false
	skip_btn.disabled = true
	close_btn.disabled = false
	
	var winner = report_data.get("winner")
	var result_color = "cyan" if winner == "A" else ("red" if winner == "B" else "gray")
	var winner_str = "进攻方 (Player) 胜利" if winner == "A" else ("防守方 胜利" if winner == "B" else "平局")
	
	dialog_text.text += "\n\n=========================================\n"
	dialog_text.text += "🏆 [color=%s]最终交战结果: %s[/color] 🏆\n" % [result_color, winner_str]
	dialog_text.text += "残骸战后打捞: \n"
	dialog_text.text += "  [color=silver]- 金属: %d[/color]\n" % report_data["salvage"].get("metal", 0)
	dialog_text.text += "  [color=lightblue]- 晶体: %d[/color]\n" % report_data["salvage"].get("crystal", 0)
	dialog_text.text += "  [color=lightgreen]- 重氢: %d[/color]\n" % report_data["salvage"].get("deuterium", 0)
	dialog_text.text += "=========================================\n"
	
	var scroll = dialog_text.get_parent() as ScrollContainer
	if scroll and is_inside_tree():
		get_tree().process_frame.connect(func():
			scroll.scroll_vertical = int(dialog_text.size.y)
		, CONNECT_ONE_SHOT)
		
	_show_settlement_screen()

func _show_settlement_screen() -> void:
	if has_node("SettlementPanel"):
		return
		
	var winner = report_data.get("winner")
	var is_victory = (winner == "A")
	
	# Root container
	var panel = PanelContainer.new()
	panel.name = "SettlementPanel"
	panel.custom_minimum_size = Vector2(480, 320)
	add_child(panel)
	
	# Set preset and center it
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Glassmorphism StyleBox
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.95) # Dark rich slate blue
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.8, 1.0, 0.9) if is_victory else Color(1.0, 0.3, 0.2, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	
	# Margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)
	
	# VBox layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# 1. Main Title
	var title = Label.new()
	title.text = "⚔️ 战 局 结 算 ⚔️"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	vbox.add_child(title)
	
	# Divider
	var div = ColorRect.new()
	div.custom_minimum_size.y = 1
	div.color = Color(0.15, 0.25, 0.35, 0.8)
	vbox.add_child(div)
	
	# 2. Victory/Defeat Banner
	var banner = Label.new()
	if winner == "A":
		banner.text = "战 役 胜 利\nVICTORY"
		banner.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8)) # Vibrant Cyan-Green
	elif winner == "B":
		banner.text = "战 役 失 败\nDEFEAT"
		banner.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2)) # Orange Red
	else:
		banner.text = "平 局\nDRAW"
		banner.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 22)
	vbox.add_child(banner)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 5
	vbox.add_child(spacer)
	
	# 3. Salvage Panel Title
	var salvage_title = Label.new()
	salvage_title.text = "资源收益回收 (Salvaged):"
	salvage_title.add_theme_font_size_override("font_size", 12)
	salvage_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vbox.add_child(salvage_title)
	
	# 4. Resources Grid
	var res_box = HBoxContainer.new()
	res_box.alignment = BoxContainer.ALIGNMENT_CENTER
	res_box.add_theme_constant_override("separation", 25)
	vbox.add_child(res_box)
	
	var salvage = report_data.get("salvage", {})
	
	# Metal
	var met_lbl = Label.new()
	met_lbl.text = "金属: %d" % salvage.get("metal", 0)
	met_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	met_lbl.add_theme_font_size_override("font_size", 13)
	res_box.add_child(met_lbl)
	
	# Crystal
	var cry_lbl = Label.new()
	cry_lbl.text = "晶体: %d" % salvage.get("crystal", 0)
	cry_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	cry_lbl.add_theme_font_size_override("font_size", 13)
	res_box.add_child(cry_lbl)
	
	# Deuterium
	var deu_lbl = Label.new()
	deu_lbl.text = "重氢: %d" % salvage.get("deuterium", 0)
	deu_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	deu_lbl.add_theme_font_size_override("font_size", 13)
	res_box.add_child(deu_lbl)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 10
	vbox.add_child(spacer2)
	
	# 5. Exit Button
	var btn = Button.new()
	btn.text = "确认并退出 (Confirm & Exit)"
	btn.custom_minimum_size.y = 38
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_close_pressed)
	vbox.add_child(btn)
	
	# Style the button beautifully
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.12, 0.2, 0.35, 0.8)
	btn_style_normal.border_width_left = 1
	btn_style_normal.border_width_top = 1
	btn_style_normal.border_width_right = 1
	btn_style_normal.border_width_bottom = 1
	btn_style_normal.border_color = Color(0.0, 0.8, 1.0, 0.5) if is_victory else Color(1.0, 0.3, 0.2, 0.5)
	btn_style_normal.corner_radius_top_left = 6
	btn_style_normal.corner_radius_top_right = 6
	btn_style_normal.corner_radius_bottom_left = 6
	btn_style_normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", btn_style_normal)
	
	var btn_style_hover = btn_style_normal.duplicate() as StyleBoxFlat
	btn_style_hover.bg_color = Color(0.18, 0.3, 0.5, 0.9)
	btn_style_hover.border_color = Color(0.0, 0.8, 1.0, 0.9) if is_victory else Color(1.0, 0.3, 0.2, 0.9)
	btn.add_theme_stylebox_override("hover", btn_style_hover)
	
	var btn_style_pressed = btn_style_hover.duplicate() as StyleBoxFlat
	btn_style_pressed.bg_color = Color(0.08, 0.15, 0.28, 0.9)
	btn.add_theme_stylebox_override("pressed", btn_style_pressed)
	
	# Focus grabber
	btn.grab_focus.call_deferred()
	
	# 6. Subtle Exit Prompt
	var prompt = Label.new()
	prompt.text = "[ 亦可按 ESC 直接退出战场 ]"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	vbox.add_child(prompt)
	
	# Animate in (Fade & Pop)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(240, 160)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_skip_pressed() -> void:
	is_skipped = true
	is_playing = false
	event_queue.clear()
	
	dialog_text.text = "[color=yellow]⚔️ 战术对抗记录 跳过 ⚔️[/color]\n"
	for line in report_data.get("logs", []):
		dialog_text.text += line + "\n"
		
	# Apply final health configurations immediately
	for s_id in initial_a_ships:
		var final_state = _find_final_ship_state(s_id, "A")
		current_a_ships[s_id] = final_state
	for s_id in initial_b_ships:
		var final_state = _find_final_ship_state(s_id, "B")
		current_b_ships[s_id] = final_state
		
	_update_fleet_hp_bars()
	_end_combat()

func _find_final_ship_state(ship_id: int, side: String) -> Dictionary:
	var rounds = report_data.get("structured_rounds", [])
	var final_hp = 100.0
	var final_shield = 100.0
	var final_armor = 100.0
	
	var init_dict = initial_a_ships if side == "A" else initial_b_ships
	var init_data = init_dict.get(ship_id, {})
	final_hp = init_data.get("max_hp", 100.0)
	final_shield = init_data.get("max_shield", 100.0)
	final_armor = init_data.get("max_armor", 100.0)
	
	# Trace final event modifying this ship
	for r in rounds:
		for ev in r.get("events", []):
			if ev["defender_id"] == ship_id and ev["defender_side"] == side:
				final_hp = ev["new_hp"]
				final_shield = ev["new_shield"]
				final_armor = ev["new_armor"]
				
	return {
		"id": ship_id,
		"hull_id": init_data.get("hull_id", "frigate"),
		"current_hp": final_hp,
		"current_shield": final_shield,
		"current_armor": final_armor,
		"max_hp": init_data.get("max_hp", 100.0),
		"max_shield": init_data.get("max_shield", 100.0),
		"max_armor": init_data.get("max_armor", 100.0)
	}

func _on_close_pressed() -> void:
	if not is_playing or is_skipped:
		var node_id = report_data.get("node_id", "")
		if node_id != "" and NetworkManager.active_combats.has(node_id):
			NetworkManager.active_combats.erase(node_id)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if close_btn and not close_btn.disabled and close_btn.visible:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

func _on_visualizer_draw() -> void:
	# 1. Twinkling Stars
	for star in stars:
		var star_col = Color(1.0, 1.0, 1.0, star["alpha"])
		visualizer.draw_circle(star["pos"], star["size"], star_col)
		
	# 2. Draw Top Commander Hologram Panels
	# 2. Draw Top Commander Hologram Panels
	var font = visualizer.get_theme_font("font")
	var W = size.x
	var H = size.y
	
	# Left (Attacker) Header
	var panel_a_rect = Rect2(30, 20, 360, 88)
	visualizer.draw_style_box(header_style_a, panel_a_rect)
	_draw_hologram_avatar(visualizer, Vector2(40, 30), Vector2(50, 68), Color(0.0, 0.85, 1.0))
	
	var attacker_faction = NetworkManager.get_faction_display_name(report_data.get("attacker", "我方"))
	var lv_a = max(3, total_a_initial_count)
	visualizer.draw_string(font, Vector2(105, 42), attacker_faction, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.CYAN)
	visualizer.draw_string(font, Vector2(240, 42), "LV %d" % lv_a, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)
	visualizer.draw_string(font, Vector2(105, 60), "尼古拉斯 (代号: 001)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	
	var stats_a = _get_fleet_totals("A")
	var total_a_val = int(stats_a["cur_shield"] + stats_a["cur_armor"] + stats_a["cur_hp"])
	var max_a_val = int(stats_a["max_shield"] + stats_a["max_armor"] + stats_a["max_hp"])
	visualizer.draw_string(font, Vector2(105, 78), "总结构: %d / %d" % [total_a_val, max_a_val], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)
	
	# Right (Defender) Header
	var panel_b_rect = Rect2(W - 390, 20, 360, 88)
	visualizer.draw_style_box(header_style_b, panel_b_rect)
	_draw_hologram_avatar(visualizer, Vector2(W - 90, 30), Vector2(50, 68), Color(1.0, 0.3, 0.2))
	
	var defender_faction = NetworkManager.get_faction_display_name(report_data.get("defender", "敌方"))
	var lv_b = max(5, total_b_initial_count * 2)
	visualizer.draw_string(font, Vector2(W - 380, 42), defender_faction, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.ORANGE_RED)
	visualizer.draw_string(font, Vector2(W - 232, 42), "LV %d" % lv_b, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)
	visualizer.draw_string(font, Vector2(W - 380, 60), "地球联合 (代号: 040)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	
	var stats_b = _get_fleet_totals("B")
	var total_b_val = int(stats_b["cur_shield"] + stats_b["cur_armor"] + stats_b["cur_hp"])
	var max_b_val = int(stats_b["max_shield"] + stats_b["max_armor"] + stats_b["max_hp"])
	visualizer.draw_string(font, Vector2(W - 380, 78), "总结构: %d / %d" % [total_b_val, max_b_val], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)
	
	# Top Center Gold Arrow
	var arrow_pts = PackedVector2Array([
		Vector2(W / 2.0 - 26, 45),
		Vector2(W / 2.0 + 14, 55),
		Vector2(W / 2.0 - 26, 65),
		Vector2(W / 2.0 - 16, 55)
	])
	visualizer.draw_colored_polygon(arrow_pts, Color.GOLD)
	visualizer.draw_polyline(arrow_pts, Color.WHITE, 1.5)
	
	# 3. Draw Left Grid cells (Attacker)
	for idx in range(9):
		var poly = _get_grid_cell_polygon(grid_center_a, idx)
		var is_active_cell = (active_attacker_id != 0 and ship_slots.get(active_attacker_id, -1) == idx and is_playing)
		var border_col = Color(0.0, 1.0, 1.0, 0.8) if is_active_cell else Color(0.0, 0.8, 1.0, 0.25)
		var fill_col = Color(0.0, 0.4, 0.6, 0.2) if is_active_cell else Color(0.0, 0.2, 0.4, 0.06)
		visualizer.draw_colored_polygon(poly, fill_col)
		visualizer.draw_polyline(poly, border_col, 2.0 if is_active_cell else 1.0)
		
	# Draw Right Grid cells (Defender)
	for idx in range(9):
		var poly = _get_grid_cell_polygon(grid_center_b, idx)
		var is_active_cell = (active_defender_id != 0 and ship_slots.get(active_defender_id, -1) == idx and is_playing)
		var border_col = Color(1.0, 0.4, 0.3, 0.8) if is_active_cell else Color(1.0, 0.3, 0.2, 0.25)
		var fill_col = Color(0.6, 0.15, 0.1, 0.2) if is_active_cell else Color(0.4, 0.1, 0.1, 0.06)
		visualizer.draw_colored_polygon(poly, fill_col)
		visualizer.draw_polyline(poly, border_col, 2.0 if is_active_cell else 1.0)

	# 4. Draw Side A (Attacker) Ships
	for s_id in initial_a_ships:
		var state = current_a_ships.get(s_id, {})
		if state.is_empty() or state.get("current_hp", 0.0) <= 0.0:
			continue
			
		var slot = ship_slots.get(s_id, 0)
		var cell_center = _get_cell_center(grid_center_a, slot)
		
		var draw_pos = cell_center
		var fade = 1.0
		if active_attacker_id == s_id:
			draw_pos += attacker_pos_offset + attacker_shake_offset
			fade = attacker_fade
		elif active_defender_id == s_id:
			draw_pos += attacker_pos_offset + attacker_shake_offset
			fade = attacker_fade
			
		_draw_warship(visualizer, draw_pos, state.get("hull_id", "frigate"), "A", fade)
		_draw_ship_health_bar(visualizer, draw_pos, state, Color.CYAN)
		
	# Draw Side B (Defender) Ships
	for s_id in initial_b_ships:
		var state = current_b_ships.get(s_id, {})
		if state.is_empty() or state.get("current_hp", 0.0) <= 0.0:
			continue
			
		var slot = ship_slots.get(s_id, 0)
		var cell_center = _get_cell_center(grid_center_b, slot)
		
		var draw_pos = cell_center
		var fade = 1.0
		if active_defender_id == s_id:
			draw_pos += defender_pos_offset + defender_shake_offset
			fade = defender_fade
		elif active_attacker_id == s_id:
			draw_pos += defender_pos_offset + defender_shake_offset
			fade = defender_fade
			
		_draw_warship(visualizer, draw_pos, state.get("hull_id", "frigate"), "B", fade)
		_draw_ship_health_bar(visualizer, draw_pos, state, Color.RED)
		
	# 5. Draw Active Projectile Line/Effect
	if not active_projectile.is_empty():
		var proj = active_projectile
		var start_p = proj["start"]
		var end_p = proj["end"]
		var t = proj["progress"]
		var type = proj["type"]
		var cur_p = start_p.lerp(end_p, t)
		
		if type == "laser":
			var beam_color = proj["color"]
			beam_color.a = 1.0 - t
			visualizer.draw_line(start_p, end_p, beam_color, 4.0)
			visualizer.draw_line(start_p, end_p, Color.WHITE, 1.5)
		elif type == "kinetic":
			visualizer.draw_circle(cur_p, 4.0, Color.GOLD)
			visualizer.draw_circle(cur_p, 2.0, Color.WHITE)
		else: # missile
			var trail_p = start_p.lerp(end_p, max(0.0, t - 0.12))
			visualizer.draw_line(trail_p, cur_p, Color.ORANGE, 3.0)
			visualizer.draw_circle(cur_p, 5.0, Color.RED)
			visualizer.draw_circle(cur_p, 2.5, Color.YELLOW)
			
	# 6. Draw explosions
	for exp in active_explosions:
		var col = exp["color"]
		col.a = exp["lifetime"] / 0.4
		visualizer.draw_circle(exp["pos"], exp["radius"], col)
		visualizer.draw_circle(exp["pos"], exp["radius"] * 0.5, Color.WHITE)
		
	# 7. Draw floating text popups
	var font_size = visualizer.get_theme_font_size("font_size")
	for pop in damage_popups:
		var col = pop["color"]
		col.a = pop["lifetime"] / 0.8
		visualizer.draw_string(font, pop["pos"], pop["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size + 4, col)
		
	# 8. Draw Attacker Weapon Slots (bottom left)
	for i in range(6):
		var box_pos = Vector2(30 + i * 45, H - 312)
		var box_rect = Rect2(box_pos, Vector2(38, 24))
		visualizer.draw_style_box(slot_style_a, box_rect)
		if i == 0:
			visualizer.draw_line(box_pos + Vector2(8, 12), box_pos + Vector2(30, 12), Color.CYAN, 2.0)
		elif i == 1:
			visualizer.draw_circle(box_pos + Vector2(19, 12), 3.0, Color.GOLD)
			
	# Draw Defender Weapon Slots (bottom right)
	for i in range(6):
		var box_pos = Vector2(W - 310 + i * 45, H - 312)
		var box_rect = Rect2(box_pos, Vector2(38, 24))
		visualizer.draw_style_box(slot_style_b, box_rect)
		if i == 0:
			visualizer.draw_line(box_pos + Vector2(8, 12), box_pos + Vector2(30, 12), Color.RED, 2.0)
		elif i == 1:
			visualizer.draw_circle(box_pos + Vector2(19, 12), 3.0, Color.GOLD)

func _draw_hologram_avatar(ctrl: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	ctrl.draw_rect(Rect2(pos, size), color, false, 1.5)
	var grid_color = color
	grid_color.a = 0.15
	for x in range(5, int(size.x), 10):
		ctrl.draw_line(pos + Vector2(x, 0), pos + Vector2(x, size.y), grid_color, 1.0)
	for y in range(5, int(size.y), 10):
		ctrl.draw_line(pos + Vector2(0, y), pos + Vector2(size.x, y), grid_color, 1.0)
		
	var center = pos + size / 2.0
	var face_color = color
	face_color.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.04) # Hologram flicker effect
	
	ctrl.draw_arc(center, size.x * 0.28, 0, TAU, 16, face_color, 1.5)
	ctrl.draw_line(center - Vector2(size.x * 0.22, size.y * 0.05), center + Vector2(size.x * 0.22, -size.y * 0.05), face_color, 2.0)
	ctrl.draw_polyline(PackedVector2Array([
		center + Vector2(-size.x * 0.12, size.y * 0.22),
		center + Vector2(-size.x * 0.22, size.y * 0.38),
		center + Vector2(size.x * 0.22, size.y * 0.38),
		center + Vector2(size.x * 0.12, size.y * 0.22)
	]), face_color, 1.5)
	
	var scan_y = int(Time.get_ticks_msec() * 0.035) % int(size.y)
	var scan_color = color
	scan_color.a = 0.35
	ctrl.draw_line(pos + Vector2(0, scan_y), pos + Vector2(size.x, scan_y), scan_color, 1.5)

func _draw_ship_health_bar(ctrl: Control, pos: Vector2, state: Dictionary, color: Color) -> void:
	var bar_width = 30.0
	var bar_height = 2.0
	var bar_pos = pos + Vector2(-bar_width / 2.0, 16.0)
	
	var cur_hp = state.get("current_hp", 1.0)
	var max_hp = state.get("max_hp", 1.0)
	var pct = clamp(float(cur_hp) / float(max_hp), 0.0, 1.0)
	
	ctrl.draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color.BLACK)
	ctrl.draw_rect(Rect2(bar_pos, Vector2(bar_width * pct, bar_height)), color)

func _get_grid_cell_polygon(center_pos: Vector2, idx: int) -> PackedVector2Array:
	var row = idx / 3
	var w_top = 0.0
	var w_bottom = 0.0
	var h = 0.0
	var cell_pos = center_pos
	
	match row:
		0:
			w_top = 50.0
			w_bottom = 60.0
			h = 20.0
			cell_pos += Vector2(-90 + (idx % 3) * 90, -45)
		1:
			w_top = 62.0
			w_bottom = 74.0
			h = 24.0
			cell_pos += Vector2(-105 + (idx % 3) * 105, 5)
		_:
			w_top = 74.0
			w_bottom = 88.0
			h = 28.0
			cell_pos += Vector2(-120 + (idx % 3) * 120, 55)
			
	var poly = PackedVector2Array()
	poly.append(cell_pos + Vector2(-w_top / 2.0, -h / 2.0))
	poly.append(cell_pos + Vector2(w_top / 2.0, -h / 2.0))
	poly.append(cell_pos + Vector2(w_bottom / 2.0, h / 2.0))
	poly.append(cell_pos + Vector2(-w_bottom / 2.0, h / 2.0))
	return poly

func _get_cell_center(center_pos: Vector2, idx: int) -> Vector2:
	var row = idx / 3
	match row:
		0:
			return center_pos + Vector2(-90 + (idx % 3) * 90, -45)
		1:
			return center_pos + Vector2(-105 + (idx % 3) * 105, 5)
		_:
			return center_pos + Vector2(-120 + (idx % 3) * 120, 55)

func _draw_warship(ctrl: Control, pos: Vector2, hull: String, side: String, fade: float) -> void:
	var texture = SHIP_TEXTURES.get(hull)
	if not texture:
		return
		
	var angle = deg_to_rad(-12.0)
	var size = texture.get_size()
	
	var base_scale = 0.2
	match hull:
		"frigate":
			base_scale = 0.16
		"destroyer":
			base_scale = 0.20
		"cruiser":
			base_scale = 0.25
		"battleship":
			base_scale = 0.30
			
	var mult = 1.1 if side == "A" else 0.95
	var scale_x = base_scale * mult
	if side == "A":
		scale_x = -scale_x
	var scale = Vector2(scale_x, base_scale * mult)
	
	ctrl.draw_set_transform(pos, angle, scale)
	ctrl.draw_texture(texture, -size / 2, Color(1, 1, 1, fade))
	ctrl.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
