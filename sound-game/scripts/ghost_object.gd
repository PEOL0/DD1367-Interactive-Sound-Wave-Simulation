extends Sprite2D

var polygon: Polygon2D
var area: Area2D
var collision_shape: CollisionPolygon2D

var can_place: bool

func _ready() -> void:
	self.modulate = Color(1,1,1,0.6)
	polygon = Polygon2D.new()
	self.add_child(polygon)
	self.z_index = 2
	
	area = Area2D.new()
	self.add_child(area)
	collision_shape = CollisionPolygon2D.new()
	area.add_child(collision_shape)
	
	area.connect("area_entered", area_entered)
	area.connect("area_exited", area_exited)

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

func set_sprite(path: String, collision_points: PackedVector2Array, size: float = 0.053):
	self.collision_shape.polygon = collision_points
	self.scale = Vector2(size,size)
	self.texture = load(path)
	print(self.texture)

func clear_polygon() -> void:
	self.texture = null
	self.collision_shape.polygon.clear()
	if polygon:
		polygon.free()

func area_entered(area: Area2D):
	self.modulate = Color(1,0.3,0.3,0.6)

func area_exited(area: Area2D):
	self.modulate = Color(1,1,1,0.6)
