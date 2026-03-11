extends CharacterBody3D

var m_WalkSpeed: float = 6.0

@export var m_Camera: Camera3D

var m_TargetVelocity: Vector3
var m_TerminalVelocity: float = -10.0
var m_Gravity: float = -10.0
var m_MouseSensitivity: float = 0.15
var m_MaxCameraRotationUp: float = 90.0
var m_MaxCameraRotationDown: float = -90.0
var m_GrabRange: float = 2.25
var m_GrabRangeBuffer: float = 0.1

@onready var m_Reticle: AnimatedSprite2D = %Reticle
@onready var m_LeftHand: Hand = %LeftHandAnchor
@onready var m_RightHand: Hand = %RightHandAnchor

var m_JumpSpeed: float = 5.0

const MAX_ARM_LENGTH := 2.0
const CENTER_PULL := 20.0

# debug
# @export var m_DebugLabel: Label
# @export var m_DebugGrabMesh: MeshInstance3D
# var m_DebugRaycastMesh: ImmediateMesh


func _ready():
	m_TargetVelocity = Vector3()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _physics_process(delta):
	if Input.is_action_pressed("ui_cancel"):
		get_tree().quit()

	# Do a single check grab earlier to simplify if either is pressed?
	if Input.is_action_just_pressed("grab_left"):
		if CheckGrab():
			m_LeftHand.set_grab_point(CheckGrabVector())
			m_LeftHand.set_grab(true)

	if Input.is_action_just_pressed("grab_right"):
		if CheckGrab():
			m_RightHand.set_grab_point(CheckGrabVector())
			m_RightHand.set_grab(true)

	if Input.is_action_just_released("grab_left"):
		m_LeftHand.set_grab(false)

	if Input.is_action_just_released("grab_right"):
		m_RightHand.set_grab(false)

	var direction: Vector3 = Vector3.ZERO

	var cameraVector = -m_Camera.global_transform.basis.z
	cameraVector.y = 0
	cameraVector = cameraVector.normalized()

	var orthogonalCameraDifferenceVector = Vector3(-cameraVector.z,0,cameraVector.x).normalized()

	if Input.is_action_pressed("walk_right"):
		direction += orthogonalCameraDifferenceVector * Input.get_action_strength("walk_right")

	if Input.is_action_pressed("walk_left"):
		direction -= orthogonalCameraDifferenceVector * Input.get_action_strength("walk_left")

	if Input.is_action_pressed("walk_backward"):
		direction -= cameraVector * Input.get_action_strength("walk_backward")

	if Input.is_action_pressed("walk_forward"):
		direction += cameraVector * Input.get_action_strength("walk_forward")

	if direction.length() > 1:
		direction = direction.normalized()

	if !is_on_floor():

		m_TargetVelocity.y += m_Gravity * delta

		if m_TargetVelocity.y < m_TerminalVelocity:
			m_TargetVelocity.y -= 2 * m_Gravity * delta

		if m_LeftHand.get_grab() or m_RightHand.get_grab():
			pass

	else:

		m_TargetVelocity.y = 0

		if Input.is_action_just_pressed("jump") and !(m_LeftHand.get_grab() or m_RightHand.get_grab()):
			m_TargetVelocity.y += m_JumpSpeed
			

	if direction.length() > 0:

		m_TargetVelocity.x = direction.x * m_WalkSpeed
		m_TargetVelocity.z = direction.z * m_WalkSpeed

	else:

		var NoYVel = velocity
		NoYVel.y = 0

		var y = m_TargetVelocity.y
		m_TargetVelocity = NoYVel.lerp(Vector3.ZERO, delta * 20)
		m_TargetVelocity.y = y

	#m_DebugLabel.text = str((m_TargetVelocity * 100).round() / 100.0)
	#apply_grab_constraints(delta)
	apply_grab_constraints(delta)
	velocity = m_TargetVelocity
	move_and_slide()

func apply_grab_constraints(delta):
	
	var grab_points: Array = []
	
	if m_LeftHand.get_grab():
		grab_points.append(m_LeftHand.get_grab_point())
		
	if m_RightHand.get_grab():
		grab_points.append(m_RightHand.get_grab_point())
	
	if len(grab_points) == 0:
		return
		
	if (Input.is_action_just_pressed("jump")):
		m_LeftHand.set_grab(false)
		m_RightHand.set_grab(false)
		m_TargetVelocity.y += m_JumpSpeed
		return
	# Pull player toward center of grab points
	var center := Vector3.ZERO
	for p in grab_points:
		center += p
	center /= grab_points.size()

	# Rope constraint for each hand
	for p in grab_points:

		var arm: Vector3 = global_position - p
		var dist := arm.length()

		if dist <= 0.0001:
			continue

		var dir := arm / dist

		# If stretched, prevent moving farther away
		if dist >= MAX_ARM_LENGTH:
			var outward_speed := m_TargetVelocity.dot(dir)
			# Remove velocity that extends the rope
			if outward_speed > 0:
				m_TargetVelocity -= dir * outward_speed

func _process(delta):

	if CheckGrab():
		m_Reticle.animation = "Active"
	else:
		m_Reticle.animation = "Inactive"


func _input(event):

	if event is InputEventMouseMotion:

		rotate_y(event.relative.x * PI / 180.0 * m_MouseSensitivity * -1)

		m_Camera.rotate_x(event.relative.y * PI / 180.0 * m_MouseSensitivity * -1)

		var rot = m_Camera.rotation_degrees
		rot.x = clamp(rot.x, m_MaxCameraRotationDown, m_MaxCameraRotationUp)
		rot.y = 0
		rot.z = 0
		m_Camera.rotation_degrees = rot


func CheckGrab():

	var start = m_Camera.global_position
	var end = m_Camera.global_position + (-m_Camera.global_transform.basis.z.normalized() * (m_GrabRange + m_GrabRangeBuffer))

	var spaceState = m_Camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start,end)

	var result = spaceState.intersect_ray(query)

	#m_DebugRaycastMesh = ImmediateMesh.new()
	#m_DebugRaycastMesh.surface_begin(Mesh.PRIMITIVE_LINES)
	#m_DebugRaycastMesh.surface_set_normal(Vector3(0,0,1))
	#m_DebugRaycastMesh.surface_set_uv(Vector2(0,0))
	#m_DebugRaycastMesh.surface_add_vertex(start)

	#m_DebugRaycastMesh.surface_set_normal(Vector3(0,0,1))
	#m_DebugRaycastMesh.surface_set_uv(Vector2(0,1))
	#m_DebugRaycastMesh.surface_add_vertex(end)

	#m_DebugRaycastMesh.surface_end()

	#m_DebugGrabMesh.mesh = m_DebugRaycastMesh

	if "collider" in result:

		var collider = result["collider"]
		var target = collider
		return true

	return false


func CheckGrabVector():

	var start = m_Camera.global_position
	var end = m_Camera.global_position + (-m_Camera.global_transform.basis.z * (m_GrabRange + m_GrabRangeBuffer))

	var spaceState = m_Camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start,end)

	var result = spaceState.intersect_ray(query)

	if "collider" in result:

		var collider = result["collider"]

		var target = collider

		if "position" in result:
			return result["position"]

	push_error("Nowhere to grab")
	return Vector3.ZERO
