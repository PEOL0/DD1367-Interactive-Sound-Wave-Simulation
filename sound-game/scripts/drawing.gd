extends Node2D

signal geometry_changed(change: Dictionary)

# Variabler för rit verktyget
const PEN_STROKE_WIDTH := 6.0
const PEN_HIT_TOLERANCE := 5.0
const PEN_MIN_SAMPLE_DISTANCE := 8.0

# Varaibler som hanterar rit verktyget
var current_drawing: PackedVector2Array = []
var current_pen_color := Color("e83d84")
var is_drawing: bool = false

# Referens till verktyg systemet
var HUD: HBoxContainer

# Variabler som används när det kommer till att flytta objekt
var dragged_shape: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO

# Konstanter relaterade till högtalaren
const MIN_SPEAKER_DISTANCE := 25.0
const SPEAKER_SCRIPT := preload("res://scripts/speaker.gd")

# Referens till hörnen för de skapade objektet
var church_points: PackedVector2Array
var house_points: PackedVector2Array
var pavillion_points: PackedVector2Array

# En lista av olika färger
var colors: Array[Color] = [Color("e83d84"), Color("e79775"), Color("8ec4cb"), Color("c44599"), Color("b4f5a2"), Color("5ee08a"), Color("c996ed"), Color("ffcc74")]



# En funktion som hanterar indata och startar relevanta funktionen
# event: Händelsen som har inträffat (mus som flyttades, knapp som trycktes, mm)
func _unhandled_input(event: InputEvent) -> void:
	# Kollar ifall vänstra musknappen är den relaterade händelsen
	if event is InputEventMouseButton and event.button_index == 1:
		# Kollar ifall den precis tryckts ner
		if event.pressed:
			var world_mouse_pos = get_global_mouse_position()
			
			# Kollar om vi tryckte på en existerande figur
			var clicked_shape = get_shape_under_mouse(world_mouse_pos)
			
			# Sätter upp variabler om vi tryckte på en figur
			if clicked_shape:
				print("Clicked shape")
				dragged_shape = clicked_shape
				drag_offset = dragged_shape.position - world_mouse_pos
				prev_pos = dragged_shape.position
			# Om vi inte tryckte på en figur
			else:
				# Kollar om vi får plasera
				if HUD.can_place:
					# Skapar figur relaterad till nuvarande verktyget
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
		# Om vi inte trycks ner knappen
		else:
			# Ställer om simulationen och avslutar ritningen
			if is_drawing:
				is_drawing = false
				queue_redraw()
				
				if current_drawing.size() > 2:
					create_pen_stroke(current_drawing, current_pen_color)
				
				current_drawing.clear()
			
			# Ställer om simulationen om vi höll på att flytta på en figur
			if dragged_shape:
				# Säkerhets funktion som ser till att objekt inte kan överlappa
				if dragged_shape.get_child(1).has_overlapping_areas():
					var colliding = false
					for area in dragged_shape.get_child(1).get_overlapping_areas():
						if area.get_parent().get_parent() != HUD:
							colliding = true
					
					# Om den kolliderar flyttas den tillbaka till orginal
					# positionen
					if colliding:
						dragged_shape.position = prev_pos
				emit_signal("geometry_changed", {"type": "move", "shape": dragged_shape})
				dragged_shape = null 
	
	# Hanterar ifall musen rör på sig
	elif event is InputEventMouseMotion:
		var world_mouse_pos = get_global_mouse_position()
		
		# Hanterar ifall vi håller på att rita
		if is_drawing:
			_append_pen_point(world_mouse_pos)
			queue_redraw()
		
		# Hanterar ifall vi håller på att flytta på ett objekt
		elif dragged_shape:
			dragged_shape.position = world_mouse_pos + drag_offset


# Denna funktion kollar ifall musens position är innanför någon av våra objekt
# mouse_pos: Positionen för musen
# returnerar: Figuren som musen är över
func get_shape_under_mouse(mouse_pos: Vector2) -> Node2D:
	# Vi loopar tillbaka så vi tar figuren som ritade sist (den som visuellt är
	# på toppen)
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if child is Polygon2D:
			# Konverterar globala mus positionen till figurens locala
			var local_pos = child.to_local(mouse_pos)
			# Använder Godots inbyggda matte för att kolla ifall punkten är innanför
			# polygonen
			if Geometry2D.is_point_in_polygon(local_pos, child.polygon):
				return child
		elif child is Line2D and _is_point_near_line(child, mouse_pos):
			return child
	return null


# Detta är en funktion som kollar ifall musens position är nära en viss linje
# stroke: Linjen som ska kollas
# mouse_pos: Positionen för musen
# returnerar: Sant om musen är nära linjen, annars Falskt
func _is_point_near_line(stroke: Line2D, mouse_pos: Vector2) -> bool:
	if stroke.points.size() < 2:
		return false
	
	var local_mouse := stroke.to_local(mouse_pos)
	var hit_threshold := maxf(stroke.width * 0.5, PEN_STROKE_WIDTH * 0.5) + PEN_HIT_TOLERANCE
	
	# Loppar igenom varje punkt i linjen
	for i in range(stroke.points.size() - 1):
		var seg_a := stroke.points[i]
		var seg_b := stroke.points[i + 1]
		var closest := Geometry2D.get_closest_point_to_segment(local_mouse, seg_a, seg_b)
		
		# Kollar ifall musens position är tillräckligt nära den givna punkten
		if local_mouse.distance_to(closest) <= hit_threshold:
			return true
	
	return false


