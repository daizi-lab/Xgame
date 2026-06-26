extends Control

const ComponentsData = preload("res://src/core/data/components_data.gd")
const ShipDesign = preload("res://src/core/models/ship_design.gd")

var current_tab: int = 0
var tab_buttons: Array[Button] = []
@onready var component_list: VBoxContainer = $MainLayout/LeftPanel/ScrollContainer/ComponentList
@onready var hull_option: OptionButton = $MainLayout/CenterPanel/HullSelection/HullOption
@onready var hull_preview: TextureRect = $MainLayout/CenterPanel/HullPreview

@onready var weapon_grid: GridContainer = $MainLayout/CenterPanel/SlotsScroll/SlotsContainer/WeaponSection/Grid
@onready var shield_grid: GridContainer = $MainLayout/CenterPanel/SlotsScroll/SlotsContainer/ShieldSection/Grid
@onready var utility_grid: GridContainer = $MainLayout/CenterPanel/SlotsScroll/SlotsContainer/UtilitySection/Grid

@onready var name_edit: LineEdit = $MainLayout/RightPanel/NameInput/LineEdit
@onready var weight_label: Label = $MainLayout/RightPanel/StatsBox/WeightProgress/Label
@onready var weight_bar: ProgressBar = $MainLayout/RightPanel/StatsBox/WeightProgress/Bar
@onready var energy_label: Label = $MainLayout/RightPanel/StatsBox/EnergyProgress/Label
@onready var energy_bar: ProgressBar = $MainLayout/RightPanel/StatsBox/EnergyProgress/Bar

@onready var hp_label: Label = $MainLayout/RightPanel/StatsBox/HP
@onready var shield_label: Label = $MainLayout/RightPanel/StatsBox/Shield
@onready var armor_label: Label = $MainLayout/RightPanel/StatsBox/Armor
@onready var speed_label: Label = $MainLayout/RightPanel/StatsBox/Speed
@onready var cost_detail: Label = $MainLayout/RightPanel/StatsBox/CostDetail
@onready var warning_label: Label = $MainLayout/RightPanel/WarningLabel
@onready var save_button: Button = $MainLayout/RightPanel/SaveButton

var current_design: ShipDesign
var blueprints: Dictionary = {}
const BLUEPRINTS_SAVE_PATH = "user://ssw_blueprints.json"
var _hull_buttons: Array[Button] = []

