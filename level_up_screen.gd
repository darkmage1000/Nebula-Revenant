# level_up_screen.gd – FIXED: WORKING LEVEL UP WITH PROPER PAUSING
extends Control

# SIGNAL: Sent when player picks an upgrade
signal upgrade_selected(data: Dictionary)

# Reference to player (set by main_game.gd)
var player: CharacterBody2D = null

# ==================== COMPREHENSIVE UPGRADE SYSTEM – Phase 2 Complete! ====================
var upgrade_options: Array = [
	# ==================== WEAPON UNLOCKS ====================
	{"type": "unlock", "weapon": "shotgun", "label": "🔫 Unlock Shotgun", "desc": "Close-range devastation. Fires 4 pellets in a spread.", "rarity": "uncommon"},
	{"type": "unlock", "weapon": "grenade", "label": "💣 Unlock Grenade Launcher", "desc": "Explosive area damage. Long-range lobbed projectiles.", "rarity": "uncommon"},
	{"type": "unlock", "weapon": "aura", "label": "☢️ Unlock Radiation Aura", "desc": "Passive damage field. Constantly hurts nearby enemies.", "rarity": "rare"},
	
	# ==================== OFFENSE STATS (PHASE 3 REBALANCED) ====================
	{"type": "stat", "key": "damage_mult", "value": 0.08, "label": "⚔️ Damage +8%", "desc": "All weapons deal more damage", "rarity": "common"},
	{"type": "stat", "key": "damage_mult", "value": 0.15, "label": "⚔️ Damage +15%", "desc": "Significant damage boost to all weapons", "rarity": "uncommon"},
	{"type": "stat", "key": "attack_speed_mult", "value": 0.10, "label": "⚡ Attack Speed +10%", "desc": "All weapons fire faster", "rarity": "common"},
	{"type": "stat", "key": "attack_speed_mult", "value": 0.18, "label": "⚡ Attack Speed +18%", "desc": "Major fire rate increase", "rarity": "uncommon"},
	{"type": "stat", "key": "crit_chance", "value": 0.03, "label": "🎯 Crit Chance +3%", "desc": "Higher chance for critical hits", "rarity": "common"},
	{"type": "stat", "key": "crit_chance", "value": 0.07, "label": "🎯 Crit Chance +7%", "desc": "Much higher critical hit chance", "rarity": "rare"},
	{"type": "stat", "key": "crit_damage", "value": 0.15, "label": "💥 Crit Damage +15%", "desc": "Critical hits deal more damage", "rarity": "uncommon"},
	{"type": "stat", "key": "crit_damage", "value": 0.30, "label": "💥 Crit Damage +30%", "desc": "Massive critical hit damage", "rarity": "rare"},
	{"type": "stat", "key": "aoe_mult", "value": 0.15, "label": "💫 Area Size +15%", "desc": "Explosions and auras are larger", "rarity": "uncommon"},
	{"type": "stat", "key": "projectiles", "value": 1, "label": "🔮 +1 Projectile", "desc": "Fire one extra projectile per shot", "rarity": "rare"},
	
	# ==================== DEFENSE STATS ====================
	{"type": "stat", "key": "max_health", "value": 30, "label": "❤️ Max HP +30", "desc": "Increases maximum health", "rarity": "common"},
	{"type": "stat", "key": "max_health", "value": 50, "label": "❤️ Max HP +50", "desc": "Large health increase", "rarity": "uncommon"},
	{"type": "stat", "key": "max_health", "value": 100, "label": "❤️ Max HP +100", "desc": "Massive health boost", "rarity": "rare"},
	{"type": "stat", "key": "health_regen", "value": 0.5, "label": "💚 Regen +0.5/sec", "desc": "Slowly regenerate health", "rarity": "common"},
	{"type": "stat", "key": "health_regen", "value": 1.5, "label": "💚 Regen +1.5/sec", "desc": "Faster health regeneration", "rarity": "uncommon"},
	{"type": "stat", "key": "health_regen", "value": 3.0, "label": "💚 Regen +3.0/sec", "desc": "Rapid health regeneration", "rarity": "rare"},
	{"type": "stat", "key": "lifesteal", "value": 0.05, "label": "🩸 Lifesteal +5%", "desc": "Heal from damage dealt", "rarity": "uncommon"},
	{"type": "stat", "key": "lifesteal", "value": 0.10, "label": "🩸 Lifesteal +10%", "desc": "Significant healing from damage", "rarity": "rare"},
	{"type": "stat", "key": "armor", "value": 5, "label": "🛡️ Armor +5", "desc": "Reduces incoming damage", "rarity": "common"},
	{"type": "stat", "key": "armor", "value": 10, "label": "🛡️ Armor +10", "desc": "Major damage reduction", "rarity": "uncommon"},
	
	# ==================== UTILITY STATS ====================
	{"type": "stat", "key": "speed", "value": 0.10, "label": "👟 Move Speed +10%", "desc": "Move faster to dodge enemies", "rarity": "common"},
	{"type": "stat", "key": "speed", "value": 0.20, "label": "👟 Move Speed +20%", "desc": "Much faster movement", "rarity": "uncommon"},
	{"type": "stat", "key": "pickup_radius", "value": 30, "label": "🧲 Pickup Radius +30", "desc": "Collect XP from further away", "rarity": "common"},
	{"type": "stat", "key": "pickup_radius", "value": 50, "label": "🧲 Pickup Radius +50", "desc": "Large XP collection range", "rarity": "uncommon"},
	{"type": "stat", "key": "luck", "value": 1, "label": "🍀 Luck +1", "desc": "Better drops, more XP, and rare upgrades", "rarity": "rare"},
	{"type": "stat", "key": "luck", "value": 2, "label": "🍀 Luck +2", "desc": "Great fortune favors you", "rarity": "legendary"},
	{"type": "stat", "key": "max_weapon_slots", "value": 1, "label": "🔧 +1 Weapon Slot", "desc": "Carry more weapons at once", "rarity": "legendary"},
	
	# ==================== PISTOL UPGRADES (PHASE 3 REBALANCED) ====================
	{"type": "weapon", "weapon": "pistol", "key": "damage", "value": 3, "label": "🔫 Pistol: +3 Damage", "desc": "More damage per shot", "rarity": "common"},
	{"type": "weapon", "weapon": "pistol", "key": "damage", "value": 5, "label": "🔫 Pistol: +5 Damage", "desc": "Major damage increase", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "pistol", "key": "attack_speed", "value": 0.10, "label": "🔫 Pistol: +10% Fire Rate", "desc": "Shoot faster", "rarity": "common"},
	{"type": "weapon", "weapon": "pistol", "key": "attack_speed", "value": 0.20, "label": "🔫 Pistol: +20% Fire Rate", "desc": "Rapid fire mode", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "pistol", "key": "pierce", "value": 1, "label": "🔫 Pistol: +1 Pierce", "desc": "Bullets pass through enemies", "rarity": "rare"},
	{"type": "weapon", "weapon": "pistol", "key": "projectiles", "value": 1, "label": "🔫 Pistol: +1 Projectile", "desc": "Fire an extra bullet", "rarity": "rare"},
	
	# ==================== SHOTGUN UPGRADES ====================
	{"type": "weapon", "weapon": "shotgun", "key": "damage", "value": 3, "label": "💥 Shotgun: +3 Damage", "desc": "Each pellet hits harder", "rarity": "common"},
	{"type": "weapon", "weapon": "shotgun", "key": "damage", "value": 5, "label": "💥 Shotgun: +5 Damage", "desc": "Devastating pellet damage", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "shotgun", "key": "projectiles", "value": 2, "label": "💥 Shotgun: +2 Pellets", "desc": "Fire more pellets per shot", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "shotgun", "key": "attack_speed", "value": 0.20, "label": "💥 Shotgun: +20% Fire Rate", "desc": "Faster between shots", "rarity": "common"},
	{"type": "weapon", "weapon": "shotgun", "key": "pierce", "value": 1, "label": "💥 Shotgun: +1 Pierce", "desc": "Pellets pass through enemies", "rarity": "rare"},
	{"type": "weapon", "weapon": "shotgun", "key": "knockback", "value": 30, "label": "💥 Shotgun: +30 Knockback", "desc": "Blast enemies away", "rarity": "uncommon"},
	
	# ==================== GRENADE UPGRADES ====================
	{"type": "weapon", "weapon": "grenade", "key": "damage", "value": 15, "label": "💣 Grenade: +15 Damage", "desc": "Bigger explosions", "rarity": "common"},
	{"type": "weapon", "weapon": "grenade", "key": "damage", "value": 30, "label": "💣 Grenade: +30 Damage", "desc": "Massive explosion damage", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "grenade", "key": "aoe", "value": 20, "label": "💣 Grenade: +20 Blast Radius", "desc": "Larger explosion area", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "grenade", "key": "aoe", "value": 40, "label": "💣 Grenade: +40 Blast Radius", "desc": "Huge explosion radius", "rarity": "rare"},
	{"type": "weapon", "weapon": "grenade", "key": "attack_speed", "value": 0.20, "label": "💣 Grenade: +20% Throw Speed", "desc": "Throw grenades faster", "rarity": "common"},
	{"type": "weapon", "weapon": "grenade", "key": "projectiles", "value": 1, "label": "💣 Grenade: +1 Grenade", "desc": "Throw multiple grenades", "rarity": "legendary"},
	
	# ==================== AURA UPGRADES ====================
	{"type": "weapon", "weapon": "aura", "key": "damage", "value": 5, "label": "☢️ Aura: +5 Damage", "desc": "Stronger radiation damage", "rarity": "common"},
	{"type": "weapon", "weapon": "aura", "key": "damage", "value": 10, "label": "☢️ Aura: +10 Damage", "desc": "Intense radiation", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "aura", "key": "damage", "value": 20, "label": "☢️ Aura: +20 Damage", "desc": "Devastating radiation field", "rarity": "rare"},
	{"type": "weapon", "weapon": "aura", "key": "aoe", "value": 25, "label": "☢️ Aura: +25 Radius", "desc": "Larger damage field", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "aura", "key": "aoe", "value": 50, "label": "☢️ Aura: +50 Radius", "desc": "Massive damage field", "rarity": "rare"},
	{"type": "weapon", "weapon": "aura", "key": "attack_speed", "value": 0.25, "label": "☢️ Aura: +25% Tick Rate", "desc": "Damage enemies more frequently", "rarity": "uncommon"},
]

