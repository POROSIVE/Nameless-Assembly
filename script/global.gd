extends Node3D

@onready var settings_menu: Control = $InteractionUI/Ingame_Settings
@onready var player: CharacterBody3D = $Player
@export var escape : StringName = &"escape"

func _ready():
	settings_menu.hide()
	player.capture_mouse()
	if not Engine.has_singleton("RecipeManager"):
		var rm = preload("res://script/RecipeManager.gd").new()
		
		rm.name =  "RecipeManager"
		Engine.register_singleton("RecipeManger", rm)
		get_tree().root.call_deferred("add_child", rm)


func _input(event):
#	I tried many times getting this right I really hope not gonna touch this again
# bro have to do this otherwise we have bug with component crafter
	if event.is_action_pressed("escape"):
		var ui:= get_tree().get_first_node_in_group("interaction_ui")
		if ui != null and ui.has_method(
			"is_crafting_panel_visible"
		) and ui.is_crafting_panel_visible():
			ui.close_crafter()
			get_viewport().set_input_as_handled()
			return
		if settings_menu.visible:
			close_stgs()
		else:
			open_stgs()
		get_viewport().set_input_as_handled()
		

#To make sure the mouse not gonna get captured when still opening settings
func open_stgs():
	settings_menu.show()
	player.release_mouse()
	settings_menu.show()
	player.release_mouse()
	var crosshair = player.get_node_or_null("Head/CanvasLayer")
	if crosshair:
		crosshair.hide()
		
		
func close_stgs():
	player.capture_mouse()
	settings_menu.hide()
	var crosshair = player.get_node_or_null("Head/CanvasLayer")
	if crosshair:
		crosshair.show()
		
		
