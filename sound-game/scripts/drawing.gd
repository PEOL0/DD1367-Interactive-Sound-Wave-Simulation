extends Node2D

signal geometry_changed

var current_drawing: PackedVector2Array = []
var is_drawing: bool = false

var dragged_shape: Polygon2D = null
var drag_offset: Vector2 = Vector2.ZERO

var colors: Array[Color] = [Color("e83d84"), Color("e79775"), Color("8ec4cb"), Color("c44599"), Color("b4f5a2"), Color("5ee08a"), Color("c996ed"), Color("ffcc74")]

func _unhandled_input(event: InputEvent) -> void:
	# Handle Mouse Button Clicks
	if event is InputEventMouseButton and event.button_index == 1:
		print("Vänster mouse klick")
		if event.pressed:
			print("Pressas")
			# Get the exact world position instead of the screen position
			var world_mouse_pos = get_global_mouse_position()
			
			# 1. Check if we clicked an existing shape first
			var clicked_shape = get_shape_under_mouse(world_mouse_pos)
			
			if clicked_shape:
				print("Clicked shape")
				dragged_shape = clicked_shape
				drag_offset = dragged_shape.position - world_mouse_pos
			else:
				print("Ritar")
				# 2. Start drawing a new shape
				is_drawing = true
				current_drawing.clear()
				current_drawing.append(world_mouse_pos)
		
		else:
			# Mouse Released (Keep this exactly the same as before)
			if is_drawing:
				is_drawing = false
				queue_redraw()
				if current_drawing.size() > 2:
					create_polygon(current_drawing)
				current_drawing.clear()
			if dragged_shape:
				emit_signal("geometry_changed")
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
	if points.size() < 3:
		return

	var triangulation := Geometry2D.triangulate_polygon(points)
	if triangulation.is_empty():
		push_warning("Invalid polygon data, triangulation failed in create_polygon")
		return

	var poly = Polygon2D.new()
	poly.polygon = points
	# Give it a random pastel color so you can tell them apart!
	poly.color = colors.get(randi_range(0,colors.size()-1))
	self.add_child(poly)
	emit_signal("geometry_changed")

func clear_shapes():
	for child in get_children():
		if child is Polygon2D:
			child.free()
	current_drawing.clear()
	is_drawing = false
	dragged_shape = null
	queue_redraw()
	emit_signal("geometry_changed")

func _draw():
	if current_drawing.size() > 5:
		draw_polygon(current_drawing, [Color(1,0,0)])
