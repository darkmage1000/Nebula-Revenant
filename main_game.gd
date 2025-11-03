# main_game.gd – UPDATED: FASTER SPAWNS + FIRST BOSS @ 2:30 + CRASH-PROOF
extends Node2D

# ------------------------------------------------------------------
# 1. PRELOADS
# ------------------------------------------------------------------
const MOB_SCENE       = preload("res://mob.tscn")
const VOID_MITE_SCENE = preload("res://VoidMite.tscn")
const XP_VIAL_SCENE   = preload("res://experience_vial.tscn")
const CHEST_SCENE     = preload("res://Chest.tscn")
const ITEM_UI_SCENE   = preload("res://ItemUI.tscn")
const GAME_HUD_SCENE  = preload("res://GameHUD.tscn")
const PAUSE_MENU_SCENE = preload("res://PauseMenu.tscn")
const ENEMY_HEALTH_BAR = preload("res://EnemyHealthBar.tscn")

# ------------------------------------------------------------------
# 2. NODES
# ------------------------------------------------------------------
@onready var player    = $Player
@onready var ui_layer  = $UILayer

# HUD reference
var game_hud = null

# Stats tracking
var enemies_killed: int = 0
var bosses_defeated: int = 0
var boss_items_collected: Array[String] = []
var items_collected: Array[Dictionary] = []  # Track all items with tier

# ------------------------------------------------------------------
# 3. SPAWN SETTINGS – TUNABLE
# ------------------------------------------------------------------
const MIN_DISTANCE_FROM_PLAYER = 500.0
const MAX_SPAWN_DISTANCE      = 1200.0
const OFFSCREEN_BUFFER        = 100.0
const MAX_SPAWN_ATTEMPTS      = 30

# ------------------------------------------------------------------
# 4. GAME STATE
# ------------------------------------------------------------------
var is_level_up_open: bool = false
var game_time: float = 0.0
var spawn_rate: float = 1.2          # FASTER! Was 2.0, now 1.2 seconds
var difficulty_mult: float = 1.0

const TANKIER_INTERVAL = 90.0        # Every 90 seconds (was 120)
const FIRST_BOSS_TIME  = 150.0       # 2:30 for testing (2.5 minutes)
const BOSS_INTERVAL    = 360.0       # Every 6 minutes after first
const APOCALYPSE_TIME  = 1800.0      # 30 minutes

# Boss tracking to prevent crashes
var boss_spawn_times: Array[float] = []
var first_boss_spawned: bool = false

# ------------------------------------------------------------------
# 5. _READY
# ------------------------------------------------------------------
func _ready() -> void:
	if player and player.has_signal("health_depleted"):
		player.health_depleted.connect(_on_player_death)
	
	# Create HUD
	if GAME_HUD_SCENE:
		game_hud = GAME_HUD_SCENE.instantiate()
		game_hud.player = player
		game_hud.main_game = self
		add_child(game_hud)
	
	print("=== NEBULA REVENANT STARTED ===")
	print("Spawn rate: %.2f seconds" % spawn_rate)
	print("First boss at: 2:30")

func _input(event: InputEvent) -> void:
	# Pause menu with ESC
	if event.is_action_pressed("ui_cancel") and not is_level_up_open:
		if not get_tree().paused:
			open_pause_menu()
	
	# Restart on death
	if event.is_action_pressed("ui_accept") and player.player_stats.current_health <= 0:
		get_tree().paused = false
		get_tree().reload_current_scene()

func open_pause_menu():
	get_tree().paused = true
	var pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.player = player
	pause_menu.main_game = self
	ui_layer.add_child(pause_menu)

