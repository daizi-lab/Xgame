extends Control

@onready var continue_btn: Button = $Center/VBox/ContinueButton
const SAVE_PATH = "user://savegame.dat"

func _ready() -> void:
	# Check if save file exists
	if FileAccess.file_exists(SAVE_PATH):
		continue_btn.disabled = false
		continue_btn.text = "继续游戏 (Continue)"
	else:
		continue_btn.disabled = true
		continue_btn.text = "继续游戏 (无存档)"
		
	# Connect button signals
	$Center/VBox/StartButton.pressed.connect(_on_start_pressed)
	$Center/VBox/ContinueButton.pressed.connect(_on_continue_pressed)
	$Center/VBox/MultiplayerButton.pressed.connect(_on_multiplayer_pressed)
	$Center/VBox/ExitButton.pressed.connect(_on_exit_pressed)

func _on_start_pressed() -> void:
	# Delete old save to start fresh
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		
	# Set load flag and change scene
	var hub_script = load("res://src/ui/main_game_hub.gd")
	hub_script.should_load_save = false
	get_tree().change_scene_to_file("res://src/ui/main_game_hub.tscn")

func _on_continue_pressed() -> void:
	# Set load flag and change scene
	var hub_script = load("res://src/ui/main_game_hub.gd")
	hub_script.should_load_save = true
	get_tree().change_scene_to_file("res://src/ui/main_game_hub.tscn")

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/network_lobby.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
