extends Node2D

@export var main_scene: PackedScene
@export var background_script: Node

func _ready() -> void:
	background_script._inject_impulse(100 / 2, 100 / 2)

func start_game():
	get_tree().change_scene_to_packed(main_scene)

func quit_game():
	get_tree().quit()
