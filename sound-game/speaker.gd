extends Node2D

@export var amplitude: float = 1.0
@onready var sprite: Sprite2D = $Sprite2D
var _dragging := false
var _drag_offset := Vector2.ZERO

func _ready():
	if sprite.texture:
		var tex_size = sprite.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			sprite.scale = Vector2(25.0 / tex_size.x, 25.0 / tex_size.y)

func emit_sound():
	var main = get_parent()
	if main and main.has_method("_inject_impulse"):
		var grid_pos := get_grid_position()
		main._inject_impulse(grid_pos.x, grid_pos.y, amplitude)
	else:
		push_error("Missing _inject_impulse (How did that happen?)")

func get_grid_position() -> Vector2i:
	var main = get_parent()
	var grid_size := Vector2i(1600, 900)
	if main and main.has_method("get_grid_size"):
		grid_size = main.get_grid_size()
	else:
		push_error("Missing _inject_impulse (How did that happen?)")

	var gx := clampi(int(round(position.x + float(grid_size.x) * 0.5)), 0, grid_size.x - 1)
	var gy := clampi(int(round(position.y + float(grid_size.y) * 0.5)), 0, grid_size.y - 1)
	return Vector2i(gx, gy)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_mouse_over_sprite(get_global_mouse_position()):
			_dragging = true
			_drag_offset = global_position - get_global_mouse_position()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() + _drag_offset
		_clamp_to_visible_screen()
		get_viewport().set_input_as_handled()

func _is_mouse_over_sprite(mouse_position: Vector2) -> bool:
	if sprite.texture == null:
		return false

	var local_mouse := to_local(mouse_position)
	var size := sprite.texture.get_size() * sprite.scale
	var half := size * 0.5
	return Rect2(-half, size).has_point(local_mouse)

func _clamp_to_visible_screen():
	var viewport := get_viewport()
	if viewport == null:
		return

	# Convert visible screen rectangle to world space (accounts for Camera2D transform/zoom).
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

	global_position.x = clamp(global_position.x, min_x + half_size.x, max_x - half_size.x)
	global_position.y = clamp(global_position.y, min_y + half_size.y, max_y - half_size.y)
