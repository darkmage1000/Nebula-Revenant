# main_game.gd – UPDATED: Character selection support + sprite handling
extends Node2D

# Character selection variable (set by character_select.gd)
var selected_character: String = "ranger"

# Map selection variable (set by character_select.gd)
var selected_map: String = "space"  # "space" or "grassy_field"

# Game mode selection variable (set by character_select.gd)
var game_mode: String = "30min"  # "10min", "20min", or "30min" (default)

# Curse system variables (set by character_select.gd)
var active_curses: Array[String] = []  # Array of active curse names

# Curse definitions
const CURSE_DATA = {
	"frailty": {
		"name": "Curse of Frailty",
		"desc": "-50% Max HP",
		"bonus": "+100% Shard Drops",
		"hp_mult": 0.5,
		"shard_mult": 2.0,
		"color": Color(0.8, 0.2, 0.2)  # Red
	},
	"haste": {
		"name": "Curse of Haste",
		"desc": "+100% Enemy Speed",
		"bonus": "+50% XP Gain",
		"speed_mult": 2.0,
		"xp_mult": 1.5,
		"color": Color(1.0, 0.8, 0.0)  # Yellow
	},
	"swarm": {
		"name": "Curse of the Swarm",
		"desc": "+50% Spawn Rate",
		"bonus": "+75% Shard Drops",
		"spawn_mult": 1.5,
		"shard_mult": 1.75,
		"color": Color(0.5, 0.0, 0.8)  # Purple
	},
	"fragility": {
		"name": "Curse of Fragility",
		"desc": "-50% Armor",
		"bonus": "+50% All Drop Rates",
		"armor_mult": 0.5,
		"drop_mult": 1.5,
		"color": Color(0.6, 0.6, 0.6)  # Gray
	},
	"weakness": {
		"name": "Curse of Weakness",
		"desc": "-25% Damage",
		"bonus": "+100% XP Gain",
		"damage_mult": 0.75,
		"xp_mult": 2.0,
		"color": Color(0.2, 0.5, 0.8)  # Blue
	}
}

# ... [all existing preloads and variables stay the same] ...
const MOB_SCENE       = preload("res://mob.tscn")
const VOID_MITE_SCENE = preload("res://VoidMite.tscn")
const NEBULITH_COLOSSUS_SCENE = preload("res://NebulithColossus.tscn")
const DARK_MAGE_SCENE = preload("res://DarkMage.tscn")
const ASTEROID_SCENE  = preload("res://Asteroid.tscn")
const FLOWER_SCENE    = preload("res://Flower.tscn")
# NEW: Advanced mob sprites
const PURPLE_ALIEN_SCENE = preload("res://PurpleAlien.tscn")
const SPACE_DRAGON2_SCENE = preload("res://SpaceDragon2.tscn")
const SPACE_DRAGON_SCENE = preload("res://SpaceDragon.tscn")
const XP_VIAL_SCENE   = preload("res://experience_vial.tscn")
const CHEST_SCENE     = preload("res://Chest.tscn")
const ITEM_UI_SCENE   = preload("res://ItemUI.tscn")
const GAME_HUD_SCENE  = preload("res://GameHUD.tscn")
const MINIMAP_SCENE   = preload("res://Minimap.tscn")
const ITEM_INVENTORY_UI_SCENE = preload("res://ItemInventoryUI.tscn")
const PAUSE_MENU_SCENE = preload("res://PauseMenu.tscn")
const ENEMY_HEALTH_BAR = preload("res://EnemyHealthBar.tscn")
const GAME_OVER_SCENE = preload("res://GameOverScreen.tscn")

@onready var player    = $Player
@onready var ui_layer  = $UILayer

var game_hud = null
var enemies_killed: int = 0
var bosses_defeated: int = 0
var boss_items_collected: Array[String] = []
var items_collected: Array[Dictionary] = []

const MIN_DISTANCE_FROM_PLAYER = 500.0
const MAX_SPAWN_DISTANCE      = 1200.0
const OFFSCREEN_BUFFER        = 200.0
const MAX_SPAWN_ATTEMPTS      = 30

var is_level_up_open: bool = false
var game_time: float = 0.0
var spawn_rate: float = 1.5  # BUFFED: 2.5 → 1.5 (40% faster spawns early game)
var difficulty_mult: float = 1.0
var mob_damage_mult: float = 1.0  # NEW: Mob damage scaling
var grassy_field_unlock_shown: bool = false  # Track if we've shown unlock notification
var alien_monk_challenge_notification_shown: bool = false  # Track Alien Monk challenge notification

# Banish/Skip tracking (per-run)
var banished_options: Array[Dictionary] = []  # Options that have been banished this run
var banish_uses_remaining: int = 0  # How many banish uses left this run
var skip_uses_remaining: int = 0  # How many skip uses left this run

const TANKIER_INTERVAL = 90.0
const EARLY_GAME_TANKIER_INTERVAL = 60.0  # NEW: Faster difficulty scaling for first 5 mins
const EARLY_GAME_DURATION = 300.0  # NEW: First 5 minutes (0:00 - 5:00)
const LEGACY_DIFFICULTY_INTERVAL = 90.0  # For boss HP calculation (original scaling)
const FIRST_BOSS_TIME  = 150.0
const BOSS_INTERVAL    = 360.0
const APOCALYPSE_TIME  = 1800.0

var boss_spawn_times: Array[float] = []
var first_boss_spawned: bool = false

# Helper function: Calculate difficulty_mult using legacy 90s interval system
# This is used ONLY for boss HP to maintain original boss tankiness
# Regular enemies still use the faster 60s interval scaling (0:00-5:00)
func get_legacy_difficulty_mult() -> float:
	# Always use 90s intervals for boss HP (no early game boost for bosses)
	return 1.0 + floor(game_time / LEGACY_DIFFICULTY_INTERVAL)

# ============================================================
# GAME MODE HELPER FUNCTIONS
# ============================================================

