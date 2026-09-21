extends CanvasLayer

var player: Node
var inventory: PlayerInventory
var current_crafter: ComponentCrafter

@onready var inventory_panel: PanelContainer = $HUD/InventoryPanel
@onready var inventory_list: VBoxContainer = $HUD/InventoryPanel/MarginContainer/InventoryColumn/InventoryList
@onready var crafting_panel: PanelContainer = $HUD/CraftingPanel
@onready var crafting_title: Label = $HUD/CraftingPanel/MarginContainer/CraftingColumn/CraftingTitle
@onready var crafting_list: VBoxContainer = $HUD/CraftingPanel/MarginContainer/CraftingColumn/CraftingList
@onready var close_button: Button = $HUD/CraftingPanel/MarginContainer/CraftingColumn/CloseButton

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()

# for note craftr locates this interface through the group instead of relying on the scene node's name.
func _ready() -> void:
	add_to_group("interaction_ui")
	crafting_panel.hide()
	inventory_panel.hide()
	close_button.pressed.connect(close_crafter)
	player = get_tree().get_first_node_in_group("player")

# Opening the crafting window also releases the mouse so the player can interact with buttons instead of continuing to control the camera
func open_crafter(
		crafter: ComponentCrafter,
		inv: PlayerInventory,
		player_node: Node
	) -> void:
	current_crafter = crafter
	inventory = inv
	player = player_node
	crafting_panel.visible = true
	crafting_title.text = crafter.display_name.to_upper()
	_refresh_inventory()
	_refresh_crafting_list()
	if player.has_method("release_mouse"):
		player.release_mouse()

# returns control
func close_crafter() -> void:
	crafting_panel.visible = false
	current_crafter = null
	if player != null and player.has_method("capture_mouse"):
		player.capture_mouse()

func toggle_inventory() -> void:
	if inventory == null:
		var player_node := get_tree().get_first_node_in_group("player")

		if player_node != null and player_node.has_method("_get_inventory"):
			inventory = player_node._get_inventory(player_node)

	inventory_panel.visible = not inventory_panel.visible

	if inventory_panel.visible:
		_refresh_inventory()


func _refresh_inventory() -> void:
	if inventory_list == null:
		return

	for child in inventory_list.get_children():
		child.queue_free()

	if inventory == null:
		var missing_label := Label.new()
		missing_label.text = "NO INVENTORY"
		inventory_list.add_child(missing_label)
		return

	var contents: Dictionary = inventory.snapshot()

	if contents.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Inventory empty"
		inventory_list.add_child(empty_label)
		return

	var item_ids: Array = contents.keys()
	item_ids.sort()

	for item_id in item_ids:
		var amount: int = int(contents[item_id])
		if amount <= 0:
			continue

		var row := HBoxContainer.new()
		var item_label := Label.new()
		item_label.text = _pretty_item_name(String(item_id))
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount_label := Label.new()
		amount_label.text = str(amount)
		row.add_child(item_label)
		row.add_child(amount_label)
		inventory_list.add_child(row)

func _refresh_crafting_list() -> void:
	if crafting_list == null:
		return

	for child in crafting_list.get_children():
		child.queue_free()

	if current_crafter == null or inventory == null:
		return

	var lookup := Callable(inventory, "get_amount")
	for recipe in RecipeManager.recipes:
		var recipe_id: String = String(recipe.get("id", ""))
		var recipe_name: String = String(
			recipe.get("display_name", recipe_id)
		)
		var inputs_text: String = _format_inputs(
			recipe.get("inputs", [])
		)
		var outputs_text: String = _format_outputs(
			recipe.get("outputs", [])
		)
		var craft_time: float = float(
			recipe.get("craft_time", 0.0)
		)
		var can_craft: bool = RecipeManager.can_craft(
			recipe,
			lookup
		)
		var recipe_button := Button.new()
		recipe_button.custom_minimum_size = Vector2(0, 76)
		recipe_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		recipe_button.text = "%s\n%s  →  %s  |  %.1fs" % [
			recipe_name,
			inputs_text,
			outputs_text,
			craft_time
		]
		recipe_button.disabled = not can_craft
		recipe_button.pressed.connect(
			_on_recipe_pressed.bind(recipe_id)
		)
		crafting_list.add_child(recipe_button)

func _on_recipe_pressed(recipe_id: String) -> void:
	if current_crafter == null or player == null:
		return
	var success := current_crafter.craft_recipe(
		recipe_id,
		player
	)
	if success:
		_refresh_inventory()
		_refresh_crafting_list()

func _on_inventory_changed(
	_item_id: String,
	_new_amount: int
) -> void:
	_refresh_inventory()

	if crafting_panel.visible:
		_refresh_crafting_list()


func _format_inputs(inputs: Array) -> String:
	var parts := PackedStringArray()

	for input in inputs:
		parts.append(
			"%dx %s"
			% [
				int(input["amount"]),
				_pretty_item_name(String(input["item"]))
			]
		)

	return ", ".join(parts)

func _format_outputs(outputs: Array) -> String:
	var parts := PackedStringArray()
	for output in outputs:
		parts.append(
			"%dx %s"
			% [
				int(output["amount"]),
				_pretty_item_name(String(output["item"]))
			]
		)

	return ", ".join(parts)
	
func _pretty_item_name(item_id: String) -> String:
	return item_id.replace("_", " ").capitalize()
