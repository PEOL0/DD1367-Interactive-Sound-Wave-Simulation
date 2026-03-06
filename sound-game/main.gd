extends Node

@onready var shader_material: ShaderMaterial = $ColorRect.material
@export var isMenu: bool

const N := 100
const TOTAL := N * N

var c_speed := 120.0
var dx := 1.0
var dt: float
var global_damping := 0.999

var p0: PackedFloat32Array
var p1: PackedFloat32Array
var p2: PackedFloat32Array
var pressure_texture: ImageTexture


# Initialises the FDTD simulation: computes a CFL-stable time step, allocates the two pressure-field buffers (current and previous), and creates the GPU texture used to visualise the field.
func _ready():
	Engine.physics_ticks_per_second = 60

	dt = dx / (c_speed * sqrt(2.0)) * 0.95

	p0 = PackedFloat32Array()
	p0.resize(TOTAL)
	p0.fill(0.0)
	p1 = PackedFloat32Array()
	p1.resize(TOTAL)
	p1.fill(0.0)
	p2 = PackedFloat32Array()
	p2.resize(TOTAL)
	p2.fill(0.0)

	var img := Image.create(N, N, false, Image.FORMAT_RF)
	pressure_texture = ImageTexture.create_from_image(img)
	shader_material.set_shader_parameter("pressure_field", pressure_texture)

	print("Simulation ready – grid %d×%d  c=%.1f  dt=%.6f  CFL r=%.4f" % [
		N, N, c_speed, dt, c_speed * dt / dx])


# Runs as many FDTD sub-steps as needed to keep the simulation synchronised with the fixed physics tick, then uploads the resulting pressure field to the GPU texture for rendering.
func _physics_process(delta):
	_fdtd_step()
	_upload_pressure()


# Performs one step of the discrete 2D wave equation. Each cell is also multiplied by a global damping factor. After the sweep the two time-level buffers are swapped so p0 always holds the latest state.
func _fdtd_step():
	var r  := c_speed * dt / dx
	var r2 := r * r

	for y in range(1, N - 1):
		var row := y * N
		for x in range(1, N - 1):
			var i := row + x
			var lap := p0[i + 1] + p0[i - 1] + p0[i + N] + p0[i - N] - 4.0 * p0[i]
			p2[i] = (2.0 * p0[i] - p1[i] + r2 * lap) * global_damping

	var tmp := p1
	p1 = p0
	p0 = p2
	p2 = tmp


# Converts the current pressure buffer to a byte array and writes it into the single-channel float texture that the shader samples.
func _upload_pressure():
	var byte_data := p0.to_byte_array()
	var img := Image.create_from_data(N, N, false, Image.FORMAT_RF, byte_data)
	pressure_texture.update(img)


# Adds pressure pulse centred at grid cell (gx, gy). The pulse is superimposed onto the existing field so multiple impulses coexist and interfere naturally.
func _inject_impulse(gx: int, gy: int, amplitude: float = 1.0):
	var radius := 4
	var sigma := 1.5
	for dy in range(-radius, radius + 1):
		for ddx in range(-radius, radius + 1):
			var px := gx + ddx
			var py := gy + dy
			if px >= 1 and px < N - 1 and py >= 1 and py < N - 1:
				var dist_sq := float(ddx * ddx + dy * dy)
				var value := amplitude * exp(-dist_sq / (2.0 * sigma * sigma))
				p0[py * N + px] += value


# Handles keyboard input: 
# Space injects an impulse at the grid centre
# R resets both pressure buffers to zero.
func _unhandled_input(event):
	if not isMenu:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_inject_impulse(N / 2, N / 2)
			print("Ljud!")

		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			p0.fill(0.0)
			p1.fill(0.0)
			print("Fält nollställt")
