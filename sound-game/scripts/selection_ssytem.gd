extends HBoxContainer
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

@export var penButton: Button
@export var drawing_node: Node
@export var buttonGroup: ButtonGroup

var ghostScript: Script = preload("res://scripts/ghost_object.gd")
var ghostObject: Sprite2D
var can_place: bool = true


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
		ghostObject.clear_polygon()



func triangle_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.TRIANGLE
		ghostObject.triangle(264)
	else:
		current_tool = Tool.EMPTY
		ghostObject.clear_polygon()

func pavillion_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.PAVILLION
		ghostObject.set_sprite("res://drawings/PVK_Paviljong.png", get_parent().get_parent().pavillion_points, 1.04)
	else:
		current_tool = Tool.EMPTY
		ghostObject.clear_polygon()

func building_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.BUILDING
		ghostObject.set_sprite("res://drawings/PVK_Buliding_2.png", get_parent().get_parent().house_points, 1.04)
	else:
		current_tool = Tool.EMPTY
		ghostObject.clear_polygon()


func church_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.CHURCH
		ghostObject.set_sprite("res://drawings/PVK_Church.png", get_parent().get_parent().church_points, 1.04)
	else:
		current_tool = Tool.EMPTY
		ghostObject.clear_polygon()



func clear_selection():
	ghostObject.clear_polygon()
	current_tool = Tool.EMPTY
	drawing_node.clear_shapes()
	for child in self.get_parent().get_parent().get_children():
		if child.name.contains("Speaker"):
			print(child.name)
			child.free()
		
	var activeButton = buttonGroup.get_pressed_button()
	if activeButton:
		activeButton.toggle_mode = false
		activeButton.toggle_mode = true



func speaker_selection(toggled_on: bool):
	if toggled_on:
		current_tool = Tool.SPEAKER
		ghostObject.clear_polygon()
		ghostObject.set_sprite("res://drawings/PVK_Speaker_Version_2.png", )
	else:
		current_tool = Tool.EMPTY
		ghostObject.clear_polygon()
