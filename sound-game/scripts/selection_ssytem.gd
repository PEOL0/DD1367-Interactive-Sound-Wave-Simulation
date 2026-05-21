extends HBoxContainer

# En egen skapad datatyp för att hålla koll
# på vilket verktyg som är vald
enum Tool {
	PEN,
	SQUARE,
	TRIANGLE,
	BUILDING,
	PAVILLION,
	CHURCH,
	SPEAKER,
	EMPTY
}

var current_tool: Tool = Tool.PEN
# Koppla INTE knappar manuellt längre via kod
# utan använd ButtonGroup i Inspector

# Objekt specific valbar referens. För att
# ge dessa variabler värden görs det utanför 
# scriptet i 'Inspector' rutan
@export var pen_button: Button
@export var drawing_node: Node
@export var buttonGroup: ButtonGroup

# Referens till koden som behövs för 'ghostObject'
# samt referens till självaste objektet
var ghost_script: Script = preload("res://scripts/ghost_object.gd")
var ghost_object: Sprite2D

# Variabel som säger om de kan plasera objekt i
# denna stund
var can_place: bool = true


# Funktion som sätter upp objektet när den först
# skapas
func _ready() -> void:
	self.get_parent().size.x = (self.size.x * self.scale.x) + 26
	
	# Skapar 'ghostObject' samt sätter dess script som ska köras.
	# Samtidigt sätts objektet in i trädet som ett bran till det
	# nuvarande objektet
	ghost_object = Sprite2D.new()
	ghost_object.set_script(ghost_script)
	self.add_child(ghost_object)
	
	pen_button.button_pressed = true


# Följande 5 funktioner gör samma sak fast för olika
# objekt. Vad de gör är att ställa om verktyget så
# att dess funktionalitet är korrekt relativt till
# det valda verktyget.

# toggled_on -> Ifall knappen är tryckt på eller av
func pen_selection(toggled_on: bool):
	if toggled_on:
		# Ställer om det nuvarande verktyget samt rensar
		# ghost_object
		current_tool = Tool.PEN
		ghost_object.clear_polygon()
	else:
		# Rensar nuvarande verktyget
		current_tool = Tool.EMPTY


# toggled_on -> Ifall knappen är tryckt på eller av
func pavillion_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.PAVILLION
		ghost_object.set_sprite("res://drawings/PVK_Paviljong.png", get_parent().get_parent().pavillion_points, 1.04)
	else:
		current_tool = Tool.EMPTY
		ghost_object.clear_polygon()


# toggled_on -> Ifall knappen är tryckt på eller av
func building_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.BUILDING
		ghost_object.set_sprite("res://drawings/PVK_Buliding_2.png", get_parent().get_parent().house_points, 1.04)
	else:
		current_tool = Tool.EMPTY
		ghost_object.clear_polygon()


# toggled_on -> Ifall knappen är tryckt på eller av
func church_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.CHURCH
		ghost_object.set_sprite("res://drawings/PVK_Church.png", get_parent().get_parent().church_points, 1.04)
	else:
		current_tool = Tool.EMPTY
		ghost_object.clear_polygon()


# toggled_on -> Ifall knappen är tryckt på eller av
func speaker_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.SPEAKER
		ghost_object.set_sprite("res://drawings/PVK_Speaker_Version_2.png", )
	else:
		current_tool = Tool.EMPTY
		ghost_object.clear_polygon()


# En funktion som rensar allt relaterat till de
# olika verktygen och dess funktionaliteter
func clear_selection():
	ghost_object.clear_polygon()
	current_tool = Tool.EMPTY
	
	# Kallar på en funktion som rensar alla skapade
	# objekt som inte är högtalare
	drawing_node.clear_shapes()
	
	# Detta är en loop som hittar alla högtalare i simulationen
	# och raderar dem objekten helt
	for child in self.get_parent().get_parent().get_children():
		if child.name.contains("Speaker"):
			child.free()
	
	# Hämtar vilken knapp som är tryckt just nu
	# och om den är på slåss den av och på igen
	var active_button = buttonGroup.get_pressed_button()
	if active_button:
		active_button.toggle_mode = false
		active_button.toggle_mode = true
