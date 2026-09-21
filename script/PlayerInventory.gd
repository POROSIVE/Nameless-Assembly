extends Node
class_name PlayerInventory
signal inventory_changed(item_id: String, new_ammount: int)

const DEFAULT_INVENTORY_PATH := "res://data/inventory.json"
const SAVE_INVENTORY_PATH := "user://player_inventory.json"
@export var starting_items: Dictionary = {}

var _items: Dictionary = {}

func _ready() -> void:
	_load_inventory()

func _load_inventory() -> void:
	# giving all items from the default inventory file wen starting the game
	# note this is for debug test only, the release should not include this
	_items = _read_inventory_file(DEFAULT_INVENTORY_PATH)
	if FileAccess.file_exists(SAVE_INVENTORY_PATH):
		var saved_items := _read_inventory_file(SAVE_INVENTORY_PATH)
		for item_id in saved_items:
			_items[item_id] = int(saved_items[item_id])
			
	print("player inventory loaded: ", _items)

func _read_inventory_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("PlayerInventory: missing file, " + path)
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("PlayerInventory: cannot open the inventory file, " + path)
		return {}
		
	var json_text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("PlayerInventory: JSON error on the line %d: %s" % [json.get_error_line() ,json.get_error_message()])
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("PlayerInventory: root must be dictionary, " + path)
		return {}
	if not data.has("items") or typeof(data["items"]) != TYPE_DICTIONARY:
		push_warning("PlayerInventory: root must be dictionary, " + path)
		return {}
		
	var result : Dictionary = {}
	for item_id in data["items"]:
		result[String(item_id)] = int(data["items"][item_id])
		
	return result


func get_amount(item_id: String) -> int:
	return int(_items.get(item_id, 0))
	
func has(item_id: String, amount: int = 1) -> bool:
	return get_amount(item_id) >=amount
	
func has_all(required: Array) -> bool:
	for entry in required:
		if not has(entry["item"], int(entry["amount"])):
			return false
	return true

func add(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	_items[item_id] = get_amount(item_id) + amount
	inventory_changed.emit(item_id, _items[item_id])
	save_inventory()

func remove(item_id: String, amount: int = 1) -> bool:
	if not has(item_id, amount):
		return false

	_items[item_id] = get_amount(item_id) - amount
	if _items[item_id] <= 0:
		_items.erase(item_id)
		
	inventory_changed.emit(item_id, _items.get(item_id, 0))
	save_inventory()
	return true
	
func consume(required: Array) -> bool:
	if not has_all(required):
		return false
	for entry in required:
		remove(entry["item"], int(entry["amount"]))
	return true
	
func snapshot() -> Dictionary:
	return _items.duplicate(true)
	
func save_inventory() -> void:
	var file := FileAccess.open(SAVE_INVENTORY_PATH, FileAccess.WRITE)
	if file == null:
		push_error("PlayerInventory: could not save inventory.")
		return
		
	file.store_string(JSON.stringify({"items": _items}, "\t"))
	
	
	
