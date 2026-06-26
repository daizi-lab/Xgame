extends Node

const CombatViewUI = preload("res://src/ui/combat_view_ui.gd")
const ShipDesign = preload("res://src/core/models/ship_design.gd")
const Fleet = preload("res://src/core/models/fleet.gd")
const BattleSimulator = preload("res://src/core/simulator/battle_simulator.gd")

func _ready() -> void:
	print("--- Running Combat Logic Verification Test ---")
	
	# 1. Setup designs
	# A: 2 frigates (base speed 100) with 2 laser_light weapons and afterburner (+25 speed)
	# Speed: 100 + 25 = 125
	var design_a = ShipDesign.new("A_Frigate", "frigate")
	design_a.weapons = ["laser_light", "laser_light"]
	design_a.utilities = ["afterburner"] 
	
	# B: 2 destroyers (base speed 80) with 2 railgun_light weapons
	# Speed: 80
	var design_b = ShipDesign.new("B_Destroyer", "destroyer")
	design_b.weapons = ["railgun_light", "railgun_light"]
	design_b.utilities = [] 
	
	var fleet_a = Fleet.new("PlayerA")
	fleet_a.add_ships(design_a, 2)
	
	var fleet_b = Fleet.new("PlayerB")
	fleet_b.add_ships(design_b, 2)
	
	print("Simulating combat...")
	var battle_result = BattleSimulator.simulate(
		fleet_a, null,
		fleet_b, null,
		2 # 2 rounds maximum
	)
	
	print("\n=== COMBAT LOGS ===")
	for line in battle_result["logs"]:
		print(line)
	print("===================\n")
	
	get_tree().quit()