# ------------------------------------------------------------------
# 6. MAIN LOOP
# ------------------------------------------------------------------
var spawn_timer: float = 0.0
func _process(delta: float) -> void:
	# Don't update when paused
	if get_tree().paused:
		return
	
	# Safety check
	if not is_instance_valid(player):
		return
		
	game_time += delta

	# 90-SEC TANKIER + FASTER (was 2 min)
	if fmod(game_time, TANKIER_INTERVAL) < delta:
		difficulty_mult += 1.0  # Was 0.5, now doubles HP every 90 sec!
		spawn_rate = max(0.2, spawn_rate * 0.75)  # Was 0.85, now 25% faster!
		print("⚡ DIFFICULTY UP! HP×%.1f | Spawn: %.2fs" % [difficulty_mult, spawn_rate])

	# FIRST BOSS @ 2:30 (for testing)
	if not first_boss_spawned and game_time >= FIRST_BOSS_TIME:
		spawn_boss()
		first_boss_spawned = true
		boss_spawn_times.append(game_time)
	
	# REGULAR BOSSES every 6 minutes after first
	if first_boss_spawned:
		var time_since_first = game_time - FIRST_BOSS_TIME
		if fmod(time_since_first, BOSS_INTERVAL) < delta:
			# Make sure we don't spawn duplicate bosses
			if not has_boss_alive():
				spawn_boss()
				boss_spawn_times.append(game_time)

	# 30-MIN APOCALYPSE
	if game_time >= APOCALYPSE_TIME and not has_node("ApocalypseMob"):
		spawn_apocalypse_mob()

	# REGULAR MOB SPAWNING
	spawn_timer += delta
	if spawn_timer >= spawn_rate:
		spawn_timer = 0.0
		spawn_mob()
		
		# After 2 minutes, also spawn void mites!
		if game_time >= 120.0:
			spawn_void_mite()

# ------------------------------------------------------------------
# 7. SPAWN MOB – 4-SIDE OFF-SCREEN
# ------------------------------------------------------------------
func spawn_mob() -> void:
	if not is_instance_valid(player):
		return
	
	# Spawn 2-3 enemies per cycle (was 1)
	var enemies_to_spawn = randi_range(2, 3)
	
	for i in range(enemies_to_spawn):
		spawn_enemy(MOB_SCENE)

# Spawn void mites (same stats, different sprite)
func spawn_void_mite() -> void:
	if not is_instance_valid(player):
		return
	spawn_enemy(VOID_MITE_SCENE)

# Generic enemy spawner
func spawn_enemy(enemy_scene: PackedScene) -> void:
	var mob = enemy_scene.instantiate()

	# Apply scaling
	mob.health      *= difficulty_mult
	mob.max_health  *= difficulty_mult
	mob.speed       *= (1.0 + game_time / 600.0)
	mob.xp_value    += int(game_time / 30.0)

	# FULL SCREEN BOUNDS – IGNORES ZOOM
	var screen_size = get_viewport_rect().size
	var cam_pos = player.global_position
	var left   = cam_pos.x - screen_size.x * 0.5
	var right  = cam_pos.x + screen_size.x * 0.5
	var top    = cam_pos.y - screen_size.y * 0.5
	var bottom = cam_pos.y + screen_size.y * 0.5

	# RANDOM SIDE
	var side = randi() % 4
	var spawn_pos: Vector2

	match side:
		0: # TOP
			spawn_pos.x = randf_range(left, right)
			spawn_pos.y = top - OFFSCREEN_BUFFER
		1: # RIGHT
			spawn_pos.x = right + OFFSCREEN_BUFFER
			spawn_pos.y = randf_range(top, bottom)
		2: # BOTTOM
			spawn_pos.x = randf_range(left, right)
			spawn_pos.y = bottom + OFFSCREEN_BUFFER
		3: # LEFT
			spawn_pos.x = left - OFFSCREEN_BUFFER
			spawn_pos.y = randf_range(top, bottom)

	mob.global_position = spawn_pos
	add_child(mob)

	if mob.has_signal("died"):
		mob.died.connect(_on_mob_died.bind(mob))
	
	# Add health bar above enemy
	if ENEMY_HEALTH_BAR:
		var health_bar = ENEMY_HEALTH_BAR.instantiate()
		health_bar.set_target(mob)
		ui_layer.add_child(health_bar)

