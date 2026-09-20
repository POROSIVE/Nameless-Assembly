extends Node
class_name PlayerInventory


signal inventory_changed(item_id: String, new_ammount: int)

@export var starting_items: Dictionary = {}

var _items: Dictionary = {}

func _ready() -> void:
	for k in starting_items:
		_items[k] = int(starting_items[k])
		
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
	
func remove(item_id: String, amount: int = 1) -> bool:
	if not has(item_id, amount):
		return false
	_items[item_id] = get_amount(item_id) - amount
	if _items[item_id] <= 0:
		_items.erase(item_id)
	inventory_changed.emit(item_id, _items.get(item_id, 0))
	return true
	
func consume(required: Array) -> bool:
	if not has_all(required):
		return false
	for entry in required:
		remove(entry["item"], int(entry["amount"]))
	return true
	
func snapshot() -> Dictionary:
	return _items.duplicate()
	
	
	
