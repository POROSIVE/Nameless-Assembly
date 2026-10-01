extends CanvasLayer

const ITEM_COLORS := {
	"steel_ingot": Color(0.6, 0.6, 0.62),
	"unobtanium_powder": Color(0.6, 0.3, 0.8),
	"resin": Color(0.7, 0.5, 0.2),
	"copper_wire": Color(0.8, 0.4, 0.1),
	"circuit_board": Color(0.2, 0.6, 0.3),
	"ammo_backplate_0_steel": Color(0.4, 0.4, 0.42),
	"ammo_shell_0_steel": Color(0.45, 0.45, 0.47),
	"ammo_propellant_0_standard": Color(0.8, 0.7, 0.2),
	"ammo_payload_0_standard": Color(0.7, 0.2, 0.2),
}
signal  crafting_opened()
signal crafting_closed()

var player: Node
var inventory: PlayerInventory
var current_crafter: ComponentCrafter


@onready var crafting_panel: PanelContainer = $HUD/CraftingPanel
@onready var crafting_title: Label = $HUD/CraftingPanel/MarginContainer/CraftingColumn/CraftingTitle
@onready var crafting_list: VBoxContainer = $HUD/CraftingPanel/MarginContainer/CraftingColumn/CraftingList
@onready var close_button: Button = $HUD/CraftingPanel/MarginContainer/CraftingColumn/CloseButton

var current_recipe_label: Label = null
var crafting_progress: ProgressBar = null

var _icon_gen: ItemIcon


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()

# for note craftr locates this interface through the group instead of relying on the scene node's name.
func _ready() -> void:
	add_to_group("interaction_ui")
	crafting_panel.hide()
	close_button.pressed.connect(close_crafter)
	_find_crafting_nodes()
	_icon_gen = ItemIcon.new()
	
func _find_crafting_nodes() -> void:
	var column := get_node_or_null("HUD/CraftingPanel/MarginContainer/CraftingColumn")
	if column == null:
		return
	current_recipe_label = column.get_node_or_null("CurrentRecipeLabel")
	crafting_progress = column.get_node_or_null("ProgressBar")
		
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
	if not inventory.inventory_changed.is_connected(
		_on_inventory_changed
	):
		inventory.inventory_changed.connect(_on_inventory_changed)
	crafting_panel.visible = true
	crafting_opened.emit()
	if crafter.has_signal("crafting_started") and not crafter.crafting_started.is_connected(_on_crafting_started):
		crafter.crafting_started.connect(_on_crafting_started)
	if crafter.has_signal("crafting_updated") and not crafter.crafting_updated.is_connected(_on_crafting_updated):
		crafter.crafting_updated.connect(_on_crafting_updated)
	if crafter.has_signal("crafting_finished") and not crafter.crafting_finished.is_connected(_on_crafting_finished):
		crafter.crafting_finished.connect(_on_crafting_finished)
		
	crafting_title.text = crafter.display_name.to_upper()
	if player.has_method("_refresh_hotbar"):
		player._refresh_hotbar()
	_refresh_crafting_list()
	current_recipe_label.text = ""
	crafting_progress.value = 0
	
	if player.has_method("release_mouse"):
		player.release_mouse()

# returns control
func close_crafter() -> void:
	if current_crafter != null and current_crafter.has_method("cancel_craft"):
		if current_crafter._is_crafting:
			current_crafter.cancel_craft()
	crafting_panel.visible = false
	crafting_closed.emit()
	current_crafter = null
	if player != null and player.has_method("capture_mouse"):
		player.capture_mouse()

func toggle_inventory() -> void:
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node == null:
		return
	if player_node.has_method("_refresh_hotbar"):
		player_node._refresh_hotbar()




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
		recipe_button.custom_minimum_size = Vector2(0,76)
		recipe_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		recipe_button.disabled = not can_craft
		
		var inputs_row := HBoxContainer.new()
		for inp in recipe.get("inputs", []):
			inputs_row.add_child(_item_icon(String(inp["item"]), int(inp["amount"])))
		var arrow := Label.new()
		arrow.text = "->"
		arrow.add_theme_font_size_override("font_size", 24)
		var outputs_row = HBoxContainer.new()
		for out in recipe.get("outputs", []):
			outputs_row.add_child(_item_icon(String(out["item"]), int(out["amount"])))
		
		var middle = HBoxContainer.new()
		middle.add_child(arrow)
		
		var details := VBoxContainer.new()
		details.add_child(inputs_row)
		details.add_child(middle)
		details.add_child(outputs_row)
		
		var outer :=  VBoxContainer.new()
		outer.add_child(details)
		var time_label := Label.new()
		time_label.text = "%.1fs" % craft_time
		time_label.add_theme_font_size_override("font_size", 12)
		outer.add_child(time_label)
		
		recipe_button.add_child(outer)
		recipe_button.pressed.connect(_on_recipe_pressed.bind(recipe_id))
		crafting_list.add_child(recipe_button)

func _on_recipe_pressed(recipe_id: String) -> void:
	if current_crafter == null or player == null:
		return
	var success := current_crafter.craft_recipe(
		recipe_id,
		player
	)
	if success:
		if player.has_method("_refresh_hotbar"):
			player._refresh_hotbar()
		_refresh_crafting_list()

func _on_inventory_changed(
	_item_id: String,
	_new_amount: int
) -> void:
	if player != null and player.has_method("_refresh_hotbar"):
		player._refresh_hotbar()
		
		

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



	
func _on_cancel_pressed() -> void:
	if current_crafter != null and current_crafter.has_method("cancel_craft"):
		current_crafter.cancel_craft()
	crafting_panel.visible = false
	if player != null and player.has_method(
		"capture_mouse"
	):
		player.capture_mouse()
		
		
func _on_crafting_started(recipe: Dictionary, total_time: float) -> void:
	var name := String(recipe.get("display_name", recipe.get("id", "?")))
	current_recipe_label.text = "Crafting: %s" % name
	crafting_progress.max_value = total_time
	
func _on_crafting_updated(time_left: float) -> void:
	crafting_progress.value = time_left
	
func _on_crafting_finished(outputs: Array) -> void:
	current_recipe_label.text = "Done!"
	crafting_progress.value = 0
	
	
func _item_color(item_id: String) -> Color:
	return ITEM_COLORS.get(item_id, Color(0.5 , 0.5, 0.5))
	
func _item_icon(item_id: String, amount: int) -> Control:
	var color := _item_color(item_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(36, 36)
	
	var border_panel := PanelContainer.new()
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = color
	border_panel.add_theme_stylebox_override("panel", border_style)
	
	var inner := PanelContainer.new()
	inner.custom_minimum_size = Vector2(30, 30)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color.darkened(0.55)
	inner.add_theme_stylebox_override("panel", fill_style)
	
	border_panel.add_child(inner)
	panel.add_child(border_panel)


	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	
	var row := HBoxContainer.new()
	row.add_child(panel)
	row.add_child(label)
	return row
	
	
	
	
	
