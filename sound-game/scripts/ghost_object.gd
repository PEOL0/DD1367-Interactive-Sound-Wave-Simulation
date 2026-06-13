extends Sprite2D


var polygon: Polygon2D
var area: Area2D

# Globala referenser till kollissions former
var collision_shape: CollisionPolygon2D
var circle_collider: CollisionShape2D

# Eb lista som kommer innehålla alla nuvarande kolliderande objekt
var colliding_area: Array[Area2D] = []

# Körs när objektet först skapas
func _ready() -> void:
	# Gör objektet mer transparent samt gör att den kommer ses över
	# andra objekt genom att ändra dess z värde
	self.modulate = Color(1,1,1,0.6)
	polygon = Polygon2D.new()
	self.add_child(polygon)
	self.z_index = 2
	
	# Skapar alla kollissions former och skapar de som barn noder till
	# huvud objektet
	area = Area2D.new()
	self.add_child(area)
	collision_shape = CollisionPolygon2D.new()
	circle_collider = CollisionShape2D.new()
	area.add_child(collision_shape)
	area.add_child(circle_collider)
	
	# Sätter funktions kallelser baserat på för skapade händelser inom Godot
	area.connect("area_entered", area_entered)
	area.connect("area_exited", area_exited)


# En funktion som körs med konstant mellanrum. Det den gör här är att
# sätta detta objekts globala position till musens globala position
func _physics_process(delta: float) -> void:
	self.global_position = get_global_mouse_position()


# En funktion som skapar en kvadrat för det transparanta objektet
# size: Storleken av formen
func square(size: float = 264.0) -> void:
	# Hittar exakta mitten av kvadraten
	var half = size / 2
	
	# Hittar alla de fyra hörnen där mitten blir (0,0)
	var points = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	
	create_polygon(points)


# En funktion som skapar en triangel för det transparanta objektet
# size: Storleken av formen
func triangle(size: float = 264.0) -> void:
	# Hittar mitten av formen
	var half = size / 2
	
	# Hittar hörnen av den liksida triangeln där mitten
	# blir (0,0)
	var points = PackedVector2Array([
		Vector2(0, -half),      # topp
		Vector2(-half, half),   # vänster
		Vector2(half, half)     # höger
	])
	
	create_polygon(points)


# En funktion som skapar en L formad figur för det transparanta objektet
# size: Storleken av formen
func l_shape(size: float = 264.0) -> void:
	# Hittar mitten av formen
	var half = size / 2
	
	# Hittar alla hörnen för figuren där mitten av formen kommer vara vid (0,0)
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


# En funktion som skapar ett synligt polygon baserat på de givna punkterna
# points: De punkterna som polygonen ska skapas från
func create_polygon(points: PackedVector2Array) -> void:
	self.texture = null
	self.scale = Vector2.ONE
	
	# Om det redan finns en polygon raderas den
	if polygon:
		polygon.free()
	
	# Här skapas ett nytt polygon objekt och sätter dess punkter till de
	# givna punkterna i 'points'
	polygon = Polygon2D.new()
	polygon.polygon = points
	self.add_child(polygon)


# En funktion som sätter den visuella bilden för objektet (sprite) som det
# transparanta objektet ska ha
# path: Fil vägen till bilden
# collision_points: Punkterna för objektets kollissions fält
# size: Storleken för bilden
func set_sprite(path: String, collision_points: PackedVector2Array = PackedVector2Array(), size: float = 0.053):
	# Kollar ifall kollisions punkterna är tomma
	if collision_points.is_empty():
		# Skapar collisions fältet ifall det inte finns givna punkter
		self.circle_collider.scale = Vector2(5.5/size,5.5/size)
		self.collision_shape.polygon.clear()
		self.circle_collider.shape = CircleShape2D.new()
	
	else:
		self.circle_collider.shape = null
		self.collision_shape.polygon = collision_points
	
	# Sätter bilden samt dess storlek
	self.scale = Vector2(size,size)
	self.texture = load(path)


# En funktion som rensar den skapade polygonen och allt relaterat till den
func clear_polygon() -> void:
	self.texture = null
	self.collision_shape.polygon.clear()
	self.circle_collider.shape = null
	if polygon:
		polygon.free()


# Denna funktion kollar ifall något har gått in i objektets kollissions area
# och löser kollissionen
# area: Arean för objektet som har "gått" in i det transparanta objektet
func area_entered(area: Area2D):
	self.modulate = Color(1,0.3,0.3,0.6)
	get_parent().can_place = false
	
	# Lägger till det kolliderade objektet in i en lista med alla kolliderade objekt
	self.colliding_area.append(area)


# Denna funktion kollar ifall något har lämnat det objektets kollissions area
# och löser kollissionen
# area: Arean för objektet som har "lämnat" det transparanta objektet
func area_exited(area: Area2D):
	# Tar bort objektet från listan med kolliderade objekt
	self.colliding_area.erase(area)
	
	# Sätter status på att nya objekt kan placeras
	if self.colliding_area.is_empty():
		self.modulate = Color(1,1,1,0.6)
		get_parent().can_place = true
