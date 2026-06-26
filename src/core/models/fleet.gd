class_name Fleet
extends Resource

const ShipDesign = preload("res://src/core/models/ship_design.gd")


# Nested class for tracking individual ship state during combat
class ActiveShip:
	var combat_id: int = 0
	var slot_index: int = 0
	var design: ShipDesign
	var current_shield: float = 0.0
	var current_armor: float = 0.0
	var current_hp: float = 0.0

	func _init(p_design: ShipDesign):
		design = p_design
		current_shield = design.get_total_shield_hp()
		current_armor = design.get_total_armor_hp()
		current_hp = design.get_total_hull_hp()

	# Applies damage and returns remaining HP. Handles type effectiveness.
	func take_damage(damage: float, type: String) -> float:
		var shield_damage = damage
		var armor_damage = damage
		
		# Type effectiveness:
		# Laser: 1.5x vs shield, 0.5x vs armor
		# Kinetic: 0.5x vs shield, 1.5x vs armor
		# Missile: 1.0x vs shield, 1.0x vs armor, but bypasses 20% of shield directly to armor/hull
		if type == "laser":
			shield_damage *= 1.5
			armor_damage *= 0.5
		elif type == "kinetic":
			shield_damage *= 0.5
			armor_damage *= 1.5
		elif type == "missile":
			var bypass = damage * 0.2
			shield_damage *= 0.8
			
			# Deal bypass damage directly to armor/hull
			if current_armor > 0:
				if bypass <= current_armor:
					current_armor -= bypass
				else:
					bypass -= current_armor
					current_armor = 0
					current_hp = max(0.0, current_hp - bypass)
			else:
				current_hp = max(0.0, current_hp - bypass)

		# 1. Deflect with Shield
		if current_shield > 0 and shield_damage > 0:
			if shield_damage <= current_shield:
				current_shield -= shield_damage
				shield_damage = 0
				damage = 0
			else:
				shield_damage -= current_shield
				current_shield = 0
				# Convert remaining shield damage back to baseline damage
				if type == "laser":
					damage = shield_damage / 1.5
				elif type == "kinetic":
					damage = shield_damage / 0.5
				else:
					damage = shield_damage / 0.8
		
		# 2. Block with Armor
		if damage > 0:
			var final_armor_dmg = damage
			if type == "laser":
				final_armor_dmg *= 0.5
			elif type == "kinetic":
				final_armor_dmg *= 1.5
				
			if current_armor > 0:
				if final_armor_dmg <= current_armor:
					current_armor -= final_armor_dmg
					damage = 0
				else:
					final_armor_dmg -= current_armor
					current_armor = 0
					# Convert remaining armor damage back to baseline
					if type == "laser":
						damage = final_armor_dmg / 0.5
					elif type == "kinetic":
						damage = final_armor_dmg / 1.5
					else:
						damage = final_armor_dmg

			# 3. Structural Hull Damage
			if damage > 0:
				current_hp = max(0.0, current_hp - damage)
				
		return current_hp

	func is_destroyed() -> bool:
		return current_hp <= 0.0

# Fleet implementation
@export var fleet_name: String = ""
@export var owner_name: String = ""
@export var ships: Dictionary = {}        # design_name (String) -> quantity (int)
@export var designs: Dictionary = {}      # design_name (String) -> ShipDesign
var active_ships: Array[ActiveShip] = []

# Navigation Properties
@export var current_node_id: String = ""
@export var target_node_id: String = ""
@export var is_moving: bool = false
@export var travel_progress: float = 0.0          # 0.0 to 1.0
@export var travel_time_remaining: float = 0.0
@export var travel_total_time: float = 0.0
@export var commander: Commander = null
@export var movement_path: Array[String] = []


func _init(p_name: String = "", p_owner: String = ""):
	fleet_name = p_name
	owner_name = p_owner

func add_ships(design: ShipDesign, qty: int) -> void:
	if not design.is_valid():
		push_warning("Attempted to add invalid ship design: ", design.design_name)
		return
	
	if not ships.has(design.design_name):
		ships[design.design_name] = 0
		designs[design.design_name] = design
	ships[design.design_name] += qty

func initialize_active_ships() -> void:
	active_ships.clear()
	for d_name in ships:
		var design = designs[d_name]
		var qty = ships[d_name]
		for i in range(qty):
			active_ships.append(ActiveShip.new(design))

func get_active_ship_count() -> int:
	var count = 0
	for ship in active_ships:
		if not ship.is_destroyed():
			count += 1
	return count

func get_total_cost() -> Dictionary:
	var total = {"metal": 0, "crystal": 0, "deuterium": 0}
	for d_name in ships:
		var qty = ships[d_name]
		var d_cost = designs[d_name].get_total_cost()
		for res in total.keys():
			total[res] += d_cost[res] * qty
	return total

func get_average_speed() -> float:
	if ships.is_empty():
		return 0.0
	var sum: float = 0.0
	var count: int = 0
	for d_name in ships:
		var qty = ships[d_name]
		sum += designs[d_name].get_speed() * qty
		count += qty
	return sum / count

func get_total_salvage() -> Dictionary:
	# Calculate metal and crystal salvage from destroyed ships (e.g. 30% of total cost)
	var total_cost = get_total_cost()
	var salvage = {}
	for res in total_cost:
		salvage[res] = int(total_cost[res] * 0.3)
	return salvage

func clean_destroyed_ships() -> void:
	active_ships = active_ships.filter(func(s): return not s.is_destroyed())
	
	# Update map-level ships dictionary
	ships.clear()
	for ship in active_ships:
		var d_name = ship.design.design_name
		if not ships.has(d_name):
			ships[d_name] = 0
		ships[d_name] += 1

func is_destroyed() -> bool:
	for ship in active_ships:
		if not ship.is_destroyed():
			return false
	return true
