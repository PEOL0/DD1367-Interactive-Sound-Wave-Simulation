extends Node2D

@export var amplitude: float = 1.0

func emit_sound():
	var main = get_parent()
	var percentage_x = position.x / get_viewport().size.x
	var x_placement = int(percentage_x * 1600.0)
	var percentage_y = position.y / get_viewport().size.y
	var y_placement = int(percentage_y * 900.0)
	main._inject_impulse(x_placement, y_placement, amplitude)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		emit_sound()
