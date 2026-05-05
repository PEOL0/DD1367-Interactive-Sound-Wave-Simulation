extends Node

@onready var shader_material: ShaderMaterial = $ColorRect.material
@export var isMenu: bool
@export var church_points: PackedVector2Array
@export var house_points: PackedVector2Array
@export var pavillion_points: PackedVector2Array
@onready var HUD: HBoxContainer = $Panel/HBoxContainer

const N := [1600, 900]
const TOTAL := N[0] * N[1]
const BUF_BYTES := TOTAL * 4 #4 because it is the size of a 32 bit float
const WORKGROUP_SIZE := 16
const DRAWING_SCRIPT := preload("res://scripts/drawing.gd")
const SPEAKER_SCRIPT := preload("res://scripts/speaker.gd")
const PEN_STROKE_WIDTH := 6.0
const PEN_HIT_TOLERANCE := 5.0
const PEN_PHYSICS_THICKNESS := PEN_STROKE_WIDTH + PEN_HIT_TOLERANCE

var c_speed := 120.0
var dx := 1.0
var dt: float
var global_damping := 0.999

var pressure_texture: ImageTexture

var rd: RenderingDevice
var shader_rid: RID
var pipeline: RID
var buffers: Array[RID] = []           
var uniform_sets: Array[RID] = []   
var obstacle_buffer: RID
var psi_x_buffer: RID
var psi_y_buffer: RID
var step := 0                       
var pending_impulses: Array = []    
const PUSH_CONST_SIZE := 48

var drawing_layer: Node2D = null
var obstacle_mask_data := PackedByteArray()
var shape_bounds_cache: Dictionary = {}
var dirty_regions: Array[Rect2i] = []


# Sets up the simulation: creates GPU buffers, loads the shader, and prepares everything to run
func _ready():
	Engine.physics_ticks_per_second = 60
	dt = dx / (c_speed * sqrt(2.0)) * 0.95

	var img := Image.create(N[0], N[1], false, Image.FORMAT_RF)
	pressure_texture = ImageTexture.create_from_image(img)
	shader_material.set_shader_parameter("pressure_field", pressure_texture)

	rd = RenderingServer.create_local_rendering_device()

	var glsl_file := load("res://fdtd.glsl") as RDShaderFile
	var spirv := glsl_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader_rid)

	var zero_data := PackedByteArray()
	zero_data.resize(BUF_BYTES)
	zero_data.fill(0)
	obstacle_mask_data = zero_data.duplicate()
	for i in 3:
		buffers.append(rd.storage_buffer_create(BUF_BYTES, zero_data))
	obstacle_buffer = rd.storage_buffer_create(BUF_BYTES, zero_data)

	# PML auxiliary buffers (psi_x, psi_y)
	psi_x_buffer = rd.storage_buffer_create(BUF_BYTES, zero_data)
	psi_y_buffer = rd.storage_buffer_create(BUF_BYTES, zero_data)

	var rotations := [
		[0, 2, 1],
		[1, 0, 2],
		[2, 1, 0],
	]
	for rot in rotations:
		var uniforms: Array[RDUniform] = []
		for i in 3:
			var newUniform := RDUniform.new()
			newUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
			newUniform.binding = i
			newUniform.add_id(buffers[rot[i]])
			uniforms.append(newUniform)
		var obstacle_uniform := RDUniform.new()
		obstacle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		obstacle_uniform.binding = 3
		obstacle_uniform.add_id(obstacle_buffer)
		uniforms.append(obstacle_uniform)

		var psi_x_uniform := RDUniform.new()
		psi_x_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		psi_x_uniform.binding = 4
		psi_x_uniform.add_id(psi_x_buffer)
		uniforms.append(psi_x_uniform)

		var psi_y_uniform := RDUniform.new()
		psi_y_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		psi_y_uniform.binding = 5
		psi_y_uniform.add_id(psi_y_buffer)
		uniforms.append(psi_y_uniform)
		uniform_sets.append(rd.uniform_set_create(uniforms, shader_rid, 0))

	if not isMenu:
		$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spawn_drawing_layer()
		print("Drawing layer ready")
		SPEAKER_SCRIPT.spawn_speaker(self, Vector2.ZERO, HUD)

	print("Simulation ready – grid %d×%d  c=%.1f  dt=%.6f  CFL r=%.4f" % [
		N[0], N[1], c_speed, dt, c_speed * dt / dx])
	
	change_rect()

func change_rect():
	var screen_size_x = get_viewport().get_visible_rect().size.x
	var scale = screen_size_x / $ColorRect.size.x
	print(scale)
	$Camera2D.zoom = Vector2(scale, scale)

func get_grid_size() -> Vector2i:
	return Vector2i(N[0], N[1])

