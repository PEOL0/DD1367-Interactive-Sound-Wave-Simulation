extends HBoxContainer
enum Tool {
	PEN,
	SQUARE,
	TRIANGLE,
	L,
	SPEAKER,
	EMPTY
}

var current_tool: Tool = Tool.PEN
# Koppla INTE knappar manuellt längre via kod
# utan använd ButtonGroup i Inspector

@export var penButton: Button
@export var drawing_node: Node
@export var buttonGroup: ButtonGroup

var ghostScript: Script = preload("res://scripts/ghost_object.gd")
var ghostObject: Sprite2D


func _ready() -> void:
	self.get_parent().size.x = (self.size.x * self.scale.x) + 26
	ghostObject = Sprite2D.new()
	ghostObject.set_script(ghostScript)
	self.add_child(ghostObject)
	penButton.button_pressed = true
	print(drawing_node)



func pen_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.PEN
		ghostObject.clear_polygon()
	else:
		current_tool = Tool.EMPTY



func square_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.SQUARE
		ghostObject.square(264)
	else:
		current_tool = Tool.EMPTY



func triangle_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.TRIANGLE
		ghostObject.triangle(264)
	else:
		current_tool = Tool.EMPTY



func l_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.L
		ghostObject.l_shape(264)
	else:
		current_tool = Tool.EMPTY



func clear_selection():
	ghostObject.clear_polygon()
	current_tool = Tool.EMPTY
	drawing_node.clear_shapes()
	var activeButton = buttonGroup.get_pressed_button()
	if activeButton:
		activeButton.toggle_mode = false
		activeButton.toggle_mode = true



func speaker_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.SPEAKER
		ghostObject.clear_polygon()
		ghostObject.set_sprite("res://assets/PVK_Speaker.png")
	else:
		current_tool = Tool.EMPTY
