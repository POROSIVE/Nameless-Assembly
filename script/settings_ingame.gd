extends Control

@onready var player: Node3D = $"../Player"
@onready var volume_slider = $VBoxContainer/VolumeSlider
@onready var vsync_checkbox = $HBoxContainer/VsyncCheckBox
@onready var fps_spinbox = $HBoxContainer2/FpsSpinBox
@onready var savebtn = $VBoxContainer3/savebtn

const CONFIG_PATH = "user://settings.cfg"

func _ready() -> void:
	load_settings()
	savebtn.pressed.connect(Callable(self, "_save_object_data"))
	volume_slider.value_changed.connect(Callable(self, "_on_volume_changed"))
	vsync_checkbox.toggled.connect(Callable(self, "_on_vsync_toggled"))
	fps_spinbox.value_changed.connect(Callable(self, "_on_fps_changed"))


# --- SIGNAL CALLBACKS ---
func _save_object_data():
	save_object_data(player)

func _on_volume_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, value)
	save_settings()

func _on_vsync_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	save_settings()

func _on_fps_changed(value: float) -> void:
	Engine.max_fps = int(value)
	save_settings()


# --- SAVE & LOAD ---
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "vsync", vsync_checkbox.button_pressed)
	config.set_value("graphics", "fps", Engine.max_fps)
	config.set_value("audio", "volume", volume_slider.value)
	config.save(CONFIG_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		# Load graphics
		if config.has_section_key("graphics", "vsync"):
			var vsync_on: bool = config.get_value("graphics", "vsync")
			vsync_checkbox.button_pressed = vsync_on
			if vsync_on:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		if config.has_section_key("graphics", "fps"):
			Engine.max_fps = int(config.get_value("graphics", "fps"))
			fps_spinbox.value = Engine.max_fps

		# Load audio
		if config.has_section_key("audio", "volume"):
			var vol = float(config.get_value("audio", "volume"))
			volume_slider.value = vol
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), vol)
	else:
		# Defaults if no config file
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Engine.max_fps = 1000
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 0.0)

func save_object_data(obj: Node3D, filename: String = "obj_data.json") -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		DirAccess.make_dir_absolute("user://datas")
	else:
		if not dir.dir_exists("datas"):
			dir.make_dir("datas")

	# Convert to arrays
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
