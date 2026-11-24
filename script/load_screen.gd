extends CanvasLayer

@onready var load_ui : Control = $LoadUI
@onready var status_label : Label = $LoadUI/VBoxContainer/StatusLabel
@onready var progress_bar : ProgressBar = $LoadUI/VBoxContainer/ProgressBar
var is_loading : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_ui.visible = false
	progress_bar.min_value = 0
	progress_bar.max_value = 100

func load_scenes(path: String) -> void:
	if is_loading:
		return
	is_loading = true
	load_ui.visible = true
	load_ui.modulate.a = 0.0
	status_label.text = "Loading..."
	progress_bar.value = 0
	var tween := create_tween()
	tween.tween_property(load_ui, "modulate:a", 1.0, 0.35)
	await tween.finished
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		await _show_error("cloud not change the scene: " + path)
		return
	
	var progress : Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty():
			progress_bar.value = progress[0] * 100
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path, progress)
		
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		await _show_error("cannot load: " + path)
		return
		
	progress_bar.value = 100
	var packed_scene := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed_scene == null:
		await _show_error(path + " is not a valid scene")
		return
	
	var tree := get_tree()
	get_tree().change_scene_to_packed(packed_scene)
	await tree.scene_changed
	tween = create_tween()
	tween.tween_property(load_ui, "modulate:a", 0.0, 0.4)
	await tween.finished
	load_ui.visible = false
	is_loading = false

func _show_error(message: String) -> void:
	push_error(message)
	status_label.text = message
	await get_tree().create_timer(1.0).timeout
	
	var tween := create_tween()
	tween.tween_property(load_ui, "modulate:a", 0.0, 0.4)
	await tween.finished
	load_ui.visible = false
	is_loading = false
