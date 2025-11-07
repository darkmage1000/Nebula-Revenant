# main_game.gd – UPDATED: FASTER SPAWNS + FIRST BOSS @ 2:30 + CRASH-PROOF
extends Node2D

# ------------------------------------------------------------------
# 1. PRELOADS
# ------------------------------------------------------------------
const MOB_SCENE       = preload("res://mob.tscn")
const VOID_MITE_SCENE = preload("res://VoidMite.tscn")
const NEBULITH_COLOSSUS_SCENE = preload("res://NebulithColossus.tscn")
const XP_VIAL_SCENE   = preload("res://experience_vial.tscn")
const CHEST_SCENE     = preload("res://Chest.tscn")
const ITEM_UI_SCENE   = preload("res://ItemUI.tscn")
const GAME_HUD_SCENE  = preload("res://GameHUD.tscn")
const PAUSE_MENU_SCENE = preload("res://PauseMenu.tscn")
const ENEMY_HEALTH_BAR = preload("res://EnemyHealthBar.tscn")
const GAME_OVER_SCENE = preload("res://GameOverScreen.tscn")  # PHASE 3

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
const OFFSCREEN_BUFFER        = 200.0  # INCREASED from 100 to 200 - ensures spawns are FAR offscreen
const MAX_SPAWN_ATTEMPTS      = 30

# ------------------------------------------------------------------
# 4. GAME STATE
# ------------------------------------------------------------------
var is_level_up_open: bool = false
var game_time: float = 0.0
var spawn_rate: float = 1.8          # BALANCED! Not too fast, not too slow
var difficulty_mult: float = 1.0

const TANKIER_INTERVAL = 90.0        # Every 90 seconds (was 120)
const FIRST_BOSS_TIME  = 150.0       # 2:30 for testing (2.5 minutes)
const BOSS_INTERVAL    = 360.0       # Every 6 minutes after first
const APOCALYPSE_TIME  = 1800.0      # 30 minutes

# Boss tracking to prevent crashes
var boss_spawn_times: Array[float] = []
var first_boss_spawned: bool = false

# PERFORMANCE OPTIMIZATION - Enemy cap to prevent FPS drops
const MAX_ENEMIES_ON_SCREEN = 300  # Cap at 300 enemies
var current_enemy_count: int = 0

# ------------------------------------------------------------------
# 5. _READY
# ------------------------------------------------------------------
func _ready() -> void:
	if player and player.has_signal("health_depleted"):
		player.health_depleted.connect(_on_player_death)

	# Create HUD - use call_deferred to ensure player is ready
	call_deferred("setup_hud")

	# Start tracking this run for save system
	if has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		save_manager.start_new_run()
		print("💾 Save system: Run tracking started")

	print("=== NEBULA REVENANT STARTED ===")
	print("Spawn rate: %.2f seconds" % spawn_rate)
	print("First boss at: 2:30")

func setup_hud():
	if GAME_HUD_SCENE and is_instance_valid(player):
		game_hud = GAME_HUD_SCENE.instantiate()
		game_hud.player = player
		game_hud.main_game = self
		add_child(game_hud)
		print("✅ HUD created with player level: %d" % player.player_stats.level)

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
	print("⏸️ Opening pause menu...")
	get_tree().paused = true
	var pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.player = player
	pause_menu.main_game = self
	ui_layer.add_child(pause_menu)
	print("✅ Pause menu added to scene!")

# ------------------------------------------------------------------
# 6. MAIN LOOP
# ------------------------------------------------------------------
var spawn_timer: float = 0.0
var save_update_timer: float = 0.0
func _process(delta: float) -> void:
	# Don't update when paused
	if get_tree().paused:
		return

	# Safety check
	if not is_instance_valid(player):
		return

	game_time += delta

	# Update save manager with current run stats every 5 seconds
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

	# 90-SEC TANKIER + FASTER (was 2 min)
	if fmod(game_time, TANKIER_INTERVAL) < delta:
		difficulty_mult += 0.5  # REDUCED! Was 1.0, now 0.5 per interval
		spawn_rate = max(0.4, spawn_rate * 0.85)  # SLOWER RAMP! Was 0.75, now 0.85 
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
		
		# After 6 minutes, occasionally spawn Nebulith Colossus (20% chance)
		if game_time >= 360.0 and randf() < 0.20:
			spawn_colossus()

# ------------------------------------------------------------------
# 7. SPAWN MOB – 4-SIDE OFF-SCREEN (WITH PERFORMANCE CAP)
# ------------------------------------------------------------------
func spawn_mob() -> void:
	if not is_instance_valid(player):
		return
	
	# PERFORMANCE: Don't spawn if at enemy cap
	if current_enemy_count >= MAX_ENEMIES_ON_SCREEN:
		return
	
	# BALANCED: Start with 1-2 enemies, gradually increase
	var enemies_to_spawn = randi_range(1, 2)  # Start with 1-2 for action
	if game_time > 180:  # After 3 minutes, spawn 2 enemies
		enemies_to_spawn = 2
	if game_time > 360:  # After 6 minutes, spawn 2-3 enemies
		enemies_to_spawn = randi_range(2, 3)
	
	for i in range(enemies_to_spawn):
		if current_enemy_count < MAX_ENEMIES_ON_SCREEN:
			spawn_enemy(MOB_SCENE)

# Spawn void mites (same stats, different sprite)
func spawn_void_mite() -> void:
	if not is_instance_valid(player):
		return
	spawn_enemy(VOID_MITE_SCENE)

