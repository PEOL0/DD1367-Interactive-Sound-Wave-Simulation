extends Node2D

@export var main_scene: PackedScene
@export var background_script: Node

# En simpel funktion som skickar en ljud puls på start skärmen
func _ready() -> void:
	background_script._inject_impulse(160 / 2, 90 / 2)


# Denna funktion ändrar spelets scen från menyn till den faktiska
# simulationen
func start_game():
	get_tree().change_scene_to_packed(main_scene)


# En funktion som stänger ner hela simulationen
func quit_game():
	get_tree().quit()
