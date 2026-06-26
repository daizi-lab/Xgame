class_name PlanetState

signal building_completed(building_id: String, new_level: int)
signal ship_completed(design_name: String, hull_id: String)

# Speed multiplier to make gameplay resources accumulate faster (1 second real time = 300 seconds game time)
const GAME_SPEED: float = 300.0

# Resources
var metal: float = 5000.0
var crystal: float = 3000.0
var deuterium: float = 1000.0

# Building Levels
var buildings: Dictionary = {
	"metal_mine": 1,
	"crystal_mine": 1,
	"deuterium_synthesizer": 0,
	"solar_power_plant": 1,
	"shipyard": 1
}

# Building Upgrades Queue
# Format: {"building_id": "metal_mine", "time_remaining": 15.0, "total_time": 15.0}
var active_upgrade: Dictionary = {}

# Shipyard Queue
# Format Array of: {"design_name": "Fighter", "hull_id": "frigate", "quantity": 5, "time_remaining_this_ship": 4.0, "time_per_ship": 4.0}
var shipyard_queue: Array[Dictionary] = []

# Base yields per hour
const BASE_METAL_HOUR: float = 30.0
const BASE_CRYSTAL_HOUR: float = 15.0
const BASE_DEUTERIUM_HOUR: float = 0.0

func _init() -> void:
	pass

# Calculate cost for next building level
func get_building_upgrade_cost(b_id: String) -> Dictionary:
	var level = buildings.get(b_id, 0)
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

# Upgrade build time in seconds
func get_building_upgrade_time(b_id: String) -> float:
	var cost = get_building_upgrade_cost(b_id)
	# Simple formula: (Metal + Crystal) / 100 * (1 - robotics_bonus)
	var base_time = (cost.get("metal", 0) + cost.get("crystal", 0)) / 100.0
	return max(3.0, base_time)

func start_building_upgrade(b_id: String) -> bool:
	if not active_upgrade.is_empty():
		return false # Another upgrade is in progress
		
	var cost = get_building_upgrade_cost(b_id)
	if not _has_resources(cost):
		return false
		
	# Deduct resources
	metal -= cost["metal"]
	crystal -= cost["crystal"]
	deuterium -= cost["deuterium"]
	
	var build_time = get_building_upgrade_time(b_id)
	active_upgrade = {
		"building_id": b_id,
		"time_remaining": build_time,
		"total_time": build_time
	}
	return true

func start_ship_construction(design_name: String, hull_id: String, qty: int, cost_per_ship: Dictionary) -> bool:
	var total_cost = {}
	for res in ["metal", "crystal", "deuterium"]:
		total_cost[res] = cost_per_ship.get(res, 0) * qty
		
	if not _has_resources(total_cost):
		return false
		
	# Deduct resources
	metal -= total_cost["metal"]
	crystal -= total_cost["crystal"]
	deuterium -= total_cost["deuterium"]
	
	# Calculate build time per ship (e.g. total cost sum / 1000)
	var sum_cost = cost_per_ship.get("metal", 0) + cost_per_ship.get("crystal", 0)
	# Base build speed depends on shipyard level
	var shipyard_lvl = buildings.get("shipyard", 1)
	var time_per_ship = max(1.0, (sum_cost / 1000.0) / float(shipyard_lvl))
	
	shipyard_queue.append({
		"design_name": design_name,
		"hull_id": hull_id,
		"quantity": qty,
		"time_remaining_this_ship": time_per_ship,
		"time_per_ship": time_per_ship
	})
	return true

func _has_resources(cost: Dictionary) -> bool:
	return metal >= cost.get("metal", 0) and \
		   crystal >= cost.get("crystal", 0) and \
		   deuterium >= cost.get("deuterium", 0)

# Real-time ticking logic
func tick(delta: float) -> void:
	# 1. Resource production calculations
	var metal_mine = buildings.get("metal_mine", 0)
	var crystal_mine = buildings.get("crystal_mine", 0)
	var deut_synth = buildings.get("deuterium_synthesizer", 0)
	var solar_plant = buildings.get("solar_power_plant", 0)
	
	# Solar energy output
	var energy_max = int(30 * solar_plant * pow(1.15, solar_plant))
	
	# Energy demands
	var energy_needed = 0
	energy_needed += int(10 * metal_mine * pow(1.1, metal_mine))
	energy_needed += int(10 * crystal_mine * pow(1.1, crystal_mine))
	energy_needed += int(20 * deut_synth * pow(1.1, deut_synth))
	
	# Energy efficiency factor
	var efficiency: float = 1.0
	if energy_needed > 0 and energy_max < energy_needed:
		efficiency = float(energy_max) / float(energy_needed)
		
	# Calculate raw hourly yields
	var metal_yield = BASE_METAL_HOUR + (30 * metal_mine * pow(1.1, metal_mine)) * efficiency
	var crystal_yield = BASE_CRYSTAL_HOUR + (20 * crystal_mine * pow(1.1, crystal_mine)) * efficiency
	var deut_yield = BASE_DEUTERIUM_HOUR + (10 * deut_synth * pow(1.1, deut_synth)) * efficiency
	
	# Increment resources (scaled by GAME_SPEED to make it playable)
	var tick_factor = (delta * GAME_SPEED) / 3600.0
	metal += metal_yield * tick_factor
	crystal += crystal_yield * tick_factor
	deuterium += deut_yield * tick_factor
	
	# 2. Process active building upgrade
	if not active_upgrade.is_empty():
		active_upgrade["time_remaining"] -= delta
		if active_upgrade["time_remaining"] <= 0.0:
			var b_id = active_upgrade["building_id"]
			buildings[b_id] = buildings.get(b_id, 0) + 1
			var new_lvl = buildings[b_id]
			
			active_upgrade.clear()
			building_completed.emit(b_id, new_lvl)
			
	# 3. Process shipyard queue
	if not shipyard_queue.is_empty():
		var current_batch = shipyard_queue[0]
		current_batch["time_remaining_this_ship"] -= delta
		if current_batch["time_remaining_this_ship"] <= 0.0:
			var d_name = current_batch["design_name"]
			var h_id = current_batch["hull_id"]
			
			ship_completed.emit(d_name, h_id)
			
			current_batch["quantity"] -= 1
			if current_batch["quantity"] > 0:
				current_batch["time_remaining_this_ship"] = current_batch["time_per_ship"]
			else:
				shipyard_queue.remove_at(0)

# Helper properties retrieval
func get_energy_max() -> int:
	var solar_plant = buildings.get("solar_power_plant", 0)
	return int(32 * solar_plant * pow(1.15, solar_plant))

func get_energy_used() -> int:
	var metal_mine = buildings.get("metal_mine", 0)
	var crystal_mine = buildings.get("crystal_mine", 0)
	var deut_synth = buildings.get("deuterium_synthesizer", 0)
	
	var energy_needed = 0
	energy_needed += int(10 * metal_mine * pow(1.1, metal_mine))
	energy_needed += int(10 * crystal_mine * pow(1.1, crystal_mine))
	energy_needed += int(20 * deut_synth * pow(1.1, deut_synth))
	return energy_needed
