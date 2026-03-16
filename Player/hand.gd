class_name Hand extends Node3D


var m_grabbing: bool = false
var m_grabbed: bool = false
var m_holdingEnemy: bool = false
@export var m_sprite: AnimatedSprite3D
var m_targetPos: Vector3
var m_grabSpeed: float = 10.0
var m_grabLockDist: float = 0.1

func _ready() -> void:
	m_targetPos = global_position
	
func set_grab(grab: bool):
	if grab == false:
		m_targetPos = global_position
		m_grabbed = false
	m_sprite.top_level = grab
	m_grabbing = grab

func set_grab_point(point: Vector3):
	m_targetPos = point

func get_grab_point() -> Vector3:
	return m_sprite.global_position

func get_grab() -> bool:
	return m_grabbed
	
func get_grabbing() -> bool:
	return m_grabbing
	
func get_holding_enemy() -> bool:
	return m_holdingEnemy
	
func set_holding_enemy(holding: bool):
	m_holdingEnemy = holding

func _physics_process(delta: float) -> void:
	if not m_grabbing:
		m_targetPos = global_position
	
	if (m_sprite.global_position.distance_to(m_targetPos) <= m_grabLockDist):
		if m_grabbing:
			m_grabbed = true
	else:
		m_sprite.global_position = m_sprite.global_position.lerp(m_targetPos, delta * m_grabSpeed)
