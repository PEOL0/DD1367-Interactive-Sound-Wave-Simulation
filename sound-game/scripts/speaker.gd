extends Node2D

# Referens till texturen som används för högtalaren
const SPEAKER_TEXTURE := preload("res://drawings/PVK_Speaker_Version_2.png")

@export var amplitude: float = 1.0

# Definerar och sätter värdet för texturen som används innan något annat
@onready var sprite: Sprite2D = $Sprite2D

# Variabel som kollar om den dras
var dragging := false

# Variabel för offset för när högtalaren dras
var drag_offset := Vector2.ZERO

# Variabel för att spara referens till verktygs systemet
var HUD: HBoxContainer = null

# En funktion som tar in ett antal parametrar för att sedan skapa en högtalare
# vid en specifik plats.
# parent: Föräldrar noden
# world_pos: Den globala positionen fär högtalaren ska skapas
# hud: Referens till systemet som hanterar de olika verktygen
# retunerar: Den skapade högtalaren
static func spawn_speaker(parent: Node, world_pos: Vector2, hud: Node = null) -> Node2D:
	# Skapar objectet och sätter dess script
	var new_speaker := Node2D.new()
	new_speaker.name = "Speaker"
	new_speaker.set_script(preload("res://scripts/speaker.gd"))
	
	# Definerar collisions området för högtalaren
	var area = Area2D.new()
	var collider = CollisionShape2D.new()
	collider.scale = Vector2(1.2, 1.2)
	collider.shape = CircleShape2D.new()
	
	new_speaker.add_child(area)
	area.add_child(collider)
	
	# Fixar texturen för högtalaren samt skapar bilden
	var speaker_sprite := Sprite2D.new()
	speaker_sprite.name = "Sprite2D"
	speaker_sprite.texture = SPEAKER_TEXTURE
	speaker_sprite.z_index = 3
	new_speaker.add_child(speaker_sprite)
	
	parent.add_child(new_speaker, true)
	new_speaker.global_position = world_pos
	
	if hud:
		new_speaker.HUD = hud
	
	return new_speaker


# Funktion som körs när objektet skapas
func _ready():
	if sprite.texture:
		var tex_size = sprite.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			sprite.scale = Vector2(25.0 / tex_size.x, 25.0 / tex_size.y)

# Skickar ut ljudvågor från högtalaren
func emit_sound():
	var main = get_parent()
	if main and main.has_method("_inject_impulse"):
		var grid_pos := get_grid_position()
		main._inject_impulse(grid_pos.x, grid_pos.y, amplitude)
	else:
		push_error("Missing _inject_impulse (How did that happen?)")

# En funktion som hämtar högtalarens position i simulations nätsystem
# returnerar: X och Y koordinaten för rutan högtalaren är på
func get_grid_position() -> Vector2i:
	var main = get_parent()
	var grid_size := Vector2i(1600, 900)
	if main and main.has_method("get_grid_size"):
		grid_size = main.get_grid_size()
	else:
		push_error("Missing get_grid_size (How did that happen?)")
	
	var gx := clampi(int(round(position.x + float(grid_size.x) * 0.5)), 0, grid_size.x - 1)
	var gy := clampi(int(round(position.y + float(grid_size.y) * 0.5)), 0, grid_size.y - 1)
	
	return Vector2i(gx, gy)


# En funktion som hanterar alla olika typer av inputs som kan ges av användaren
# event: Den knapp som trycktes, mus som rördes, mm
func _input(event):
	# Kollar först om händelsen är en mus tryck
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Kollar ifall musen befinner över högtalaren
		if event.pressed and _is_mouse_over_sprite(get_global_mouse_position()):
			dragging = true
			drag_offset = global_position - get_global_mouse_position()
			get_viewport().set_input_as_handled()
		
		# Kollar ifall knappen släpps
		elif not event.pressed and dragging:
			dragging = false
			get_viewport().set_input_as_handled()
	
	# Kollar om händelsen är att musen rör på sig och att högtalaren får röra på
	# sig
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() + drag_offset
		_clamp_to_visible_screen()
		get_viewport().set_input_as_handled()


# En funktion som kollar ifall musen befinner sig över högtalaren
# mouse_position: Globala positionen som musen befinner is på
# returnerar: Sant om musen är över högtalaren
func _is_mouse_over_sprite(mouse_position: Vector2) -> bool:
	if sprite.texture == null:
		return false
	
	var local_mouse := to_local(mouse_position)
	var size := sprite.texture.get_size() * sprite.scale
	var half := size * 0.5
	
	return Rect2(-half, size).has_point(local_mouse)


# En funktion som säkerställer att högtalaren stannar på skärmen och inte
# åker halft utanför
func _clamp_to_visible_screen():
	# Hämtar skärmens egenskaper
	var viewport := get_viewport()
	if viewport == null:
		return

	# Konverterar skärmens rectangel till världens yta (tar hänsyn till
	# Camera2D transform/zoom)
	var visible_rect := viewport.get_visible_rect()
	var canvas := viewport.get_canvas_transform().affine_inverse()
	var top_left := canvas * visible_rect.position
	var bottom_right := canvas * (visible_rect.position + visible_rect.size)
	
	var min_x: float = minf(top_left.x, bottom_right.x)
	var max_x: float = maxf(top_left.x, bottom_right.x)
	var min_y: float = minf(top_left.y, bottom_right.y)
	var max_y: float = maxf(top_left.y, bottom_right.y)
	
	var half_size := Vector2.ZERO
	if sprite.texture:
		half_size = sprite.texture.get_size() * sprite.scale * 0.5
	
	# Updaterar högtalarens position till det innanför skärmen
	global_position.x = clamp(global_position.x, min_x + half_size.x, max_x - half_size.x)
	global_position.y = clamp(global_position.y, min_y + half_size.y, max_y - half_size.y)