# Runs every physics frame: sends work to the GPU to advance the sound simulation one time step
func _physics_process(_delta):
	if not dirty_regions.is_empty():
		_rebuild_obstacle_mask()

	var r := c_speed * dt / dx
	var r2 := r * r
	var dispatch_x := ceili(float(N[0]) / WORKGROUP_SIZE)
	var dispatch_y := ceili(float(N[1]) / WORKGROUP_SIZE)

	var pml_thickness := 24.0
	var pml_sigma := 2.0
	var sigma_dt := pml_sigma * dt

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_sets[step], 0)

	for imp in pending_impulses:
		var packedConstants := _pack_impulse_constants(N[0], N[1], r2, global_damping, imp.gx, imp.gy, imp.amp, imp.sigma)
		rd.compute_list_set_push_constant(compute_list, packedConstants, PUSH_CONST_SIZE)
		rd.compute_list_dispatch(compute_list, dispatch_x, dispatch_y, 1)
		rd.compute_list_add_barrier(compute_list)
	pending_impulses.clear()

	var packed1 := _pack_step_constants(N[0], N[1], r2, global_damping, 1, pml_thickness, sigma_dt)
	rd.compute_list_set_push_constant(compute_list, packed1, PUSH_CONST_SIZE)
	rd.compute_list_dispatch(compute_list, dispatch_x, dispatch_y, 1)
	rd.compute_list_add_barrier(compute_list)

	var packed2 := _pack_step_constants(N[0], N[1], r2, global_damping, 2, pml_thickness, sigma_dt)
	rd.compute_list_set_push_constant(compute_list, packed2, PUSH_CONST_SIZE)
	rd.compute_list_dispatch(compute_list, dispatch_x, dispatch_y, 1)
	rd.compute_list_add_barrier(compute_list)

	var packed3 := _pack_step_constants(N[0], N[1], r2, global_damping, 3, pml_thickness, sigma_dt)
	rd.compute_list_set_push_constant(compute_list, packed3, PUSH_CONST_SIZE)
	rd.compute_list_dispatch(compute_list, dispatch_x, dispatch_y, 1)
	rd.compute_list_add_barrier(compute_list)

	rd.compute_list_end()
	rd.submit()
	rd.sync()

	step = (step + 1) % 3

	var data := rd.buffer_get_data(buffers[step], 0, BUF_BYTES)
	var result_img := Image.create_from_data(N[0], N[1], false, Image.FORMAT_RF, data)
	pressure_texture.update(result_img)

#Adds the drawing layer as a child and connects the script and signal
func _spawn_drawing_layer():
	drawing_layer = Node2D.new()
	drawing_layer.name = "DrawingLayer"
	drawing_layer.set_script(DRAWING_SCRIPT)
	add_child(drawing_layer)
	drawing_layer.HUD = HUD
	HUD.drawing_node = drawing_layer
	drawing_layer.church_points = church_points
	drawing_layer.house_points = house_points
	drawing_layer.pavillion_points = pavillion_points
	if drawing_layer.has_signal("geometry_changed"):
		drawing_layer.connect("geometry_changed", Callable(self, "_on_geometry_changed"))

#Queues only changed regions so obstacle updates scale with local edits.
func _on_geometry_changed(change: Dictionary):
	var change_type: String = str(change.get("type", ""))
	match change_type:
		"add":
			var shape_to_add = change.get("shape", null)
			var add_bounds := _compute_shape_grid_bounds(shape_to_add)
			shape_bounds_cache[shape_to_add] = add_bounds
			dirty_regions.append(add_bounds)
		"move":
			var moved_shape = change.get("shape", null)
			var new_bounds := _compute_shape_grid_bounds(moved_shape)

			var old_bounds: Rect2i = shape_bounds_cache.get(moved_shape, new_bounds)
			shape_bounds_cache[moved_shape] = new_bounds
			dirty_regions.append(old_bounds.merge(new_bounds))
		"clear":
			shape_bounds_cache.clear()
			dirty_regions.clear()
			dirty_regions.append(Rect2i(0, 0, N[0], N[1]))
		_:
			dirty_regions.append(Rect2i(0, 0, N[0], N[1]))

func _rebuild_obstacle_mask() -> void:
	var merged_regions := _merge_dirty_regions(dirty_regions)
	dirty_regions.clear()

	for region in merged_regions:
		_clear_region(obstacle_mask_data, region)

	var active_shapes: Array[Node2D] = []
	for child in drawing_layer.get_children():
		if child is Polygon2D or child is Line2D:
			var shape := child as Node2D
			var bounds := _compute_shape_grid_bounds(shape)
			if _is_valid_region(bounds):
				shape_bounds_cache[shape] = bounds
				active_shapes.append(shape)

	for region in merged_regions:
		for shape in active_shapes:
			var cached_bounds: Rect2i = shape_bounds_cache.get(shape, Rect2i(0, 0, 0, 0))
			if not _is_valid_region(cached_bounds) or not cached_bounds.intersects(region):
				continue
			if shape is Polygon2D and (shape as Polygon2D).polygon.size() > 2:
				_rasterize_polygon_mask(shape as Polygon2D, obstacle_mask_data)
			elif shape is Line2D and (shape as Line2D).points.size() > 1:
				_rasterize_stroke_mask(shape as Line2D, PEN_PHYSICS_THICKNESS, obstacle_mask_data)

	rd.buffer_update(obstacle_buffer, 0, BUF_BYTES, obstacle_mask_data)

