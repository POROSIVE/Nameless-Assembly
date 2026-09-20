extends CharacterBody3D

@export_group("Crouch Parameters")
@export var CROUCH_SPEED: float = 3.0
@export var TOGGLE_CROUCH: bool = false
@export var CROUCH_HEIGHT: float = 1.2
@export var STAND_HEIGHT: float = 2.0
@export var CROUCH_CAM_OFFSET: float = -0.5
@export var CROUCH_TRANSITION_SPEED: float = 10.0

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

var is_crouching: bool = false
var current_cam_y: float = 0.0

var grabbed_hose = null
var grabbed_end := ""

@export var settings_menu: Control
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var original_cam_y: float = $Head/Camera3D.position.y

func _ready() -> void:
#	all player inpt
	capture_mouse()
	current_cam_y = original_cam_y
	var focused_node = get_viewport().gui_get_focus_owner()
	if focused_node:
		focused_node.release_focus()
		
func _unhandled_input(event: InputEvent) -> void:
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

func _physics_process(delta: float) -> void:
	handle_crouch(delta)
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	#speed selection logic
	if is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = Vector3.ZERO
	
	if input_dir != Vector2.ZERO:
		direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
		
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	#camera height lerping for Crouch
	var target_cam_y = original_cam_y + (CROUCH_CAM_OFFSET if is_crouching else 0.0)
	current_cam_y = lerp(current_cam_y, target_cam_y, delta * CROUCH_TRANSITION_SPEED)
	
	#apply headbob on top of the base crouch height
	if is_on_floor() and velocity.length() > 0.1:
		t_bob += delta * velocity.length()
		var bob = _headbob(t_bob)
		camera.position = Vector3(bob.x, current_cam_y + bob.y, bob.z)
	else:
		camera.position.x = lerp(camera.position.x, 0.0, delta * 10.0)
		camera.position.y = lerp(camera.position.y, current_cam_y, delta * 10.0)
		camera.position.z = lerp(camera.position.z, 0.0, delta * 10.0)
	
	#fov
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
		
	update_hose_grab()
	move_and_slide()

#crouching logic
func handle_crouch(delta: float) -> void:
	if TOGGLE_CROUCH:
		if Input.is_action_just_pressed("crouch"):
			if is_crouching:
				try_uncrouch()
			else:
				is_crouching = true
	else:
		if Input.is_action_pressed("crouch"):
			is_crouching = true
		else:
			try_uncrouch()
				
	var target_height: float = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var shape = $CollisionShape3D.shape as CapsuleShape3D
	if shape:
		shape.height = lerp(shape.height, target_height, delta * CROUCH_TRANSITION_SPEED)
				 

func try_uncrouch() -> void:
	if has_node("ShapeCast3D") and $ShapeCast3D.is_colliding():
		print("Cant uncrouch, hitting: ", $ShapeCast3D.get_collider(0)) 
	else:
		is_crouching = false
		
#hose mechanics & mouse capture
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
		
	var collider: Node = interaction_ray.get_collider()
	
	if collider.has_method("interact"):
		collider.interact(self)
		return
		
	var hose_handle: Node = find_hose_handle(collider)
	try_grab_hose_handle(hose_handle)
	
func try_grab_hose_handle(hit_object: Node) -> void:
	if hit_object == null:
		return
	if not hit_object.is_in_group("hose_handle"):
		print("Could not find hose parent.")
		return
		
	var hose = hit_object.get_parent()
	if not hose.has_method("begin_grabbing_start") or not hose.has_method("begin_grabbing_end"):
		print("The Parent does not appear to be a flexiblehose.")
		return
	if hit_object.name == "StartHandle":
		hose.begin_grabbing_start()
		grabbed_hose = hose
		grabbed_end = "start"
		print("Grabbed START of hose.")
		return
		
	if hit_object.name == "EndHandle":
		hose.begin_grabbing_end()
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
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return global_position
		
	# get normalized forwarddirection safely without divesion by zero
	var cam_transform = camera.global_transform.orthonormalized()
	var forward_dir = cam_transform.basis.z
	
	if forward_dir.length_squared() == 0:
		return camera.global_position
		
	return camera.global_position - forward_dir * HOSE_HOLD_DISTANCE


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
	
