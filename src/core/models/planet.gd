class_name Planet
extends Resource

signal building_completed(building_id: String, new_level: int)
signal ship_completed(design_name: String, hull_id: String)

@export var planet_id: String = ""
@export var planet_name: String = ""
@export var owner_name: String = "Neutral" # "Player", "Enemy", "Neutral"

# Building Levels
# 10 building slots
# Format: {"type": String ("metal_mine", "crystal_mine", etc., or "empty"), "level": int}
@export var buildings: Array = [
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0},
	{"type": "empty", "level": 0}
]

# Building Upgrades Queue
# Format Array of: {"slot_index": int, "building_id": String, "proposed_type": String, "time_remaining": float, "total_time": float}
@export var active_upgrades: Array = []

# Shipyard Queue
# Format Array of: {"design_name": String, "hull_id": String, "quantity": int, "time_remaining_this_ship": float, "time_per_ship": float}
@export var shipyard_queue: Array = []

# Hangar for completed ships
# Format: { "design_name" (String) -> quantity (int) }
@export var hangar: Dictionary = {}

# We also cache the designs built on this planet so we can reconstruct them when forming fleets
@export var designs: Dictionary = {} # design_name -> ShipDesign

# Base yields per hour
const BASE_METAL_HOUR: float = 10.0
const BASE_CRYSTAL_HOUR: float = 10.0
const BASE_DEUTERIUM_HOUR: float = 10.0

func _init(p_id: String = "", p_name: String = "", p_owner: String = "Neutral") -> void:
	planet_id = p_id
	planet_name = p_name
	owner_name = p_owner
	
	# Clear and initialize to 10 empty slots
	buildings = []
	for i in range(10):
		buildings.append({"type": "empty", "level": 0})

func get_building_total_level(b_id: String) -> int:
	var total = 0
	for b in buildings:
		if b and b.get("type", "empty") == b_id:
			total += b.get("level", 0)
	return total

func get_building_upgrade_cost_for_level(b_id: String, level: int) -> Dictionary:
	var next_level = level + 1
	var cost = {"metal": 0, "crystal": 0, "deuterium": 0}
	
	if b_id == "metal_mine":
		cost["metal"] = int(60 * pow(1.5, next_level - 1))
		cost["crystal"] = int(15 * pow(1.5, next_level - 1))
	elif b_id == "crystal_mine":
		cost["metal"] = int(48 * pow(1.6, next_level - 1))
		cost["crystal"] = int(24 * pow(1.6, next_level - 1))
	elif b_id == "deuterium_synthesizer":
		cost["metal"] = int(225 * pow(1.5, next_level - 1))
		cost["crystal"] = int(75 * pow(1.5, next_level - 1))
	elif b_id == "solar_power_plant":
		cost["metal"] = int(75 * pow(1.5, next_level - 1))
		cost["crystal"] = int(30 * pow(1.5, next_level - 1))
	elif b_id == "shipyard":
		cost["metal"] = int(400 * pow(2.0, next_level - 1))
		cost["crystal"] = int(200 * pow(2.0, next_level - 1))
		
	return cost

func get_slot_upgrade_cost(slot_index: int, proposed_type: String = "") -> Dictionary:
	if slot_index < 0 or slot_index >= buildings.size():
		return {"metal": 0, "crystal": 0, "deuterium": 0}
	var b = buildings[slot_index]
	var type = b["type"]
	var level = b["level"]
	if type == "empty":
		if proposed_type.is_empty():
			return {"metal": 0, "crystal": 0, "deuterium": 0}
		return get_building_upgrade_cost_for_level(proposed_type, 0)
	else:
		return get_building_upgrade_cost_for_level(type, level)

func get_slot_upgrade_time(slot_index: int, proposed_type: String = "") -> float:
	var cost = get_slot_upgrade_cost(slot_index, proposed_type)
	var base_time = (cost.get("metal", 0) + cost.get("crystal", 0)) / 100.0
	return max(3.0, base_time)

func start_building_upgrade(slot_index: int, proposed_type: String, global_res: Dictionary) -> bool:
	if active_upgrades.size() >= 3:
		return false # Maximum 3 upgrades in queue
		
	if slot_index < 0 or slot_index >= buildings.size():
		return false
		
	if buildings[slot_index]["type"] == "empty" and proposed_type.is_empty():
		return false
		
	var cost = get_slot_upgrade_cost(slot_index, proposed_type)
	if not _has_resources(cost, global_res):
		return false
		
	# Deduct from global resources
	global_res["metal"] -= cost["metal"]
	global_res["crystal"] -= cost["crystal"]
	global_res["deuterium"] -= cost["deuterium"]
	
	var build_time = get_slot_upgrade_time(slot_index, proposed_type)
	active_upgrades.append({
		"slot_index": slot_index,
		"building_id": proposed_type if buildings[slot_index]["type"] == "empty" else buildings[slot_index]["type"],
		"proposed_type": proposed_type,
		"time_remaining": build_time,
		"total_time": build_time
	})
	return true