func _ready() -> void:
	print("[ShipDesignerUI] Initializing Designer UI...")
	
	# Premium HUD Overhaul: Clean headers and wrap panels dynamically
	var left_panel = $MainLayout/LeftPanel
	var center_panel = $MainLayout/CenterPanel
	var right_panel = $MainLayout/RightPanel
	
	# Set responsive sizes before wrapping to fit in 1024x576 resolution
	left_panel.custom_minimum_size = Vector2(250, 0)
	right_panel.custom_minimum_size = Vector2(250, 0)
	
	# Enable autowrap to prevent RightPanel from stretching due to long text
	weight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	energy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shield_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	armor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Set progress bars to be sleeker (8px height) to save vertical space
	weight_bar.custom_minimum_size.y = 8
	energy_bar.custom_minimum_size.y = 8
	
	_clean_and_style_header(left_panel, "组件库 (Components)")
	_clean_and_style_header(center_panel, "战舰装配区 (Assembly Yard)")
	_clean_and_style_header(right_panel, "设计蓝图与指标 (Specifications)")
	
	_wrap_panel(left_panel, Color(0.0, 0.75, 0.85, 0.4))
	_wrap_panel(center_panel, Color(0.0, 0.75, 0.85, 0.4))
	_wrap_panel(right_panel, Color(0.0, 0.75, 0.85, 0.4))
	
	# Set deep background color
	$Background.color = Color(0.04, 0.05, 0.08, 1.0)
	
	var old_tab_bar = left_panel.get_node_or_null("TabBar")
	if old_tab_bar:
		var tab_panel = PanelContainer.new()
		tab_panel.name = "TabPanel"
		tab_panel.size_flags_horizontal = SIZE_EXPAND_FILL
		
		var tab_panel_style = StyleBoxFlat.new()
		tab_panel_style.bg_color = Color(0.04, 0.06, 0.08, 0.6) # deep dark translucent
		tab_panel_style.border_width_left = 1
		tab_panel_style.border_width_top = 1
		tab_panel_style.border_width_right = 1
		tab_panel_style.border_width_bottom = 1
		tab_panel_style.border_color = Color(0.0, 0.75, 0.85, 0.25)
		tab_panel_style.corner_radius_top_left = 6
		tab_panel_style.corner_radius_top_right = 6
		tab_panel_style.corner_radius_bottom_left = 6
		tab_panel_style.corner_radius_bottom_right = 6
		tab_panel.add_theme_stylebox_override("panel", tab_panel_style)
		
		var tab_margin = MarginContainer.new()
		tab_margin.add_theme_constant_override("margin_left", 4)
		tab_margin.add_theme_constant_override("margin_top", 4)
		tab_margin.add_theme_constant_override("margin_right", 4)
		tab_margin.add_theme_constant_override("margin_bottom", 4)
		tab_panel.add_child(tab_margin)
		
		var tab_hbox = HBoxContainer.new()
		tab_hbox.name = "TabHBox"
		tab_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
		tab_hbox.add_theme_constant_override("separation", 4)
		tab_margin.add_child(tab_hbox)
		
		var idx = old_tab_bar.get_index()
		left_panel.remove_child(old_tab_bar)
		old_tab_bar.queue_free()
		
		left_panel.add_child(tab_panel)
		left_panel.move_child(tab_panel, idx)
		
		var tab_titles = ["武器", "防御", "辅助"]
		for i in range(tab_titles.size()):
			var btn = Button.new()
			btn.text = tab_titles[i]
			btn.size_flags_horizontal = SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 28)
			btn.toggle_mode = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.pressed.connect(_on_tab_button_pressed.bind(i))
			tab_hbox.add_child(btn)
			tab_buttons.append(btn)
			
		# Select first tab by default
		_update_tab_button_visuals(0)
	
	# Style option drop down button
	var opt_style_normal = StyleBoxFlat.new()
	opt_style_normal.bg_color = Color(0.08, 0.12, 0.18, 0.8)
	opt_style_normal.border_width_left = 1
	opt_style_normal.border_width_top = 1
	opt_style_normal.border_width_right = 1
	opt_style_normal.border_width_bottom = 1
	opt_style_normal.border_color = Color(0.0, 0.75, 0.85, 0.4)
	opt_style_normal.corner_radius_top_left = 4
	opt_style_normal.corner_radius_top_right = 4
	opt_style_normal.corner_radius_bottom_left = 4
	opt_style_normal.corner_radius_bottom_right = 4
	opt_style_normal.content_margin_left = 10
	opt_style_normal.content_margin_right = 10
	
	var opt_style_hover = opt_style_normal.duplicate()
	opt_style_hover.bg_color = Color(0.12, 0.18, 0.25, 0.9)
	opt_style_hover.border_color = Color(0.0, 0.85, 1.0, 1.0)
	
	hull_option.add_theme_stylebox_override("normal", opt_style_normal)
	hull_option.add_theme_stylebox_override("hover", opt_style_hover)
	hull_option.add_theme_stylebox_override("pressed", opt_style_hover)
	hull_option.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	hull_option.add_theme_color_override("font_hover_color", Color(0.3, 0.95, 1.0))
	hull_option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var popup = hull_option.get_popup()
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
		
	# Style LineEdit
	var edit_style = StyleBoxFlat.new()
	edit_style.bg_color = Color(0.05, 0.07, 0.1, 0.8)
	edit_style.border_width_left = 1
	edit_style.border_width_top = 1
	edit_style.border_width_right = 1
	edit_style.border_width_bottom = 1
	edit_style.border_color = Color(0.0, 0.75, 0.85, 0.4)
	edit_style.corner_radius_top_left = 4
	edit_style.corner_radius_top_right = 4
	edit_style.corner_radius_bottom_left = 4
	edit_style.corner_radius_bottom_right = 4
	edit_style.content_margin_left = 10
	edit_style.content_margin_right = 10
	
	name_edit.add_theme_stylebox_override("normal", edit_style)
	name_edit.add_theme_stylebox_override("focus", edit_style)
	name_edit.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	
	# Style ProgressBars
	_style_progress_bar(weight_bar, Color.CYAN)
	_style_progress_bar(energy_bar, Color.GREEN)
	weight_bar.modulate = Color.WHITE
	energy_bar.modulate = Color.WHITE
	
	# Style slot section labels
	var w_lbl = weapon_grid.get_parent().get_node_or_null("Label")
	if w_lbl:
		w_lbl.add_theme_font_size_override("font_size", 11)
		w_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	var s_lbl = shield_grid.get_parent().get_node_or_null("Label")
	if s_lbl:
		s_lbl.add_theme_font_size_override("font_size", 11)
		s_lbl.add_theme_color_override("font_color", Color(0.15, 0.8, 0.5))
	var u_lbl = utility_grid.get_parent().get_node_or_null("Label")
	if u_lbl:
		u_lbl.add_theme_font_size_override("font_size", 11)
		u_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.15))
		
	# Style stats labels
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	shield_label.add_theme_font_size_override("font_size", 11)
	shield_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	armor_label.add_theme_font_size_override("font_size", 11)
	armor_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.15))
	speed_label.add_theme_font_size_override("font_size", 11)
	speed_label.add_theme_color_override("font_color", Color(0.15, 0.8, 0.5))
	var cost_lbl = right_panel.get_node_or_null("StatsBox/Cost")
	if cost_lbl:
		cost_lbl.text = "预计建造消耗:"
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	
	# Style action buttons
	_style_action_button(save_button, Color(0.0, 0.75, 0.85))
	
	# Load existing blueprints
	_load_blueprints()
	
	# Connect signals
	# Handled programmatically via tab_buttons
	hull_option.item_selected.connect(_on_hull_selected)
	name_edit.text_changed.connect(_on_name_changed)
	save_button.pressed.connect(_on_save_pressed)
	
	# Populate hull selections
	hull_option.clear()
	var idx = 0
	for h_id in ComponentsData.HULLS:
		var name = ComponentsData.HULLS[h_id].get("name", h_id)
		hull_option.add_item(name, idx)
		hull_option.set_item_metadata(idx, h_id)
		idx += 1
		
	# Hide default option and label
	var hull_selection_container = hull_option.get_parent()
	var default_label = hull_selection_container.get_node_or_null("Label") if hull_selection_container else null
	if default_label:
		default_label.visible = false
	hull_option.visible = false
	
	# Wrap HullSelection in a styled PanelContainer capsule to match segmented style
	if hull_selection_container and not hull_selection_container.get_parent() is PanelContainer:
		var parent_node = hull_selection_container.get_parent()
		var s_idx = hull_selection_container.get_index()
		parent_node.remove_child(hull_selection_container)
		
		var hull_panel = PanelContainer.new()
		hull_panel.name = "HullSelectionPanel"
		hull_panel.size_flags_horizontal = SIZE_EXPAND_FILL
		
		var hull_panel_style = StyleBoxFlat.new()
		hull_panel_style.bg_color = Color(0.04, 0.06, 0.08, 0.6) # deep dark translucent
		hull_panel_style.border_width_left = 1
		hull_panel_style.border_width_top = 1
		hull_panel_style.border_width_right = 1
		hull_panel_style.border_width_bottom = 1
		hull_panel_style.border_color = Color(0.0, 0.75, 0.85, 0.25)
		hull_panel_style.corner_radius_top_left = 6
		hull_panel_style.corner_radius_top_right = 6
		hull_panel_style.corner_radius_bottom_left = 6
		hull_panel_style.corner_radius_bottom_right = 6
		hull_panel.add_theme_stylebox_override("panel", hull_panel_style)
		
		var hull_margin = MarginContainer.new()
		hull_margin.add_theme_constant_override("margin_left", 4)
		hull_margin.add_theme_constant_override("margin_top", 4)
		hull_margin.add_theme_constant_override("margin_right", 4)
		hull_margin.add_theme_constant_override("margin_bottom", 4)
		hull_panel.add_child(hull_margin)
		
		hull_margin.add_child(hull_selection_container)
		hull_selection_container.add_theme_constant_override("separation", 4)
		
		parent_node.add_child(hull_panel)
		parent_node.move_child(hull_panel, s_idx)
		
	# Create custom segmented hull buttons
	_hull_buttons.clear()
	var h_idx = 0
	for h_id in ComponentsData.HULLS:
		var h_data = ComponentsData.HULLS[h_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(105, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Set button internal hierarchy
		var margin = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		margin.add_child(vbox)
		
		# Hull name
		var h_name_lbl = Label.new()
		var clean_name = h_data.get("name").replace("船体", "")
		h_name_lbl.text = clean_name
		h_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h_name_lbl.add_theme_font_size_override("font_size", 12)
		h_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(h_name_lbl)
		
		# Hull spec details
		var total_slots = h_data.get("weapon_slots", 0) + h_data.get("shield_slots", 0) + h_data.get("utility_slots", 0)
		var h_desc_lbl = Label.new()
		h_desc_lbl.text = "HP:%d | 插槽:%d" % [h_data.get("hp", 0), total_slots]
		h_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h_desc_lbl.add_theme_font_size_override("font_size", 9)
		h_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(h_desc_lbl)
		
		btn.pressed.connect(_on_custom_hull_button_pressed.bind(h_idx))
		hull_selection_container.add_child(btn)
		_hull_buttons.append(btn)
		h_idx += 1
		
	# Select first hull as default
	if hull_option.item_count > 0:
		hull_option.select(0)
		_on_hull_selected(0)
		_update_hull_buttons_visuals(0)
		
	# Draw components list
	_update_component_list()
	
	print("[_ready] MainLayout children count: ", $MainLayout.get_child_count())
	for c in $MainLayout.get_children():
		print("[_ready] Child: ", c.name, " class: ", c.get_class())

func _on_tab_changed(tab_idx: int) -> void:
	_update_component_list()

func _on_hull_selected(index: int) -> void:
	var h_id = hull_option.get_item_metadata(index)
	current_design = ShipDesign.new(name_edit.text.strip_edges(), h_id)
	
	# Load hull preview image
	var tex_path = "res://assets/images/hulls/%s.png" % h_id
	if ResourceLoader.exists(tex_path):
		hull_preview.texture = load(tex_path)
	else:
		hull_preview.texture = null
		
	_rebuild_slots()
	_update_stats()

func _on_custom_hull_button_pressed(index: int) -> void:
	hull_option.select(index)
	_on_hull_selected(index)
	_update_hull_buttons_visuals(index)

func _update_hull_buttons_visuals(selected_idx: int) -> void:
	for i in range(_hull_buttons.size()):
		var btn = _hull_buttons[i]
		btn.button_pressed = (i == selected_idx)
		
		var style_normal = StyleBoxFlat.new()
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.corner_radius_bottom_right = 4
		style_normal.content_margin_top = 6
		style_normal.content_margin_bottom = 6
		
		var style_hover = style_normal.duplicate()
		
		var vbox_node = btn.get_node_or_null("MarginContainer/VBoxContainer")
		if not vbox_node:
			continue
		var name_lbl = vbox_node.get_child(0) as Label
		var desc_lbl = vbox_node.get_child(1) as Label
		
		if i == selected_idx:
			# Active Selected Style: Glowing neon cyan card
			style_normal.bg_color = Color(0.0, 0.5, 0.6, 0.25) # glass cyan tint
			style_normal.border_width_left = 1
			style_normal.border_width_top = 1
			style_normal.border_width_right = 1
			style_normal.border_width_bottom = 1
			style_normal.border_color = Color(0.0, 0.9, 1.0, 1.0) # bright cyan border
			style_normal.shadow_color = Color(0.0, 0.9, 1.0, 0.2)
			style_normal.shadow_size = 4
			
			if name_lbl: name_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			if desc_lbl: desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_normal)
			btn.add_theme_stylebox_override("pressed", style_normal)
			btn.add_theme_stylebox_override("focus", style_normal)
		else:
			# Inactive Normal Style: Dark, transparent card with NO border
			style_normal.bg_color = Color(0, 0, 0, 0)
			style_normal.border_width_left = 0
			style_normal.border_width_top = 0
			style_normal.border_width_right = 0
			style_normal.border_width_bottom = 0
			style_normal.shadow_size = 0
			
			# Inactive Hover Style: Brighten background on hover
			style_hover.bg_color = Color(0.0, 0.75, 0.85, 0.08)
			style_hover.border_width_left = 0
			style_hover.border_width_top = 0
			style_hover.border_width_right = 0
			style_hover.border_width_bottom = 0
			style_hover.shadow_size = 0
			
			if name_lbl: name_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65)) # muted grey-blue text
			if desc_lbl: desc_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_normal)
			btn.add_theme_stylebox_override("focus", style_normal)

