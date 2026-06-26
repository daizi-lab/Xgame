class_name ComponentsData

const HULLS = {
	"frigate": {
		"name": "护卫舰船体",
		"hp": 200,
		"base_speed": 100,
		"weapon_slots": 2,
		"shield_slots": 2,
		"utility_slots": 1,
		"energy_cap": 80,
		"weight_cap": 120,
		"cost": {"metal": 1000, "crystal": 500, "deuterium": 0}
	},
	"destroyer": {
		"name": "驱逐舰船体",
		"hp": 500,
		"base_speed": 80,
		"weapon_slots": 4,
		"shield_slots": 3,
		"utility_slots": 2,
		"energy_cap": 200,
		"weight_cap": 250,
		"cost": {"metal": 3000, "crystal": 1500, "deuterium": 0}
	},
	"cruiser": {
		"name": "巡洋舰船体",
		"hp": 1200,
		"base_speed": 60,
		"weapon_slots": 6,
		"shield_slots": 5,
		"utility_slots": 3,
		"energy_cap": 500,
		"weight_cap": 600,
		"cost": {"metal": 8000, "crystal": 4000, "deuterium": 1000}
	},
	"battleship": {
		"name": "战列舰船体",
		"hp": 3000,
		"base_speed": 40,
		"weapon_slots": 10,
		"shield_slots": 8,
		"utility_slots": 4,
		"energy_cap": 1200,
		"weight_cap": 1500,
		"cost": {"metal": 25000, "crystal": 12000, "deuterium": 3000}
	}
}

const WEAPONS = {
	"laser_light": {
		"name": "轻型脉冲激光",
		"damage": 25,
		"accuracy": 0.85,
		"type": "laser", # laser, kinetic, missile
		"energy_use": 10,
		"weight": 8,
		"cost": {"metal": 100, "crystal": 50, "deuterium": 0}
	},
	"laser_heavy": {
		"name": "重型高能激光",
		"damage": 75,
		"accuracy": 0.80,
		"type": "laser",
		"energy_use": 35,
		"weight": 25,
		"cost": {"metal": 400, "crystal": 200, "deuterium": 0}
	},
	"railgun_light": {
		"name": "轻型电磁轨道炮",
		"damage": 35,
		"accuracy": 0.70,
		"type": "kinetic",
		"energy_use": 15,
		"weight": 12,
		"cost": {"metal": 150, "crystal": 30, "deuterium": 0}
	},
	"railgun_heavy": {
		"name": "重型电磁轨道炮",
		"damage": 110,
		"accuracy": 0.65,
		"type": "kinetic",
		"energy_use": 50,
		"weight": 40,
		"cost": {"metal": 600, "crystal": 120, "deuterium": 0}
	},
	"missile_launcher": {
		"name": "暴风鱼雷发射器",
		"damage": 95,
		"accuracy": 0.60,
		"type": "missile",
		"energy_use": 5,
		"weight": 15,
		"cost": {"metal": 200, "crystal": 100, "deuterium": 50}
	}
}

const SHIELDS = {
	"deflector_light": {
		"name": "轻型偏导护盾",
		"shield_hp": 80,
		"armor_hp": 0,
		"energy_use": 15,
		"weight": 5,
		"cost": {"metal": 150, "crystal": 100, "deuterium": 0}
	},
	"deflector_heavy": {
		"name": "重型力场护盾",
		"shield_hp": 300,
		"armor_hp": 0,
		"energy_use": 55,
		"weight": 20,
		"cost": {"metal": 500, "crystal": 400, "deuterium": 0}
	},
	"composite_armor_light": {
		"name": "轻型复合装甲板",
		"shield_hp": 0,
		"armor_hp": 120,
		"energy_use": 0,
		"weight": 15,
		"cost": {"metal": 80, "crystal": 20, "deuterium": 0}
	},
	"composite_armor_heavy": {
		"name": "重型纳米装甲板",
		"shield_hp": 0,
		"armor_hp": 450,
		"energy_use": 0,
		"weight": 50,
		"cost": {"metal": 300, "crystal": 50, "deuterium": 0}
	}
}

const UTILITIES = {
	"reactor_booster": {
		"name": "辅助核聚变核心",
		"energy_bonus": 50,
		"weight": 10,
		"cost": {"metal": 200, "crystal": 100, "deuterium": 0}
	},
	"cargo_hold": {
		"name": "扩展货舱",
		"cargo_bonus": 500,
		"weight": 15,
		"cost": {"metal": 100, "crystal": 10, "deuterium": 0}
	},
	"afterburner": {
		"name": "超载加力燃烧室",
		"speed_bonus": 25,
		"energy_use": 20,
		"weight": 8,
		"cost": {"metal": 150, "crystal": 75, "deuterium": 20}
	}
}
