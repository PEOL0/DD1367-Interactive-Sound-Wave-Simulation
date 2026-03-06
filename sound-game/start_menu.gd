extends Node2D

@export var main_scene: PackedScene

func start_game():
	get_tree().change_scene_to_packed(main_scene)

func quit_game():
	get_tree().quit()