func _on_name_changed(new_text: String) -> void:
	current_design.design_name = new_text.strip_edges()
	_update_stats()

func _update_component_list() -> void:
	# Clear previous list
	for child in component_list.get_children():
		child.queue_free()
		
	var active_tab = current_tab
	var data_source = {}
	var category = ""
	
	if active_tab == 0:
		data_source = ComponentsData.WEAPONS
		category = "weapon"
	elif active_tab == 1:
		data_source = ComponentsData.SHIELDS
		category = "shield"
	elif active_tab == 2:
		data_source = ComponentsData.UTILITIES
		category = "utility"
		
	for comp_id in data_source:
		var item = data_source[comp_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 72)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Inner container structure for margins and responsive padding
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Connect hover animations for premium slide effect
		btn.mouse_entered.connect(func():
			var tween = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_method(
				func(val): margin.add_theme_constant_override("margin_left", val),
				margin.get_theme_constant("margin_left"),
				14,
				0.15
			)
		)
		btn.mouse_exited.connect(func():
			var tween = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_method(
				func(val): margin.add_theme_constant_override("margin_left", val),
				margin.get_theme_constant("margin_left"),
				8,
				0.15
			)
		)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(hbox)
		
		# Colors & Badge text based on category/type
		var base_color = Color(0.0, 0.85, 1.0) # default cyan
		var badge_text = "EQUIP"
		var badge_bg = Color(0.0, 0.5, 0.6, 0.15)
		var badge_border = Color(0.0, 0.85, 1.0, 0.4)
		
		if category == "weapon":
			base_color = Color(0.95, 0.4, 0.3) # coral red
			var w_type = item.get("type", "")
			if w_type == "laser":
				badge_text = "激光"
			elif w_type == "kinetic":
				badge_text = "动能"
			elif w_type == "missile":
				badge_text = "导弹"
			badge_bg = Color(0.85, 0.3, 0.2, 0.15)
			badge_border = Color(0.95, 0.4, 0.3, 0.4)
		elif category == "shield":
			base_color = Color(0.2, 0.85, 0.5) # emerald green
			if item.get("shield_hp", 0) > 0:
				badge_text = "护盾"
			else:
				badge_text = "装甲"
			badge_bg = Color(0.15, 0.7, 0.4, 0.15)
			badge_border = Color(0.2, 0.85, 0.5, 0.4)
		elif category == "utility":
			base_color = Color(0.9, 0.6, 0.15) # amber gold
			if item.get("energy_bonus", 0) > 0:
				badge_text = "能源"
			elif item.get("speed_bonus", 0) > 0:
				badge_text = "推进"
			elif item.get("cargo_bonus", 0) > 0:
				badge_text = "货舱"
			badge_bg = Color(0.8, 0.5, 0.1, 0.15)
			badge_border = Color(0.9, 0.6, 0.15, 0.4)
		
		# High-tech slot panel for the icon
		var icon_panel = PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(44, 44)
		icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var icon_panel_style = StyleBoxFlat.new()
		icon_panel_style.bg_color = Color(0.04, 0.06, 0.08, 0.8)
		icon_panel_style.border_width_left = 1
		icon_panel_style.border_width_top = 1
		icon_panel_style.border_width_right = 1
		icon_panel_style.border_width_bottom = 1
		icon_panel_style.border_color = badge_border
		icon_panel_style.corner_radius_top_left = 4
		icon_panel_style.corner_radius_top_right = 4
		icon_panel_style.corner_radius_bottom_left = 4
		icon_panel_style.corner_radius_bottom_right = 4
		icon_panel.add_theme_stylebox_override("panel", icon_panel_style)
		
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var icon_path = _get_component_icon_path(comp_id)
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		
		var icon_center = CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.add_child(icon_rect)
		icon_panel.add_child(icon_center)
		
		hbox.add_child(icon_panel)
		
		# Text Container
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(vbox)
		
		# Title HBox for badge alignment
		var title_hbox = HBoxContainer.new()
		title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title_hbox)
		
		# Component Title
		var name_lbl = Label.new()
		name_lbl.text = item.get("name")
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", base_color)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_hbox.add_child(name_lbl)
		
		# Type Badge Panel
		var badge_panel = PanelContainer.new()
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = badge_bg
		badge_style.border_width_left = 1
		badge_style.border_width_top = 1
		badge_style.border_width_right = 1
		badge_style.border_width_bottom = 1
		badge_style.border_color = badge_border
		badge_style.corner_radius_top_left = 3
		badge_style.corner_radius_top_right = 3
		badge_style.corner_radius_bottom_left = 3
		badge_style.corner_radius_bottom_right = 3
		badge_style.content_margin_left = 4
		badge_style.content_margin_right = 4
		badge_style.content_margin_top = 1
		badge_style.content_margin_bottom = 1
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var badge_lbl = Label.new()
		badge_lbl.text = badge_text
		badge_lbl.add_theme_font_size_override("font_size", 8)
		badge_lbl.add_theme_color_override("font_color", base_color)
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.add_child(badge_lbl)
		
		title_hbox.add_child(badge_panel)
		
		# Primary Stats Row
		var stats_hbox1 = HBoxContainer.new()
		stats_hbox1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_hbox1.add_theme_constant_override("separation", 10)
		vbox.add_child(stats_hbox1)
		
		if category == "weapon":
			_create_stat_pair(stats_hbox1, "攻击", str(item.get("damage", 0)), Color(0.95, 0.4, 0.3))
			_create_stat_pair(stats_hbox1, "命中", "%d%%" % int(item.get("accuracy", 0.0) * 100), Color(0.9, 0.75, 0.15))
		elif category == "shield":
			if item.get("shield_hp", 0) > 0:
				_create_stat_pair(stats_hbox1, "护盾值", str(item.get("shield_hp", 0)), Color(0.0, 0.85, 1.0))
			else:
				_create_stat_pair(stats_hbox1, "装甲值", str(item.get("armor_hp", 0)), Color(0.2, 0.85, 0.5))
		elif category == "utility":
			if item.get("energy_bonus", 0) > 0:
				_create_stat_pair(stats_hbox1, "产电", "+%d" % item.get("energy_bonus", 0), Color(0.2, 0.85, 0.5))
			if item.get("speed_bonus", 0) > 0:
				_create_stat_pair(stats_hbox1, "航速", "+%d" % item.get("speed_bonus", 0), Color(0.0, 0.85, 1.0))
			if item.get("cargo_bonus", 0) > 0:
				_create_stat_pair(stats_hbox1, "货舱", "+%d" % item.get("cargo_bonus", 0), Color(0.9, 0.6, 0.15))
				
		# Secondary Stats Row (Weight and Energy Use)
		var stats_hbox2 = HBoxContainer.new()
		stats_hbox2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_hbox2.add_theme_constant_override("separation", 10)
		vbox.add_child(stats_hbox2)
		
		_create_stat_pair(stats_hbox2, "重量", str(item.get("weight")), Color(0.85, 0.9, 0.95))
		_create_stat_pair(stats_hbox2, "电耗", str(item.get("energy_use", 0)), Color(0.85, 0.9, 0.95))
		
		btn.pressed.connect(_add_component_to_first_slot.bind(category, comp_id))
		_style_component_button(btn, category)
		component_list.add_child(btn)

