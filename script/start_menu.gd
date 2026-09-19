extends Control
@onready var start_menu = $"."
@onready var settings_menu = $"../SettingsMenu"
@onready var start_btn = $VBoxContainer/Start_btn
@onready var settings_btn = $VBoxContainer/settings_btn

func _ready():
	print("game started")
	start_btn.pressed.connect(Callable(self, "_start_btn_pressed"))
	settings_btn.pressed.connect(Callable(self, "_settings_btn_pressed"))

func _start_btn_pressed():
	get_tree().change_scene_to_file("res://scene/factory.tscn")
	
func _settings_btn_pressed():
	start_menu.hide()
	settings_menu.show()

func new_game_data(obj: Node3D, filename: String = "obj_data.json") -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		DirAccess.make_dir_absolute("user://datas")
	else:
		if not dir.dir_exists("datas"):
			dir.make_dir("datas")

	var data := {
		"position": [obj.global_transform.origin.x, obj.global_transform.origin.y, obj.global_transform.origin.z],
		"rotation": [obj.rotation_degrees.x, obj.rotation_degrees.y, obj.rotation_degrees.z]
	}
	var file_path := "user://datas/" + filename
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Saved object data to: ", file_path)
	else:
		push_error("Could not open file for writing: " + file_path)

func load_object_data(obj: Node3D, filename: String = "obj_data.json") -> void:
	var file_path := "user://datas/" + filename
	if not FileAccess.file_exists(file_path):
		push_error("File not found: " + file_path)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var result = JSON.parse_string(text)
	if typeof(result) == TYPE_DICTIONARY:
		var pos_arr: Array = result["position"]
		var rot_arr: Array = result["rotation"]

		obj.global_transform.origin = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		obj.rotation_degrees = Vector3(rot_arr[0], rot_arr[1], rot_arr[2])
		print("Data Loaded!")
