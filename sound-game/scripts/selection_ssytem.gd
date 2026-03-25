extends HBoxContainer
enum Tool {
	PEN,
	SQUARE,
	TRIANGLE,
	L,
	DELETE
}

var current_tool: Tool = Tool.PEN
# Koppla INTE knappar manuellt längre via kod
# utan använd ButtonGroup i Inspector

@export var penButton: Button
@export var squareButton: Button
@export var triangleButton: Button
@export var lButton: Button
@export var clearButton: Button
@export var drawing_node: Node


func _ready() -> void:
	self.get_parent().size.x = (self.size.x * self.scale.x) + 26
	penButton.button_pressed = true
	


# 🔘 PEN
func pen_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.PEN


# 🔲 SQUARE
func square_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.SQUARE


# 🔺 TRIANGLE
func triangle_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.TRIANGLE


# 🧱 L-SHAPE
func l_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.L



func clear_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.DELETE