func _rebuild_slots() -> void:
	# Clear slots grids
	for grid in [weapon_grid, shield_grid, utility_grid]:
		for child in grid.get_children():
			child.queue_free()
			
	var hull_data = current_design.get_hull_data()
	if hull_data.is_empty():
		return
		
	# Weapons slots
	var w_slots = hull_data.get("weapon_slots", 0)
	for i in range(w_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 48)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		
		if i < current_design.weapons.size():
			var comp_id = current_design.weapons[i]
			var comp_name = ComponentsData.WEAPONS[comp_id].get("name")
			
			# Custom hierarchy to prevent stretching
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 6)
			margin.add_theme_constant_override("margin_right", 6)
			margin.add_theme_constant_override("margin_top", 4)
			margin.add_theme_constant_override("margin_bottom", 4)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(margin)
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 6)
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(hbox)
			
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(28, 28)
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var icon_path = _get_component_icon_path(comp_id)
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path)
			hbox.add_child(icon_rect)
			
			var name_lbl = Label.new()
			name_lbl.text = comp_name
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hbox.add_child(name_lbl)
			
			btn.tooltip_text = "点击移除该武器"
			btn.pressed.connect(_remove_component.bind("weapon", i))
			_style_slot_button(btn, "weapon", false, comp_id)
		else:
			btn.text = "[ 空武器槽 ]"
			btn.disabled = true
			_style_slot_button(btn, "weapon", true)
		weapon_grid.add_child(btn)
		
	# Shields slots
	var s_slots = hull_data.get("shield_slots", 0)
	for i in range(s_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 48)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		
		if i < current_design.shields.size():
			var comp_id = current_design.shields[i]
			var comp_name = ComponentsData.SHIELDS[comp_id].get("name")
			
			# Custom hierarchy to prevent stretching
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 6)
			margin.add_theme_constant_override("margin_right", 6)
			margin.add_theme_constant_override("margin_top", 4)
			margin.add_theme_constant_override("margin_bottom", 4)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(margin)
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 6)
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(hbox)
			
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(28, 28)
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var icon_path = _get_component_icon_path(comp_id)
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path)
			hbox.add_child(icon_rect)
			
			var name_lbl = Label.new()
			name_lbl.text = comp_name
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hbox.add_child(name_lbl)
			
			btn.tooltip_text = "点击移除该护盾/装甲"
			btn.pressed.connect(_remove_component.bind("shield", i))
			_style_slot_button(btn, "shield", false, comp_id)
		else:
			btn.text = "[ 空防御槽 ]"
			btn.disabled = true
			_style_slot_button(btn, "shield", true)
		shield_grid.add_child(btn)
		
	# Utilities slots
	var u_slots = hull_data.get("utility_slots", 0)
	for i in range(u_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 48)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		
		if i < current_design.utilities.size():
			var comp_id = current_design.utilities[i]
			var comp_name = ComponentsData.UTILITIES[comp_id].get("name")
			
			# Custom hierarchy to prevent stretching
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 6)
			margin.add_theme_constant_override("margin_right", 6)
			margin.add_theme_constant_override("margin_top", 4)
			margin.add_theme_constant_override("margin_bottom", 4)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(margin)
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 6)
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(hbox)
			
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(28, 28)
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var icon_path = _get_component_icon_path(comp_id)
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path)
			hbox.add_child(icon_rect)
			
			var name_lbl = Label.new()
			name_lbl.text = comp_name
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hbox.add_child(name_lbl)
			
			btn.tooltip_text = "点击移除该设备"
			btn.pressed.connect(_remove_component.bind("utility", i))
			_style_slot_button(btn, "utility", false, comp_id)
		else:
			btn.text = "[ 空辅助槽 ]"
			btn.disabled = true
			_style_slot_button(btn, "utility", true)
		utility_grid.add_child(btn)

