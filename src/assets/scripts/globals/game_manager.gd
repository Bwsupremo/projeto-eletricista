extends Node

var main_menu : CanvasLayer
var lobby : CanvasLayer
var briefing : CanvasLayer
var game : Node
var result : CanvasLayer
var main : Main

func _ready() -> void:
	_check_launch_args()

func create_main_menu() -> CanvasLayer:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu.get_parent().remove_child(main_menu)
	main_menu = load("res://assets/scenes/ui/main_menu.tscn").instantiate()
	return main_menu

func create_lobby() -> CanvasLayer:
	lobby = load("res://assets/scenes/ui/lobby.tscn").instantiate()
	return lobby

func create_briefing() -> CanvasLayer:
	briefing = load("res://assets/scenes/ui/briefing.tscn").instantiate()
	return briefing

func create_game() -> Node:
	game = load("res://assets/scenes/game/game.tscn").instantiate()
	return game

func create_result() -> CanvasLayer:
	result = load("res://assets/scenes/ui/result.tscn").instantiate()
	return result

func _check_launch_args() -> void:
	var args = OS.get_cmdline_args()
	if "--no-sound" in args:
		var master_bus_index = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(master_bus_index, true)
	if "--host" in args:
		await get_tree().create_timer(0.5).timeout
		NetworkManager._on_host_lan()
	if "--join" in args:
		await get_tree().create_timer(1.5).timeout
		NetworkManager._on_join_lan()
