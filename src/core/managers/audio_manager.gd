extends Node

var click_sound: AudioStream
var laser_sound: AudioStream
var railgun_sound: AudioStream
var explosion_sound: AudioStream

func _ready() -> void:
	# Keep audio playing during pause and scene changes
	process_mode = PROCESS_MODE_ALWAYS
	_load_resources()
	
	# Connect to scene tree node additions to automatically hook all UI buttons in the game
	get_tree().node_added.connect(_on_node_added)
	
	# Hook any buttons that are already instantiated in the scene tree
	_hook_existing_buttons(get_tree().root)

func _load_resources() -> void:
	if ResourceLoader.exists("res://assets/audio/click.wav"):
		click_sound = load("res://assets/audio/click.wav")
		print("[AudioManager] Loaded click sound.")
	if ResourceLoader.exists("res://assets/audio/laser.wav"):
		laser_sound = load("res://assets/audio/laser.wav")
		print("[AudioManager] Loaded laser sound.")
	if ResourceLoader.exists("res://assets/audio/railgun.wav"):
		railgun_sound = load("res://assets/audio/railgun.wav")
		print("[AudioManager] Loaded railgun sound.")
	if ResourceLoader.exists("res://assets/audio/explosion.wav"):
		explosion_sound = load("res://assets/audio/explosion.wav")
		print("[AudioManager] Loaded explosion sound.")

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node)

func _hook_existing_buttons(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node)
	for child in node.get_children():
		_hook_existing_buttons(child)

func _hook_button(btn: BaseButton) -> void:
	# Check if connection already exists to avoid duplicate sound triggers
	if not btn.pressed.is_connected(play_click):
		btn.pressed.connect(play_click)

func play_sound(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.play()
	player.finished.connect(func():
		player.queue_free()
	)

func play_click() -> void:
	play_sound(click_sound, -6.0, randf_range(0.95, 1.05))

func play_laser() -> void:
	play_sound(laser_sound, -4.0, randf_range(0.95, 1.05))

func play_railgun() -> void:
	play_sound(railgun_sound, -2.0, randf_range(0.9, 1.1))

func play_explosion(pitch_scale: float = 1.0) -> void:
	play_sound(explosion_sound, -2.0, pitch_scale * randf_range(0.9, 1.1))
