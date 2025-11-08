# save_manager.gd - AUTO-SAVE SYSTEM: Saves every run + periodic saves
extends Node

const SAVE_PATH = "user://nebula_revenant_save.json"

# Current run tracking (for mid-run saves)
var current_run_shards: int = 0
var current_run_level: int = 1
var current_run_time: float = 0.0
var current_run_kills: int = 0
var current_run_active: bool = false

# Default save data structure
var save_data = {
	"total_shards": 0,
	"lifetime_shards": 0,
	"runs_completed": 0,
	"best_time": 0,
	"highest_level": 0,
	"total_kills": 0,
	
	# CHARACTER UNLOCK SYSTEM - NEW!
	"unlocks": {
		"swordmaiden_unlocked": false,
		"swordmaiden_challenge_best": 0  # Best level reached for unlock challenge
	},
	
	# Permanent upgrades
	"upgrades": {
		"starting_damage": 0,
		"starting_health": 0,
		"starting_speed": 0,
		"starting_luck": 0,
		"xp_boost": 0,
		"currency_boost": 0,
		"starting_weapon_slot": 0,
		"reroll_count": 0,
	}
}

func _ready():
	load_game()
	# ENSURE unlocks data exists (for old save files)
	ensure_unlocks_data()
	# Start auto-save timer
	start_autosave_timer()

func ensure_unlocks_data():
	# Make sure unlocks dictionary exists
	if not save_data.has("unlocks"):
		save_data.unlocks = {
			"swordmaiden_unlocked": false,
			"swordmaiden_challenge_best": 0
		}
		save_game()
		print("✅ Added unlocks data to save file")
	else:
		# Make sure all unlock keys exist
		if not save_data.unlocks.has("swordmaiden_unlocked"):
			save_data.unlocks.swordmaiden_unlocked = false
		if not save_data.unlocks.has("swordmaiden_challenge_best"):
			save_data.unlocks.swordmaiden_challenge_best = 0
		save_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		print("💾 Game saved!")
		return true
	else:
		print("❌ Failed to save game!")
		return false

# ==============================================================
# AUTO-SAVE SYSTEM - Saves during gameplay
# ==============================================================

func start_autosave_timer():
	# Auto-save every 30 seconds during gameplay
	var timer = Timer.new()
	timer.name = "AutoSaveTimer"
	timer.wait_time = 30.0
	timer.autostart = false
	timer.timeout.connect(_on_autosave_timeout)
	add_child(timer)
	print("⏱️ Auto-save system ready (saves every 30 seconds)")

func _on_autosave_timeout():
	if current_run_active:
		print("💾 Auto-saving current run progress...")
		# Save current progress (in case game closes)
		save_game()
		print("✅ Auto-save complete! Shards this run: %d" % current_run_shards)

# Start tracking a new run
func start_new_run():
	current_run_shards = 0
	current_run_level = 1
	current_run_time = 0.0
	current_run_kills = 0
	current_run_active = true
	
	# Start auto-save timer
	var timer = get_node_or_null("AutoSaveTimer")
	if timer:
		timer.start()
	
	print("🎮 New run started - auto-save enabled")

# Update current run stats (call this during gameplay)
func update_run_stats(shards: int = -1, level: int = -1, time: float = -1, kills: int = -1):
	if not current_run_active:
		return
	
	if shards >= 0:
		current_run_shards = shards
	if level >= 0:
		current_run_level = level
	if time >= 0:
		current_run_time = time
	if kills >= 0:
		current_run_kills = kills

# End current run and save everything
func end_run():
	if not current_run_active:
		return

	current_run_active = false

	# Stop auto-save timer
	var timer = get_node_or_null("AutoSaveTimer")
	if timer:
		timer.stop()

	# CRITICAL FIX: Record run stats BEFORE ending (for Swordmaiden unlock tracking)
	var run_data = {
		"level": current_run_level,
		"time_survived": current_run_time,
		"kills": current_run_kills,
		"shards": current_run_shards
	}
	record_run_stats(run_data)
	print("📊 Run stats recorded: Level %d, Time %.1fs, Kills %d" % [current_run_level, current_run_time, current_run_kills])

	# Add any collected shards to bank
	if current_run_shards > 0:
		add_shards(current_run_shards)
		print("💰 Run ended: %d shards added to bank" % current_run_shards)

	print("🏁 Run ended - final save complete")

# Manual save button (for pause menu)
func manual_save():
	if save_game():
		print("💾 Manual save successful!")
		return true
	else:
		print("❌ Manual save failed!")
		return false

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("📄 No save file found, using defaults")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var loaded_data = json.get_data()
			# Merge loaded data with defaults (in case new fields added)
			for key in loaded_data:
				if save_data.has(key):
					if key == "upgrades":
						# Merge upgrade data
						for upgrade_key in loaded_data.upgrades:
							save_data.upgrades[upgrade_key] = loaded_data.upgrades[upgrade_key]
					elif key == "unlocks":
						# Merge unlock data
						for unlock_key in loaded_data.unlocks:
							save_data.unlocks[unlock_key] = loaded_data.unlocks[unlock_key]
					else:
						save_data[key] = loaded_data[key]
			
			print("💾 Game loaded! Shards: %d" % save_data.total_shards)
			return true
		else:
			print("❌ Failed to parse save file!")
			return false
	
	return false

# Add shards
func add_shards(amount: int):
	save_data.total_shards += amount
	save_data.lifetime_shards += amount
	save_game()

