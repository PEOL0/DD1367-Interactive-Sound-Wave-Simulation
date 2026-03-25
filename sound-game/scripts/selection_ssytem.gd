extends HBoxContainer

var penSelected : bool = false
@export var penButton : Button

func _ready() -> void:
	self.get_parent().size.x = (self.size.x * self.scale.x) + 26

func pen_selection(toggled_on: bool):
	penSelected = toggled_on

func non_pen_pressed():
	penSelected = false
	penButton.button_pressed = false
