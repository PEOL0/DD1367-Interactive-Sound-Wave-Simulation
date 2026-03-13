extends Node

@onready var shader_material: ShaderMaterial = $ColorRect.material
@export var isMenu: bool

const N := [1600, 900]
const TOTAL := N[0] * N[1]
const BUF_BYTES := TOTAL * 4 #4 because it is the size of a 32 bit float
const WORKGROUP_SIZE := 16

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
var step := 0                       
var pending_impulses: Array = []    
const PUSH_CONST_SIZE := 48


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
	for i in 3:
		buffers.append(rd.storage_buffer_create(BUF_BYTES, zero_data))

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
		uniform_sets.append(rd.uniform_set_create(uniforms, shader_rid, 0))

	print("Simulation ready – grid %d×%d  c=%.1f  dt=%.6f  CFL r=%.4f" % [
		N[0], N[1], c_speed, dt, c_speed * dt / dx])


# Runs every physics frame: sends work to the GPU to advance the sound simulation one time step
func _physics_process(_delta):
	var r := c_speed * dt / dx
	var r2 := r * r
	var dispatch_x := ceili(float(N[0]) / WORKGROUP_SIZE)
	var dispatch_y := ceili(float(N[1]) / WORKGROUP_SIZE)

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_sets[step], 0)

	for imp in pending_impulses:
		var packedConstants := _pack_impulse_constants(N[0], N[1], r2, global_damping, imp.gx, imp.gy, imp.amp, imp.sigma)
		rd.compute_list_set_push_constant(compute_list, packedConstants, PUSH_CONST_SIZE)
		rd.compute_list_dispatch(compute_list, dispatch_x, dispatch_y, 1)
		rd.compute_list_add_barrier(compute_list)
	pending_impulses.clear()

	var packedConstants := _pack_step_constants(N[0], N[1], r2, global_damping)
	rd.compute_list_set_push_constant(compute_list, packedConstants, PUSH_CONST_SIZE)
	rd.compute_list_dispatch(compute_list, dispatch_x, dispatch_y, 1)

	rd.compute_list_end()
	rd.submit()
	rd.sync()

	step = (step + 1) % 3

	var data := rd.buffer_get_data(buffers[step], 0, BUF_BYTES)
	var result_img := Image.create_from_data(N[0], N[1], false, Image.FORMAT_RF, data)
	pressure_texture.update(result_img)


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
func _pack_step_constants(width: int, height: int, r2_val: float, damping: float) -> PackedByteArray:
	return _pack_base_constants(width, height, r2_val, damping, 0)


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


# Handles keyboard input: Space creates a sound pulse in the center, R resets the simulation
func _unhandled_input(event):
	if not isMenu:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_inject_impulse(N[0] / 2, N[1] / 2)
			print("Sound")

		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			var zero_data := PackedByteArray()
			zero_data.resize(BUF_BYTES)
			zero_data.fill(0)
			for buf_rid in buffers:
				rd.buffer_update(buf_rid, 0, BUF_BYTES, zero_data)
			step = 0
			print("Reset")


# Cleans up all GPU resourcese
func _exit_tree():
	if rd:
		for us in uniform_sets:
			if us.is_valid():
				rd.free_rid(us)
		for buf_rid in buffers:
			if buf_rid.is_valid():
				rd.free_rid(buf_rid)
		if pipeline.is_valid():
			rd.free_rid(pipeline)
		if shader_rid.is_valid():
			rd.free_rid(shader_rid)
		rd.free()