func _add_component_to_first_slot(category: String, comp_id: String) -> void:
	var hull_data = current_design.get_hull_data()
	
	if category == "weapon":
		if current_design.weapons.size() < hull_data.get("weapon_slots", 0):
			current_design.weapons.append(comp_id)
	elif category == "shield":
		if current_design.shields.size() < hull_data.get("shield_slots", 0):
			current_design.shields.append(comp_id)
	elif category == "utility":
		if current_design.utilities.size() < hull_data.get("utility_slots", 0):
			current_design.utilities.append(comp_id)
			
	_rebuild_slots()
	_update_stats()

func _remove_component(category: String, index: int) -> void:
	if category == "weapon":
		current_design.weapons.remove_at(index)
	elif category == "shield":
		current_design.shields.remove_at(index)
	elif category == "utility":
		current_design.utilities.remove_at(index)
		
	_rebuild_slots()
	_update_stats()

func _update_stats() -> void:
	var hull_data = current_design.get_hull_data()
	if hull_data.is_empty():
		return
		
	# 1. Weight balance
	var total_weight = current_design.get_total_weight()
	var max_weight = hull_data.get("weight_cap", 0.0)
	weight_label.text = "载重 (Weight): %d/%d" % [int(total_weight), int(max_weight)]
	weight_bar.max_value = max_weight
	weight_bar.value = total_weight
	
	if total_weight > max_weight:
		_set_bar_fill_color(weight_bar, Color.RED)
	else:
		_set_bar_fill_color(weight_bar, Color.CYAN)
		
	# 2. Power Grid balance
	# Calculate reactor output (hull base + utility booster bonuses)
	var reactor_output = hull_data.get("energy_cap", 0.0)
	for u_id in current_design.utilities:
		if ComponentsData.UTILITIES.has(u_id):
			reactor_output += ComponentsData.UTILITIES[u_id].get("energy_bonus", 0.0)
			
	# Calculate total consumption
	var power_consumption = 0.0
	var get_use = func(comp_id, data_source):
		if data_source.has(comp_id):
			return data_source[comp_id].get("energy_use", 0.0)
		return 0.0
		
	for w_id in current_design.weapons:
		power_consumption += get_use.call(w_id, ComponentsData.WEAPONS)
	for s_id in current_design.shields:
		power_consumption += get_use.call(s_id, ComponentsData.SHIELDS)
	for u_id in current_design.utilities:
		power_consumption += get_use.call(u_id, ComponentsData.UTILITIES)
		
	var net_power = reactor_output - power_consumption
	energy_label.text = "电力 (Energy): %d/%d (净:%+d)" % [int(power_consumption), int(reactor_output), int(net_power)]
	energy_bar.max_value = reactor_output
	energy_bar.value = power_consumption
	
	if net_power < 0:
		_set_bar_fill_color(energy_bar, Color.RED)
	else:
		_set_bar_fill_color(energy_bar, Color.GREEN)
		
	# 3. Dynamic spec labels
	hp_label.text = "结构 (Hull HP): %d" % current_design.get_total_hull_hp()
	shield_label.text = "护盾 (Shield HP): %d" % current_design.get_total_shield_hp()
	armor_label.text = "装甲 (Armor HP): %d" % current_design.get_total_armor_hp()
	speed_label.text = "速度 (Speed): %d" % current_design.get_speed()
	
	# 4. Costs
	var cost = current_design.get_total_cost()
	cost_detail.text = "金属:%d 晶体:%d 重氢:%d" % [cost["metal"], cost["crystal"], cost["deuterium"]]
	
	# 5. Validation warnings
	var is_valid = true
	var warn_msg = ""
	
	if current_design.design_name.is_empty():
		is_valid = false
		warn_msg = "* 请输入战舰蓝图名称。"
	elif total_weight > max_weight:
		is_valid = false
		warn_msg = "* 超重警告: 设备总重量超过船体载重限制！"
	elif net_power < 0:
		is_valid = false
		warn_msg = "* 过载警告: 能源供应不足！请移除耗电组件或增加辅助反应堆。"
		
	warning_label.text = warn_msg
	save_button.disabled = not is_valid