# Get difficulty interval based on game mode and current time
func get_difficulty_interval() -> float:
	match game_mode:
		"10min":  # Blitz: 3x faster scaling
			return 30.0  # Every 30 seconds
		"20min":  # Quick: 1.5x faster scaling
			return 45.0  # Every 45 seconds
		"30min":  # Epic: Normal scaling
			# Dynamic scaling: faster in first 5 minutes, normal after
			return EARLY_GAME_TANKIER_INTERVAL if game_time < EARLY_GAME_DURATION else TANKIER_INTERVAL
		_:
			return TANKIER_INTERVAL

# Get damage multiplier interval based on game mode
func get_damage_interval() -> float:
	match game_mode:
		"10min":  # Blitz: 3x faster damage scaling
			return 40.0  # Every 40 seconds
		"20min":  # Quick: 1.5x faster damage scaling
			return 80.0  # Every 80 seconds
		"30min":  # Epic: Normal damage scaling
			return 120.0  # Every 2 minutes
		_:
			return 120.0

# Get base spawn rate based on game mode
func get_base_spawn_rate() -> float:
	match game_mode:
		"10min":  # Blitz: Fastest spawn rate
			return 1.0
		"20min":  # Quick: Faster spawn rate
			return 1.2
		"30min":  # Epic: Normal spawn rate
			return 1.5
		_:
			return 1.5

# Get first boss time based on game mode
func get_first_boss_time() -> float:
	match game_mode:
		"10min":  # Blitz: Boss at 1:00
			return 60.0
		"20min":  # Quick: Boss at 1:30
			return 90.0
		"30min":  # Epic: Boss at 2:30
			return 150.0
		_:
			return 150.0

# Get boss interval based on game mode
func get_boss_interval() -> float:
	match game_mode:
		"10min":  # Blitz: Boss every 3 minutes
			return 180.0
		"20min":  # Quick: Boss every 4 minutes
			return 240.0
		"30min":  # Epic: Boss every 6 minutes
			return 360.0
		_:
			return 360.0

# Get mini-boss interval based on game mode
func get_mini_boss_interval() -> float:
	match game_mode:
		"10min":  # Blitz: Mini-boss every 1 minute
			return 60.0
		"20min":  # Quick: Mini-boss every 1.5 minutes
			return 90.0
		"30min":  # Epic: Mini-boss every 2 minutes
			return 120.0
		_:
			return 120.0

# Get mini-boss start time based on game mode
func get_mini_boss_start_time() -> float:
	match game_mode:
		"10min":  # Blitz: Start mini-bosses at 2:00
			return 120.0
		"20min":  # Quick: Start mini-bosses at 3:00
			return 180.0
		"30min":  # Epic: Start mini-bosses at 2:30 (after first boss)
			return get_first_boss_time()
		_:
			return get_first_boss_time()

# Get victory time based on game mode
func get_victory_time() -> float:
	match game_mode:
		"10min":  # Blitz: Victory at 10:00
			return 600.0
		"20min":  # Quick: Victory at 20:00
			return 1200.0
		"30min":  # Epic: Victory at 30:00
			return 1800.0
		_:
			return 1800.0

const MAX_ENEMIES_ON_SCREEN = 300
var current_enemy_count: int = 0

# MAP SIZE - Increased for more exploration space
const MAP_WIDTH = 30000
const MAP_HEIGHT = 30000

func _ready() -> void:
	print("=== MAIN GAME _ready() called ===")
	print("   Selected character: %s" % selected_character)
	print("   Selected map: %s" % selected_map)
	print("   Selected game mode: %s" % game_mode)

	# Set spawn rate based on game mode
	spawn_rate = get_base_spawn_rate()

	# Load the appropriate background based on selected map
	setup_background()

	# CRITICAL: Set player character BEFORE anything else
	if player and player.has_method("set_character"):
		player.set_character(selected_character)
		print("✅ Main game: Character set to '%s'" % selected_character)
	else:
		print("⚠️ WARNING: Failed to set character! Player or set_character() not found")

	if player and player.has_signal("health_depleted"):
		player.health_depleted.connect(_on_player_death)

	call_deferred("setup_hud")

	if has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		save_manager.start_new_run()
		print("💾 Save system: Run tracking started")

		# Initialize banish/skip uses from purchased tiers
		banish_uses_remaining = save_manager.get_upgrade_level("banish_tier")
		skip_uses_remaining = save_manager.get_upgrade_level("skip_tier")
		print("🚫 Banish uses this run: %d" % banish_uses_remaining)
		print("⏭️ Skip uses this run: %d" % skip_uses_remaining)

	# Apply curse effects to spawn rate
	apply_spawn_curse_effects()

	print("=== NEBULA REVENANT STARTED ===")
	print("Game Mode: %s" % game_mode)
	print("Spawn rate: %.2f seconds" % spawn_rate)
	print("Difficulty interval: %.0f seconds" % get_difficulty_interval())
	print("Damage interval: %.0f seconds" % get_damage_interval())
	print("First boss at: %.0f seconds" % get_first_boss_time())
	print("Boss interval: %.0f seconds" % get_boss_interval())
	print("Victory time: %.0f seconds" % get_victory_time())

func setup_background():
	# Remove existing SpaceBackground if it exists
	var old_background = get_node_or_null("SpaceBackground")
	if old_background:
		old_background.queue_free()
		print("🗑️ Removed default SpaceBackground")

	# Load the appropriate background based on selected map
	var background_script = null

	if selected_map == "grassy_field":
		# Load GrassyBackground
		if ResourceLoader.exists("res://GrassyBackground.gd"):
			background_script = load("res://GrassyBackground.gd")
			print("🌱 Loading Grassy Field background")
		else:
			print("⚠️ Warning: GrassyBackground.gd not found, falling back to space")
			selected_map = "space"

	# Default to space background
	if selected_map == "space" or background_script == null:
		if ResourceLoader.exists("res://SpaceBackground.gd"):
			background_script = load("res://SpaceBackground.gd")
			print("🌌 Loading Space background")
		else:
			print("❌ Error: SpaceBackground.gd not found!")
			return

	# Instantiate the background
	if background_script:
		var background = Node2D.new()
		background.set_script(background_script)
		background.name = "Background"
		# Add as first child so it renders behind everything
		add_child(background)
		move_child(background, 0)
		print("✅ Background loaded successfully: %s" % selected_map)

