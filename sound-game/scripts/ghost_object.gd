extends Sprite2D

var polygon: Polygon2D

func _ready() -> void:
	self.modulate = Color(1,1,1,0.6)
	self.add_child(polygon)
	self.z_index = 2

func _physics_process(delta: float) -> void:
	self.global_position = get_global_mouse_position()
	

func square(size: float = 264.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	
	create_polygon(points)

func triangle(size: float = 264.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		Vector2(0, -half),      # topp
		Vector2(-half, half),   # vänster
		Vector2(half, half)     # höger
	])
	
	create_polygon(points)

func l_shape(size: float = 264.0) -> void:
	var half = size / 2
	
	var points = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(-half/2, -half),
		Vector2(-half/2, half/2),
		Vector2(half, half/2),
		Vector2(half, half),
		Vector2(-half, half),
		Vector2(-half, -half)
	])
	
	create_polygon(points)

func create_polygon(points: PackedVector2Array) -> void:
	self.texture = null
	self.scale = Vector2.ONE
	if polygon:
		polygon.free()
	polygon = Polygon2D.new()
	polygon.polygon = points
	self.add_child(polygon)

func set_sprite(path: String, size: float = 0.053):
	self.scale = Vector2(size,size)
	self.texture = load(path)

func clear_polygon() -> void:
	self.texture = null
	if polygon:
		polygon.free()
