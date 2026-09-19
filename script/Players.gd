extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const SENSITIVITY := 0.005

const BOB_FREQ := 2.0
const BOB_AMP := 0.08

const BASE_FOV := 75.0
const FOV_CHANGE := 1.5

const HOSE_HOLD_DISTANCE := 2.0

var mouse_captured : bool = false
var speed := WALK_SPEED
var gravity := 9.8
var t_bob := 0.0
var initial_cam_pos: Vector3

var grabbed_hose = null
var grabbed_end := ""

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var settings_menu = $"../Ingame_Settings"

func _unhandled_input(event: InputEvent) -> void:
#	all player inpt
	if mouse_captured and event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)

		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-40.0),
			deg_to_rad(60.0)
		)

	if event.is_action_pressed("grab"):
		if grabbed_hose == null:
			try_grab_hose_from_camera()

	if event.is_action_released("grab"):
		if grabbed_hose != null:
			release_hose()


func _ready() :
	initial_cam_pos = camera.transform.origin


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	#handle sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
		
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

		
	if is_on_floor() and velocity.length() > 0.1:
		t_bob += delta * velocity.length()
		camera.transform.origin = initial_cam_pos + _headbob(t_bob)
	else:
		camera.transform.origin = camera.transform.origin.lerp(initial_cam_pos, delta * 10.0)
	
	#fov
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
		
	update_hose_grab()
	move_and_slide()


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
	
func find_hose_handle(node: Node) -> Node:
	var current := node

	while current != null:
		if current.is_in_group("hose_handle"):
			return current

		current = current.get_parent()

	return null

func try_grab_hose_from_camera() -> void:
	if not interaction_ray.is_colliding():
		print("Nothing detected by interaction ray.")
		return
		
	var hit_object: Node = find_hose_handle(
		interaction_ray.get_collider()
	)
	try_grab_hose_handle(hit_object)
	
func try_grab_hose_handle(hit_object: Node) -> void:
	if hit_object == null:
		return
	if not hit_object.is_in_group("hose_handle"):
		print("Object is not a hose handle.")
		return
	# StartHandle and EndHandle are direct children of FlexibleHose.
	var hose = hit_object.get_parent()
	if hose == null:
		print("Could not find hose parent.")
		return
	if not hose.has_method("begin_grabbing_start"):
		print("The parent does not appear to be a FlexibleHose.")
		return
	if hit_object.name == "StartHandle":
		if hose.begin_grabbing_start():
			grabbed_hose = hose
			grabbed_end = "start"
			print("Grabbed START of hose.")
			return
	if hit_object.name == "EndHandle":
		if hose.begin_grabbing_end():
			grabbed_hose = hose
			grabbed_end = "end"
			print("Grabbed END of hose.")
			return
	print("Could not grab this hose handle.")

func update_hose_grab() -> void:	
	if grabbed_hose == null:		
		return
	var hold_position := get_hose_hold_position()
	if grabbed_end == "start":
		grabbed_hose.move_start_handle(hold_position)
	elif grabbed_end == "end":
		grabbed_hose.move_end_handle(hold_position)

func get_hose_hold_position() -> Vector3:
	if not is_instance_valid(camera):
		return global_position
	if not camera.is_inside_tree():
		return global_position
	return (
		camera.global_position
		- camera.global_transform.basis.z * HOSE_HOLD_DISTANCE
	)

func release_hose() -> void:
	if grabbed_hose != null:
		print("Released hose.")

	grabbed_hose = null
	grabbed_end = ""

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP
	return pos
