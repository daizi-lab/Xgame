class_name GalaxyNode
extends Resource

const Fleet = preload("res://src/core/models/fleet.gd")

@export var node_id: String = ""
@export var node_name: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var owner_name: String = "Neutral":
	set(value):
		owner_name = value
		for p in planets:
			p.owner_name = value
@export var connected_node_ids: Array[String] = []
@export var stationed_fleets: Array[Fleet] = []
@export var planets: Array = []
@export var is_auto_managed: bool = false
@export var auto_manage_target: String = "balanced" # "balanced", "economic", "military"

func _init(p_id: String = "", p_name: String = "", p_pos: Vector2 = Vector2.ZERO, p_owner: String = "Neutral", p_connections: Array[String] = []):
	node_id = p_id
	node_name = p_name
	position = p_pos
	owner_name = p_owner
	connected_node_ids = p_connections

func add_fleet(fleet: Fleet) -> void:
	if not stationed_fleets.has(fleet):
		stationed_fleets.append(fleet)
		fleet.current_node_id = node_id
		fleet.target_node_id = ""
		fleet.is_moving = false
		fleet.travel_progress = 0.0

func remove_fleet(fleet: Fleet) -> void:
	stationed_fleets.erase(fleet)
