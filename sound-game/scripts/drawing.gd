extends Node2D

signal geometry_changed

var current_drawing: PackedVector2Array = []
var is_drawing: bool = false
var HUD: HBoxContainer

var dragged_shape: Polygon2D = null
var drag_offset: Vector2 = Vector2.ZERO
const MIN_SPEAKER_DISTANCE := 25.0
const SPEAKER_SCRIPT := preload("res://scripts/speaker.gd")
const SPEAKER_TEXTURE := preload("res://assets/PVK_Speaker.png")

var colors: Array[Color] = [Color("e83d84"), Color("e79775"), Color("8ec4cb"), Color("c44599"), Color("b4f5a2"), Color("5ee08a"), Color("c996ed"), Color("ffcc74")]

func _unhandled_input(event: InputEvent) -> void:
	
	# Handle Mouse Button Clicks
	if event is InputEventMouseButton and event.button_index == 1:
		print("Vänster mouse klick")
		
		if event.pressed:
			print("Pressas")
			
			var world_mouse_pos = get_global_mouse_position()
			
			# 1. Check if we clicked an existing shape first
			var clicked_shape = get_shape_under_mouse(world_mouse_pos)
			
			if clicked_shape:
				print("Clicked shape")
				dragged_shape = clicked_shape
				drag_offset = dragged_shape.position - world_mouse_pos
			
			else:
				# 2. Create shape depending on tool
				match HUD.current_tool:
					
					HUD.Tool.TRIANGLE:
						print("Skapar triangle")
						create_triangle(world_mouse_pos)
					
					HUD.Tool.L:
						print("Skapar L")
						create_l_shape(world_mouse_pos)
					
					HUD.Tool.SQUARE:
						print("Skapar kvadrat")
						create_square(world_mouse_pos)
					
					HUD.Tool.PEN:
						print("Ritar")
						is_drawing = true
						current_drawing.clear()
						current_drawing.append(world_mouse_pos)
						
					HUD.Tool.DELETE:
						print("clearar")
						clear_shapes()

					HUD.Tool.SPEAKER:
						print("Skapar speaker")
						spawn_speaker(world_mouse_pos)
		
		else:
			# Mouse Released
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

func create_square(center: Vector2, size: float = 50.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		center + Vector2(-half, -half),
		center + Vector2(half, -half),
		center + Vector2(half, half),
		center + Vector2(-half, half)
	])
	
	create_polygon(points)

func create_triangle(center: Vector2, size: float = 60.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		center + Vector2(0, -half),      # topp
		center + Vector2(-half, half),   # vänster
		center + Vector2(half, half)     # höger
	])
	
	create_polygon(points)

func create_l_shape(center: Vector2, size: float = 60.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		center + Vector2(-half, -half),
		center + Vector2(-half/2, -half),
		center + Vector2(-half/2, half/2),
		center + Vector2(half, half/2),
		center + Vector2(half, half),
		center + Vector2(-half, half),
		center + Vector2(-half, -half)
	])
	
	create_polygon(points)


func spawn_speaker(world_pos: Vector2) -> void:
	var main_node := get_parent()

	if not _can_spawn_speaker_at(main_node, world_pos):
		print("too close to another speaker")
		return

	var new_speaker := Node2D.new()
	new_speaker.set_script(SPEAKER_SCRIPT)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = SPEAKER_TEXTURE
	sprite.region_rect = Rect2(0, 0, 50, 50)
	new_speaker.add_child(sprite)

	main_node.add_child(new_speaker)
	new_speaker.global_position = world_pos


func _can_spawn_speaker_at(main_node: Node, world_pos: Vector2) -> bool:
	for child in main_node.get_children():
		if child is Node2D and child.has_method("emit_sound"):
			if (child as Node2D).global_position.distance_to(world_pos) < MIN_SPEAKER_DISTANCE:
				return false
	return true


func clear_shapes():
	for child in get_children():
		if child is Polygon2D:
			child.free()
	current_drawing.clear()
	is_drawing = false
	dragged_shape = null
	queue_redraw()
	print("test")
	emit_signal("geometry_changed")

func _draw():
	if current_drawing.size() > 5:
		draw_polygon(current_drawing, [Color(1,0,0)])
