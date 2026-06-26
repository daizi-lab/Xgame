class_name Commander
extends Resource

@export var commander_name: String = ""

# Attributes act as multipliers (1.0 = base, 1.1 = +10% effectiveness)
@export var aiming: float = 1.0
@export var initiative: float = 1.0
@export var evasion: float = 1.0
@export var electronic: float = 1.0

func _init(p_name: String = "", p_aiming: float = 1.0, p_init: float = 1.0, p_eva: float = 1.0, p_elec: float = 1.0):
	commander_name = p_name
	aiming = p_aiming
	initiative = p_init
	evasion = p_eva
	electronic = p_elec