func setup_hud():
	if GAME_HUD_SCENE and is_instance_valid(player):
		game_hud = GAME_HUD_SCENE.instantiate()
		game_hud.player = player
		game_hud.main_game = self
		add_child(game_hud)
		print("✅ HUD created with player level: %d" % player.player_stats.level)

	if MINIMAP_SCENE and is_instance_valid(player):
		var minimap = MINIMAP_SCENE.instantiate()
		minimap.player = player
		minimap.main_game = self
		ui_layer.add_child(minimap)
		print("✅ Minimap created")

	if ITEM_INVENTORY_UI_SCENE:
		var item_ui = ITEM_INVENTORY_UI_SCENE.instantiate()
		item_ui.main_game = self
		item_ui.position = Vector2(10, 240)
		ui_layer.add_child(item_ui)
		print("✅ Item inventory UI created")

	if ResourceLoader.exists("res://NebulaShardUI.gd"):
		var shard_ui_script = load("res://NebulaShardUI.gd")
		var shard_ui = Control.new()
		shard_ui.set_script(shard_ui_script)
		shard_ui.set("player", player)
		shard_ui.position = Vector2(10, 120)
		ui_layer.add_child(shard_ui)
		print("✅ Nebula shard UI created")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not is_level_up_open:
		if not get_tree().paused:
			open_pause_menu()
	
	if event.is_action_pressed("ui_accept") and player.player_stats.current_health <= 0:
		get_tree().paused = false
		get_tree().reload_current_scene()

func open_pause_menu():
	print("⏸️ Opening pause menu...")
	get_tree().paused = true
	var pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.player = player
	pause_menu.main_game = self
	ui_layer.add_child(pause_menu)
	print("✅ Pause menu added to scene!")

var spawn_timer: float = 0.0
var save_update_timer: float = 0.0
func _process(delta: float) -> void:
	# DEBUG: Press F12 to fast-forward to 30-minute mark (for testing unlock)
	if Input.is_key_pressed(KEY_F12):
		game_time = 1799.0
		print("🔧 DEBUG: Fast-forwarded to 29:59 - unlock will trigger in 1 second!")

	if get_tree().paused:
		return

	if not is_instance_valid(player):
		return

	game_time += delta

	save_update_timer += delta
	if save_update_timer >= 5.0:
		save_update_timer = 0.0
		if has_node("/root/SaveManager") and is_instance_valid(player):
			var save_manager = get_node("/root/SaveManager")
			save_manager.update_run_stats(
				player.run_stats.shards_collected,
				player.player_stats.level,
				game_time,
				enemies_killed
			)

	# Dynamic difficulty scaling using game mode-specific intervals
	var current_interval = get_difficulty_interval()

	# Check if we just crossed a difficulty threshold
	if fmod(game_time, current_interval) < delta:
		difficulty_mult += 1.0
		spawn_rate = max(0.5, spawn_rate * 0.88)
		print("⚡ DIFFICULTY UP! HP×%.1f | Spawn: %.2fs (Mode: %s)" % [difficulty_mult, spawn_rate, game_mode])

	# Game mode-specific damage scaling
	var damage_interval = get_damage_interval()
	if fmod(game_time, damage_interval) < delta:
		# Base increase: +100% damage every 2 mins
		var damage_increase = 1.0

		# Exponential scaling after 10 minutes (600s)
		if game_time >= 600.0:
			damage_increase = 1.5  # +150% per tier after 10 minutes

		mob_damage_mult += damage_increase
		print("🔥 MOB DAMAGE UP! ×%.1f (+%.0f%% this tier)" % [mob_damage_mult, damage_increase * 100])

	# Game mode-specific boss spawning
	var first_boss_time = get_first_boss_time()
	var boss_interval = get_boss_interval()

	if not first_boss_spawned and game_time >= first_boss_time:
		spawn_boss()
		first_boss_spawned = true
		boss_spawn_times.append(game_time)

	if first_boss_spawned:
		var time_since_first = game_time - first_boss_time
		if fmod(time_since_first, boss_interval) < delta:
			if not has_boss_alive():
				spawn_boss()
				boss_spawn_times.append(game_time)

	# Victory condition: Spawn Omega Dragon at victory time
	var victory_time = get_victory_time()
	if game_time >= victory_time:
		# Spawn mega boss at victory time if not already spawned
		if not has_node("OmegaDragon"):
			spawn_mega_final_boss()

		# NO AUTO-VICTORY: Player must defeat the Omega Dragon to win!

	# Check for grassy field unlock at 30 minutes (1800 seconds)
	if game_time >= 1800.0 and not grassy_field_unlock_shown:
		grassy_field_unlock_shown = true
		if has_node("/root/SaveManager"):
			var save_manager = get_node("/root/SaveManager")
			# unlock_grassy_field returns true if this is the first time unlocking
			if save_manager.unlock_grassy_field():
				show_grassy_field_unlock_notification()

	# Check for Alien Monk challenge complete at 30:00 (1800 seconds) ONLY on grassy_field map
	if game_time >= 1800.0 and not alien_monk_challenge_notification_shown and selected_map == "grassy_field":
		alien_monk_challenge_notification_shown = true
		if has_node("/root/SaveManager"):
			var save_manager = get_node("/root/SaveManager")
			# complete_alien_monk_challenge returns true if this is the first time completing
			if save_manager.complete_alien_monk_challenge():
				show_alien_monk_challenge_notification()

	# Game mode-specific mini-boss spawning
	var mini_boss_start = get_mini_boss_start_time()
	var mini_boss_interval = get_mini_boss_interval()

	if game_time >= mini_boss_start and fmod(game_time - mini_boss_start, mini_boss_interval) < delta:
		if not has_boss_alive():  # Don't spawn mini-boss if regular boss is active
			spawn_mini_boss()

	spawn_timer += delta
	if spawn_timer >= spawn_rate:
		spawn_timer = 0.0
		spawn_mob()

		if game_time >= 120.0 and randf() < 0.50:
			spawn_void_mite()

		if randf() < 0.20:
			spawn_asteroid()

		if game_time >= 360.0 and randf() < 0.10:
			spawn_colossus()

		if game_time >= 360.0 and randf() < 0.08:
			spawn_dark_mage()