func _is_valid_region(region: Rect2i) -> bool:
	return region.size.x > 0 and region.size.y > 0


func _world_bounds_to_grid_rect(min_x: float, max_x: float, min_y: float, max_y: float) -> Rect2i:
	var half_width := N[0] * 0.5
	var half_height := N[1] * 0.5
	var grid_x_min := clampi(int(floor(min_x + half_width)), 0, N[0] - 1)
	var grid_x_max := clampi(int(ceil(max_x + half_width)), 0, N[0] - 1)
	var grid_y_min := clampi(int(floor(min_y + half_height)), 0, N[1] - 1)
	var grid_y_max := clampi(int(ceil(max_y + half_height)), 0, N[1] - 1)

	return Rect2i(grid_x_min, grid_y_min, grid_x_max - grid_x_min + 1, grid_y_max - grid_y_min + 1)


func _compute_shape_grid_bounds(shape: Node2D) -> Rect2i:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	if shape is Polygon2D:
		if shape.polygon.size() < 3:
			return Rect2i(0, 0, 0, 0)
		for local_pt in shape.polygon:
			var world_pt := shape.to_global(local_pt)
			min_x = min(min_x, world_pt.x)
			max_x = max(max_x, world_pt.x)
			min_y = min(min_y, world_pt.y)
			max_y = max(max_y, world_pt.y)
	elif shape is Line2D:
		if shape.points.size() < 2:
			return Rect2i(0, 0, 0, 0)
		var half_thickness := maxf(PEN_PHYSICS_THICKNESS * 0.5, shape.width * 0.5)
		for local_pt in shape.points:
			var world_pt := shape.to_global(local_pt)
			min_x = min(min_x, world_pt.x - half_thickness)
			max_x = max(max_x, world_pt.x + half_thickness)
			min_y = min(min_y, world_pt.y - half_thickness)
			max_y = max(max_y, world_pt.y + half_thickness)
	else:
		return Rect2i(0, 0, 0, 0)

	return _world_bounds_to_grid_rect(min_x, max_x, min_y, max_y)


func _merge_dirty_regions(regions: Array[Rect2i]) -> Array[Rect2i]:
	var merged: Array[Rect2i] = []
	for region in regions:
		if not _is_valid_region(region):
			continue
		var merged_into_existing := false
		for i in range(merged.size()):
			if merged[i].intersects(region) or merged[i].grow(1).intersects(region):
				merged[i] = merged[i].merge(region)
				merged_into_existing = true
				break
		if not merged_into_existing:
			merged.append(region)
	return merged


func _clear_region(mask_data: PackedByteArray, region: Rect2i) -> void:
	if not _is_valid_region(region):
		return
	for grid_y in range(region.position.y, region.position.y + region.size.y):
		for grid_x in range(region.position.x, region.position.x + region.size.x):
			var idx := grid_y * N[0] + grid_x
			mask_data.encode_u32(idx * 4, 0)

#Helper for building the obstacle mask. Computes the bounding box and then checks wheter all the points inside the bounds are inside the polygon and encodes it as 1=in and 0=out.
func _rasterize_polygon_mask(shape: Polygon2D, mask_data: PackedByteArray):
	var shape_points: PackedVector2Array = []
	for local_pt in shape.polygon:
		shape_points.append(shape.to_global(local_pt))

	if shape_points.is_empty():
		return

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for p in shape_points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var bounds := _world_bounds_to_grid_rect(min_x, max_x, min_y, max_y)
	var grid_x_min := bounds.position.x
	var grid_y_min := bounds.position.y
	var grid_x_max := bounds.position.x + bounds.size.x
	var grid_y_max := bounds.position.y + bounds.size.y
	
	var half_width := N[0] * 0.5
	var half_height := N[1] * 0.5

	for grid_y in range(grid_y_min, grid_y_max):
		for grid_x in range(grid_x_min, grid_x_max):
			var world_p := Vector2(float(grid_x) - half_width, float(grid_y) - half_height)
			if Geometry2D.is_point_in_polygon(world_p, shape_points):
				var idx := grid_y * N[0] + grid_x
				mask_data.encode_u32(idx * 4, 1)


