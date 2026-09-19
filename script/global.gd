extends Node3D

@onready var settings_menu: Control = $Ingame_Settings
@onready var player: CharacterBody3D = $Player
@export var escape : StringName = &"escape"

func _ready():
	settings_menu.hide()
	player.capture_mouse()

func _input(event):
#	I tried many times getting this right I really hope not gonna touch this again
	if event.is_action_pressed(escape):
		if settings_menu.visible:
			close_stgs()
		else:
			open_stgs()
		get_viewport().set_input_as_handled()

#To make sure the mouse not gonna get captured when still opening settings
func open_stgs():
	settings_menu.show()
	player.release_mouse()

func close_stgs():
	player.capture_mouse()
	settings_menu.hide()
