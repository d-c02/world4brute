extends RigidBody3D
var m_EnemyPackedScene = preload("res://enemy.tscn")
var m_StandUpThreshold = 1.0
var m_respawnCountdown = 0.0
const m_RESPAWN_TIME = 1.0
@onready var m_FloorRaycast = %FloorRaycast
@onready var m_Hitbox: Area3D = %Area3D

func _ready() -> void:
	m_Hitbox.body_entered.connect(on_collision)

func on_collision(other: Node3D):
	if other is Enemy:
		other.queue_free()
		queue_free()

func _physics_process(delta: float) -> void:
	m_FloorRaycast.global_position = global_position
	if m_FloorRaycast.is_colliding():
		m_respawnCountdown += delta
		if m_respawnCountdown >= m_RESPAWN_TIME:
			var enemy: CharacterBody3D = m_EnemyPackedScene.instantiate()
			#get_tree().get_current_scene()
			get_tree().get_root().add_child(enemy)
			enemy.global_position = m_FloorRaycast.get_collision_point()
			queue_free()
	else:
		m_respawnCountdown = 0
