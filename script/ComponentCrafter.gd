extends StaticBody3D
class_name  ComponentCrafter


@export var display_name: String = "Component Crafter"
@export var auto_pick_recipe: bool = true
@export var recipe_id: String = ""

@onready var prompt_label: Label3D = $PromptLabel

var _is_crafting: bool = false
var _craft_timer: float = 0.0
var _active_recipe: Dictionary = {}
var _crafting_player: PlayerInventory = null

signal crafting_started(recipe: Dictionary)
signal crafting_finished(recipe: Dictionary, outputs: Array)

func _ready() -> void:
	_update_prompt()

func _process(delta: float) -> void:
	if not _is_crafting:
		return
	_craft_timer -= delta
	_update_prompt()
	if _craft_timer <= 0.0:
		_finish_craft()

func interact(player: Node) -> void:
	var inv := _get_inventory(player)
	if inv == null:
		return

	if _is_crafting:
		var recipe_name := String(
			_active_recipe.get(
				"display_name",
				_active_recipe.get("id", "?")
			)
		)
		print(
			"[%s] Busy crafting %s (%.1fs left)"
			% [display_name, recipe_name, _craft_timer]
		)
		return

	var ui := get_tree().get_first_node_in_group("interaction_ui")
	if ui != null and ui.has_method("open_crafter"):
		ui.open_crafter(self, inv, player)
		return

	var recipe := _pick_recipe(inv)
	if recipe.is_empty():
		print(
			"[%s] Nothing craftable with current inventory."
			% display_name
		)
		return
	if not inv.consume(recipe["inputs"]):
		print(
			"[%s] Nothing changed - minimum check failed."
			% display_name
		)
		return
		
	_start_craft(recipe, inv)

func _pick_recipe(inv: PlayerInventory) -> Dictionary:
	var lookup := Callable(inv, "get_amount")
	if auto_pick_recipe:
		return RecipeManager.find_craftable(lookup)
	var r : Dictionary = RecipeManager.get_recipe(recipe_id)
	if r.is_empty():
		return{}
	if not RecipeManager.can_craft(r, lookup):
		return{}
	return r
	
func _start_craft(recipe:Dictionary, inv: PlayerInventory) -> void:
	_active_recipe = recipe
	_crafting_player = inv
	_craft_timer = float(recipe["craft_time"])
	_is_crafting = true
	crafting_started.emit(recipe)
	print("[%s] started %s (%.1fs)" % [ display_name, recipe.get("display_name", recipe["id"]), _craft_timer])
	_update_prompt()
	
func craft_recipe(recipe_id_to_craft: String, player: Node) -> bool:
	if _is_crafting:
		return false
	var inv := _get_inventory(player)
	if inv == null:
		return false
	var recipe: Dictionary = RecipeManager.get_recipe(recipe_id_to_craft)
	if recipe.is_empty():
		push_warning(
			"Recipe not found: %s"
			% recipe_id_to_craft
		)
		return false
	var lookup := Callable(inv, "get_amount")
	if not RecipeManager.can_craft(recipe, lookup):
		return false
	if not inv.consume(recipe["inputs"]):
		return false
	_start_craft(recipe, inv)
	return true

func _finish_craft() -> void: 
	var recipe := _active_recipe
	var outputs: Array = recipe.get("outputs", [])
	_is_crafting = false
	
	if is_instance_valid(_crafting_player):
		for out in outputs:
			_crafting_player.add(out["item"], int(out["amount"]))
		crafting_finished.emit(recipe, outputs)
		print("[%s] Finished %s -> %s" % [
			display_name, recipe.get("display_name", recipe["id"]), _format_outputs(outputs)
		])
	else: 
		push_warning("ComponentCrafter: player gonebefore craft finished; output lost.")
		
	_active_recipe = {}
	_crafting_player = null
	_craft_timer = 0.0
	_update_prompt()
	
func _update_prompt() -> void:
	if prompt_label == null:
		return
	if _is_crafting:
		var recipe_name := String(
			_active_recipe.get("display_name", "?")
		)
		prompt_label.text = "Crafting %s... (%.1fs)" % [
			recipe_name,
			maxf(_craft_timer, 0.0)
		]
	else:
		prompt_label.text = "%s\n[E] Craft" % display_name
		
		
func _get_inventory(player: Node) -> PlayerInventory:
	for child in player.get_children():
		if child is PlayerInventory:
			return child
	var inv := PlayerInventory.new()
	inv.name = "PlayerInventory"
	player.add_child(inv)
	return inv
	
func _format_outputs(outputs: Array) -> String:
	var parts := PackedStringArray()
	for o in outputs:
		parts.append("%dx %s" % [int(o["amount"]), o["item"]])
	return ", ".join(parts)