# UI Nodes - now using correct paths from the scene
@onready var title_label: Label = $Label
@onready var button_container: VBoxContainer = $CenterContainer/OptionsContainer

func _ready() -> void:
	# Set title
	if title_label:
		title_label.text = "LEVEL UP! Choose One:"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 32)
	
	# Clear old buttons
	for child in button_container.get_children():
		child.queue_free()
	
	# OFFER 2ND WEAPON AS COMMON OPTION if player only has 1 weapon
	# But don't force it - let them choose!
	var available_pool = _filter_available_upgrades()
	
	# If player has 1 weapon, make weapon unlocks COMMON rarity to appear often
	if player and player.player_stats.current_weapons.size() == 1:
		for opt in upgrade_options:
			if opt.type == "unlock" and not player.player_stats.current_weapons.has(opt.weapon):
				# Create a common rarity version of this weapon unlock
				var common_weapon = opt.duplicate()
				common_weapon["rarity"] = "common"  # Make it common!
				available_pool.append(common_weapon)
	
	# Randomly pick 3 upgrades with luck-based rarity weighting
	var selected = []
	var pool = available_pool.duplicate()
	while selected.size() < 3 and pool.size() > 0:
		var idx = _pick_weighted_upgrade(pool)
		selected.append(pool[idx])
		pool.remove_at(idx)
	
	# Create buttons for each upgrade
	for opt in selected:
		var btn = Button.new()
		btn.text = opt.label
		if opt.has("desc"):
			btn.tooltip_text = opt.desc
		btn.custom_minimum_size = Vector2(400, 80)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_upgrade_pressed.bind(opt))
		button_container.add_child(btn)