# En funktion som lägger till en punkt till ritningen
# world_mouse_pos: Den globala positionen för musen
func _append_pen_point(world_mouse_pos: Vector2) -> void:
	if current_drawing.is_empty():
		current_drawing.append(world_mouse_pos)
		return
	
	if current_drawing[current_drawing.size() - 1].distance_to(world_mouse_pos) >= PEN_MIN_SAMPLE_DISTANCE:
		current_drawing.append(world_mouse_pos)



# Gör om den ritade linjen, eller objekt, till ett solid objekt
# points: Punkterna för linjen
# sprite: Bilden för objektet
func create_polygon(points: PackedVector2Array, sprite: Sprite2D = null) -> void:
	# Säkerhet för att en polygon kan skapas
	if points.size() < 3:
		return

	var triangulation := Geometry2D.triangulate_polygon(points)
	if triangulation.is_empty():
		push_warning("Invalid polygon data, triangulation failed in create_polygon")
		return

	var poly = Polygon2D.new()
	poly.polygon = points
	
	# Ger polygonen en slumpmässig färg
	poly.color = colors.get(randi_range(0,colors.size()-1))
	
	self.add_child(poly)
	
	# Om det är ett förskapad objekt läggs kollissions arean till
	if sprite:
		poly.add_child(sprite)
		var area = Area2D.new()
		var collider = CollisionPolygon2D.new()
		collider.polygon = points
		poly.add_child(area)
		area.add_child(collider)
	
	# Skickar signal att geometrin i simulationen har ändrats
	emit_signal("geometry_changed", {"type": "add", "shape": poly})


# En funktion som tar en mängd punkter och gör om de till en linje
# points: Punkterna i linjen
# stroke_color: Färgen för linjen
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


# Följande 6 funktionen skapar olika objekt in i simulationen
# Skapar en kvadrat
# center: Mitten av figuren
# size: Storleken
func create_square(center: Vector2, size: float = 50.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		center + Vector2(-half, -half),
		center + Vector2(half, -half),
		center + Vector2(half, half),
		center + Vector2(-half, half)
	])
	
	create_polygon(points)


# Skapar en triangel
# center: Mitten av figuren
# size: Storleken
func create_triangle(center: Vector2, size: float = 60.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		center + Vector2(0, -half),      # topp
		center + Vector2(-half, half),   # vänster
		center + Vector2(half, half)     # höger
	])
	
	create_polygon(points)


# Skapar en L formad figur
# center: Mitten av figuren
# size: Storleken
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


# Skapar en Pavilljong
# center: Mitten av figuren
# size: Storleken
func create_pavillion(center: Vector2, size: float = 0.23):
	var points: PackedVector2Array
	for point in pavillion_points:
		points.append(center + point*size)
	var sprite = Sprite2D.new()
	sprite.texture = load("res://drawings/PVK_Paviljong.png")
	sprite.scale = Vector2(size, size)
	sprite.position = center
	create_polygon(points, sprite)


# Skapar ett kvarter av byggnader
# center: Mitten av figuren
# size: Storleken
func create_building(center: Vector2, size: float = 0.23):
	var points: PackedVector2Array
	for point in house_points:
		points.append(center + point*size)
	var sprite = Sprite2D.new()
	sprite.texture = load("res://drawings/PVK_Buliding_2.png")
	sprite.scale = Vector2(size, size)
	sprite.position = center
	create_polygon(points, sprite)


# Skapar en kyrka
# center: Mitten av figuren
# size: Storleken
func create_church(center: Vector2, size: float = 0.23):
	var points: PackedVector2Array
	for point in church_points:
		points.append(center + point*size)
	var sprite = Sprite2D.new()
	sprite.texture = load("res://drawings/PVK_Church.png")
	sprite.scale = Vector2(size, size)
	sprite.position = center
	create_polygon(points, sprite)


# En funktion som skapar en högtalare
func spawn_speaker(world_pos: Vector2) -> void:
	var main_node := get_parent()
	
	# Kollar ifall en högtalare får skapas
	if not _can_spawn_speaker_at(main_node, world_pos):
		return
	
	SPEAKER_SCRIPT.spawn_speaker(main_node, world_pos, HUD)


# En funktion som kollar ifall en högtalare får skapas
# main_node: Huvud noden
# world_pos: Positionen där högtalaren ska skapas
# returnerar: Sant om den får skapas, Falskt annars
func _can_spawn_speaker_at(main_node: Node, world_pos: Vector2) -> bool:
	for child in main_node.get_children():
		if child is Node2D and child.has_method("emit_sound"):
			if (child as Node2D).global_position.distance_to(world_pos) < MIN_SPEAKER_DISTANCE:
				return false
	return true


# En funktion som rensar att figurer och objekt från simulationen
func clear_shapes():
	# Hämtar alla objekt och raderar dem
	for child in get_children():
		if child is Polygon2D or child is Line2D:
			child.free()
	current_drawing.clear()
	
	# Ställer om varaibler för säkerhet
	is_drawing = false
	dragged_shape = null
	
	queue_redraw()
	emit_signal("geometry_changed", {"type": "clear"})


# En simpel funktion som updaterar alla ritade objekt
func _draw():
	if current_drawing.size() > 1:
		draw_polyline(current_drawing, current_pen_color, PEN_STROKE_WIDTH, true)
