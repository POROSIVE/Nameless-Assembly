extends Node3D

@export_category("Hose Settings")
@export var point_count: int = 30
@export var hose_length: float = 1.0
@export var hose_radius: float = 0.3
@export var tube_sides: int = 16
@export var simulation_iterations: int = 8
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)
@export var damping: float = 0.985

@export_category("Hose References")
@export var start_handle: AnimatableBody3D
@export var end_handle: AnimatableBody3D
@export var start_detector: Area3D
@export var end_detector: Area3D
@export var pipe_mesh: MeshInstance3D


var points: PackedVector3Array
var previous_points: PackedVector3Array

var start_connected: bool = false
var end_connected: bool = false
var is_locked: bool = false

var old_mesh: ArrayMesh


func _ready() -> void:
	if start_handle == null:
		start_handle = $StartHandle

	if end_handle == null:
		end_handle = $EndHandle

	if start_detector == null:
		start_detector = $StartHandle/StartDetector

	if end_detector == null:
		end_detector = $EndHandle/EndDetector

	if pipe_mesh == null:
		pipe_mesh = $PipeMesh

	start_detector.area_entered.connect(_on_start_detector_area_entered)
	start_detector.area_exited.connect(_on_start_detector_area_exited)

	end_detector.area_entered.connect(_on_end_detector_area_entered)
	end_detector.area_exited.connect(_on_end_detector_area_exited)

	initialize_hose()
	update_pipe_mesh()


func initialize_hose() -> void:
	points = PackedVector3Array()
	previous_points = PackedVector3Array()

	var start_position: Vector3 = to_local(start_handle.global_position)
	var end_position: Vector3 = to_local(end_handle.global_position)

	for i in range(point_count):
		var t: float = float(i) / float(point_count - 1)

		var point: Vector3 = start_position.lerp(end_position, t)

		points.append(point)
		previous_points.append(point)


func _physics_process(delta: float) -> void:
	if is_locked:
		return

	simulate_hose(delta)
	update_pipe_mesh()


func simulate_hose(delta: float) -> void:
	if point_count < 3:
		return

	var start_position: Vector3 = to_local(start_handle.global_position)
	var end_position: Vector3 = to_local(end_handle.global_position)

	var point_spacing: float = hose_length / float(point_count - 1)

	# Move the internal points using Verlet integration.
	for i in range(1, point_count - 1):
		var current_position: Vector3 = points[i]

		var velocity: Vector3 = (
			points[i] - previous_points[i]
		) * damping

		previous_points[i] = current_position

		points[i] = (
			current_position
			+ velocity
			+ gravity * delta * delta
		)

	# Apply distance constraints several times.
	for iteration in range(simulation_iterations):
		points[0] = start_position
		points[point_count - 1] = end_position

		for i in range(point_count - 1):
			var point_a: Vector3 = points[i]
			var point_b: Vector3 = points[i + 1]

			var difference: Vector3 = point_b - point_a
			var distance: float = difference.length()

			if distance <= 0.001:
				continue

			var correction_amount: float = (
				distance - point_spacing
			) / distance

			var correction: Vector3 = difference * correction_amount

			if i == 0:
				# The start handle is fixed to its current position.
				points[i + 1] -= correction

			elif i + 1 == point_count - 1:
				# The end handle is fixed to its current position.
				points[i] += correction

			else:
				# Internal points share the correction.
				points[i] += correction * 0.5
				points[i + 1] -= correction * 0.5

	# Make sure both ends exactly follow their handles.
	points[0] = start_position
	points[point_count - 1] = end_position


func update_pipe_mesh() -> void:
	if points.size() < 2:
		return

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array = []

	# Generate a circular ring around every hose point.
	for i in range(points.size()):
		var current_point: Vector3 = points[i]

		var tangent: Vector3

		if i == 0:
			tangent = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			tangent = (
				points[points.size() - 1]
				- points[points.size() - 2]
			).normalized()
		else:
			tangent = (
				points[i + 1] - points[i - 1]
			).normalized()

		var reference_up := Vector3.UP

		# Avoid a bad cross product when the hose points upward.
		if abs(tangent.dot(reference_up)) > 0.95:
			reference_up = Vector3.RIGHT

		var side: Vector3 = tangent.cross(reference_up).normalized()
		var up: Vector3 = side.cross(tangent).normalized()

		var ring: Array[Vector3] = []

		for j in range(tube_sides):
			var angle: float = (
				TAU * float(j) / float(tube_sides)
			)

			var offset: Vector3 = (
				side * cos(angle) * hose_radius
				+ up * sin(angle) * hose_radius
			)

			ring.append(current_point + offset)

		rings.append(ring)

	# Convert neighboring rings into triangles.
	for i in range(rings.size() - 1):
		var ring_a: Array = rings[i]
		var ring_b: Array = rings[i + 1]

		for j in range(tube_sides):
			var next_j: int = (j + 1) % tube_sides

			var a: Vector3 = ring_a[j]
			var b: Vector3 = ring_a[next_j]
			var c: Vector3 = ring_b[next_j]
			var d: Vector3 = ring_b[j]

			var normal_1: Vector3 = (b - a).cross(c - a).normalized()
			var normal_2: Vector3 = (c - a).cross(d - a).normalized()

			surface_tool.set_normal(normal_1)
			surface_tool.add_vertex(a)

			surface_tool.set_normal(normal_1)
			surface_tool.add_vertex(b)

			surface_tool.set_normal(normal_1)
			surface_tool.add_vertex(c)

			surface_tool.set_normal(normal_2)
			surface_tool.add_vertex(a)

			surface_tool.set_normal(normal_2)
			surface_tool.add_vertex(c)

			surface_tool.set_normal(normal_2)
			surface_tool.add_vertex(d)

	# Delete the previous generated mesh.
	old_mesh = pipe_mesh.mesh as ArrayMesh

	var generated_mesh: ArrayMesh = surface_tool.commit()

	if generated_mesh != null:
		pipe_mesh.mesh = generated_mesh


