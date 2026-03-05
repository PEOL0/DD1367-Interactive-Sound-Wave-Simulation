extends Node2D

var current_drawing: PackedVector2Array = []
var is_drawing: bool = false

var dragged_shape: Polygon2D = null
var drag_offset: Vector2 = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# Handle Mouse Button Clicks
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Get the exact world position instead of the screen position
			var world_mouse_pos = get_global_mouse_position()
			
			# 1. Check if we clicked an existing shape first
			var clicked_shape = get_shape_under_mouse(world_mouse_pos)
			
			if clicked_shape:
				dragged_shape = clicked_shape
				drag_offset = dragged_shape.position - world_mouse_pos
			else:
				# 2. Start drawing a new shape
				is_drawing = true
				current_drawing.clear()
				current_drawing.append(world_mouse_pos)
		
		else:
			# Mouse Released (Keep this exactly the same as before)
			if is_drawing:
				is_drawing = false
				if current_drawing.size() > 2:
					create_polygon(current_drawing)
				current_drawing.clear()
				queue_redraw()
				
			if dragged_shape:
				dragged_shape = null 

	# Handle Mouse Movement
	elif event is InputEventMouseMotion:
		var world_mouse_pos = get_global_mouse_position()
		if is_drawing:
			current_drawing.append(world_mouse_pos)
			queue_redraw()
		elif dragged_shape:
			dragged_shape.position = world_mouse_pos + drag_offset


# This function checks if the mouse position is inside any of our drawn shapes
func get_shape_under_mouse(mouse_pos: Vector2) -> Polygon2D:
	# We loop backwards so we grab the shape drawn last (the one visually on top)
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if child is Polygon2D:
			# Convert global mouse position to the shape's local space
			var local_pos = child.to_local(mouse_pos)
			# Use Godot's built-in math to check if the point is inside the polygon
			if Geometry2D.is_point_in_polygon(local_pos, child.polygon):
				return child
	return null

# Turns the drawn line into a solid object
func create_polygon(points: PackedVector2Array) -> void:
	var poly = Polygon2D.new()
	poly.polygon = points
	# Give it a random pastel color so you can tell them apart!
	poly
