# main_game.gd – UPDATED: Character selection support + sprite handling
extends Node2D

# Character selection variable (set by character_select.gd)
var selected_character: String = "ranger"

# ... [all existing preloads and variables stay the same] ...
const MOB_SCENE       = preload("res://mob.tscn")
const VOID_MITE_SCENE = preload("res://VoidMite.tscn")
const NEBULITH_COLOSSUS_SCENE = preload("res://NebulithColossus.tscn")
const DARK_MAGE_SCENE = preload("res://DarkMage.tscn")
const ASTEROID_SCENE  = preload("res://Asteroid.tscn")
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
var spawn_rate: float = 2.5
var difficulty_mult: float = 1.0
var mob_damage_mult: float = 1.0  # NEW: Mob damage scaling

const TANKIER_INTERVAL = 90.0
const FIRST_BOSS_TIME  = 150.0
const BOSS_INTERVAL    = 360.0
const APOCALYPSE_TIME  = 1800.0

var boss_spawn_times: Array[float] = []
var first_boss_spawned: bool = false

const MAX_ENEMIES_ON_SCREEN = 300
var current_enemy_count: int = 0

# MAP SIZE - Increased for more exploration space
const MAP_WIDTH = 30000
const MAP_HEIGHT = 30000

func _ready() -> void:
	print("=== MAIN GAME _ready() called ===")
	print("   Selected character: %s" % selected_character)
	
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

	# Every 90 seconds: Increase HP/spawn rate
	if fmod(game_time, TANKIER_INTERVAL) < delta:
		difficulty_mult += 1.0
		spawn_rate = max(0.5, spawn_rate * 0.88)
		print("⚡ DIFFICULTY UP! HP×%.1f | Spawn: %.2fs" % [difficulty_mult, spawn_rate])
	
	# NEW: Every 4 minutes (240 seconds): Increase mob damage
	if fmod(game_time, 240.0) < delta:
		mob_damage_mult += 0.5  # +50% damage every 4 mins
		print("🔥 MOB DAMAGE UP! ×%.1f" % mob_damage_mult)

	if not first_boss_spawned and game_time >= FIRST_BOSS_TIME:
		spawn_boss()
		first_boss_spawned = true
		boss_spawn_times.append(game_time)
	
	if first_boss_spawned:
		var time_since_first = game_time - FIRST_BOSS_TIME
		if fmod(time_since_first, BOSS_INTERVAL) < delta:
			if not has_boss_alive():
				spawn_boss()
				boss_spawn_times.append(game_time)

	if game_time >= APOCALYPSE_TIME and not has_node("ApocalypseMob"):
		spawn_mega_final_boss()
	
	# NEW: Mini-boss spawning system (starts after first boss at 2:30)
	if game_time >= FIRST_BOSS_TIME and fmod(game_time - FIRST_BOSS_TIME, 120.0) < delta:  # Every 2 minutes after first boss
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
	if not is_instance_valid(player) or not ASTEROID_SCENE:
		return

	var asteroid = ASTEROID_SCENE.instantiate()

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

	asteroid.global_position = spawn_pos
	add_child(asteroid)

func spawn_enemy(enemy_scene: PackedScene) -> void:
	var mob = enemy_scene.instantiate()

	mob.health      *= difficulty_mult
	mob.max_health  *= difficulty_mult
	mob.speed       *= (1.0 + game_time / 600.0)
	mob.xp_value    += int(game_time / 30.0)
	
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
		
	var boss = MOB_SCENE.instantiate()
	boss.name = "Boss_%d" % int(game_time)
	boss.add_to_group("boss")
	boss.scale = Vector2(6, 6)
	
	boss.health = 200.0 * difficulty_mult
	boss.max_health = 200.0 * difficulty_mult
	boss.xp_value = 100
	boss.speed = 150.0

	var screen_size = get_viewport_rect().size
	boss.global_position = player.global_position + Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
	
	add_child(boss)
	
	if boss.has_signal("died"):
		boss.died.connect(_on_mob_died.bind(boss))
	
	print("👹 BOSS SPAWNED at %.1f seconds! HP: %.0f" % [game_time, boss.health])

