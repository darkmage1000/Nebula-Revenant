# EnemyHealthBar.gd – RED HEALTH BAR ABOVE ENEMIES
extends Control

@onready var health_bar = $HealthBar
@onready var health_label = $HealthBar/Label

var target_mob: CharacterBody2D = null

func _ready():
	# Red health bar for enemies
	health_bar.modulate = Color(1.0, 0.2, 0.2)

func _process(_delta: float):
	if not is_instance_valid(target_mob):
		queue_free()
		return
	
	# Position above enemy
	global_position = target_mob.global_position - Vector2(30, 50)
	
	# Update health bar
	health_bar.max_value = target_mob.max_health
	health_bar.value = target_mob.health
	
	# Update label (optional - comment out if you don't want numbers)
	health_label.text = "%d" % int(target_mob.health)
	
	# Hide when at full health (optional)
	if target_mob.health >= target_mob.max_health:
		visible = false
	else:
		visible = true

func set_target(mob: CharacterBody2D):
	target_mob = mob
