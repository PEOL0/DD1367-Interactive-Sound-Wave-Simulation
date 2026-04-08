extends HBoxContainer
enum Tool {
	PEN,
	SQUARE,
	TRIANGLE,
	L,
	DELETE,
	SPEAKER,
	EMPTY
}

var current_tool: Tool = Tool.PEN
# Koppla INTE knappar manuellt längre via kod
# utan använd ButtonGroup i Inspector

@export var penButton: Button
@export var squareButton: Button
@export var triangleButton: Button
@export var lButton: Button
@export var speakerButton: Button
@export var clearButton: Button
@export var drawing_node: Node
@export var buttonGroup: ButtonGroup


func _ready() -> void:
	self.get_parent().size.x = (self.size.x * self.scale.x) + 26
	penButton.button_pressed = true
	print(drawing_node)



func pen_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.PEN
	else:
		current_tool = Tool.EMPTY



func square_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.SQUARE
	else:
		current_tool = Tool.EMPTY



func triangle_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.TRIANGLE
	else:
		current_tool = Tool.EMPTY



func l_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.L
	else:
		current_tool = Tool.EMPTY



func clear_selection():
	current_tool = Tool.EMPTY
	drawing_node.clear_shapes()
	var activeButton = buttonGroup.get_pressed_button()
	if activeButton:
		activeButton.toggle_mode = false
		activeButton.toggle_mode = true



func speaker_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.SPEAKER
	else:
		current_tool = Tool.EMPTY