func spawn_mob() -> void:
	if not is_instance_valid(player):
		return
	
	if current_enemy_count >= MAX_ENEMIES_ON_SCREEN:
		return
	
	# NEW: Mob replacement system based on time
	var mob_scene = MOB_SCENE  # Default slime
	
	# Replace slimes with purple aliens at 8:30 (510 seconds)
	if game_time >= 510:
		mob_scene = PURPLE_ALIEN_SCENE
	
	var enemies_to_spawn = 1
	if game_time > 180:
		enemies_to_spawn = randi_range(1, 2)
	if game_time > 600:
		enemies_to_spawn = 2
	
	for i in range(enemies_to_spawn):
		if current_enemy_count < MAX_ENEMIES_ON_SCREEN:
			spawn_enemy(mob_scene)

func spawn_void_mite() -> void:
	if not is_instance_valid(player):
		return
	
	# NEW: Replace void mites with space dragon 2 at 10:00 (600 seconds)
	var mite_scene = VOID_MITE_SCENE
	if game_time >= 600:
		mite_scene = SPACE_DRAGON2_SCENE
	
	spawn_enemy(mite_scene)

func spawn_colossus() -> void:
	if not is_instance_valid(player):
		return
	
	# NEW: Replace colossus with space dragon at 20:00 (1200 seconds)
	var colossus_scene = NEBULITH_COLOSSUS_SCENE
	if game_time >= 1200:
		colossus_scene = SPACE_DRAGON_SCENE
	
	spawn_enemy(colossus_scene)

func spawn_dark_mage() -> void:
	if not is_instance_valid(player):
		return
	spawn_enemy(DARK_MAGE_SCENE)

func spawn_asteroid() -> void:
	# Spawn obstacles based on selected map
	if not is_instance_valid(player):
		return

	# Choose scene based on map type
	var obstacle_scene = ASTEROID_SCENE if selected_map == "space" else FLOWER_SCENE

	if not obstacle_scene:
		return

	var obstacle = obstacle_scene.instantiate()

	var screen_size = get_viewport_rect().size
	var cam_pos = player.global_position

	const ASTEROID_PADDING = 50.0
	var total_buffer = OFFSCREEN_BUFFER + ASTEROID_PADDING

	var left   = cam_pos.x - (screen_size.x * 0.5)
	var right  = cam_pos.x + (screen_size.x * 0.5)
	var top    = cam_pos.y - (screen_size.y * 0.5)
	var bottom = cam_pos.y + (screen_size.y * 0.5)

	var side = randi() % 4
	var spawn_pos: Vector2

	match side:
		0:
			spawn_pos.x = randf_range(left - total_buffer, right + total_buffer)
			spawn_pos.y = top - total_buffer
		1:
			spawn_pos.x = right + total_buffer
			spawn_pos.y = randf_range(top - total_buffer, bottom + total_buffer)
		2:
			spawn_pos.x = randf_range(left - total_buffer, right + total_buffer)
			spawn_pos.y = bottom + total_buffer
		3:
			spawn_pos.x = left - total_buffer
			spawn_pos.y = randf_range(top - total_buffer, bottom + total_buffer)

	obstacle.global_position = spawn_pos
	add_child(obstacle)

func spawn_enemy(enemy_scene: PackedScene) -> void:
	var mob = enemy_scene.instantiate()

	mob.health      *= difficulty_mult
	mob.max_health  *= difficulty_mult
	mob.speed       *= (1.0 + game_time / 600.0)
	mob.xp_value    += int(game_time / 30.0)

	# Apply curse effects: speed multiplier
	var speed_curse_mult = get_curse_multiplier("speed_mult")
	if speed_curse_mult > 1.0:
		mob.speed *= speed_curse_mult

	# NEW: Apply mob damage scaling
	if mob.has_method("set_damage_multiplier"):
		mob.set_damage_multiplier(mob_damage_mult)

	var screen_size = get_viewport_rect().size
	var cam_pos = player.global_position
	
	const ENEMY_SIZE_PADDING = 50.0
	var total_buffer = OFFSCREEN_BUFFER + ENEMY_SIZE_PADDING
	
	var left   = cam_pos.x - (screen_size.x * 0.5)
	var right  = cam_pos.x + (screen_size.x * 0.5)
	var top    = cam_pos.y - (screen_size.y * 0.5)
	var bottom = cam_pos.y + (screen_size.y * 0.5)

	var side = randi() % 4
	var spawn_pos: Vector2

	match side:
		0:
			spawn_pos.x = randf_range(left - total_buffer, right + total_buffer)
			spawn_pos.y = top - total_buffer
		1:
			spawn_pos.x = right + total_buffer
			spawn_pos.y = randf_range(top - total_buffer, bottom + total_buffer)
		2:
			spawn_pos.x = randf_range(left - total_buffer, right + total_buffer)
			spawn_pos.y = bottom + total_buffer
		3:
			spawn_pos.x = left - total_buffer
			spawn_pos.y = randf_range(top - total_buffer, bottom + total_buffer)

	mob.global_position = spawn_pos
	add_child(mob)
	
	current_enemy_count += 1

	if mob.has_signal("died"):
		mob.died.connect(_on_mob_died.bind(mob))
	
	if ENEMY_HEALTH_BAR:
		var health_bar = ENEMY_HEALTH_BAR.instantiate()
		health_bar.set_target(mob)
		ui_layer.add_child(health_bar)