func _on_save_pressed() -> void:
	if not current_design.is_valid():
		warning_label.text = "* 保存失败：设计违反约束条件！"
		return
		
	# Construct blueprint serialization dictionary
	var bp = {
		"design_name": current_design.design_name,
		"hull_id": current_design.hull_id,
		"weapons": current_design.weapons,
		"shields": current_design.shields,
		"utilities": current_design.utilities
	}
	
	blueprints[current_design.design_name] = bp
	
	# Save to local file
	var file = FileAccess.open(BLUEPRINTS_SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(blueprints)
		file.store_string(json_str)
		file.close()
		print("[ShipDesignerUI] Blueprint saved successfully to: ", BLUEPRINTS_SAVE_PATH)
		warning_label.text = "✓ 蓝图 '%s' 保存成功！" % current_design.design_name
		warning_label.add_theme_color_override("font_color", Color.GREEN)
		
		# Reset warn label color back to red after delay
		get_tree().create_timer(3.0).timeout.connect(func():
			if warning_label.text.begins_with("✓"):
				warning_label.text = ""
			warning_label.add_theme_color_override("font_color", Color.RED)
		)
	else:
		warning_label.text = "* 文件写入失败，无法保存蓝图！"

func _load_blueprints() -> void:
	if FileAccess.file_exists(BLUEPRINTS_SAVE_PATH):
		var file = FileAccess.open(BLUEPRINTS_SAVE_PATH, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			file.close()
			var json = JSON.new()
			var parse_err = json.parse(json_str)
			if parse_err == OK:
				if json.data is Dictionary:
					blueprints = json.data
					print("[ShipDesignerUI] Loaded %d existing blueprints." % blueprints.size())

func _get_component_icon_path(comp_id: String) -> String:
	if comp_id.begins_with("laser"):
		return "res://assets/images/components/laser.png"
	elif comp_id.begins_with("railgun"):
		return "res://assets/images/components/railgun.png"
	elif comp_id.begins_with("missile"):
		return "res://assets/images/components/missile.png"
	elif comp_id.begins_with("deflector"):
		return "res://assets/images/components/shield.png"
	elif comp_id.begins_with("composite_armor"):
		return "res://assets/images/components/armor.png"
	elif comp_id == "reactor_booster":
		return "res://assets/images/components/reactor.png"
	elif comp_id == "cargo_hold":
		return "res://assets/images/components/cargo.png"
	elif comp_id == "afterburner":
		return "res://assets/images/components/afterburner.png"
	return ""

func _wrap_panel(node: Control, color_border: Color) -> void:
	var parent = node.get_parent()
	print("[_wrap_panel] Wrapping node: ", node.name if node else "null", " parent: ", parent.name if parent else "null")
	if not parent:
		print("[_wrap_panel] Parent is null, exiting early!")
		return
	var idx = node.get_index()
	
	# Create premium stylebox
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.8) # translucent deep space blue
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color_border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(color_border.r, color_border.g, color_border.b, 0.12)
	style.shadow_size = 6
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = node.custom_minimum_size
	panel.size_flags_horizontal = node.size_flags_horizontal
	panel.size_flags_vertical = node.size_flags_vertical
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	
	# Reparent the node
	parent.remove_child(node)
	parent.add_child(panel)
	parent.move_child(panel, idx)
	
	margin.add_child(node)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size = Vector2.ZERO # Let panel container govern size
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0

func _clean_and_style_header(panel: VBoxContainer, title_text: String) -> void:
	var header = panel.get_node_or_null("PanelHeader")
	if header:
		var label = header.get_node_or_null("Label") as Label
		if label:
			header.remove_child(label)
			panel.add_child(label)
			panel.move_child(label, 0) # Put it at the top
			label.text = title_text
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.layout_mode = 2 # Container managed
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Add a nice thin HSeparator under the title for that high-tech HUD look
			var sep = HSeparator.new()
			var sep_style = StyleBoxLine.new()
			sep_style.color = Color(0.0, 0.75, 0.85, 0.3)
			sep_style.grow_begin = 4.0
			sep_style.grow_end = 4.0
			sep.add_theme_stylebox_override("line", sep_style)
			panel.add_child(sep)
			panel.move_child(sep, 1)
			
		header.queue_free()

func _style_component_button(btn: Button, category: String) -> void:
	var base_color = Color(0.0, 0.85, 1.0) # default cyan
	if category == "weapon":
		base_color = Color(0.95, 0.4, 0.3) # coral red
	elif category == "shield":
		base_color = Color(0.2, 0.85, 0.5) # emerald green
	elif category == "utility":
		base_color = Color(0.9, 0.6, 0.15) # amber gold
		
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.08, 0.12, 0.45) # glass dark
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(base_color.r, base_color.g, base_color.b, 0.25)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(base_color.r * 0.15, base_color.g * 0.15, base_color.b * 0.15, 0.65)
	style_hover.border_width_left = 1
	style_hover.border_width_top = 1
	style_hover.border_width_right = 1
	style_hover.border_width_bottom = 1
	style_hover.border_color = Color(base_color.r, base_color.g, base_color.b, 0.85)
	style_hover.corner_radius_top_left = 6
	style_hover.corner_radius_top_right = 6
	style_hover.corner_radius_bottom_left = 6
	style_hover.corner_radius_bottom_right = 6
	style_hover.shadow_color = Color(base_color.r, base_color.g, base_color.b, 0.15)
	style_hover.shadow_size = 5
	style_hover.content_margin_left = 8
	style_hover.content_margin_right = 8
	
	var style_pressed = style_hover.duplicate()
	style_pressed.bg_color = Color(base_color.r * 0.05, base_color.g * 0.05, base_color.b * 0.05, 0.85)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_normal)
	btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _style_slot_button(btn: Button, category: String, is_empty: bool, comp_id: String = "") -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	var style_hover = StyleBoxFlat.new()
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	
	if is_empty:
		style_normal.bg_color = Color(0.04, 0.06, 0.09, 0.4)
		style_normal.border_width_left = 1
		style_normal.border_width_top = 1
		style_normal.border_width_right = 1
		style_normal.border_width_bottom = 1
		style_normal.border_color = Color(0.2, 0.25, 0.3, 0.3)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("disabled", style_normal)
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.45, 0.5))
	else:
		var color_base = Color(0.0, 0.75, 0.85) # default weapons cyan
		if category == "shield":
			color_base = Color(0.15, 0.8, 0.5) # defense green
		elif category == "utility":
			color_base = Color(0.85, 0.55, 0.15) # utility orange
			
		style_normal.bg_color = Color(color_base.r * 0.1, color_base.g * 0.1, color_base.b * 0.1, 0.6)
		style_normal.border_width_left = 1
		style_normal.border_width_top = 1
		style_normal.border_width_right = 1
		style_normal.border_width_bottom = 1
		style_normal.border_color = Color(color_base.r * 0.8, color_base.g * 0.8, color_base.b * 0.8, 0.8)
		style_normal.shadow_color = Color(color_base.r, color_base.g, color_base.b, 0.1)
		style_normal.shadow_size = 3
		
		style_hover.bg_color = Color(color_base.r * 0.2, color_base.g * 0.2, color_base.b * 0.2, 0.8)
		style_hover.border_width_left = 1
		style_hover.border_width_top = 1
		style_hover.border_width_right = 1
		style_hover.border_width_bottom = 1
		style_hover.border_color = Color(color_base.r, color_base.g, color_base.b, 1.0)
		style_hover.shadow_color = Color(color_base.r, color_base.g, color_base.b, 0.25)
		style_hover.shadow_size = 5
		
		var style_pressed = style_hover.duplicate()
		style_pressed.bg_color = Color(color_base.r * 0.05, color_base.g * 0.05, color_base.b * 0.05, 0.9)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", style_normal)
		btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _style_progress_bar(bar: ProgressBar, color_base: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color_base
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", sb)
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.18, 0.6)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)

