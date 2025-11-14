# SummonSpaceships.gd - Spawns ships that orbit player then dash at enemies
extends Node2D

var stats: Dictionary = {}
var player: CharacterBody2D = null
var time_since_last_spawn: float = 0.0
var initial_delay_timer: float = 0.0
var has_spawned_first: bool = false

const SPACESHIP_SCENE = preload("res://Spaceship.tscn")
const INITIAL_DELAY: float = 3.0  # Increased from 1.5 - longer delay before first spawn

func _ready():
	add_to_group("weapon")

func set_player_ref(player_node: CharacterBody2D):
	player = player_node

func set_stats(new_stats: Dictionary):
	stats = new_stats.duplicate()

func _process(delta: float):
	if not is_instance_valid(player) or stats.is_empty():
		return

	# Handle initial spawn delay
	if not has_spawned_first:
		initial_delay_timer += delta
		if initial_delay_timer >= INITIAL_DELAY:
			spawn_spaceships()
			has_spawned_first = true
			time_since_last_spawn = 0.0
		return

	time_since_last_spawn += delta

	# Calculate spawn interval based on attack speed
	var attack_mult = player.player_stats.get("attack_speed_mult", 1.0)
	var final_attack_speed = stats.get("attack_speed", 0.5) * attack_mult
	var spawn_interval = 1.0 / max(0.1, final_attack_speed)

	if time_since_last_spawn >= spawn_interval:
		spawn_spaceships()
		time_since_last_spawn = 0.0

func spawn_spaceships():
	if not is_instance_valid(player):
		return

	# Calculate total ships to spawn
	var base_ships = stats.get("projectiles", 2)
	var bonus_ships = player.player_stats.get("projectiles", 0)
	var total_ships = base_ships + bonus_ships

	# Calculate damage
	var base_damage = stats.get("damage", 20.0)
	var final_damage = base_damage * player.player_stats.get("damage_mult", 1.0)

	# Calculate size multiplier
	var size_mult = stats.get("size_mult", 1.0)

	# Calculate move speed
	var base_speed = stats.get("move_speed", 250.0)
	var final_speed = base_speed * stats.get("speed_mult", 1.0)

	# Get pierce value
	var pierce = stats.get("pierce", 0)

	# Spawn ships in circular pattern around player
	for i in range(total_ships):
		var spaceship = SPACESHIP_SCENE.instantiate()

		# Position ship in orbit around player
		var angle = (TAU / total_ships) * i
		var orbit_radius = 80.0
		var spawn_offset = Vector2(cos(angle), sin(angle)) * orbit_radius

		spaceship.global_position = player.global_position + spawn_offset
		spaceship.damage = final_damage
		spaceship.move_speed = final_speed
		spaceship.size_mult = size_mult
		spaceship.pierce = pierce
		spaceship.player = player
		spaceship.orbit_angle = angle  # Starting orbit angle

		# Evolution flags
		spaceship.carrier_fleet = stats.get("carrier_fleet", false)
		spaceship.kamikaze = stats.get("kamikaze", false)

		# Add to main game scene (player's parent)
		player.get_parent().add_child(spaceship)

		# Report damage for lifesteal tracking
		player.report_weapon_damage("summon_spaceships", final_damage)