func spawn_boss() -> void:
	if not is_instance_valid(player):
		print("⚠️ Cannot spawn boss: Player invalid")
		return

	if has_boss_alive():
		print("⚠️ Boss already exists, skipping spawn")
		return

	# Determine which boss to spawn based on bosses_defeated count (cycling progression)
	var boss_scene = MOB_SCENE
	var boss_name = "Slime Boss"
	var boss_scale = Vector2(6, 6)

	var boss_cycle = bosses_defeated % 7  # 7 boss types in rotation

	match boss_cycle:
		0:  # Slime
			boss_scene = MOB_SCENE
			boss_name = "Slime King"
			boss_scale = Vector2(6, 6)
		1:  # Void Mite
			boss_scene = VOID_MITE_SCENE
			boss_name = "Void Overlord"
			boss_scale = Vector2(6, 6)
		2:  # Nebulith Colossus
			boss_scene = NEBULITH_COLOSSUS_SCENE
			boss_name = "Colossus Prime"
			boss_scale = Vector2(7, 7)
		3:  # Dark Mage
			boss_scene = DARK_MAGE_SCENE
			boss_name = "Arch Mage"
			boss_scale = Vector2(6, 6)
		4:  # Purple Alien
			boss_scene = PURPLE_ALIEN_SCENE
			boss_name = "Alien Emperor"
			boss_scale = Vector2(6, 6)
		5:  # Space Dragon 2
			boss_scene = SPACE_DRAGON2_SCENE
			boss_name = "Ancient Dragon"
			boss_scale = Vector2(5, 5)
		6:  # Space Dragon (strongest in cycle)
			boss_scene = SPACE_DRAGON_SCENE
			boss_name = "Elder Dragon"
			boss_scale = Vector2(5, 5)

	var boss = boss_scene.instantiate()
	boss.name = boss_name
	boss.add_to_group("boss")
	boss.scale = boss_scale

	# Use legacy difficulty_mult for boss HP (original 90s scaling, not buffed 60s early game)
	var legacy_mult = get_legacy_difficulty_mult()
	boss.health = 400.0 * legacy_mult  # Tanky but killable! 20x base mob HP
	boss.max_health = 400.0 * legacy_mult
	boss.xp_value = 100
	boss.speed = 150.0

	# Bosses hit 2x harder than regular mobs to be more threatening
	if boss.has_method("set_damage_multiplier"):
		boss.set_damage_multiplier(mob_damage_mult * 2.0)

	var screen_size = get_viewport_rect().size
	boss.global_position = player.global_position + Vector2(screen_size.x * 0.5, screen_size.y * 0.5)

	add_child(boss)

	if boss.has_signal("died"):
		boss.died.connect(_on_mob_died.bind(boss))

	print("👹 BOSS SPAWNED: %s (Cycle: %d) at %.1f seconds! HP: %.0f (legacy_mult: %.1f vs current_mult: %.1f)" % [boss_name, boss_cycle, game_time, boss.health, legacy_mult, difficulty_mult])

# NEW: Mega Final Boss - SPACE DRAGON - takes up over half the screen, fast, one-shot damage
func spawn_mega_final_boss() -> void:
	if not is_instance_valid(player):
		return

	# Load the OmegaDragon script
	var omega_dragon_script = load("res://OmegaDragon.gd")

	# Create new mob instance and attach OmegaDragon script
	var mega_boss = MOB_SCENE.instantiate()
	mega_boss.set_script(omega_dragon_script)
	mega_boss.name = "OmegaDragon"
	mega_boss.add_to_group("boss")
	mega_boss.add_to_group("mega_boss")
	mega_boss.scale = Vector2(2.5, 2.5)  # 2.5x size (intimidating but not overwhelming)

	# Mode-specific HP scaling
	var boss_hp: float
	match game_mode:
		"10min":  # Blitz: 50,000 HP (2-3 minute fight)
			boss_hp = 50000.0
		"20min":  # Quick: 100,000 HP (3-4 minute fight)
			boss_hp = 100000.0
		"30min":  # Epic: 200,000 HP (4-5 minute fight)
			boss_hp = 200000.0
		_:
			boss_hp = 200000.0

	mega_boss.health = boss_hp
	mega_boss.max_health = boss_hp
	mega_boss.speed = 120.0  # Slower than player (140) but dash compensates
	mega_boss.xp_value = 10000

	# Reasonable damage, not instant-kill
	if mega_boss.has_method("set_damage_multiplier"):
		mega_boss.set_damage_multiplier(1.0)

	# Spawn position - to the right of player
	var screen_size = get_viewport_rect().size
	mega_boss.global_position = player.global_position + Vector2(screen_size.x * 0.6, 0)

	add_child(mega_boss)

	# Connect death signal to victory trigger
	if mega_boss.has_signal("died"):
		mega_boss.died.connect(_on_omega_dragon_died.bind(mega_boss))

	# Create boss health bar UI
	spawn_boss_health_bar(mega_boss)

	# Dramatic announcement
	print("💀💀💀 THE OMEGA DRAGON HAS AWAKENED! 💀💀💀")
	print("⚔️ DEFEAT THE OMEGA DRAGON TO WIN! ⚔️")
	print("🐉 Boss HP: %.0f | Mode: %s" % [boss_hp, game_mode])

	# Debug: Verify group membership
	print("🐉 DEBUG: OmegaDragon groups: %s" % [mega_boss.get_groups()])
	print("🐉 DEBUG: In boss group? %s" % mega_boss.is_in_group("boss"))
	print("🐉 DEBUG: In mob group? %s" % mega_boss.is_in_group("mob"))

func _on_omega_dragon_died(boss: Node):
	if not is_instance_valid(boss):
		return

	# Killing the Omega Dragon triggers victory!
	print("🎉🐉 OMEGA DRAGON DEFEATED! VICTORY! 🐉🎉")

	# Destroy boss health bar
	destroy_boss_health_bar()

	# Trigger victory after short delay for dramatic effect
	await get_tree().create_timer(1.5).timeout
	trigger_victory()

