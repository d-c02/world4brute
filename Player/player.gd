extends CharacterBody3D

var m_WalkSpeed: float = 10.0
var m_WalkAccel: float = 40.0
var m_WalkFriction: float = 80.0
var m_StandingCamPos: float = 0.5
@onready var m_StandHitbox: CollisionShape3D = %StandHitbox

var m_CrouchSpeed: float = 5.0
var m_CrouchAccel = 40.0
var m_CrouchFriction: float = 60.0
var m_CrouchCamPos: float = 0.0
@onready var m_CrouchHitbox: CollisionShape3D = %CrouchHitbox
var m_Crouching: bool = false
@onready var m_HandsAnchor: Node3D = %HandsAnchor

var m_GrabAccel: float = 30.0

var m_AirAccel: float = 20.0
var m_AirFriction: float = 20.0
var m_AirSpeed: float = 10.0

var m_DashSpeed: float = 10.0
var m_GroundPoundSpeed: float = 100.0

@export var m_Camera: Camera3D

var m_TargetVelocity: Vector3
var m_TerminalVelocity: float = -50.0
var m_Gravity: float = -10.0
var m_MouseSensitivity: float = 0.15
var m_MaxCameraRotationUp: float = 90.0
var m_MaxCameraRotationDown: float = -89.9
var m_GrabRange: float = 2.25
var m_GrabRangeBuffer: float = 0.1

var m_throwStrength: float = 2000.0
var m_EnemyRagdoll = preload("res://enemy_ragdoll.tscn")

@onready var m_Reticle: AnimatedSprite2D = %Reticle
@onready var m_LeftHand: Hand = %LeftHandAnchor
@onready var m_LeftHandAnim: AnimatedSprite3D = %LeftHandAnim
@onready var m_RightHand: Hand = %RightHandAnchor
@onready var m_RightHandAnim: AnimatedSprite3D = %RightHandAnim

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
		var grab = CheckGrab()
		if grab != null:
			if grab is Enemy:
				m_LeftHand.set_holding_enemy(true)
				m_LeftHandAnim.animation = "holding_enemy"
				grab.queue_free()
			else:
				m_LeftHand.set_grab_point(CheckGrabVector())
				m_LeftHand.set_grab(true)
				m_LeftHandAnim.animation = "grabbing"

	if Input.is_action_just_pressed("grab_right"):
		var grab = CheckGrab()
		if grab != null:
			if grab is Enemy:
				m_RightHand.set_holding_enemy(true)
				m_RightHandAnim.animation = "holding_enemy"
				grab.queue_free()
			else:
				m_RightHand.set_grab_point(CheckGrabVector())
				m_RightHand.set_grab(true)
				m_RightHandAnim.animation = "grabbing"

	if Input.is_action_just_released("grab_left"):
		if m_LeftHand.get_grab() or m_LeftHand.get_grabbing():
			m_LeftHand.set_grab(false)
			m_LeftHandAnim.animation = "default"
		elif m_LeftHand.get_holding_enemy():
			m_LeftHandAnim.animation = "default"
			m_LeftHand.set_holding_enemy(false)
			var enemyRagdoll: RigidBody3D = m_EnemyRagdoll.instantiate()
			add_child(enemyRagdoll)
			enemyRagdoll.global_position = global_position
			enemyRagdoll.top_level = true
			enemyRagdoll.apply_force(-m_Camera.global_basis.z * m_throwStrength)
	if Input.is_action_just_released("grab_right"):
		if m_RightHand.get_grab() or m_RightHand.get_grabbing():
			m_RightHand.set_grab(false)
			m_RightHandAnim.animation = "default"
		elif m_RightHand.get_holding_enemy():
			m_RightHandAnim.animation = "default"
			m_RightHand.set_holding_enemy(false)
			var enemyRagdoll: RigidBody3D = m_EnemyRagdoll.instantiate()
			add_child(enemyRagdoll)
			enemyRagdoll.global_position = global_position
			enemyRagdoll.top_level = true
			enemyRagdoll.apply_force(-m_Camera.global_basis.z * m_throwStrength)
	
	if Input.is_action_just_pressed("crouch"):
		m_Crouching = true
		m_CrouchHitbox.disabled = false
		m_StandHitbox.disabled = true
		m_Camera.transform.origin.y = m_CrouchCamPos
	
	if Input.is_action_just_released("crouch"):
		m_Crouching = false
		m_CrouchHitbox.disabled = true
		m_StandHitbox.disabled = false
		m_Camera.transform.origin.y = m_StandingCamPos

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
	
	if Input.is_action_just_pressed("dash"):
		m_TargetVelocity += direction * m_DashSpeed
	
	if !is_on_floor():


		if m_TargetVelocity.y > m_TerminalVelocity:
			m_TargetVelocity.y += m_Gravity * delta
		
		
		if Input.is_action_pressed("ground_pound"):
			m_TargetVelocity += Vector3.DOWN * m_GroundPoundSpeed * delta
		else:
			if m_TargetVelocity.y < m_TerminalVelocity:
				m_TargetVelocity.y -= 2 * m_Gravity * delta

	else:

		m_TargetVelocity.y = 0

		if Input.is_action_just_pressed("jump") and !(m_LeftHand.get_grab() or m_RightHand.get_grab()):
			m_TargetVelocity.y += m_JumpSpeed
			

	if direction.length() > 0:
		if (is_on_floor()):
			if (m_Crouching):
				m_TargetVelocity.x += direction.x * m_CrouchAccel * delta
				m_TargetVelocity.z += direction.z * m_CrouchAccel * delta
			else:
				m_TargetVelocity.x += direction.x * m_WalkAccel * delta
				m_TargetVelocity.z += direction.z * m_WalkAccel * delta
		elif m_LeftHand.get_grab() or m_RightHand.get_grab():
			m_TargetVelocity.x += direction.x * m_GrabAccel * delta
			m_TargetVelocity.z += direction.z * m_GrabAccel * delta
		else:
			m_TargetVelocity.x += direction.x * m_AirAccel * delta
			m_TargetVelocity.z += direction.z * m_AirAccel * delta
	else:

		var NoYVel = velocity
		NoYVel.y = 0

		var y = m_TargetVelocity.y
		m_TargetVelocity = NoYVel.lerp(Vector3.ZERO, delta * 20)
		m_TargetVelocity.y = y

	if (is_on_floor()):
		if m_Crouching:
			if m_TargetVelocity.length() > m_CrouchSpeed:
				m_TargetVelocity -= m_CrouchFriction * m_TargetVelocity.normalized() * delta
		else:
			if m_TargetVelocity.length() > m_WalkSpeed:
				m_TargetVelocity -= m_WalkFriction * m_TargetVelocity.normalized() * delta
	else:
		if m_TargetVelocity.length() > m_AirSpeed:
				m_TargetVelocity -= m_AirFriction * m_TargetVelocity.normalized() * delta
		
	#m_DebugLabel.text = str((m_TargetVelocity * 100).round() / 100.0)
	#apply_grab_constraints(delta)
	apply_grab_constraints(delta)
	velocity = m_TargetVelocity
	move_and_slide()

