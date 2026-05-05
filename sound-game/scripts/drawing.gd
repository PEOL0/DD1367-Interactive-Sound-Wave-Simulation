extends Node2D

signal geometry_changed(change: Dictionary)

const PEN_STROKE_WIDTH := 6.0
const PEN_HIT_TOLERANCE := 5.0
const PEN_MIN_SAMPLE_DISTANCE := 8.0

var current_drawing: PackedVector2Array = []
var is_drawing: bool = false
var HUD: HBoxContainer

var dragged_shape: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
const MIN_SPEAKER_DISTANCE := 25.0
const SPEAKER_SCRIPT := preload("res://scripts/speaker.gd")
var current_pen_color := Color("e83d84")

var church_points: PackedVector2Array
var house_points: PackedVector2Array
var pavillion_points: PackedVector2Array

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
					
					HUD.Tool.PAVILLION:
						print("Skapar Paviljong")
						create_pavillion(world_mouse_pos)
					
					HUD.Tool.CHURCH:
						print("Skapar Kyrka")
						create_church(world_mouse_pos)
					
					HUD.Tool.BUILDING:
						print("Skapar Byggnad")
						create_building(world_mouse_pos)
					
					HUD.Tool.SQUARE:
						print("Skapar kvadrat")
						create_square(world_mouse_pos)
					
					HUD.Tool.PEN:
						print("Ritar")
						is_drawing = true
						current_drawing.clear()
						current_pen_color = colors.get(randi_range(0, colors.size() - 1))
						current_drawing.append(world_mouse_pos)

					HUD.Tool.SPEAKER:
						print("Skapar speaker")
						spawn_speaker(world_mouse_pos)
		
		else:
			# Mouse Released
			if is_drawing:
				is_drawing = false
				queue_redraw()
				
				if current_drawing.size() > 2:
					create_pen_stroke(current_drawing, current_pen_color)
				
				current_drawing.clear()
			
			if dragged_shape:
				emit_signal("geometry_changed", {"type": "move", "shape": dragged_shape})
				dragged_shape = null 

	# Handle Mouse Movement
	elif event is InputEventMouseMotion:
		var world_mouse_pos = get_global_mouse_position()
		
		if is_drawing:
			_append_pen_point(world_mouse_pos)
			queue_redraw()
		
		elif dragged_shape:
			dragged_shape.position = world_mouse_pos + drag_offset

# This function checks if the mouse position is inside any of our drawn shapes
func get_shape_under_mouse(mouse_pos: Vector2) -> Node2D:
	# We loop backwards so we grab the shape drawn last (the one visually on top)
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if child is Polygon2D:
			# Convert global mouse position to the shape's local space
			var local_pos = child.to_local(mouse_pos)
			# Use Godot's built-in math to check if the point is inside the polygon
			if Geometry2D.is_point_in_polygon(local_pos, child.polygon):
				return child
		elif child is Line2D and _is_point_near_line(child, mouse_pos):
			return child
	return null

func _is_point_near_line(stroke: Line2D, mouse_pos: Vector2) -> bool:
	if stroke.points.size() < 2:
		return false

	var local_mouse := stroke.to_local(mouse_pos)
	var hit_threshold := maxf(stroke.width * 0.5, PEN_STROKE_WIDTH * 0.5) + PEN_HIT_TOLERANCE

	for i in range(stroke.points.size() - 1):
		var seg_a := stroke.points[i]
		var seg_b := stroke.points[i + 1]
		var closest := Geometry2D.get_closest_point_to_segment(local_mouse, seg_a, seg_b)
		if local_mouse.distance_to(closest) <= hit_threshold:
			return true

	return false

func _append_pen_point(world_mouse_pos: Vector2) -> void:
	if current_drawing.is_empty():
		current_drawing.append(world_mouse_pos)
		return

	if current_drawing[current_drawing.size() - 1].distance_to(world_mouse_pos) >= PEN_MIN_SAMPLE_DISTANCE:
		current_drawing.append(world_mouse_pos)

# Turns the drawn line into a solid object
func create_polygon(points: PackedVector2Array, sprite: Sprite2D = null) -> void:
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
<<<<<<< update-graphic
	if sprite:
		poly.add_child(sprite)
=======
>>>>>>> main
	emit_signal("geometry_changed", {"type": "add", "shape": poly})

func create_pen_stroke(points: PackedVector2Array, stroke_color: Color) -> void:
	if points.size() < 2:
		return

	var stroke := Line2D.new()
	stroke.width = PEN_STROKE_WIDTH
	stroke.default_color = stroke_color
	stroke.joint_mode = Line2D.LINE_JOINT_ROUND
	stroke.begin_cap_mode = Line2D.LINE_CAP_ROUND
	stroke.end_cap_mode = Line2D.LINE_CAP_ROUND
	stroke.antialiased = true
	stroke.points = points
	add_child(stroke)
	emit_signal("geometry_changed", {"type": "add", "shape": stroke})

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

func create_pavillion(center: Vector2, size: float = 0.23):
	var points: PackedVector2Array
	for point in pavillion_points:
		points.append(center + point*size)
	var sprite = Sprite2D.new()
	sprite.texture = load("res://drawings/PVK_Paviljong.png")
	sprite.scale = Vector2(size, size)
	sprite.position = center
	create_polygon(points, sprite)

func create_building(center: Vector2, size: float = 0.23):
	var points: PackedVector2Array
	for point in house_points:
		points.append(center + point*size)
	var sprite = Sprite2D.new()
	sprite.texture = load("res://drawings/PVK_Buliding_2.png")
	sprite.scale = Vector2(size, size)
	sprite.position = center
	create_polygon(points, sprite)

func create_church(center: Vector2, size: float = 0.23):
	var points: PackedVector2Array
	for point in church_points:
		points.append(center + point*size)
	var sprite = Sprite2D.new()
	sprite.texture = load("res://drawings/PVK_Church.png")
	sprite.scale = Vector2(size, size)
	sprite.position = center
	create_polygon(points, sprite)


func spawn_speaker(world_pos: Vector2) -> void:
	var main_node := get_parent()

	if not _can_spawn_speaker_at(main_node, world_pos):
		print("too close to another speaker")
		return

	SPEAKER_SCRIPT.spawn_speaker(main_node, world_pos, HUD)


func _can_spawn_speaker_at(main_node: Node, world_pos: Vector2) -> bool:
	for child in main_node.get_children():
		if child is Node2D and child.has_method("emit_sound"):
			if (child as Node2D).global_position.distance_to(world_pos) < MIN_SPEAKER_DISTANCE:
				return false
	return true


func clear_shapes():
	for child in get_children():
		if child is Polygon2D or child is Line2D:
			child.queue_free()
	current_drawing.clear()
	is_drawing = false
	dragged_shape = null
	queue_redraw()
	print("test")
	emit_signal("geometry_changed", {"type": "clear"})

func _draw():
	if current_drawing.size() > 1:
		draw_polyline(current_drawing, current_pen_color, PEN_STROKE_WIDTH, true)