func _on_mega_boss_killed(boss: Node):
	# Legacy function - redirects to new handler
	_on_omega_dragon_died(boss)

# Boss Health Bar management
var boss_health_bar: Node = null

func spawn_boss_health_bar(boss: Node) -> void:
	# Destroy existing health bar if present
	destroy_boss_health_bar()

	# Load and instantiate boss health bar
	var boss_health_bar_script = load("res://BossHealthBar.gd")
	boss_health_bar = Node.new()
	boss_health_bar.set_script(boss_health_bar_script)
	boss_health_bar.name = "BossHealthBar"

	# Add to UI layer
	ui_layer.add_child(boss_health_bar)

	# Set boss name
	if boss_health_bar.has_method("set_boss_name"):
		boss_health_bar.set_boss_name("OMEGA DRAGON")

	# Initialize health
	if boss_health_bar.has_method("update_health"):
		boss_health_bar.update_health(boss.health, boss.max_health)

	# Connect to boss health_changed signal
	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health_changed)

	print("💚 Boss health bar spawned!")

func destroy_boss_health_bar() -> void:
	if boss_health_bar and is_instance_valid(boss_health_bar):
		boss_health_bar.queue_free()
		boss_health_bar = null

func _on_boss_health_changed(current_health: float, max_health: float) -> void:
	if boss_health_bar and is_instance_valid(boss_health_bar):
		if boss_health_bar.has_method("update_health"):
			boss_health_bar.update_health(current_health, max_health)

# NEW: Mini-boss spawning system - cycles through enemy types (elites)
func spawn_mini_boss() -> void:
	if not is_instance_valid(player):
		return

	# Calculate how many mini-bosses have been spawned (every 2 minutes starting at 2:30)
	var minutes_elapsed = (game_time - FIRST_BOSS_TIME) / 120.0
	var mini_boss_count = int(minutes_elapsed)

	# Determine which elite to spawn based on mini_boss_count (cycling progression)
	var boss_scene = MOB_SCENE
	var boss_name = "Elite"
	var boss_scale = Vector2(3, 3)

	var elite_cycle = mini_boss_count % 7  # 7 elite types in rotation

	match elite_cycle:
		0:  # Slime Elite
			boss_scene = MOB_SCENE
			boss_name = "Slime Elite"
			boss_scale = Vector2(3, 3)
		1:  # Void Mite Elite
			boss_scene = VOID_MITE_SCENE
			boss_name = "Void Elite"
			boss_scale = Vector2(3, 3)
		2:  # Nebulith Colossus Elite
			boss_scene = NEBULITH_COLOSSUS_SCENE
			boss_name = "Colossus Elite"
			boss_scale = Vector2(3.5, 3.5)
		3:  # Dark Mage Elite
			boss_scene = DARK_MAGE_SCENE
			boss_name = "Mage Elite"
			boss_scale = Vector2(3, 3)
		4:  # Purple Alien Elite
			boss_scene = PURPLE_ALIEN_SCENE
			boss_name = "Alien Elite"
			boss_scale = Vector2(3, 3)
		5:  # Space Dragon 2 Elite
			boss_scene = SPACE_DRAGON2_SCENE
			boss_name = "Dragon Elite"
			boss_scale = Vector2(2.5, 2.5)
		6:  # Space Dragon Elite
			boss_scene = SPACE_DRAGON_SCENE
			boss_name = "Elder Elite"
			boss_scale = Vector2(2.5, 2.5)

	var mini_boss = boss_scene.instantiate()
	mini_boss.name = boss_name
	mini_boss.add_to_group("mini_boss")
	mini_boss.scale = boss_scale

	# Use legacy difficulty_mult for boss HP (original 90s scaling, not buffed 60s early game)
	var legacy_mult = get_legacy_difficulty_mult()

	# Mini-boss stats: 12x normal mob health (tanky elites!)
	mini_boss.health = mini_boss.base_health * 12.0 * legacy_mult
	mini_boss.max_health = mini_boss.health
	mini_boss.speed = mini_boss.base_speed * 1.3  # 30% faster
	mini_boss.xp_value = 50  # Good XP reward

	# Mini-bosses hit 1.5x harder than regular mobs
	if mini_boss.has_method("set_damage_multiplier"):
		mini_boss.set_damage_multiplier(mob_damage_mult * 1.5)

	var screen_size = get_viewport_rect().size
	mini_boss.global_position = player.global_position + Vector2(screen_size.x * 0.5, screen_size.y * 0.5)

	add_child(mini_boss)

	if mini_boss.has_signal("died"):
		mini_boss.died.connect(_on_mob_died.bind(mini_boss))

	if ENEMY_HEALTH_BAR:
		var health_bar = ENEMY_HEALTH_BAR.instantiate()
		health_bar.set_target(mini_boss)
		ui_layer.add_child(health_bar)

	print("👑 ELITE SPAWNED: %s (Cycle: %d)" % [boss_name, elite_cycle])

func has_boss_alive() -> bool:
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		if is_instance_valid(boss):
			return true
	return false

func _on_mob_died(dead_mob: Node) -> void:
	if not is_instance_valid(dead_mob):
		return

	current_enemy_count = max(0, current_enemy_count - 1)
	enemies_killed += 1

	if XP_VIAL_SCENE:
		var vial = XP_VIAL_SCENE.instantiate()
		vial.global_position = dead_mob.global_position
		vial.value = dead_mob.xp_value
		# Deferred to avoid physics flush issues
		call_deferred("add_child", vial)

	# Spawn chests for both bosses and mini-bosses
	if dead_mob.is_in_group("boss"):
		bosses_defeated += 1
		print("💎 BOSS DEFEATED! Dropping chest...")
		spawn_chest(dead_mob.global_position)
	elif dead_mob.is_in_group("mini_boss"):
		print("👑 MINI-BOSS DEFEATED! Dropping chest...")
		spawn_chest(dead_mob.global_position)