# ------------------------------------------------------------------
# 8. BOSS & APOCALYPSE
# ------------------------------------------------------------------
func spawn_boss() -> void:
	if not is_instance_valid(player):
		print("⚠️ Cannot spawn boss: Player invalid")
		return
	
	# Prevent duplicate bosses
	if has_boss_alive():
		print("⚠️ Boss already exists, skipping spawn")
		return
		
	var boss = MOB_SCENE.instantiate()
	boss.name = "Boss_%d" % int(game_time)  # Unique name
	boss.add_to_group("boss")  # Add to boss group for tracking
	boss.scale = Vector2(6, 6)
	
	# Boss stats scale with difficulty
	boss.health = 200.0 * difficulty_mult  # Base 200 HP
	boss.max_health = 200.0 * difficulty_mult
	boss.xp_value = 100
	boss.speed = 150.0  # Slower than normal enemies

	# Spawn in CENTER of screen relative to player
	var screen_size = get_viewport_rect().size
	boss.global_position = player.global_position + Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
	
	add_child(boss)
	
	# Connect signal safely
	if boss.has_signal("died"):
		boss.died.connect(_on_mob_died.bind(boss))
	
	print("👹 BOSS SPAWNED at %.1f seconds! HP: %.0f" % [game_time, boss.health])

func spawn_apocalypse_mob() -> void:
	if not is_instance_valid(player):
		return
		
	var apoc = MOB_SCENE.instantiate()
	apoc.name = "ApocalypseMob"
	apoc.add_to_group("boss")
	apoc.scale = Vector2(8, 8)
	apoc.health = 5000.0 * difficulty_mult
	apoc.max_health = 5000.0 * difficulty_mult
	apoc.speed = 200.0
	apoc.xp_value = 1000

	var screen_size = get_viewport_rect().size
	apoc.global_position = player.global_position + Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
	
	add_child(apoc)
	
	if apoc.has_signal("died"):
		apoc.died.connect(_on_mob_died.bind(apoc))
	
	print("💀 APOCALYPSE MOB SPAWNED!")

# Check if any boss is currently alive
func has_boss_alive() -> bool:
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		if is_instance_valid(boss):
			return true
	return false

# ------------------------------------------------------------------
# 9. DEATH HANDLING
# ------------------------------------------------------------------
func _on_mob_died(dead_mob: Node) -> void:
	if not is_instance_valid(dead_mob):
		return
	
	# Track kills
	enemies_killed += 1
	
	# Drop XP vial
	if XP_VIAL_SCENE:
		var vial = XP_VIAL_SCENE.instantiate()
		vial.global_position = dead_mob.global_position
		vial.value = dead_mob.xp_value
		add_child(vial)

	# Boss drops chest
	if dead_mob.is_in_group("boss"):
		bosses_defeated += 1
		print("💎 BOSS DEFEATED! Dropping chest...")
		spawn_chest(dead_mob.global_position)

func spawn_chest(pos: Vector2) -> void:
	if not CHEST_SCENE:
		print("⚠️ Chest scene not found, giving instant buff instead")
		give_boss_buff()
		return
	
	# Determine chest tier based on bosses defeated
	var tier = "yellow"
	if bosses_defeated == 1:
		tier = "yellow"  # First boss = common
	elif bosses_defeated <= 3:
		tier = "blue"  # 2-3 bosses = uncommon
	elif bosses_defeated <= 6:
		tier = "green"  # 4-6 bosses = rare
	else:
		tier = "purple"  # 7+ bosses = legendary!
	
	var chest = CHEST_SCENE.instantiate()
	chest.tier = tier
	chest.global_position = pos
	add_child(chest)
	print("📦 %s chest spawned at boss location!" % tier.to_upper())