func start_ship_construction(design_name: String, hull_id: String, qty: int, cost_per_ship: Dictionary, design_obj: RefCounted, global_res: Dictionary, system_shipyard_lvl: int = 0) -> bool:
	var total_cost = {}
	for res in ["metal", "crystal", "deuterium"]:
		total_cost[res] = cost_per_ship.get(res, 0) * qty
		
	if not _has_resources(total_cost, global_res):
		return false
		
	# Deduct from global resources
	global_res["metal"] -= total_cost["metal"]
	global_res["crystal"] -= total_cost["crystal"]
	global_res["deuterium"] -= total_cost["deuterium"]
	
	# Cache the design so we can reconstruct it when forming a fleet
	designs[design_name] = design_obj
	
	# Calculate build time per ship based on system-wide shipyard level
	var sum_cost = cost_per_ship.get("metal", 0) + cost_per_ship.get("crystal", 0)
	var shipyard_lvl = system_shipyard_lvl
	if shipyard_lvl <= 0:
		shipyard_lvl = get_building_total_level("shipyard")
	shipyard_lvl = max(1, shipyard_lvl)
	
	var time_per_ship = max(1.0, (sum_cost / 1000.0) / float(shipyard_lvl))
	
	shipyard_queue.append({
		"design_name": design_name,
		"hull_id": hull_id,
		"quantity": qty,
		"time_remaining_this_ship": time_per_ship,
		"time_per_ship": time_per_ship
	})
	return true

func _has_resources(cost: Dictionary, global_res: Dictionary) -> bool:
	return global_res.get("metal", 0.0) >= cost.get("metal", 0) and \
		   global_res.get("crystal", 0.0) >= cost.get("crystal", 0) and \
		   global_res.get("deuterium", 0.0) >= cost.get("deuterium", 0)

# Retrieve current energy status
func get_energy_max() -> int:
	var solar_plant = get_building_total_level("solar_power_plant")
	return int(30 * solar_plant * pow(1.15, solar_plant))

func get_energy_used() -> int:
	var metal_mine = get_building_total_level("metal_mine")
	var crystal_mine = get_building_total_level("crystal_mine")
	var deut_synth = get_building_total_level("deuterium_synthesizer")
	
	var energy_needed = 0
	energy_needed += int(10 * metal_mine * pow(1.1, metal_mine))
	energy_needed += int(10 * crystal_mine * pow(1.1, crystal_mine))
	energy_needed += int(20 * deut_synth * pow(1.1, deut_synth))
	return energy_needed

func tick(delta: float, game_speed: float, global_res: Dictionary) -> void:
	if owner_name == "Neutral":
		# Neutral planets do not produce resources or advance queues
		return
		
	# 1. Resource production calculations
	var metal_mine = get_building_total_level("metal_mine")
	var crystal_mine = get_building_total_level("crystal_mine")
	var deut_synth = get_building_total_level("deuterium_synthesizer")
	
	var energy_max = get_energy_max()
	var energy_needed = get_energy_used()
	
	var metal_yield = 0.0
	var crystal_yield = 0.0
	var deut_yield = 0.0
	
	var efficiency: float = 1.0
	if energy_needed > energy_max:
		efficiency = float(energy_max) / float(energy_needed) if energy_needed > 0 else 1.0
		
	metal_yield = (BASE_METAL_HOUR + (30 * metal_mine * pow(1.1, metal_mine))) * efficiency
	crystal_yield = (BASE_CRYSTAL_HOUR + (20 * crystal_mine * pow(1.1, crystal_mine))) * efficiency
	deut_yield = (BASE_DEUTERIUM_HOUR + (10 * deut_synth * pow(1.1, deut_synth))) * efficiency
		
	var tick_factor = (delta * game_speed) / 3600.0
	global_res["metal"] += metal_yield * tick_factor
	global_res["crystal"] += crystal_yield * tick_factor
	global_res["deuterium"] += deut_yield * tick_factor
	
	# 2. Process active building upgrade
	if not active_upgrades.is_empty():
		var current = active_upgrades[0]
		current["time_remaining"] -= delta
		if current["time_remaining"] <= 0.0:
			var slot_idx = current["slot_index"]
			var proposed = current["proposed_type"]
			var b = buildings[slot_idx]
			if b["type"] == "empty":
				b["type"] = proposed
				b["level"] = 1
			else:
				b["level"] += 1
				
			var new_lvl = b["level"]
			var b_id = b["type"]
			
			active_upgrades.remove_at(0)
			building_completed.emit(b_id, new_lvl)
			print("[Planet] %s built/upgraded %s to level %d in slot %d" % [planet_name, b_id, new_lvl, slot_idx])
			
	# 3. Process shipyard queue
	if not shipyard_queue.is_empty():
		var current_batch = shipyard_queue[0]
		current_batch["time_remaining_this_ship"] -= delta
		if current_batch["time_remaining_this_ship"] <= 0.0:
			var d_name = current_batch["design_name"]
			var h_id = current_batch["hull_id"]
			
			# Add completed ship to local hangar
			if not hangar.has(d_name):
				hangar[d_name] = 0
			hangar[d_name] += 1
			
			ship_completed.emit(d_name, h_id)
			print("[Planet] %s shipyard finished construction of %s. Hangar: %d" % [planet_name, d_name, hangar[d_name]])
			
			current_batch["quantity"] -= 1
			if current_batch["quantity"] > 0:
				current_batch["time_remaining_this_ship"] = current_batch["time_per_ship"]
			else:
				shipyard_queue.remove_at(0)

func demolish_building(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= buildings.size():
		return false
		
	var b = buildings[slot_index]
	if b["type"] == "empty":
		return false
		
	# Check if this slot has an active upgrade/construction running
	for upgrade in active_upgrades:
		if upgrade.get("slot_index") == slot_index:
			return false
			
	b["type"] = "empty"
	b["level"] = 0
	return true