func spawn_chest(pos: Vector2) -> void:
	if not CHEST_SCENE:
		print("⚠️ Chest scene not found, giving instant buff instead")
		give_boss_buff()
		return
	
	var tier = "yellow"
	if bosses_defeated == 1:
		tier = "yellow"
	elif bosses_defeated <= 3:
		tier = "blue"
	elif bosses_defeated <= 6:
		tier = "green"
	else:
		tier = "purple"
	
	var chest = CHEST_SCENE.instantiate()
	chest.tier = tier
	chest.global_position = pos
	# Deferred to avoid physics flush issues
	call_deferred("add_child", chest)
	print("📦 %s chest spawned at boss location!" % tier.to_upper())

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

func give_chest_buff(buff_type: String) -> void:
	if not is_instance_valid(player):
		return
	
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

func show_chest_animation(item_data: Dictionary, final_rarity: String):
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	overlay.add_child(bg)
	
	var box = PanelContainer.new()
	box.position = Vector2(get_viewport().size.x / 2 - 200, get_viewport().size.y / 2 - 150)
	box.size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	box.add_child(vbox)
	
	var rarity_label = Label.new()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 48)
	rarity_label.text = "ROLLING..."
	vbox.add_child(rarity_label)
	
	var item_label = Label.new()
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 24)
	item_label.text = ""
	vbox.add_child(item_label)
	
	var desc_label = Label.new()
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.text = ""
	vbox.add_child(desc_label)
	
	overlay.add_child(box)
	ui_layer.add_child(overlay)
	
	var rarity_colors = {
		"yellow": Color(1.0, 0.9, 0.3),
		"blue": Color(0.3, 0.6, 1.0),
		"green": Color(0.2, 1.0, 0.3),
		"purple": Color(0.8, 0.3, 1.0)
	}
	
	var rarity_names = ["yellow", "blue", "green", "purple"]
	var swap_count = 0
	var max_swaps = 20
	var swap_interval = 0.15
	
	var swap_timer = Timer.new()
	swap_timer.wait_time = swap_interval
	swap_timer.one_shot = false
	overlay.add_child(swap_timer)
	
	swap_timer.timeout.connect(func():
		swap_count += 1
		
		if swap_count >= max_swaps:
			var final_color = rarity_colors[final_rarity]
			rarity_label.text = final_rarity.to_upper()
			rarity_label.add_theme_color_override("font_color", final_color)
			item_label.text = item_data.name
			item_label.add_theme_color_override("font_color", final_color)
			desc_label.text = item_data.description
			swap_timer.stop()
			
			await get_tree().create_timer(2.0).timeout
			
			var chest_nodes = get_tree().get_nodes_in_group("chest")
			for chest in chest_nodes:
				if chest.has_method("apply_item_to_player"):
					chest.apply_item_to_player()
					break
			
			items_collected.append({
				"name": item_data.name,
				"tier": final_rarity,
				"description": item_data.description
			})
			
			overlay.queue_free()
			get_tree().paused = false
		else:
			var random_rarity = rarity_names[randi() % rarity_names.size()]
			var color = rarity_colors[random_rarity]
			rarity_label.text = random_rarity.to_upper()
			rarity_label.add_theme_color_override("font_color", color)
			box.modulate = color
	)
	
	swap_timer.start()

func show_item_ui(item_data: Dictionary, tier: String):
	if not ITEM_UI_SCENE:
		return
	
	var item_ui = ITEM_UI_SCENE.instantiate()
	item_ui.set_item(item_data, tier)
	ui_layer.add_child(item_ui)
	
	items_collected.append({
		"name": item_data.name,
		"tier": tier,
		"description": item_data.description
	})
	
	print("✨ Collected: [%s] %s" % [tier.to_upper(), item_data.name])

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

	# Set banish/skip uses remaining and banished options list
	lvl_up.banish_uses_remaining = banish_uses_remaining
	lvl_up.skip_uses_remaining = skip_uses_remaining
	lvl_up.banished_options_list = banished_options.duplicate()

	ui_layer.add_child(lvl_up)

	# Connect signals
	if lvl_up.has_signal("upgrade_selected"):
		lvl_up.upgrade_selected.connect(_on_level_up_upgrade_selected)
	if lvl_up.has_signal("option_banished"):
		lvl_up.option_banished.connect(_on_option_banished)
	if lvl_up.has_signal("option_skipped"):
		lvl_up.option_skipped.connect(_on_option_skipped)

func _on_level_up_upgrade_selected(upgrade_data: Dictionary) -> void:
	print("Upgrade selected: ", upgrade_data)

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

	# Remove the level-up screen from UI
	for child in ui_layer.get_children():
		if child.name == "LevelUpScreen" or child.has_signal("upgrade_selected"):
			child.queue_free()
			break

	is_level_up_open = false
	get_tree().paused = false

func _on_option_banished(option: Dictionary) -> void:
	print("🚫 Option banished: %s" % option.label)

	# Add to banished list (avoid duplicates)
	var already_banished = false
	for banished_opt in banished_options:
		if banished_opt.label == option.label:
			already_banished = true
			break

	if not already_banished:
		banished_options.append(option)
		print("📝 Added to banished list. Total banished: %d" % banished_options.size())

	# Decrement uses
	banish_uses_remaining = max(0, banish_uses_remaining - 1)
	print("🚫 Banish uses remaining: %d" % banish_uses_remaining)

	# Remove the level-up screen from UI
	for child in ui_layer.get_children():
		if child.name == "LevelUpScreen" or child.has_signal("upgrade_selected"):
			child.queue_free()
			break

	# Close level-up screen and unpause
	is_level_up_open = false
	get_tree().paused = false

func _on_option_skipped() -> void:
	print("⏭️ Level-up skipped")

	# Calculate XP refund (25% of XP required for this level)
	var xp_to_refund = int(player.player_stats.xp_to_next_level * 0.25)
	print("💎 Refunding %d XP (25%% of %d)" % [xp_to_refund, player.player_stats.xp_to_next_level])

	# Refund XP to player
	player.player_stats.current_xp += xp_to_refund

	# Decrement uses
	skip_uses_remaining = max(0, skip_uses_remaining - 1)
	print("⏭️ Skip uses remaining: %d" % skip_uses_remaining)

	# Remove the level-up screen from UI
	for child in ui_layer.get_children():
		if child.name == "LevelUpScreen" or child.has_signal("upgrade_selected"):
			child.queue_free()
			break

	# Close level-up screen and unpause
	is_level_up_open = false
	get_tree().paused = false