# Spend shards
func spend_shards(amount: int) -> bool:
	if save_data.total_shards >= amount:
		save_data.total_shards -= amount
		save_game()
		return true
	return false

# Get current shards
func get_shards() -> int:
	return save_data.total_shards

# Upgrade system
func get_upgrade_level(upgrade_name: String) -> int:
	if save_data.upgrades.has(upgrade_name):
		return save_data.upgrades[upgrade_name]
	return 0

func purchase_upgrade(upgrade_name: String, cost: int) -> bool:
	if save_data.upgrades.has(upgrade_name):
		if spend_shards(cost):
			save_data.upgrades[upgrade_name] += 1
			save_game()
			print("✅ Purchased: %s (Level %d)" % [upgrade_name, save_data.upgrades[upgrade_name]])
			return true
	return false

# ==============================================================
# CHARACTER UNLOCK SYSTEM - NEW!
# ==============================================================

# Check if swordmaiden is unlocked
func is_swordmaiden_unlocked() -> bool:
	if not save_data.has("unlocks"):
		return false
	return save_data.unlocks.get("swordmaiden_unlocked", false)

# Check if challenge is complete (level 30 reached)
func is_swordmaiden_challenge_complete() -> bool:
	if not save_data.has("unlocks"):
		return false
	return save_data.unlocks.get("swordmaiden_challenge_best", 0) >= 30

# Get challenge progress
func get_swordmaiden_challenge_progress() -> int:
	if not save_data.has("unlocks"):
		return 0
	return save_data.unlocks.get("swordmaiden_challenge_best", 0)

# Try to purchase swordmaiden unlock
func try_unlock_swordmaiden() -> bool:
	# Must complete challenge first
	if not is_swordmaiden_challenge_complete():
		print("❌ Challenge not complete! Reach level 30 first.")
		return false
	
	# Must have enough shards
	if save_data.total_shards < 5000:
		print("❌ Not enough shards! Need 5000, have %d" % save_data.total_shards)
		return false
	
	# Purchase!
	if spend_shards(5000):
		save_data.unlocks.swordmaiden_unlocked = true
		save_game()
		print("🗡️ SWORDMAIDEN UNLOCKED!")
		return true
	
	return false

# Update challenge progress
func update_swordmaiden_challenge(level: int):
	if not save_data.has("unlocks"):
		save_data.unlocks = {
			"swordmaiden_unlocked": false,
			"swordmaiden_challenge_best": 0
		}
	
	if level > save_data.unlocks.swordmaiden_challenge_best:
		save_data.unlocks.swordmaiden_challenge_best = level
		save_game()
		
		if level >= 30 and not save_data.unlocks.swordmaiden_unlocked:
			print("🏆 CHALLENGE COMPLETE! Swordmaiden can now be purchased for 5000 shards!")

# ==============================================================
# ORIGINAL FUNCTIONS
# ==============================================================

# Track run stats
func record_run_stats(stats: Dictionary):
	save_data.runs_completed += 1
	
	# Update best stats
	if stats.get("time_survived", 0) > save_data.best_time:
		save_data.best_time = stats.get("time_survived", 0)
	
	if stats.get("level", 0) > save_data.highest_level:
		save_data.highest_level = stats.get("level", 0)
	
	save_data.total_kills += stats.get("kills", 0)
	
	# Update character unlock challenge
	update_swordmaiden_challenge(stats.get("level", 0))
	
	save_game()

# Get starting bonuses based on upgrades
func get_starting_bonuses() -> Dictionary:
	return {
		"damage_bonus": save_data.upgrades.starting_damage * 0.05,
		"health_bonus": save_data.upgrades.starting_health * 20,
		"speed_bonus": save_data.upgrades.starting_speed * 0.05,
		"luck_bonus": save_data.upgrades.starting_luck,
		"xp_multiplier": 1.0 + (save_data.upgrades.xp_boost * 0.10),
		"currency_multiplier": 1.0 + (save_data.upgrades.currency_boost * 0.20),
		"extra_weapon_slot": save_data.upgrades.starting_weapon_slot,
		"reroll_count": save_data.upgrades.reroll_count
	}

# Reset progress (for testing)
func reset_all_progress():
	save_data = {
		"total_shards": 0,
		"lifetime_shards": 0,
		"runs_completed": 0,
		"best_time": 0,
		"highest_level": 0,
		"total_kills": 0,
		"unlocks": {
			"swordmaiden_unlocked": false,
			"swordmaiden_challenge_best": 0
		},
		"upgrades": {
			"starting_damage": 0,
			"starting_health": 0,
			"starting_speed": 0,
			"starting_luck": 0,
			"xp_boost": 0,
			"currency_boost": 0,
			"starting_weapon_slot": 0,
			"reroll_count": 0,
		}
	}
	save_game()
	print("⚠️ All progress reset!")

# TESTING: Unlock swordmaiden for free (for development)
func unlock_swordmaiden_dev():
	if not save_data.has("unlocks"):
		save_data.unlocks = {}
	save_data.unlocks.swordmaiden_unlocked = true
	save_data.unlocks.swordmaiden_challenge_best = 30
	save_game()
	print("🔓 DEV: Swordmaiden unlocked for testing!")

# TESTING: Set challenge progress for testing
func set_challenge_progress_dev(level: int):
	if not save_data.has("unlocks"):
		save_data.unlocks = {}
	save_data.unlocks.swordmaiden_challenge_best = level
	save_game()
	print("🔧 DEV: Challenge progress set to %d" % level)
