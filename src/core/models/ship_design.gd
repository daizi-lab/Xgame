class_name ShipDesign
extends Resource

const ComponentsData = preload("res://src/core/data/components_data.gd")


@export var design_name: String = ""
@export var hull_id: String = ""
@export var weapons: Array = []
@export var shields: Array = []
@export var utilities: Array = []

func _init(p_name: String = "", p_hull: String = ""):
	design_name = p_name
	hull_id = p_hull

func get_hull_data() -> Dictionary:
	if ComponentsData.HULLS.has(hull_id):
		return ComponentsData.HULLS[hull_id]
	return {}

func get_total_weight() -> float:
	var total: float = 0.0
	# Hulls don't have weight as they define the capacity, but let's check components
	for w_id in weapons:
		if ComponentsData.WEAPONS.has(w_id):
			total += ComponentsData.WEAPONS[w_id].get("weight", 0.0)
	for s_id in shields:
		if ComponentsData.SHIELDS.has(s_id):
			total += ComponentsData.SHIELDS[s_id].get("weight", 0.0)
	for u_id in utilities:
		if ComponentsData.UTILITIES.has(u_id):
			total += ComponentsData.UTILITIES[u_id].get("weight", 0.0)
	return total

func get_total_energy_net() -> float:
	var hull_data = get_hull_data()
	if hull_data.is_empty():
		return 0.0
	
	var production: float = hull_data.get("energy_cap", 0.0)
	var consumption: float = 0.0
	
	for w_id in weapons:
		if ComponentsData.WEAPONS.has(w_id):
			consumption += ComponentsData.WEAPONS[w_id].get("energy_use", 0.0)
	for s_id in shields:
		if ComponentsData.SHIELDS.has(s_id):
			consumption += ComponentsData.SHIELDS[s_id].get("energy_use", 0.0)
	for u_id in utilities:
		if ComponentsData.UTILITIES.has(u_id):
			var u_data = ComponentsData.UTILITIES[u_id]
			consumption += u_data.get("energy_use", 0.0)
			production += u_data.get("energy_bonus", 0.0) # Reactor boosters add to production
			
	return production - consumption

func get_total_cost() -> Dictionary:
	var total = {"metal": 0, "crystal": 0, "deuterium": 0}
	var hull_data = get_hull_data()
	if hull_data.is_empty():
		return total
		
	# Add hull cost
	var h_cost = hull_data.get("cost", {})
	for res in total.keys():
		total[res] += h_cost.get(res, 0)
		
	# Add components costs
	var add_comp_cost = func(comp_data: Dictionary):
		var cost = comp_data.get("cost", {})
		for res in total.keys():
			total[res] += cost.get(res, 0)
			
	for w_id in weapons:
		if ComponentsData.WEAPONS.has(w_id):
			add_comp_cost.call(ComponentsData.WEAPONS[w_id])
	for s_id in shields:
		if ComponentsData.SHIELDS.has(s_id):
			add_comp_cost.call(ComponentsData.SHIELDS[s_id])
	for u_id in utilities:
		if ComponentsData.UTILITIES.has(u_id):
			add_comp_cost.call(ComponentsData.UTILITIES[u_id])
			
	return total

func get_total_shield_hp() -> float:
	var total: float = 0.0
	for s_id in shields:
		if ComponentsData.SHIELDS.has(s_id):
			total += ComponentsData.SHIELDS[s_id].get("shield_hp", 0.0)
	return total

func get_total_armor_hp() -> float:
	var total: float = 0.0
	for s_id in shields:
		if ComponentsData.SHIELDS.has(s_id):
			total += ComponentsData.SHIELDS[s_id].get("armor_hp", 0.0)
	return total

func get_total_hull_hp() -> float:
	var hull_data = get_hull_data()
	return hull_data.get("hp", 0.0)

func get_speed() -> float:
	var hull_data = get_hull_data()
	if hull_data.is_empty():
		return 0.0
	var speed: float = hull_data.get("base_speed", 0.0)
	for u_id in utilities:
		if ComponentsData.UTILITIES.has(u_id):
			speed += ComponentsData.UTILITIES[u_id].get("speed_bonus", 0.0)
	return speed

func is_valid() -> bool:
	var hull_data = get_hull_data()
	if hull_data.is_empty():
		return false
		
	# Check slots limits
	if weapons.size() > hull_data.get("weapon_slots", 0):
		return false
	if shields.size() > hull_data.get("shield_slots", 0):
		return false
	if utilities.size() > hull_data.get("utility_slots", 0):
		return false
		
	# Check weight
	if get_total_weight() > hull_data.get("weight_cap", 0.0):
		return false
		
	# Check energy net
	if get_total_energy_net() < 0.0:
		return false
		
	return true
