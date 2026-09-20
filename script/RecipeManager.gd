extends Node

const RECIPES_PATH := "res://data/recipes.json"

var recipes: Array[Dictionary] = []
var _by_id: Dictionary= {}

func _ready() -> void:
	_load_recipes()
	
func _load_recipes() -> void:
	recipes.clear()
	_by_id.clear()
	
	if not FileAccess.file_exists(RECIPES_PATH):
		push_error("RecipeManage : missing %s" % RECIPES_PATH)
		return
		
	var text := FileAccess.get_file_as_string(RECIPES_PATH)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("RecipeManager: JSON parse error line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("recipes"):
		push_error("RecipeManagaer: root must be { \"recipes\": [...]}")
		return

	for r in data ["recipes"]:
		if _validate(r):
			recipes.append(r)
			_by_id[r["id"]] = r
			
		print("RecipeManager: loaded %d recipes." % recipes.size())
		
func _validate(r) -> bool:
	if typeof(r) != TYPE_DICTIONARY:
		push_warning("RecipeManager: skipping non-dict entry: %s" % r)
		return false
		
	for key in ["id", "inputs", "outputs", "craft_time"]:
		if not r.has(key):
			push_warning("RecipeManager: recipe '%s' inputs/outputs must be arrays" % r["id"])
			return false
	if typeof(r["inputs"]) != TYPE_ARRAY or typeof(r["outputs"]) != TYPE_ARRAY:
		push_warning("RecipeManager: recipe '%s' input/outputs must be arrays" % r["id"])
		return false
	return true

func get_recipe(id: String) -> Dictionary:
	return _by_id.get(id, {})
	
func can_craft(recipe: Dictionary, inventory_lookup: Callable) -> bool:
	for entry in recipe["inputs"]:
		if inventory_lookup.call(entry["item"]) < int(entry["amount"]):
			return false
	return true
		
func find_craftable(inventory_lookup: Callable) -> Dictionary:
	for r in recipes:
		if can_craft(r, inventory_lookup):
			return r
	return {}
		
func list_craftable(inventory_lookup: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in recipes:
		if can_craft(r, inventory_lookup):
			out.append(r)
	return out
	
	 