# NEW: Mega Final Boss - takes up over half the screen, fast, one-shot damage
func spawn_mega_final_boss() -> void:
	if not is_instance_valid(player):
		return
		
	var mega_boss = MOB_SCENE.instantiate()
	mega_boss.name = "MegaFinalBoss"
	mega_boss.add_to_group("boss")
	mega_boss.add_to_group("mega_boss")
	mega_boss.scale = Vector2(15, 15)  # MASSIVE - over half the screen
	mega_boss.health = 50000.0 * difficulty_mult  # Insane HP pool
	mega_boss.max_health = 50000.0 * difficulty_mult
	mega_boss.speed = 250.0  # Fast enough to catch player
	mega_boss.xp_value = 5000
	
	# One-shot damage marker
	if mega_boss.has_method("set_damage_multiplier"):
		mega_boss.set_damage_multiplier(9999.0)  # Instant death on contact

	var screen_size = get_viewport_rect().size
	mega_boss.global_position = player.global_position + Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
	
	add_child(mega_boss)
	
	if mega_boss.has_signal("died"):
		mega_boss.died.connect(_on_mega_boss_killed.bind(mega_boss))
	
	print("💀💀💀 MEGA FINAL BOSS SPAWNED! ONE-SHOT KILL ON CONTACT! 💀💀💀")

func _on_mega_boss_killed(boss: Node):
	if not is_instance_valid(boss):
		return
	
	# Killing the mega boss ends the run immediately
	print("🎉 MEGA BOSS DEFEATED! YOU WIN! 🎉")
	await get_tree().create_timer(1.0).timeout
	_on_player_death()  # Show game over screen with victory stats

# NEW: Mini-boss spawning system - each mob type gets a mini-boss variant
func spawn_mini_boss() -> void:
	if not is_instance_valid(player):
		return
	
	# Determine which mini-boss to spawn based on game time
	var boss_scene = MOB_SCENE  # Default
	var boss_name = "Slime"
	var boss_scale = Vector2(3, 3)
	
	if game_time < 510:  # 0-8:30 - Slime mini-boss
		boss_scene = MOB_SCENE
		boss_name = "SlimeKing"
	elif game_time < 600:  # 8:30-10:00 - Void Mite mini-boss
		boss_scene = VOID_MITE_SCENE
		boss_name = "VoidMother"
	elif game_time < 1200:  # 10:00-20:00 - Colossus mini-boss
		boss_scene = NEBULITH_COLOSSUS_SCENE
		boss_name = "ColossusPrime"
		boss_scale = Vector2(4, 4)
	elif game_time < APOCALYPSE_TIME:  # 20:00-30:00 - Dark Mage mini-boss
		boss_scene = DARK_MAGE_SCENE
		boss_name = "ArchMage"
	else:  # After 30:00 - Purple Alien mini-boss
		# Will use purple alien scene when we create it
		boss_scene = DARK_MAGE_SCENE
		boss_name = "AlienOverlord"
	
	var mini_boss = boss_scene.instantiate()
	mini_boss.name = boss_name
	mini_boss.add_to_group("mini_boss")
	mini_boss.scale = boss_scale
	
	# Mini-boss stats: 5x normal mob health
	mini_boss.health = mini_boss.base_health * 5.0 * difficulty_mult
	mini_boss.max_health = mini_boss.health
	mini_boss.speed = mini_boss.base_speed * 1.3  # 30% faster
	mini_boss.xp_value = 50  # Good XP reward
	
	var screen_size = get_viewport_rect().size
	mini_boss.global_position = player.global_position + Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
	
	add_child(mini_boss)
	
	if mini_boss.has_signal("died"):
		mini_boss.died.connect(_on_mob_died.bind(mini_boss))
	
	if ENEMY_HEALTH_BAR:
		var health_bar = ENEMY_HEALTH_BAR.instantiate()
		health_bar.set_target(mini_boss)
		ui_layer.add_child(health_bar)
	
	print("👑 MINI-BOSS SPAWNED: %s" % boss_name)

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
		add_child(vial)

	if dead_mob.is_in_group("boss"):
		bosses_defeated += 1
		print("💎 BOSS DEFEATED! Dropping chest...")
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
	add_child(chest)
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
	ui_layer.add_child(lvl_up)
	
	if lvl_up.has_signal("upgrade_selected"):
		lvl_up.upgrade_selected.connect(_on_level_up_upgrade_selected)

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
	
	is_level_up_open = false
	get_tree().paused = false

func _on_player_death() -> void:
	get_tree().paused = true
	print("💀 GAME OVER – %.0f seconds!" % game_time)
	print("Bosses defeated: %d" % bosses_defeated)
	print("Enemies killed: %d" % enemies_killed)
	
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