# TODO: STOP PLAYER FROM GOING TOO FAR AND NEEDING TO CORRECT
func apply_grab_constraints(delta):

	var grab_points: Array = []
	
	if m_LeftHand.get_grab():
		grab_points.append(m_LeftHand.get_grab_point())
		
	if m_RightHand.get_grab():
		grab_points.append(m_RightHand.get_grab_point())
	
	if grab_points.size() == 0:
		return

	if Input.is_action_just_pressed("jump"):
		m_TargetVelocity.y += m_JumpSpeed
		if (!is_on_floor()):
			if m_LeftHand.get_grab():
				m_LeftHand.set_grab(false)
				m_LeftHandAnim.animation = "default"
			if m_RightHand.get_grab():
				m_RightHand.set_grab(false)
				m_RightHandAnim.animation = "default"
			return

	var predicted_position: Vector3 = global_position + m_TargetVelocity * delta

	for p in grab_points:

		var arm: Vector3 = predicted_position - p
		var dist := arm.length()

		if dist <= 0.0001:
			continue

		var dir := arm / dist

		if dist > MAX_ARM_LENGTH:

			var correction := dist - MAX_ARM_LENGTH
			predicted_position -= dir * correction

	# Apply corrected position
	global_position = lerp(global_position, predicted_position, delta * 10)

	for p in grab_points:

		var arm: Vector3 = global_position - p
		var dist := arm.length()

		if dist <= 0.0001:
			continue

		var dir := arm / dist

		if dist >= MAX_ARM_LENGTH:

			var outward_speed := m_TargetVelocity.dot(dir)

			if outward_speed > 0:
				m_TargetVelocity -= dir * outward_speed

func _process(_delta):

	if CheckGrab() != null:
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
		return target

	return null


func CheckGrabVector():

	var start = m_Camera.global_position
	var end = m_Camera.global_position + (-m_Camera.global_transform.basis.z * (m_GrabRange + m_GrabRangeBuffer))

	var spaceState = m_Camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start,end)

	var result = spaceState.intersect_ray(query)

	if "collider" in result:

		var collider = result["collider"]

		#var target = collider

		if "position" in result:
			return result["position"]

	push_error("Nowhere to grab")
	return Vector3.ZERO
