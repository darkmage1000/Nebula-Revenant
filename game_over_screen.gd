# game_over_screen.gd - PHASE 4: Shows run stats + SAVES CURRENCY
extends Control

signal exit_to_menu

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var stats_container = $Panel/VBoxContainer/ScrollContainer/StatsContainer
@onready var exit_button = $Panel/VBoxContainer/ExitButton

var run_stats: Dictionary = {}

func _ready():
	# Make sure it pauses game
	process_mode = Node.PROCESS_MODE_ALWAYS

	if exit_button:
		# Ensure button can process input while game is paused
		exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
		exit_button.pressed.connect(_on_exit_pressed)
		print("✅ Game Over: Exit button connected")
	else:
		print("❌ Game Over: Exit button not found!")

	display_stats()

func set_run_stats(stats: Dictionary):
	run_stats = stats
	
	# PHASE 4: Save shards collected and run stats
	if has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		
		# End the current run (this saves shards and stops auto-save)
		save_manager.end_run()
		
		var shards = stats.get("shards_collected", 0)
		if shards > 0:
			print("💾 Saved %d shards to bank!" % shards)
		
		# Record run stats for career tracking
		save_manager.record_run_stats(stats)
		print("💾 Full run stats saved!")
	
	if is_inside_tree():
		display_stats()

func display_stats():
	if not stats_container:
		return
	
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()
	
	# Title
	if title_label:
		title_label.text = "GAME OVER"
	
	# Calculate playtime
	var time_seconds = run_stats.get("time_survived", 0)
	var minutes = int(time_seconds / 60)
	var seconds = int(time_seconds) % 60
	var time_string = "%d:%02d" % [minutes, seconds]
	
	# Add stat labels
	add_stat_label("=== RUN COMPLETE ===", 28, Color(1, 0.9, 0.3))
	add_stat_label("Time Survived: %s" % time_string, 22)
	add_stat_label("Final Level: %d" % run_stats.get("level", 0), 20)
	add_stat_label("Total XP Gained: %d" % run_stats.get("total_xp", 0), 18)
	add_stat_label("Enemies Killed: %d" % run_stats.get("kills", 0), 18)
	add_stat_label("Total Damage Dealt: %d" % run_stats.get("damage_dealt", 0), 18)
	
	# PHASE 4: Show currency collected
	add_spacing(10)
	var shards = run_stats.get("shards_collected", 0)
	add_stat_label("💎 Nebula Shards Earned: %d" % shards, 24, Color(0.3, 0.8, 1.0))
	
	# Add spacing
	add_spacing(20)
	
	# Final stats
	add_stat_label("--- Final Stats ---", 22, Color(1.0, 0.9, 0.3))
	add_stat_label("Max HP: %.0f" % run_stats.get("max_health", 0), 18)
	add_stat_label("Damage: %.0f%%" % (run_stats.get("damage_mult", 1.0) * 100), 18)
	add_stat_label("Attack Speed: %.0f%%" % (run_stats.get("attack_speed_mult", 1.0) * 100), 18)
	add_stat_label("Move Speed: %.0f" % run_stats.get("speed", 0), 18)
	add_stat_label("Crit Chance: %.0f%%" % (run_stats.get("crit_chance", 0) * 100), 18)
	add_stat_label("Luck: %d" % run_stats.get("luck", 0), 18)
	
	# Weapons equipped
	add_spacing(15)
	add_stat_label("--- Weapons Used ---", 20, Color(0.3, 0.8, 1.0))
	var weapons = run_stats.get("weapons", [])
	if weapons.size() > 0:
		for weapon in weapons:
			add_stat_label("• %s" % weapon, 16)
	else:
		add_stat_label("• Pistol", 16)

func add_stat_label(text: String, font_size: int = 20, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(label)

func add_spacing(height: int):
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	stats_container.add_child(spacer)

func _on_exit_pressed():
	print("🏠 Game Over: Exit button pressed!")

	# Disable input processing to prevent double-clicks
	if exit_button:
		exit_button.disabled = true

	# CRITICAL: Unpause BEFORE changing scene
	get_tree().paused = false

	# Disable ALL input processing
	set_process_input(false)
	set_process_unhandled_input(false)

	# Emit signal (for any listeners)
	exit_to_menu.emit()

	# Change scene on next frame to ensure unpause takes effect
	await get_tree().process_frame

	print("✅ Game Over: Changing to main menu...")
	get_tree().change_scene_to_file("res://MainMenu.tscn")
