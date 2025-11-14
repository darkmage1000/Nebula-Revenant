# AcidPool.gd - Spawns acid pools at player position that apply unique DOTs
extends Node2D

var stats: Dictionary = {}
var player: CharacterBody2D = null
var time_since_last_spawn: float = 0.0

const ACID_POOL_SCENE = preload("res://AcidPoolEntity.tscn")

func _ready():
	add_to_group("weapon")

func set_player_ref(player_node: CharacterBody2D):
	player = player_node

func set_stats(new_stats: Dictionary):
	stats = new_stats.duplicate()

func _process(delta: float):
	if not is_instance_valid(player) or stats.is_empty():
		return

	time_since_last_spawn += delta

	# Calculate spawn interval based on attack speed
	var attack_mult = player.player_stats.get("attack_speed_mult", 1.0)
	var final_attack_speed = stats.get("attack_speed", 0.67) * attack_mult  # Base: 1.5s interval = 0.67 attack speed
	var spawn_interval = 1.0 / max(0.1, final_attack_speed)

	if time_since_last_spawn >= spawn_interval:
		spawn_acid_pool()
		time_since_last_spawn = 0.0

func spawn_acid_pool():
	if not is_instance_valid(player):
		return

	var pool = ACID_POOL_SCENE.instantiate()

	# Position at player's current location
	pool.global_position = player.global_position

	# Calculate pool properties
	var base_damage = stats.get("damage", 10.0)
	var final_damage = base_damage * player.player_stats.get("damage_mult", 1.0)

	var base_radius = stats.get("aoe", 50.0)
	# Apply both aoe_mult and attack_range_mult to radius
	var final_radius = base_radius * player.player_stats.get("aoe_mult", 1.0) * player.player_stats.get("attack_range_mult", 1.0)

	var base_tick_rate = stats.get("tick_rate", 0.4)
	var tick_rate = base_tick_rate

	var duration = stats.get("duration", 1.5)

	# Set pool properties
	pool.damage_per_tick = final_damage
	pool.tick_rate = tick_rate
	pool.duration = duration
	pool.radius = final_radius
	pool.player = player

	# Evolution flags
	pool.corrosive_nova = stats.get("corrosive_nova", false)
	pool.lingering_death = stats.get("lingering_death", false)

	# Add to main game scene
	player.get_parent().add_child(pool)
