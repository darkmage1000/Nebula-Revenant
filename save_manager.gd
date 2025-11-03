# save_manager.gd - PHASE 4: Persistent save system for meta-progression
extends Node

const SAVE_PATH = "user://nebula_revenant_save.json"

# Default save data structure
var save_data = {
	"total_shards": 0,
	"lifetime_shards": 0,
	"runs_completed": 0,
	"best_time": 0,
	"highest_level": 0,
	"total_kills": 0,
	
	# Permanent upgrades
	"upgrades": {
		"starting_damage": 0,      # +5% damage per level
		"starting_health": 0,      # +20 HP per level
		"starting_speed": 0,       # +5% speed per level
		"starting_luck": 0,        # +1 luck per level
		"xp_boost": 0,             # +10% XP per level
		"currency_boost": 0,       # +20% shards per level
		"starting_weapon_slot": 0, # +1 weapon slot (max 1)
		"reroll_count": 0,         # +1 reroll per level (max 3)
	}
}

func _ready():
	load_game()

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

# Track run stats
func record_run_stats(stats: Dictionary):
	save_data.runs_completed += 1
	
	# Update best stats
	if stats.get("time_survived", 0) > save_data.best_time:
		save_data.best_time = stats.get("time_survived", 0)
	
	if stats.get("level", 0) > save_data.highest_level:
		save_data.highest_level = stats.get("level", 0)
	
	save_data.total_kills += stats.get("kills", 0)
	
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