# Pick an upgrade weighted by rarity and player luck
func _pick_weighted_upgrade(pool: Array) -> int:
	if not player or pool.size() == 0:
		return 0
	
	# Rarity weights (higher = more common)
	var rarity_weights = {
		"common": 100,
		"uncommon": 50,
		"rare": 20,
		"legendary": 5
	}
	
	# Luck increases rare weights (each luck point increases rare weights by 20%)
	var luck = player.player_stats.get("luck", 0)
	var luck_mult = 1.0 + (luck * 0.20)
	rarity_weights["rare"] = int(rarity_weights["rare"] * luck_mult)
	rarity_weights["legendary"] = int(rarity_weights["legendary"] * luck_mult * 1.5)
	
	# Calculate total weight
	var total_weight = 0
	for opt in pool:
		var rarity = opt.get("rarity", "common")
		total_weight += rarity_weights.get(rarity, 100)
	
	# Pick randomly based on weight
	var roll = randi() % total_weight
	var cumulative = 0
	
	for i in range(pool.size()):
		var rarity = pool[i].get("rarity", "common")
		cumulative += rarity_weights.get(rarity, 100)
		if roll < cumulative:
			return i
	
	return 0  # Fallback

# Filter upgrades based on what weapons player has unlocked
func _filter_available_upgrades() -> Array:
	var filtered = []
	
	for opt in upgrade_options:
		# Check if this is a weapon unlock
		if opt.type == "unlock":
			# Only offer if player doesn't have this weapon yet
			if player and not player.player_stats.current_weapons.has(opt.weapon):
				filtered.append(opt)
		# Check if this is a weapon-specific upgrade
		elif opt.type == "weapon":
			# Only offer if player HAS this weapon
			if player and player.player_stats.current_weapons.has(opt.weapon):
				filtered.append(opt)
		# Stat upgrades are always available
		elif opt.type == "stat":
			filtered.append(opt)
	
	return filtered

# Called when a button is pressed
func _on_upgrade_pressed(option: Dictionary) -> void:
	var data: Dictionary = {}
	
	match option.type:
		"unlock":
			data["unlock_weapon"] = option.weapon
		"stat":
			data["stat_key"] = option.key
			data["value"] = option.value
		"weapon":
			data["weapon_key"] = option.weapon
			data["upgrade_key"] = option.key
			data["value"] = option.value
	
	# Emit signal → main_game handles upgrade
	upgrade_selected.emit(data)
	
	# Remove self from scene
	queue_free()