func _on_start_detector_area_entered(area: Area3D) -> void:
	if not area.is_in_group("materializer_output"):
		return
	start_connected = true
	var dock := area.get_node_or_null("DockPoint")
	if dock != null:
		snap_start_to_dock(dock)
	check_if_hose_should_lock()


func _on_start_detector_area_exited(area: Area3D) -> void:
	if area.is_in_group("materializer_output"):
		start_connected = false

		if is_locked:
			unlock_hose()


func _on_end_detector_area_entered(area: Area3D) -> void:
	if not area.is_in_group("smelter_input"):
		return
	end_connected = true
	var dock := area.get_node_or_null("DockPoint")
	if dock != null:
		snap_end_to_dock(dock)
	check_if_hose_should_lock()


func _on_end_detector_area_exited(area: Area3D) -> void:
	if area.is_in_group("smelter_input"):
		end_connected = false

		if is_locked:
			unlock_hose()


func check_if_hose_should_lock() -> void:
	if start_connected and end_connected:
		lock_hose()


func lock_hose() -> void:
	if is_locked:
		return

	is_locked = true

	# Make sure the final curve uses the exact handle positions.
	points[0] = to_local(start_handle.global_position)
	points[points.size() - 1] = to_local(end_handle.global_position)

	# Tell the player interaction system that the ends cannot be grabbed.
	start_handle.set_meta("can_be_grabbed", false)
	end_handle.set_meta("can_be_grabbed", false)

	update_pipe_mesh()
	create_locked_collision()


func unlock_hose() -> void:
	if not is_locked:
		return

	is_locked = false

	start_handle.set_meta("can_be_grabbed", true)
	end_handle.set_meta("can_be_grabbed", true)

	remove_locked_collision()


func create_locked_collision() -> void:
	remove_locked_collision()

	if pipe_mesh.mesh == null:
		return

	var faces: PackedVector3Array = pipe_mesh.mesh.get_faces()

	if faces.is_empty():
		return

	var collision_body := StaticBody3D.new()
	collision_body.name = "LockedHoseCollision"

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"

	var concave_shape := ConcavePolygonShape3D.new()
	concave_shape.set_faces(faces)

	collision_shape.shape = concave_shape

	collision_body.add_child(collision_shape)
	add_child(collision_body)


func remove_locked_collision() -> void:
	var old_collision := get_node_or_null("LockedHoseCollision")

	if old_collision != null:
		old_collision.queue_free()


# These functions can be called by your player interaction system.
func begin_grabbing_start() -> bool:
	if is_locked:
		return false

	if not start_handle.get_meta("can_be_grabbed", true):
		return false

	return true


func begin_grabbing_end() -> bool:
	if is_locked:
		return false
	if not end_handle.get_meta("can_be_grabbed", true):
		return false
	return true


func move_start_handle(world_position: Vector3) -> void:
	if is_locked:
		return
	if not is_instance_valid(start_handle):
		return
	if not start_handle.is_inside_tree():
		return
	start_handle.global_position = world_position

func move_end_handle(world_position: Vector3) -> void:
	if is_locked:
		return
	if not is_instance_valid(end_handle):
		return
	if not end_handle.is_inside_tree():
		return
	end_handle.global_position = world_position

func snap_start_to_dock(dock: Node3D) -> void:
	if not is_instance_valid(dock):
		return
	if not dock.is_inside_tree():
		return
	start_handle.global_transform = dock.global_transform
	
func snap_end_to_dock(dock: Node3D) -> void:
	if not is_instance_valid(dock):
		return
	if not dock.is_inside_tree():
		return
	var target_transform := dock.global_transform
	# Flip the hose end around the dock's local Y axis.
	target_transform.basis = (
		target_transform.basis
		* Basis(Vector3.UP, PI)
	)
	end_handle.global_transform = target_transform
