extends SceneTree

const ShipDesign = preload("res://src/core/models/ship_design.gd")
const Fleet = preload("res://src/core/models/fleet.gd")
const Commander = preload("res://src/core/models/commander.gd")
const BattleSimulator = preload("res://src/core/simulator/battle_simulator.gd")


func _init() -> void:
	print("=========================================")
	print("   SSW 战斗模拟引擎测试工具 (Godot 4.7)   ")
	print("=========================================")
	
	# 1. 创建战舰设计
	# A. 阵风级护卫舰 (高速突击型)
	var design_frigate = ShipDesign.new("阵风级护卫舰", "frigate")
	design_frigate.weapons = ["laser_light", "laser_light"]
	design_frigate.shields = ["deflector_light", "composite_armor_light"]
	design_frigate.utilities = ["afterburner"]
	
	# B. 雷霆级驱逐舰 (中程导弹袭击型)
	var design_destroyer = ShipDesign.new("雷霆级驱逐舰", "destroyer")
	design_destroyer.weapons = ["missile_launcher", "railgun_light"]
	design_destroyer.shields = ["deflector_light", "composite_armor_light"]
	design_destroyer.utilities = ["cargo_hold", "reactor_booster"]
	
	# C. 铁甲级巡洋舰 (重装火力型)
	var design_cruiser = ShipDesign.new("铁甲级巡洋舰", "cruiser")
	design_cruiser.weapons = ["laser_heavy", "railgun_heavy", "railgun_heavy"]
	design_cruiser.shields = ["deflector_heavy", "composite_armor_heavy", "composite_armor_heavy"]
	design_cruiser.utilities = ["reactor_booster", "reactor_booster", "afterburner"]
	
	# 验证设计合法性
	var designs = [design_frigate, design_destroyer, design_cruiser]
	print("\n[设计库有效性验证]:")
	for d in designs:
		var status = "合法" if d.is_valid() else "非法"
		print("设计名: %s (%s) -> 状态: %s" % [d.design_name, d.hull_id, status])
		print("  - 载重: %.1f / %.1f" % [d.get_total_weight(), d.get_hull_data().get("weight_cap", 0.0)])
		print("  - 电力净值: %.1f" % d.get_total_energy_net())
		print("  - 单舰造价: 金属 %d, 晶体 %d, 重氢 %d" % [
			d.get_total_cost()["metal"], 
			d.get_total_cost()["crystal"], 
			d.get_total_cost()["deuterium"]
		])
		print("  - 基础速度: %.1f" % d.get_speed())
		
	# 2. 组建舰队
	# A 舰队：12艘护卫舰 + 2艘巡洋舰
	var fleet_a = Fleet.new("红色帝国先遣舰队")
	fleet_a.add_ships(design_frigate, 12)
	fleet_a.add_ships(design_cruiser, 2)
	
	# B 舰队：6艘驱逐舰
	var fleet_b = Fleet.new("蓝色联邦巡逻队")
	fleet_b.add_ships(design_destroyer, 6)
	
	# 3. 创建指挥官
	# 夏亚上尉：高瞄准(1.20)与高先制/主动权(1.15)
	var cmd_a = Commander.new("夏亚上尉", 1.20, 1.15, 1.05, 1.00)
	# 阿姆罗少尉：极高的闪避/回避率(1.30)
	var cmd_b = Commander.new("阿姆罗少尉", 1.05, 1.05, 1.30, 1.10)
	
	# 4. 执行战斗模拟
	print("\n================== 战斗开始 ==================")
	var result = BattleSimulator.simulate(fleet_a, cmd_a, fleet_b, cmd_b, 10)
	
	# 逐行输出战斗细节日志
	for log_line in result["logs"]:
		print(log_line)
		
	print("\n================== 战斗结算 ==================")
	var winner_str = "平局"
	if result["winner"] == "A":
		winner_str = "红色帝国先遣舰队 (A)"
	elif result["winner"] == "B":
		winner_str = "蓝色联邦巡逻队 (B)"
		
	print("战局赢家: %s" % winner_str)
	print("交战回合: %d" % result["rounds_played"])
	print("A队存活舰船: %s" % [str(result["surviving_fleet_a"])])
	print("B队存活舰船: %s" % [str(result["surviving_fleet_b"])])
	print("残骸回收总量: 金属 %d, 晶体 %d, 重氢 %d" % [
		result["salvage"]["metal"],
		result["salvage"]["crystal"],
		result["salvage"]["deuterium"]
	])
	print("=========================================\n")
	
	quit()
