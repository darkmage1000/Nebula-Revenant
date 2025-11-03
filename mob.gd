# mob.gd – FIXED: 20 HP = 2 PISTOL SHOTS TO KILL
extends CharacterBody2D

signal died

const XP_VIAL_SCENE = preload("res://experience_vial.tscn")
const FLOATING_DMG_SCENE = preload("res://FloatingDmg.tscn")
const POISON_COLOR = Color(0.0, 0.8, 0.2)
const AURA_COLOR = Color(0.1, 0.6, 1.0)
const CRIT_COLOR = Color(1.0, 0.5, 0.0)
const WEAPON_COLOR = Color(1.0, 1.0, 0.0)

# BALANCED BASE STATS - 2 shots to kill with starting pistol (12 damage)
var base_speed = 150
var base_health: float = 20.0
var speed: float = 150
var health: float = 20.0
var max_health: float = 20.0
var xp_value: int = 10
var level_scaling_applied: bool = false
var is_colossus: bool = false  # Special flag for tanky enemy

var active_dots: Dictionary = {}

@onready var player = get_node("/root/MainGame/Player")

func _ready():
	add_to_group("mob")  # Important for grenades to find enemies!
	
	# Check if this is a Nebulith Colossus by node name
	if name.begins_with("NebulithColossus") or get_node_or_null("ColossusSprite"):
		is_colossus = true
		# Colossus has 3x health, slower speed, more XP
		base_health = 60.0  # 3x tankier
		base_speed = 100   # Slower
		health = base_health
		speed = base_speed
		xp_value = 30  # 3x XP reward
	
	apply_level_scaling()
	max_health = health

func apply_level_scaling():
	if level_scaling_applied or not is_instance_valid(player):
		return
	
	var player_level = player.player_stats.get("level", 1)
	
	# PHASE 3: MUCH SLOWER enemy scaling to match XP changes
	# Health scales: +4% per level (was +8%)
	# Speed scales: +1% per level (was +2%)
	# XP scales: +3% per level (was +5%)
	
	var level_mult = player_level - 1  # No scaling at level 1
	
	# Health: Moderate exponential growth
	health = base_health * pow(1.04, level_mult)
	max_health = health
	
	# Speed: Very slow linear growth
	speed = base_speed * (1.0 + (level_mult * 0.01))
	speed += randf_range(-20, 20)  # Add some variation
	
	# XP: Scales slower with level
	xp_value = int(10 * (1.0 + (level_mult * 0.03)))
	
	level_scaling_applied = true
	
	if player_level > 10:
		print("Mob spawned at player level %d: HP=%.1f Speed=%.1f XP=%d" % [player_level, health, speed, xp_value])

func _physics_process(delta):
	if not is_instance_valid(player):
		return
		
	var direction = global_position.direction_to(player.global_position)
	direction += Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	
	velocity = direction.normalized() * speed
	move_and_slide()
	
	_process_dots(delta)

func _process_dots(delta):
	var dots_to_remove = []
	
	for source_key in active_dots:
		var dot_data = active_dots[source_key]
		dot_data.tick_timer += delta
		
		take_damage(dot_data.damage_per_sec * delta, true)
		
		if dot_data.tick_timer >= 1.0:
			show_damage_number(dot_data.damage_per_sec, dot_data.color)
			
			if dot_data.ticks_remaining > 0:
				dot_data.ticks_remaining -= 1
				if dot_data.ticks_remaining == 0:
					dots_to_remove.append(source_key)
			dot_data.tick_timer = 0.0
	
	for key in dots_to_remove:
		active_dots.erase(key)

func take_damage(amount: float, is_dot: bool = false, is_crit: bool = false):
	health -= amount 
	
	if not is_dot:
		var color = WEAPON_COLOR
		if is_crit:
			color = CRIT_COLOR
		show_damage_number(amount, color)
	
	if health <= 0:
		died.emit()
		
		# PHASE 3: Track kill for player stats
		if is_instance_valid(player) and player.has_method("register_kill"):
			player.register_kill()
		
		# Drop XP vial
		var vial = XP_VIAL_SCENE.instantiate()
		vial.global_position = global_position
		vial.value = xp_value
		get_parent().add_child(vial)
		
		# PHASE 4: Drop currency (5% chance per enemy)
		if randf() < 0.05:  # 5% drop rate
			var shard_value = 1  # Base shard value
			if randf() < 0.1:  # 10% chance for bonus shard
				shard_value = randi_range(2, 5)
			
			# Try to spawn shard (gracefully handle if scene doesn't exist)
			var shard_scene = null
			if ResourceLoader.exists("res://NebulaShard.tscn"):
				shard_scene = ResourceLoader.load("res://NebulaShard.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
			
			if shard_scene:
				var shard = shard_scene.instantiate()
				if shard:
					if shard.has_method("set") and "value" in shard:
						shard.value = shard_value
					shard.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
					get_parent().add_child(shard)
		
		queue_free()

func start_dot(source_key: String, damage_per_sec: float, num_ticks: int, color: Color):
	if damage_per_sec <= 0: return
	
	if active_dots.has(source_key):
		active_dots[source_key].ticks_remaining += num_ticks
	else:
		active_dots[source_key] = {
			"damage_per_sec": damage_per_sec,
			"ticks_remaining": num_ticks,
			"tick_timer": 0.0,
			"color": color
		}

func stop_dot(source_key: String):
	active_dots.erase(source_key)

func show_damage_number(amount: float, color: Color):
	if not FLOATING_DMG_SCENE:
		return
		
	var dmg = FLOATING_DMG_SCENE.instantiate()
	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if ui_layer:
		ui_layer.add_child(dmg)
	else:
		get_parent().add_child(dmg)
	
	dmg.global_position = global_position
	if dmg.has_method("set_damage_text"):
		dmg.set_damage_text(amount, color)

func apply_knockback(knockback_amount: float, source_position: Vector2):
	if knockback_amount <= 0.0:
		return
	
	var direction = global_position.direction_to(source_position).normalized()
	const KNOCKBACK_PUSH_VELOCITY = 1500.0
	velocity = direction * -1.0 * (knockback_amount / 50.0) * KNOCKBACK_PUSH_VELOCITY