# Spawn Nebulith Colossus (tanky enemy after 6 minutes)
func spawn_colossus() -> void:
	if not is_instance_valid(player):
		return
	spawn_enemy(NEBULITH_COLOSSUS_SCENE)

# Generic enemy spawner - FIXED: ALWAYS SPAWN OFFSCREEN
func spawn_enemy(enemy_scene: PackedScene) -> void:
	var mob = enemy_scene.instantiate()

	# Apply scaling
	mob.health      *= difficulty_mult
	mob.max_health  *= difficulty_mult
	mob.speed       *= (1.0 + game_time / 600.0)
	mob.xp_value    += int(game_time / 30.0)

	# Calculate spawn position COMPLETELY offscreen
	var screen_size = get_viewport_rect().size
	var cam_pos = player.global_position
	
	# Add extra padding for enemy size (enemies can be 20-40 pixels)
	const ENEMY_SIZE_PADDING = 50.0
	var total_buffer = OFFSCREEN_BUFFER + ENEMY_SIZE_PADDING
	
	var left   = cam_pos.x - (screen_size.x * 0.5)
	var right  = cam_pos.x + (screen_size.x * 0.5)
	var top    = cam_pos.y - (screen_size.y * 0.5)
	var bottom = cam_pos.y + (screen_size.y * 0.5)

	# Pick random side (0=top, 1=right, 2=bottom, 3=left)
	var side = randi() % 4
	var spawn_pos: Vector2

	match side:
		0: # TOP - spawn ABOVE screen
			spawn_pos.x = randf_range(left - total_buffer, right + total_buffer)  # Wider range
			spawn_pos.y = top - total_buffer  # Well above screen
		1: # RIGHT - spawn to RIGHT of screen
			spawn_pos.x = right + total_buffer  # Well to the right
			spawn_pos.y = randf_range(top - total_buffer, bottom + total_buffer)  # Taller range
		2: # BOTTOM - spawn BELOW screen
			spawn_pos.x = randf_range(left - total_buffer, right + total_buffer)  # Wider range
			spawn_pos.y = bottom + total_buffer  # Well below screen
		3: # LEFT - spawn to LEFT of screen
			spawn_pos.x = left - total_buffer  # Well to the left
			spawn_pos.y = randf_range(top - total_buffer, bottom + total_buffer)  # Taller range

	mob.global_position = spawn_pos
	add_child(mob)
	
	# PERFORMANCE: Track enemy count
	current_enemy_count += 1

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
	
	# PERFORMANCE: Decrement enemy count
	current_enemy_count = max(0, current_enemy_count - 1)
	
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

# FIXED: Show chest rarity animation with color swapping
func show_chest_animation(item_data: Dictionary, final_rarity: String):
	# Create the UI overlay
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Dark background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	overlay.add_child(bg)
	
	# Chest box
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
	
	# Color swap animation
	var rarity_colors = {
		"yellow": Color(1.0, 0.9, 0.3),
		"blue": Color(0.3, 0.6, 1.0),
		"green": Color(0.2, 1.0, 0.3),
		"purple": Color(0.8, 0.3, 1.0)
	}
	
	var rarity_names = ["yellow", "blue", "green", "purple"]
	var swap_count = 0
	var max_swaps = 20  # Fast swapping for 3 seconds
	var swap_interval = 0.15
	
	var swap_timer = Timer.new()
	swap_timer.wait_time = swap_interval
	swap_timer.one_shot = false
	overlay.add_child(swap_timer)
	
	swap_timer.timeout.connect(func():
		swap_count += 1
		
		if swap_count >= max_swaps:
			# Show final result
			var final_color = rarity_colors[final_rarity]
			rarity_label.text = final_rarity.to_upper()
			rarity_label.add_theme_color_override("font_color", final_color)
			item_label.text = item_data.name
			item_label.add_theme_color_override("font_color", final_color)
			desc_label.text = item_data.description
			swap_timer.stop()
			
			# Auto-close after 2 seconds and apply item
			await get_tree().create_timer(2.0).timeout
			
			# Apply item to player
			var chest_nodes = get_tree().get_nodes_in_group("chest")
			for chest in chest_nodes:
				if chest.has_method("apply_item_to_player"):
					chest.apply_item_to_player()
					break
			
			# Track collected item
			items_collected.append({
				"name": item_data.name,
				"tier": final_rarity,
				"description": item_data.description
			})
			
			overlay.queue_free()
			get_tree().paused = false
		else:
			# Randomly swap colors
			var random_rarity = rarity_names[randi() % rarity_names.size()]
			var color = rarity_colors[random_rarity]
			rarity_label.text = random_rarity.to_upper()
			rarity_label.add_theme_color_override("font_color", color)
			box.modulate = color
	)
	
	swap_timer.start()

# Show item UI when chest is opened (OLD METHOD - REPLACED BY ANIMATION)
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
# 12. DEATH + GAME OVER
# ------------------------------------------------------------------
func _on_player_death() -> void:
	get_tree().paused = true
	print("💀 GAME OVER – %.0f seconds!" % game_time)
	print("Bosses defeated: %d" % bosses_defeated)
	print("Enemies killed: %d" % enemies_killed)
	
	# PHASE 3: Show game over screen with stats
	if GAME_OVER_SCENE and is_instance_valid(player):
		var game_over = GAME_OVER_SCENE.instantiate()
		var stats = player.get_run_stats()
		game_over.set_run_stats(stats)
		ui_layer.add_child(game_over)
		
		# Connect exit button
		if game_over.has_signal("exit_to_menu"):
			game_over.exit_to_menu.connect(_on_exit_to_menu)

func _on_exit_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")  # Go to main menu