# Fallback if chest scene doesn't exist
func give_boss_buff() -> void:
	if not is_instance_valid(player):
		return
		
	var buffs = [
		{"type": "damage", "value": 0.5, "name": "+50% Damage"},
		{"type": "health", "value": 100, "name": "+100 Max HP"},
		{"type": "speed", "value": 0.3, "name": "+30% Speed"},
	]
	
	var buff = buffs[randi() % buffs.size()]
	
	match buff.type:
		"damage":
			player.player_stats.damage_mult *= (1.0 + buff.value)
		"health":
			player.player_stats.max_health += buff.value
			player.player_stats.current_health = player.player_stats.max_health
		"speed":
			player.player_stats.speed *= (1.0 + buff.value)
	
	print("⚡ Boss buff applied: %s" % buff.name)

# Called by chest.gd
func give_chest_buff(buff_type: String) -> void:
	if not is_instance_valid(player):
		return
	
	# Track collected items
	var buff_name = ""
	
	match buff_type:
		"god_mode":
			player.player_stats.damage_mult *= 2.0
			player.player_stats.max_health *= 2.0
			player.player_stats.current_health = player.player_stats.max_health
			buff_name = "God Mode (x2 Damage & Health)"
			print("⚡ GOD MODE: x2 Damage & Health!")
		"infinite_health":
			player.player_stats.max_health += 200
			player.player_stats.current_health = player.player_stats.max_health
			player.player_stats.health_regen += 5.0
			buff_name = "Infinite Health (+200 HP, +5 HP/sec)"
			print("⚡ INFINITE HEALTH: +200 HP + 5 HP/sec!")
		"speed_boost":
			player.player_stats.speed *= 1.5
			player.player_stats.attack_speed_mult *= 1.5
			buff_name = "Speed Boost (x1.5 Move & Attack)"
			print("⚡ SPEED BOOST: x1.5 Move & Attack Speed!")
	
	boss_items_collected.append(buff_name)

# Show item UI when chest is opened
func show_item_ui(item_data: Dictionary, tier: String):
	if not ITEM_UI_SCENE:
		return
	
	var item_ui = ITEM_UI_SCENE.instantiate()
	item_ui.set_item(item_data, tier)
	ui_layer.add_child(item_ui)
	
	# Track collected item
	items_collected.append({
		"name": item_data.name,
		"tier": tier,
		"description": item_data.description
	})
	
	print("✨ Collected: [%s] %s" % [tier.to_upper(), item_data.name])

# ------------------------------------------------------------------
# 10. XP + LEVEL UP
# ------------------------------------------------------------------
func give_xp_to_player(amount: int) -> void:
	if player and player.has_method("pickup_xp"):
		player.pickup_xp(amount)

func show_level_up_options() -> void:
	if is_level_up_open: 
		return
	is_level_up_open = true
	get_tree().paused = true

	var lvl_up = preload("res://LevelUpScreen.tscn").instantiate()
	lvl_up.player = player
	ui_layer.add_child(lvl_up)
	
	if lvl_up.has_signal("upgrade_selected"):
		lvl_up.upgrade_selected.connect(_on_level_up_upgrade_selected)

# ------------------------------------------------------------------
# 11. UPGRADE HANDLER
# ------------------------------------------------------------------
func _on_level_up_upgrade_selected(upgrade_data: Dictionary) -> void:
	print("Upgrade selected: ", upgrade_data)
	
	# Apply upgrade
	if upgrade_data.has("unlock_weapon"):
		player.add_weapon(upgrade_data.unlock_weapon)
	elif upgrade_data.has("weapon_key"):
		player.upgrade_weapon(
			upgrade_data.weapon_key, 
			upgrade_data.upgrade_key, 
			upgrade_data.value
		)
	elif upgrade_data.has("stat_key"):
		player.upgrade_player_stat(
			upgrade_data.stat_key, 
			upgrade_data.value
		)
	
	# Unpause
	is_level_up_open = false
	get_tree().paused = false

# ------------------------------------------------------------------
# 12. DEATH + RESTART
# ------------------------------------------------------------------
func _on_player_death() -> void:
	get_tree().paused = true
	print("💀 GAME OVER – %.0f seconds!" % game_time)
	print("Bosses defeated: %d" % boss_spawn_times.size())