func _rasterize_stroke_mask(stroke: Line2D, width_cells: float, mask_data: PackedByteArray) -> void:
	var stroke_points: PackedVector2Array = []
	for local_pt in stroke.points:
		stroke_points.append(stroke.to_global(local_pt))

	if stroke_points.size() < 2:
		return

	var half_thickness := maxf(width_cells * 0.5, stroke.width * 0.5)
	var half_width := N[0] * 0.5
	var half_height := N[1] * 0.5

	for i in range(stroke_points.size() - 1):
		var seg_a := stroke_points[i]
		var seg_b := stroke_points[i + 1]

		var min_x: float = min(seg_a.x, seg_b.x) - half_thickness
		var max_x: float = max(seg_a.x, seg_b.x) + half_thickness
		var min_y: float = min(seg_a.y, seg_b.y) - half_thickness
		var max_y: float = max(seg_a.y, seg_b.y) + half_thickness

		var bounds := _world_bounds_to_grid_rect(min_x, max_x, min_y, max_y)
		var grid_x_min := bounds.position.x
		var grid_y_min := bounds.position.y
		var grid_x_max := bounds.position.x + bounds.size.x
		var grid_y_max := bounds.position.y + bounds.size.y

		for grid_y in range(grid_y_min, grid_y_max):
			for grid_x in range(grid_x_min, grid_x_max):
				var world_p := Vector2(float(grid_x) - half_width, float(grid_y) - half_height)
				var closest := Geometry2D.get_closest_point_to_segment(world_p, seg_a, seg_b)
				if world_p.distance_to(closest) <= half_thickness:
					var idx := grid_y * N[0] + grid_x
					mask_data.encode_u32(idx * 4, 1)


# Packs the shared simulation settings into raw bytes so the GPU shader can read them
func _pack_base_constants(width: int, height: int, r2_val: float, damping: float, mode: int) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(PUSH_CONST_SIZE)
	buf.encode_s32(0, width)
	buf.encode_s32(4, height)
	buf.encode_float(8, r2_val)
	buf.encode_float(12, damping)
	buf.encode_s32(16, mode)
	return buf


# Packs settings for a normal simulation step
func _pack_step_constants(width: int, height: int, r2_val: float, damping: float, subpass: int = 0, thickness: float = 0.0, sigma_dt: float = 0.0) -> PackedByteArray:
	var buf := _pack_base_constants(width, height, r2_val, damping, 0)
	buf.encode_float(36, float(subpass))
	buf.encode_float(40, thickness)
	buf.encode_float(44, sigma_dt)
	return buf


# Packs settings for adding a sound impulse at a specific point on the grid
func _pack_impulse_constants(width: int, height: int, r2_val: float, damping: float, ix: int, iy: int, amp: float, sigma: float) -> PackedByteArray:
	var buf := _pack_base_constants(width, height, r2_val, damping, 1)
	buf.encode_s32(20, ix)
	buf.encode_s32(24, iy)
	buf.encode_float(28, amp)
	buf.encode_float(32, sigma)
	return buf


# Adds a sound pulse to the queue so it gets applied on the next frame
func _inject_impulse(gx: int, gy: int, amplitude: float = 1.0):
	pending_impulses.append({"gx": gx, "gy": gy, "amp": amplitude, "sigma": 1.5})


func _get_speakers() -> Array[Node]:
	var speakers: Array[Node] = []
	for child in get_children():
		if child is Node2D and child.has_method("emit_sound"):
			speakers.append(child)
	return speakers


# Handles keyboard input: Space creates a sound pulse in the center, R resets the simulation
func _unhandled_input(event):
	if not isMenu:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			var speakers := _get_speakers()
			if not speakers.is_empty():
				for speaker_node in speakers:
					speaker_node.emit_sound()
			else:
				push_warning("Missing speaker (!!!!!?)")
			print("Sound")

		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			var zero_data := PackedByteArray()
			zero_data.resize(BUF_BYTES)
			zero_data.fill(0)
			for buf_rid in buffers:
				rd.buffer_update(buf_rid, 0, BUF_BYTES, zero_data)
			step = 0
			print("Reset")

		if event is InputEventKey and event.pressed and event.keycode == KEY_C:
			if drawing_layer and drawing_layer.has_method("clear_shapes"):
				drawing_layer.clear_shapes()
				print("Shapes cleared")


# Cleans up all GPU resourcese
func _exit_tree():
	if rd:
		for us in uniform_sets:
			if us.is_valid():
				rd.free_rid(us)
		for buf_rid in buffers:
			if buf_rid.is_valid():
				rd.free_rid(buf_rid)
		if obstacle_buffer.is_valid():
			rd.free_rid(obstacle_buffer)
		if pipeline.is_valid():
			rd.free_rid(pipeline)
		if shader_rid.is_valid():
			rd.free_rid(shader_rid)
		rd.free()
