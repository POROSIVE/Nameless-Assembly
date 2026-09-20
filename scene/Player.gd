extends CharacterBody3D

@export_group("Crouch Parameters")
@export var CROUCH_SPEED: float = 3.0
@export var TOGGLE_CROUCH: bool = false
@export var CROUCH_HEIGHT: float = 1.2
@export var STAND_HEIGHT: float = 2.0
@export var CROUCH_CAM_OFFSET: float = -0.5
@export var CROUCH_TRANSITION_SPEED: float = 10.0

var is_crouching: bool = false
@onready var original_cam_y: float = $Head/Camera3D.position.y

var speed = WALK_SPEED
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005

const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

var current_cam_y: float = 0.0

var gravity = 9.8
var initial_cam_pos : Vector3

@onready var head = $Head
@onready var camera = $Head/Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))


func _ready() :
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_cam_y = original_cam_y
	var focused_node = get_viewport().gui_get_focus_owner()
	if focused_node:
		focused_node.release_focus()
		
	
		



func _physics_process(delta):
	#toggle vs hold logic
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
		#handle target camera positon			
		
		#handle camera & colsion height lerping
		var target_height: float = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
				
		#Adjust collision capsule height
		var shape = $CollisionShape3D.shape as CapsuleShape3D
		if shape:
			shape.height = lerp(shape.height, target_height, delta * CROUCH_TRANSITION_SPEED)
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
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

	#calculate base camera y for crouching
	var target_cam_y = original_cam_y + (CROUCH_CAM_OFFSET if is_crouching else 0.0)
	current_cam_y = lerp(current_cam_y, target_cam_y, delta * CROUCH_TRANSITION_SPEED)
		
		
	#headbob on top of base croch/stand camera y position
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
	
	
	move_and_slide()
	
	
#Handling CROUCH
	
			
func try_uncrouch() -> void:
	if $ShapeCast3D.is_colliding():
		print("Can't uncrouch, hitting::", $ShapeCast3d.get_collider(0))
	else:
		is_crouching = false 
		
	#Only stand up is nothing is colliding
	if not $ShapeCast3D.is_colliding():
		is_crouching = FLAG_PROCESS_THREAD_MESSAGES
		
			
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		print("Key pressed physcial code:", event.physical_keycode)


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP
	return pos