func trigger_victory() -> void:
	# Victory achieved - show game over screen with victory message
	get_tree().paused = true
	print("🎉 VICTORY! – %.0f seconds! Mode: %s" % [game_time, game_mode])
	print("Bosses defeated: %d" % bosses_defeated)
	print("Enemies killed: %d" % enemies_killed)

	# CRITICAL: Save collected shards before showing game over screen
	if has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		save_manager.end_run()
		print("💾 Run finalized, shards saved!")

	if GAME_OVER_SCENE and is_instance_valid(player):
		var game_over = GAME_OVER_SCENE.instantiate()
		var stats = player.get_run_stats()
		game_over.set_run_stats(stats)
		ui_layer.add_child(game_over)

		if game_over.has_signal("exit_to_menu"):
			game_over.exit_to_menu.connect(_on_exit_to_menu)

func _on_player_death() -> void:
	get_tree().paused = true
	print("💀 GAME OVER – %.0f seconds!" % game_time)
	print("Bosses defeated: %d" % bosses_defeated)
	print("Enemies killed: %d" % enemies_killed)

	# CRITICAL: Save collected shards before showing game over screen
	if has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		save_manager.end_run()
		print("💾 Run finalized, shards saved!")

	if GAME_OVER_SCENE and is_instance_valid(player):
		var game_over = GAME_OVER_SCENE.instantiate()
		var stats = player.get_run_stats()
		game_over.set_run_stats(stats)
		ui_layer.add_child(game_over)

		if game_over.has_signal("exit_to_menu"):
			game_over.exit_to_menu.connect(_on_exit_to_menu)

func _on_exit_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

# Show grassy field unlock notification
func show_grassy_field_unlock_notification():
	print("🌱 Showing grassy field unlock notification")

	# Create full-screen overlay
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	overlay.add_child(bg)

	# Notification panel
	var panel = PanelContainer.new()
	panel.position = Vector2(get_viewport().size.x / 2 - 300, get_viewport().size.y / 2 - 150)
	panel.size = Vector2(600, 300)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	title.text = "NEW MAP UNLOCKED!"
	vbox.add_child(title)

	# Map name
	var map_name = Label.new()
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_name.add_theme_font_size_override("font_size", 36)
	map_name.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	map_name.text = "Grassy Field"
	vbox.add_child(map_name)

	# Description
	var desc = Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 20)
	desc.text = "You survived 30 minutes!\nSelect this map from the Character Select screen."
	vbox.add_child(desc)

	overlay.add_child(panel)
	ui_layer.add_child(overlay)

	# Auto-dismiss after 5 seconds
	await get_tree().create_timer(5.0).timeout
	overlay.queue_free()

# Show Alien Monk challenge complete notification
func show_alien_monk_challenge_notification():
	print("✨ Showing Alien Monk challenge complete notification")

	# Create full-screen overlay
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	overlay.add_child(bg)

	# Notification panel
	var panel = PanelContainer.new()
	panel.position = Vector2(get_viewport().size.x / 2 - 300, get_viewport().size.y / 2 - 150)
	panel.size = Vector2(600, 300)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.7, 0.4, 1.0))
	title.text = "CHALLENGE COMPLETE!"
	vbox.add_child(title)

	# Character name
	var char_name = Label.new()
	char_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_name.add_theme_font_size_override("font_size", 36)
	char_name.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0))
	char_name.text = "Alien Monk"
	vbox.add_child(char_name)

	# Description
	var desc = Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 20)
	desc.text = "You survived 30:00 on Grassy Field!\nPurchase Alien Monk for 750 Nebula Shards in the main menu."
	vbox.add_child(desc)

	overlay.add_child(panel)
	ui_layer.add_child(overlay)

	# Auto-dismiss after 5 seconds
	await get_tree().create_timer(5.0).timeout
	overlay.queue_free()


# ==============================================================
# CURSE SYSTEM FUNCTIONS
# ==============================================================

# Apply spawn rate curse effects (called once in _ready)
func apply_spawn_curse_effects():
	# Get spawn rate multiplier from curses
	var spawn_mult = get_curse_multiplier("spawn_mult")

	if spawn_mult > 1.0:
		# spawn_mult > 1.0 means spawn MORE enemies
		# To spawn 1.5x as many, we need to spawn 1.5x as often
		# Which means divide spawn_rate by 1.5 (make it faster)
		var old_spawn_rate = spawn_rate
		spawn_rate = spawn_rate / spawn_mult
		print("🔥 Curse of the Swarm: Spawn rate %.2fs → %.2fs (×%.1f faster)" % [old_spawn_rate, spawn_rate, spawn_mult])

# Get total multiplier for a specific stat from all active curses
func get_curse_multiplier(stat_name: String) -> float:
	var total_mult = 1.0
	for curse_key in active_curses:
		if CURSE_DATA.has(curse_key):
			var curse = CURSE_DATA[curse_key]
			if curse.has(stat_name):
				total_mult *= curse[stat_name]
	return total_mult

# Check if any curse affects a specific stat
func has_curse_affecting(stat_name: String) -> bool:
	for curse_key in active_curses:
		if CURSE_DATA.has(curse_key) and CURSE_DATA[curse_key].has(stat_name):
			return true
	return false

# Get formatted description of all active curses
func get_active_curses_text() -> String:
	if active_curses.is_empty():
		return "No curses active"
	
	var text = ""
	for curse_key in active_curses:
		if CURSE_DATA.has(curse_key):
			var curse = CURSE_DATA[curse_key]
			text += curse.name + ": " + curse.desc + " → " + curse.bonus + "\n"
	return text.strip_edges()