func _set_bar_fill_color(bar: ProgressBar, color: Color) -> void:
	var sb = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if sb:
		sb.bg_color = color
	else:
		var new_sb = StyleBoxFlat.new()
		new_sb.bg_color = color
		new_sb.corner_radius_top_left = 4
		new_sb.corner_radius_top_right = 4
		new_sb.corner_radius_bottom_left = 4
		new_sb.corner_radius_bottom_right = 4
		bar.add_theme_stylebox_override("fill", new_sb)

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

func _on_tab_button_pressed(index: int) -> void:
	# Click sound effect
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_click()
	
	current_tab = index
	_update_tab_button_visuals(index)
	_on_tab_changed(index)

func _update_tab_button_visuals(selected_idx: int) -> void:
	for i in range(tab_buttons.size()):
		var btn = tab_buttons[i]
		btn.button_pressed = (i == selected_idx)
		
		# Define distinct styles for active, inactive, and hover states
		var style_normal = StyleBoxFlat.new()
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.corner_radius_bottom_right = 4
		style_normal.content_margin_top = 6
		style_normal.content_margin_bottom = 6
		style_normal.content_margin_left = 10
		style_normal.content_margin_right = 10
		
		var style_hover = style_normal.duplicate()
		
		if i == selected_idx:
			# Active Selected Style: Glowing neon cyan card
			style_normal.bg_color = Color(0.0, 0.5, 0.6, 0.25) # glass cyan tint
			style_normal.border_width_left = 1
			style_normal.border_width_top = 1
			style_normal.border_width_right = 1
			style_normal.border_width_bottom = 1
			style_normal.border_color = Color(0.0, 0.9, 1.0, 1.0) # bright cyan border
			style_normal.shadow_color = Color(0.0, 0.9, 1.0, 0.2)
			style_normal.shadow_size = 4
			
			btn.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			btn.add_theme_color_override("font_focus_color", Color(0.0, 0.9, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(0.0, 0.9, 1.0))
			btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.9, 1.0))
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_normal)
			btn.add_theme_stylebox_override("pressed", style_normal)
			btn.add_theme_stylebox_override("focus", style_normal)
		else:
			# Inactive Normal Style: Dark, transparent card with NO border
			style_normal.bg_color = Color(0, 0, 0, 0)
			style_normal.border_width_left = 0
			style_normal.border_width_top = 0
			style_normal.border_width_right = 0
			style_normal.border_width_bottom = 0
			style_normal.shadow_size = 0
			
			# Inactive Hover Style: Brighten background on hover
			style_hover.bg_color = Color(0.0, 0.75, 0.85, 0.08)
			style_hover.border_width_left = 0
			style_hover.border_width_top = 0
			style_hover.border_width_right = 0
			style_hover.border_width_bottom = 0
			style_hover.shadow_size = 0
			
			btn.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65)) # muted grey-blue text
			btn.add_theme_color_override("font_focus_color", Color(0.55, 0.6, 0.65))
			btn.add_theme_color_override("font_hover_color", Color(0.0, 0.85, 1.0)) # bright text on hover
			btn.add_theme_color_override("font_pressed_color", Color(0.55, 0.6, 0.65))
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_normal)
			btn.add_theme_stylebox_override("focus", style_normal)

func _create_stat_pair(parent: Control, key: String, val: String, val_color: Color) -> void:
	var pair_hbox = HBoxContainer.new()
	pair_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair_hbox.add_theme_constant_override("separation", 3)
	parent.add_child(pair_hbox)
	
	var key_lbl = Label.new()
	key_lbl.text = key + ":"
	key_lbl.add_theme_font_size_override("font_size", 9)
	key_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6, 0.8)) # muted key color
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair_hbox.add_child(key_lbl)
	
	var val_lbl = Label.new()
	val_lbl.text = val
	val_lbl.add_theme_font_size_override("font_size", 9)
	val_lbl.add_theme_color_override("font_color", val_color) # colored value
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair_hbox.add_child(val_lbl)
