# bullet.gd – FULL: ALL UPGRADES + AREA2D (NO ERRORS)
extends Area2D

# BULLET STATS
var damage: float = 10.0
var pierce: int = 0
var poison_enabled: bool = false
var poison_damage: float = 0.0
var burn_enabled: bool = false
var burn_damage: float = 0.0
var knockback_amount: float = 0.0

# PLAYER REF
var player: CharacterBody2D = null

func _ready():
	if not player:
		player = get_node("/root/MainGame/Player")

func _process(delta):
	global_position += Vector2(800, 0).rotated(rotation) * delta

# Handle collision with CharacterBody2D enemies
func _on_body_entered(body):
	if body.is_in_group("mob"):
		apply_hit(body)

# Handle collision with Area2D obstacles (asteroids, flowers)
func _on_area_entered(area):
	if area.is_in_group("asteroid") or area.is_in_group("flower"):
		apply_obstacle_hit(area)

func apply_hit(mob):
	if not is_instance_valid(mob): return
	
	# CRITICAL HIT
	var is_crit: bool = false
	var final_damage: float = damage
	if player and player.player_stats:
		if randf() < player.player_stats.crit_chance:
			is_crit = true
			final_damage *= player.player_stats.crit_damage
	
	# APPLY DAMAGE
	mob.take_damage(final_damage, false, is_crit)
	
	# LIFESTEAL
	if player:
		player.report_weapon_damage("bullet", final_damage)
	
	# KNOCKBACK
	if knockback_amount > 0:
		mob.apply_knockback(knockback_amount, global_position)
	
	# POISON
	if poison_enabled and poison_damage > 0:
		var key = "poison_" + str(get_instance_id())
		mob.start_dot(key, poison_damage, 3, Color(0.0, 0.8, 0.2))
	
	# BURN + SLOW
	if burn_enabled and burn_damage > 0:
		var key = "burn_" + str(get_instance_id())
		mob.start_dot(key, burn_damage, 3, Color(1.0, 0.3, 0.0))
		mob.active_dots[key]["is_burn"] = true
	
	# PIERCE
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()

func apply_obstacle_hit(obstacle):
	if not is_instance_valid(obstacle): return

	# Damage obstacle (asteroid or flower)
	if obstacle.has_method("take_damage"):
		obstacle.take_damage(damage)

	# Bullets always destroyed by obstacles (no pierce)
	queue_free()
