extends KinematicBody
 
export(int) var speed = 10
export(int) var h_acceleration = 6
export(int) var air_acceleration = 1
export(int) var normal_acceleration = 6
export(float) var mouse_sensitivity = 0.03
export(int) var gravity = 20
export(int) var jump = 10
export(int) var friction = 0.9
 
onready var head = $Head
onready var ground_check = $GroundCheck
 
var full_contact = false
 
var direction = Vector3.ZERO
var h_velocity = Vector3.ZERO
var movement = Vector3.ZERO
var gravity_vec = Vector3.ZERO
 
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	#// If this peer has control on this player
	if is_network_master():
		$Head/Camera.make_current() #// Also set the camera, or all peers will use a camera from same player.
	#// If not, disable every process in the game.
	else:
		set_process(false)
		set_process_input(false)
		set_physics_process(false)
 
remote func _set_position(pos):
	global_transform.origin = pos
 
# Separated function to do rotation job.
remote func _set_rotation(rot: Vector2): 
	rotate_y(deg2rad(-rot.x * mouse_sensitivity))
	head.rotate_x(deg2rad(-rot.y * mouse_sensitivity))
	head.rotation.x = clamp(head.rotation.x, deg2rad(-89), deg2rad(89))
 
func _input(event):
	if event is InputEventMouseMotion:
		_set_rotation(event.relative) # call function locally.
		rpc_unreliable("_set_rotation", event.relative) # also, make a call to all other machines.
 
func _process(delta):
	rpc_unreliable("_set_position", global_transform.origin)
 
func _physics_process(dt):
	direction = Vector3.ZERO
	
	if ground_check.is_colliding():
		full_contact = true
	else:
		full_contact = false
	
	if not is_on_floor():
		gravity_vec += Vector3.DOWN * gravity * dt
		h_acceleration = air_acceleration
	elif is_on_floor() and full_contact:
		gravity_vec = -get_floor_normal() * gravity
		h_acceleration = normal_acceleration
	else:
		gravity_vec = -get_floor_normal()
		h_acceleration = normal_acceleration
	
	if Input.is_action_just_pressed("jump") and (is_on_floor() or ground_check.is_colliding()):
		gravity_vec = Vector3.UP * jump
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	elif Input.is_action_pressed("move_right"):
		direction += transform.basis.x
	
	direction = direction.normalized()
	h_velocity = h_velocity.linear_interpolate(direction * speed, h_acceleration * dt)
	movement.z = h_velocity.z + gravity_vec.z
	movement.x = h_velocity.x + gravity_vec.x
	movement.y = gravity_vec.y
 
	move_and_slide(movement, Vector3.UP)
	
	# NOTE: This movement is literally broken when you have more advanced moves, but it's still working so I call it the day :)
