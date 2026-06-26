class_name BattleSimulator

const ComponentsData = preload("res://src/core/data/components_data.gd")
const Fleet = preload("res://src/core/models/fleet.gd")
const Commander = preload("res://src/core/models/commander.gd")


static func simulate(
	fleet_a: Fleet, 
	commander_a: Commander, 
	fleet_b: Fleet, 
	commander_b: Commander, 
	max_rounds: int = 10
) -> Dictionary:
	
	# Initialize active ship states
	fleet_a.initialize_active_ships()
	fleet_b.initialize_active_ships()
	
	# Sequentially assign combat_id and slot_index to avoid float precision issues during ENet RPC serialization
	var id_seq = 1
	var idx_a = 0
	for ship in fleet_a.active_ships:
		ship.combat_id = id_seq
		ship.slot_index = idx_a % 9
		id_seq += 1
		idx_a += 1
	var idx_b = 0
	for ship in fleet_b.active_ships:
		ship.combat_id = id_seq
		ship.slot_index = idx_b % 9
		id_seq += 1
		idx_b += 1
	
	# Record initial counts to calculate losses later
	var initial_a = _get_surviving_counts(fleet_a)
	var initial_b = _get_surviving_counts(fleet_b)
	
	var initial_a_ships = _get_initial_ships_info(fleet_a)
	var initial_b_ships = _get_initial_ships_info(fleet_b)
	
	var combat_log: Array[String] = []
	combat_log.append("--- 战斗开始 ---")
	combat_log.append("进攻方 (A): %s，指挥官: %s" % [fleet_a.owner_name, commander_a.commander_name if commander_a else "无"])
	combat_log.append("防守方 (B): %s，指挥官: %s" % [fleet_b.owner_name, commander_b.commander_name if commander_b else "无"])
	
	var rounds_played = 0
	var winner = "Draw"
	var structured_rounds: Array = []
	
	for round_idx in range(1, max_rounds + 1):
		if fleet_a.is_destroyed() or fleet_b.is_destroyed():
			break
			
		rounds_played = round_idx
		combat_log.append("\n== 回合 %d ==" % round_idx)
		
		var round_events = []
		
		# 1. Gather active ships and sort them according to grid slot priorities (front-to-back, top-to-bottom)
		var slot_priority_a = [2, 5, 8, 1, 4, 7, 0, 3, 6]
		var sort_a = func(x, y):
			var p_x = slot_priority_a.find(x.slot_index)
			var p_y = slot_priority_a.find(y.slot_index)
			if p_x != p_y:
				return p_x < p_y
			return x.combat_id < y.combat_id

		var slot_priority_b = [0, 3, 6, 1, 4, 7, 2, 5, 8]
		var sort_b = func(x, y):
			var p_x = slot_priority_b.find(x.slot_index)
			var p_y = slot_priority_b.find(y.slot_index)
			if p_x != p_y:
				return p_x < p_y
			return x.combat_id < y.combat_id

		var list_a = []
		for ship in fleet_a.active_ships:
			if not ship.is_destroyed():
				list_a.append(ship)
		list_a.sort_custom(sort_a)

		var list_b = []
		for ship in fleet_b.active_ships:
			if not ship.is_destroyed():
				list_b.append(ship)
		list_b.sort_custom(sort_b)

		# Interleave A and B ships for alternating crossing fire based on total speed sum
		var speed_sum_a = 0.0
		for ship in list_a:
			speed_sum_a += ship.design.get_speed() * (commander_a.initiative if commander_a else 1.0)
			
		var speed_sum_b = 0.0
		for ship in list_b:
			speed_sum_b += ship.design.get_speed() * (commander_b.initiative if commander_b else 1.0)
			
		var a_first = speed_sum_a >= speed_sum_b
		
		var combatants = []
		var i = 0
		var j = 0
		while i < list_a.size() or j < list_b.size():
			if a_first:
				if i < list_a.size():
					combatants.append({"ship": list_a[i], "side": "A"})
					i += 1
				if j < list_b.size():
					combatants.append({"ship": list_b[j], "side": "B"})
					j += 1
			else:
				if j < list_b.size():
					combatants.append({"ship": list_b[j], "side": "B"})
					j += 1
				if i < list_a.size():
					combatants.append({"ship": list_a[i], "side": "A"})
					i += 1
		
		# 2. Sequential firing
		for combatant in combatants:
			var attacker = combatant["ship"]
			var side = combatant["side"]
			
			# If the attacker was destroyed earlier this round, it cannot fire
			if attacker.is_destroyed():
				continue
				
			var target_fleet = fleet_b if side == "A" else fleet_a
			var target_commander = commander_b if side == "A" else commander_a
			var attacker_commander = commander_a if side == "A" else commander_b
			
			if target_fleet.is_destroyed():
				break
				
			# Select target
			var target = _select_random_target(target_fleet.active_ships)
			if target == null:
				break
				
			var attacker_name = "%s[%d]" % [attacker.design.design_name, attacker.combat_id]
			var target_name = "%s[%d]" % [target.design.design_name, target.combat_id]
			
			# Fire all weapons equipped (unique weapon types only)
			var unique_weapons = []
			for w_id in attacker.design.weapons:
				if not unique_weapons.has(w_id):
					unique_weapons.append(w_id)
					
			for w_id in unique_weapons:
				if target.is_destroyed():
					# Select new target if previous target is destroyed
					target = _select_random_target(target_fleet.active_ships)
					if target == null:
						break
					target_name = "%s[%d]" % [target.design.design_name, target.combat_id]
					
				if not ComponentsData.WEAPONS.has(w_id):
					continue
					
				var weapon = ComponentsData.WEAPONS[w_id]
				var base_accuracy = weapon.get("accuracy", 0.70)
				var aim_mult = attacker_commander.aiming if attacker_commander else 1.0
				var eva_mult = target_commander.evasion if target_commander else 1.0
				
				# Hit chance formula: accuracy * attacker_aim / defender_evasion
				var hit_chance = clamp((base_accuracy * aim_mult) / eva_mult, 0.05, 0.95)
				
				var event = {
					"attacker_side": side,
					"attacker_name": attacker.design.design_name,
					"attacker_id": attacker.combat_id,
					"defender_side": "B" if side == "A" else "A",
					"defender_name": target.design.design_name,
					"defender_id": target.combat_id,
					"weapon_name": weapon.get("name", "未知武器"),
					"weapon_type": weapon.get("type", "laser"),
					"hit": false,
					"damage": 0.0,
					"is_destroyed": false,
					"old_shield": target.current_shield,
					"old_armor": target.current_armor,
					"old_hp": target.current_hp,
					"new_shield": target.current_shield,
					"new_armor": target.current_armor,
					"new_hp": target.current_hp
				}
				
				if randf() <= hit_chance:
					var base_dmg = weapon.get("damage", 10.0)
					# Random damage fluctuation (90% - 110%)
					var dmg = base_dmg * randf_range(0.9, 1.1)
					
					var old_shield = target.current_shield
					var old_armor = target.current_armor
					var old_hp = target.current_hp
					var remaining_hp = target.take_damage(dmg, weapon.get("type", "laser"))
					
					event["hit"] = true
					event["damage"] = dmg
					event["is_destroyed"] = target.is_destroyed()
					event["old_shield"] = old_shield
					event["old_armor"] = old_armor
					event["old_hp"] = old_hp
					event["new_shield"] = target.current_shield
					event["new_armor"] = target.current_armor
					event["new_hp"] = target.current_hp
					
					var hit_msg = "  - %s 使用 [%s] 轰击 %s，造成 %.1f 点伤害" % [attacker_name, weapon.get("name"), target_name, dmg]
					if target.is_destroyed():
						hit_msg += " (击毁!)"
					else:
						hit_msg += " (剩余: 盾 %.1f/甲 %.1f/体 %.1f)" % [target.current_shield, target.current_armor, target.current_hp]
					combat_log.append(hit_msg)
				else:
					combat_log.append("  - %s 使用 [%s] 射击 %s，但未命中 (命中率: %d%%)" % [attacker_name, weapon.get("name"), target_name, int(hit_chance * 100)])
				
				round_events.append(event)

		# 3. End of round cleanup
		fleet_a.clean_destroyed_ships()
		fleet_b.clean_destroyed_ships()
		
		combat_log.append("回合结束: A 剩余 %d 艘 | B 剩余 %d 艘" % [fleet_a.get_active_ship_count(), fleet_b.get_active_ship_count()])
		structured_rounds.append({"round": round_idx, "events": round_events})

	# 4. Resolve Winner
	var final_a_destroyed = fleet_a.is_destroyed()
	var final_b_destroyed = fleet_b.is_destroyed()
	
	if final_a_destroyed and final_b_destroyed:
		winner = "Draw"
		combat_log.append("\n双方舰队皆尽数毁灭！同归于尽。")
	elif final_b_destroyed:
		winner = "A"
		combat_log.append("\n进攻方 (A) 获得最终胜利！")
	elif final_a_destroyed:
		winner = "B"
		combat_log.append("\n防守方 (B) 获得最终胜利！")
	else:
		winner = "Draw"
		combat_log.append("\n战斗达到最大回合上限，以平局结束。")

	# Surviving counts
	var surviving_a = _get_surviving_counts(fleet_a)
	var surviving_b = _get_surviving_counts(fleet_b)
	
	# Salvage Calculation (30% of destroyed ships' costs)
	var salvage = {"metal": 0, "crystal": 0, "deuterium": 0}
	var add_salvage = func(initial_counts: Dictionary, surviving_counts: Dictionary, designs: Dictionary):
		for d_name in initial_counts:
			var init_qty = initial_counts[d_name]
			var surv_qty = surviving_counts.get(d_name, 0)
			var destroyed_qty = init_qty - surv_qty
			if destroyed_qty > 0:
				var cost = designs[d_name].get_total_cost()
				for res in salvage:
					salvage[res] += int(cost.get(res, 0) * destroyed_qty * 0.3)

	add_salvage.call(initial_a, surviving_a, fleet_a.designs)
	add_salvage.call(initial_b, surviving_b, fleet_b.designs)
	
	combat_log.append("\n战场回收残骸: 金属 %d, 晶体 %d, 重氢 %d" % [salvage["metal"], salvage["crystal"], salvage["deuterium"]])
	combat_log.append("--- 战斗结束 ---")
	
	return {
		"winner": winner,
		"rounds_played": rounds_played,
		"salvage": salvage,
		"logs": combat_log,
		"surviving_fleet_a": surviving_a,
		"surviving_fleet_b": surviving_b,
		"structured_rounds": structured_rounds,
		"initial_a_ships": initial_a_ships,
		"initial_b_ships": initial_b_ships
	}

static func _select_random_target(active_ships: Array) -> Fleet.ActiveShip:
	var alive = active_ships.filter(func(s): return not s.is_destroyed())
	if alive.is_empty():
		return null
	return alive[randi() % alive.size()]

static func _get_surviving_counts(fleet: Fleet) -> Dictionary:
	var counts = {}
	for ship in fleet.active_ships:
		if not ship.is_destroyed():
			var d_name = ship.design.design_name
			counts[d_name] = counts.get(d_name, 0) + 1
	return counts

static func _get_initial_ships_info(fleet: Fleet) -> Array:
	var info = []
	for ship in fleet.active_ships:
		info.append({
			"id": ship.combat_id,
			"name": ship.design.design_name,
			"hull_id": ship.design.hull_id,
			"max_shield": ship.design.get_total_shield_hp(),
			"max_armor": ship.design.get_total_armor_hp(),
			"max_hp": ship.design.get_total_hull_hp()
		})
	return info

