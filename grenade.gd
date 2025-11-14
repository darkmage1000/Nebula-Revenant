# grenade.gd – FINAL: THROWS + EXPLODES
extends Node2D

var stats: Dictionary = {}
var player: CharacterBody2D = null 
var time_since_last_shot: float = 0.0

const GRENADE_PROJECTILE_SCENE = preload("res://GrenadeProjectile.tscn")
@onready var shooting_point: Marker2D = $ShootingPoint 

func _ready():
	add_to_group("weapon")

func set_player_ref(player_node: CharacterBody2D):
	player = player_node

func set_stats(new_stats: Dictionary):
	stats = new_stats.duplicate()

func _process(delta: float):
	if not is_instance_valid(player) or stats.is_empty():
		return
		
	time_since_last_shot += delta
	
	var attack_mult = player.player_stats.get("attack_speed_mult", 1.0)
	var final_attack_speed = stats.attack_speed * attack_mult
	var shoot_cooldown = 1.0 / max(0.1, final_attack_speed)

	if time_since_last_shot >= shoot_cooldown:
		shoot()
		time_since_last_shot = 0.0

func shoot():
	if not is_instance_valid(player) or not is_instance_valid(shooting_point):
		return

	var total_projectiles = stats.projectiles + player.player_stats.projectiles
	var final_damage = stats.damage * player.player_stats.damage_mult
	var final_aoe = stats.aoe * player.player_stats.aoe_mult
	var final_distance = stats.get("distance", 300) * player.player_stats.get("attack_range_mult", 1.0)

	var base_direction = get_direction_to_closest_enemy()

	for i in range(total_projectiles):
		var new_grenade = GRENADE_PROJECTILE_SCENE.instantiate()

		new_grenade.global_position = shooting_point.global_position
		new_grenade.damage = final_damage
		new_grenade.aoe = final_aoe
		new_grenade.distance = final_distance
		new_grenade.aoe_mult = player.player_stats.aoe_mult
		
		new_grenade.poison_enabled = stats.get("poison", false)
		if stats.get("poison", false):
			new_grenade.poison_damage = stats.damage
		
		new_grenade.burn_enabled = stats.get("burn", false)
		if stats.get("burn", false):
			new_grenade.burn_damage = stats.damage * 0.5
		
		new_grenade.pierce = stats.get("pierce", 0)
		new_grenade.knockback_amount = stats.get("knockback", 0.0)
		new_grenade.player = player

		# Evolution flags
		new_grenade.cluster_bomb = stats.get("cluster_bomb", false)
		new_grenade.sticky_mine = stats.get("sticky_mines", false)

		new_grenade.rotation = base_direction.angle()
		player.get_parent().add_child(new_grenade)
		
		player.report_weapon_damage("grenade", final_damage)

func get_direction_to_closest_enemy() -> Vector2:
	var closest_target: Node2D = null
	var min_distance: float = 999999.0

	# Get all targetable entities (mobs, asteroids, and flowers)
	var mobs: Array[Node] = get_tree().get_nodes_in_group("mob")
	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroid")
	var flowers: Array[Node] = get_tree().get_nodes_in_group("flower")
	var all_targets = mobs + asteroids + flowers

	for target in all_targets:
		if is_instance_valid(target) and target is Node2D:
			var distance = global_position.distance_to(target.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_target = target as Node2D

	if is_instance_valid(closest_target):
		return global_position.direction_to(closest_target.global_position)
	else:
		return Vector2.RIGHT
