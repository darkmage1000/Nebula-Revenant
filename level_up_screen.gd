# level_up_screen.gd – FIXED: WORKING LEVEL UP WITH PROPER PAUSING
extends Control

# SIGNAL: Sent when player picks an upgrade
signal upgrade_selected(data: Dictionary)
signal option_banished(option: Dictionary)
signal option_skipped

# Reference to player (set by main_game.gd)
var player: CharacterBody2D = null

# Banish/Skip tracking (set by main_game.gd each level-up)
var banish_uses_remaining: int = 0
var skip_uses_remaining: int = 0
var banished_options_list: Array[Dictionary] = []  # Options banished this run (passed from main_game)
var current_upgrade_options: Array = []  # Store selected options for banish/skip

# ==================== COMPREHENSIVE UPGRADE SYSTEM – Phase 2 Complete! ====================
var upgrade_options: Array = [
	# ==================== WEAPON UNLOCKS ====================
	{"type": "unlock", "weapon": "pistol", "label": "🔫 Unlock Pistol", "desc": "Reliable ranged weapon. Rapid fire with good accuracy.", "rarity": "common"},
	{"type": "unlock", "weapon": "shotgun", "label": "🔫 Unlock Shotgun", "desc": "Close-range devastation. Fires 4 pellets in a spread.", "rarity": "uncommon"},
	{"type": "unlock", "weapon": "grenade", "label": "💣 Unlock Grenade Launcher", "desc": "Explosive area damage. Long-range lobbed projectiles.", "rarity": "uncommon"},
	{"type": "unlock", "weapon": "aura", "label": "☢️ Unlock Radiation Aura", "desc": "Passive damage field. Constantly hurts nearby enemies.", "rarity": "rare"},
	{"type": "unlock", "weapon": "sword", "label": "⚔️ Unlock Energy Sword", "desc": "Powerful melee weapon. Wide slashing arc with high damage.", "rarity": "rare"},
	{"type": "unlock", "weapon": "lightning_spell", "label": "⚡ Unlock Lightning Spell", "desc": "Chain lightning ranged spell. Bounces to nearby enemies.", "rarity": "rare"},
	{"type": "unlock", "weapon": "laser_beam", "label": "🔵 Unlock Laser Beam", "desc": "Auto-aiming laser that tracks and pierces all enemies in its path.", "rarity": "rare"},
	{"type": "unlock", "weapon": "summon_spaceships", "label": "🚀 Unlock Summon Spaceships", "desc": "Spawns ships that orbit then crash into enemies. Suicide bombers!", "rarity": "rare"},
	{"type": "unlock", "weapon": "acid_pool", "label": "☣️ Unlock Acid Pool", "desc": "Spawns acid pools at your position that damage enemies over time.", "rarity": "uncommon"},

	# ==================== OFFENSE STATS (HEAVILY NERFED) ====================
	{"type": "stat", "key": "damage_mult", "value": 0.04, "label": "⚔️ Damage +4%", "desc": "All weapons deal more damage", "rarity": "common"},
	{"type": "stat", "key": "damage_mult", "value": 0.08, "label": "⚔️ Damage +8%", "desc": "Significant damage boost to all weapons", "rarity": "uncommon"},
	{"type": "stat", "key": "attack_speed_mult", "value": 0.05, "label": "⚡ Attack Speed +5%", "desc": "All weapons fire faster", "rarity": "common"},
	{"type": "stat", "key": "attack_speed_mult", "value": 0.10, "label": "⚡ Attack Speed +10%", "desc": "Major fire rate increase", "rarity": "uncommon"},
	{"type": "stat", "key": "attack_range_mult", "value": 0.08, "label": "🎯 Attack Range +8%", "desc": "Shoot enemies from further away", "rarity": "common"},
	{"type": "stat", "key": "attack_range_mult", "value": 0.15, "label": "🎯 Attack Range +15%", "desc": "Significantly increased weapon range", "rarity": "uncommon"},
	{"type": "stat", "key": "attack_range_mult", "value": 0.25, "label": "🎯 Attack Range +25%", "desc": "Major range boost for all weapons", "rarity": "rare"},
	{"type": "stat", "key": "crit_chance", "value": 0.03, "label": "🎯 Crit Chance +3%", "desc": "Higher chance for critical hits", "rarity": "common"},
	{"type": "stat", "key": "crit_chance", "value": 0.07, "label": "🎯 Crit Chance +7%", "desc": "Much higher critical hit chance", "rarity": "rare"},
	{"type": "stat", "key": "crit_damage", "value": 0.15, "label": "💥 Crit Damage +15%", "desc": "Critical hits deal more damage", "rarity": "uncommon"},
	{"type": "stat", "key": "crit_damage", "value": 0.30, "label": "💥 Crit Damage +30%", "desc": "Massive critical hit damage", "rarity": "rare"},
	{"type": "stat", "key": "aoe_mult", "value": 0.15, "label": "💫 Area Size +15%", "desc": "Explosions and auras are larger", "rarity": "uncommon"},
	{"type": "stat", "key": "projectiles", "value": 1, "label": "🔮 +1 Projectile", "desc": "Fire one extra projectile per shot", "rarity": "rare"},
	
	# ==================== DEFENSE STATS ====================
	{"type": "stat", "key": "max_health", "value": 30, "label": "❤️ Max HP +30", "desc": "Increases maximum health", "rarity": "common"},
	{"type": "stat", "key": "max_health", "value": 40, "label": "❤️ Max HP +40", "desc": "Large health increase", "rarity": "uncommon"},
	{"type": "stat", "key": "max_health", "value": 60, "label": "❤️ Max HP +60", "desc": "Massive health boost", "rarity": "rare"},
	{"type": "stat", "key": "health_regen", "value": 0.25, "label": "💚 Regen +0.25/sec", "desc": "Slowly regenerate health", "rarity": "common"},
	{"type": "stat", "key": "health_regen", "value": 0.75, "label": "💚 Regen +0.75/sec", "desc": "Faster health regeneration", "rarity": "uncommon"},
	{"type": "stat", "key": "health_regen", "value": 1.5, "label": "💚 Regen +1.5/sec", "desc": "Rapid health regeneration", "rarity": "rare"},
	{"type": "stat", "key": "lifesteal", "value": 0.015, "label": "🩸 Lifesteal +1.5%", "desc": "Heal from damage dealt", "rarity": "uncommon"},
	{"type": "stat", "key": "lifesteal", "value": 0.03, "label": "🩸 Lifesteal +3%", "desc": "Significant healing from damage", "rarity": "rare"},
	{"type": "stat", "key": "armor", "value": 3, "label": "🛡️ Armor +3", "desc": "Reduces incoming damage", "rarity": "common"},
	{"type": "stat", "key": "armor", "value": 6, "label": "🛡️ Armor +6", "desc": "Major damage reduction", "rarity": "uncommon"},
	
	# ==================== UTILITY STATS ====================
	{"type": "stat", "key": "speed", "value": 0.10, "label": "👟 Move Speed +10%", "desc": "Move faster to dodge enemies", "rarity": "common"},
	{"type": "stat", "key": "speed", "value": 0.20, "label": "👟 Move Speed +20%", "desc": "Much faster movement", "rarity": "uncommon"},
	{"type": "stat", "key": "pickup_radius", "value": 30, "label": "🧲 Pickup Radius +30", "desc": "Collect XP from further away", "rarity": "common"},
	{"type": "stat", "key": "pickup_radius", "value": 50, "label": "🧲 Pickup Radius +50", "desc": "Large XP collection range", "rarity": "uncommon"},
	{"type": "stat", "key": "luck", "value": 1, "label": "🍀 Luck +1", "desc": "Better drops, more XP, and rare upgrades", "rarity": "rare"},
	{"type": "stat", "key": "luck", "value": 2, "label": "🍀 Luck +2", "desc": "Great fortune favors you", "rarity": "legendary"},
	# REMOVED: Weapon slots are now a permanent meta-progression upgrade only (not in level-up pool)
	
	# ==================== PISTOL UPGRADES (HEAVILY NERFED) ====================
	{"type": "weapon", "weapon": "pistol", "key": "damage", "value": 1.5, "label": "🔫 Pistol: +1.5 Damage", "desc": "More damage per shot", "rarity": "common"},
	{"type": "weapon", "weapon": "pistol", "key": "damage", "value": 2.5, "label": "🔫 Pistol: +2.5 Damage", "desc": "Major damage increase", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "pistol", "key": "attack_speed", "value": 0.08, "label": "🔫 Pistol: +8% Fire Rate", "desc": "Shoot faster", "rarity": "common"},
	{"type": "weapon", "weapon": "pistol", "key": "attack_speed", "value": 0.15, "label": "🔫 Pistol: +15% Fire Rate", "desc": "Rapid fire mode", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "pistol", "key": "pierce", "value": 1, "label": "🔫 Pistol: +1 Pierce", "desc": "Bullets pass through enemies", "rarity": "rare"},
	{"type": "weapon", "weapon": "pistol", "key": "projectiles", "value": 1, "label": "🔫 Pistol: +1 Projectile", "desc": "Fire an extra bullet", "rarity": "rare"},
	
	# ==================== SHOTGUN UPGRADES ====================
	{"type": "weapon", "weapon": "shotgun", "key": "damage", "value": 1.5, "label": "💥 Shotgun: +1.5 Damage", "desc": "Each pellet hits harder", "rarity": "common"},
	{"type": "weapon", "weapon": "shotgun", "key": "damage", "value": 2.5, "label": "💥 Shotgun: +2.5 Damage", "desc": "Devastating pellet damage", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "shotgun", "key": "projectiles", "value": 2, "label": "💥 Shotgun: +2 Pellets", "desc": "Fire more pellets per shot", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "shotgun", "key": "attack_speed", "value": 0.12, "label": "💥 Shotgun: +12% Fire Rate", "desc": "Faster between shots", "rarity": "common"},
	{"type": "weapon", "weapon": "shotgun", "key": "pierce", "value": 1, "label": "💥 Shotgun: +1 Pierce", "desc": "Pellets pass through enemies", "rarity": "rare"},
	{"type": "weapon", "weapon": "shotgun", "key": "knockback", "value": 30, "label": "💥 Shotgun: +30 Knockback", "desc": "Blast enemies away", "rarity": "uncommon"},
	
	# ==================== GRENADE UPGRADES ====================
	{"type": "weapon", "weapon": "grenade", "key": "damage", "value": 8, "label": "💣 Grenade: +8 Damage", "desc": "Bigger explosions", "rarity": "common"},
	{"type": "weapon", "weapon": "grenade", "key": "damage", "value": 15, "label": "💣 Grenade: +15 Damage", "desc": "Massive explosion damage", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "grenade", "key": "aoe", "value": 10, "label": "💣 Grenade: +10 Blast Radius", "desc": "Larger explosion area", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "grenade", "key": "aoe", "value": 15, "label": "💣 Grenade: +15 Blast Radius", "desc": "Bigger explosion radius", "rarity": "rare"},
	{"type": "weapon", "weapon": "grenade", "key": "attack_speed", "value": 0.12, "label": "💣 Grenade: +12% Throw Speed", "desc": "Throw grenades faster", "rarity": "common"},
	{"type": "weapon", "weapon": "grenade", "key": "projectiles", "value": 1, "label": "💣 Grenade: +1 Grenade", "desc": "Throw multiple grenades", "rarity": "legendary"},
	
	# ==================== AURA UPGRADES ====================
	{"type": "weapon", "weapon": "aura", "key": "damage", "value": 2.5, "label": "☢️ Aura: +2.5 Damage", "desc": "Stronger radiation damage", "rarity": "common"},
	{"type": "weapon", "weapon": "aura", "key": "damage", "value": 5, "label": "☢️ Aura: +5 Damage", "desc": "Intense radiation", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "aura", "key": "damage", "value": 10, "label": "☢️ Aura: +10 Damage", "desc": "Devastating radiation field", "rarity": "rare"},
	{"type": "weapon", "weapon": "aura", "key": "aoe", "value": 25, "label": "☢️ Aura: +25 Radius", "desc": "Larger damage field", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "aura", "key": "aoe", "value": 50, "label": "☢️ Aura: +50 Radius", "desc": "Massive damage field", "rarity": "rare"},
	{"type": "weapon", "weapon": "aura", "key": "attack_speed", "value": 0.15, "label": "☢️ Aura: +15% Tick Rate", "desc": "Damage enemies more frequently", "rarity": "uncommon"},

	# ==================== SWORD UPGRADES (Energy Sword - Sword Maiden) ====================
	{"type": "weapon", "weapon": "sword", "key": "damage", "value": 3, "label": "⚔️ Sword: +3 Damage", "desc": "Sharper blade, more damage per swing", "rarity": "common"},
	{"type": "weapon", "weapon": "sword", "key": "damage", "value": 6, "label": "⚔️ Sword: +6 Damage", "desc": "Major damage increase", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "sword", "key": "damage", "value": 12, "label": "⚔️ Sword: +12 Damage", "desc": "Devastating slash damage", "rarity": "rare"},
	{"type": "weapon", "weapon": "sword", "key": "attack_speed", "value": 0.10, "label": "⚔️ Sword: +10% Swing Speed", "desc": "Swing faster", "rarity": "common"},
	{"type": "weapon", "weapon": "sword", "key": "attack_speed", "value": 0.20, "label": "⚔️ Sword: +20% Swing Speed", "desc": "Rapid slashing", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "sword", "key": "attack_speed", "value": 0.35, "label": "⚔️ Sword: +35% Swing Speed", "desc": "Lightning-fast strikes", "rarity": "rare"},
	{"type": "weapon", "weapon": "sword", "key": "distance", "value": 15, "label": "⚔️ Sword: +15 Range", "desc": "Extended melee reach", "rarity": "common"},
	{"type": "weapon", "weapon": "sword", "key": "distance", "value": 25, "label": "⚔️ Sword: +25 Range", "desc": "Much longer reach", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "sword", "key": "distance", "value": 40, "label": "⚔️ Sword: +40 Range", "desc": "Massive melee range", "rarity": "rare"},
	{"type": "weapon", "weapon": "sword", "key": "aoe", "value": 15, "label": "⚔️ Sword: +15 Arc Size", "desc": "Wider swing angle", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "sword", "key": "aoe", "value": 30, "label": "⚔️ Sword: +30 Arc Size", "desc": "Much wider swing arc", "rarity": "rare"},
	{"type": "weapon", "weapon": "sword", "key": "aoe", "value": 50, "label": "⚔️ Sword: +50 Arc Size", "desc": "Near 360° slashing arc", "rarity": "legendary"},
	{"type": "weapon", "weapon": "sword", "key": "projectiles", "value": 1, "label": "⚔️ Sword: +1 Target", "desc": "Hit one more enemy per swing", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "sword", "key": "projectiles", "value": 2, "label": "⚔️ Sword: +2 Targets", "desc": "Hit two more enemies per swing", "rarity": "rare"},
	{"type": "weapon", "weapon": "sword", "key": "projectiles", "value": 3, "label": "⚔️ Sword: +3 Targets", "desc": "Cleave through multiple foes", "rarity": "legendary"},
	{"type": "weapon", "weapon": "sword", "key": "knockback", "value": 30, "label": "⚔️ Sword: +30 Knockback", "desc": "Push enemies back further", "rarity": "common"},
	{"type": "weapon", "weapon": "sword", "key": "knockback", "value": 60, "label": "⚔️ Sword: +60 Knockback", "desc": "Massive knockback force", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "sword", "key": "poison", "value": true, "label": "⚔️ Sword: Poison Edge", "desc": "30% chance to poison enemies (30% weapon dmg/sec)", "rarity": "rare"},

	# ==================== LIGHTNING SPELL UPGRADES (Alien Monk) ====================
	{"type": "weapon", "weapon": "lightning_spell", "key": "chain_targets", "value": 1, "label": "⚡ Lightning: +1 Chain Target", "desc": "Lightning bounces to one more enemy", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "chain_targets", "value": 2, "label": "⚡ Lightning: +2 Chain Targets", "desc": "Lightning bounces to two more enemies", "rarity": "rare"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "projectiles", "value": 1, "label": "⚡ Lightning: +1 Projectile", "desc": "Fire an extra lightning bolt", "rarity": "rare"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "projectiles", "value": 2, "label": "⚡ Lightning: +2 Projectiles", "desc": "Fire two extra lightning bolts", "rarity": "legendary"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "damage", "value": 2.5, "label": "⚡ Lightning: +2.5 Damage", "desc": "More damage per bolt and chain", "rarity": "common"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "damage", "value": 5, "label": "⚡ Lightning: +5 Damage", "desc": "Major damage increase", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "damage", "value": 10, "label": "⚡ Lightning: +10 Damage", "desc": "Devastating lightning damage", "rarity": "rare"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "attack_speed", "value": 0.10, "label": "⚡ Lightning: +10% Cast Speed", "desc": "Cast spells faster", "rarity": "common"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "attack_speed", "value": 0.20, "label": "⚡ Lightning: +20% Cast Speed", "desc": "Rapid spell casting", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "attack_speed", "value": 0.35, "label": "⚡ Lightning: +35% Cast Speed", "desc": "Lightning-fast spell casting", "rarity": "rare"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "chain_range", "value": 50, "label": "⚡ Lightning: +50 Chain Range", "desc": "Lightning chains jump further", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "lightning_spell", "key": "chain_range", "value": 100, "label": "⚡ Lightning: +100 Chain Range", "desc": "Massive chain jump distance", "rarity": "rare"},

	# ==================== LASER BEAM UPGRADES ====================
	{"type": "weapon", "weapon": "laser_beam", "key": "damage", "value": 1, "label": "🔵 Laser: +1 Damage", "desc": "More damage per tick", "rarity": "common"},
	{"type": "weapon", "weapon": "laser_beam", "key": "damage", "value": 2, "label": "🔵 Laser: +2 Damage", "desc": "Significant damage increase", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "laser_beam", "key": "damage", "value": 4, "label": "🔵 Laser: +4 Damage", "desc": "Devastating laser damage", "rarity": "rare"},
	{"type": "weapon", "weapon": "laser_beam", "key": "attack_speed", "value": 0.10, "label": "🔵 Laser: +10% Attack Speed", "desc": "Faster tick rate", "rarity": "common"},
	{"type": "weapon", "weapon": "laser_beam", "key": "attack_speed", "value": 0.20, "label": "🔵 Laser: +20% Attack Speed", "desc": "Rapid energy pulses", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "laser_beam", "key": "attack_speed", "value": 0.35, "label": "🔵 Laser: +35% Attack Speed", "desc": "Blazing fast laser", "rarity": "rare"},
	{"type": "weapon", "weapon": "laser_beam", "key": "distance", "value": 0.25, "label": "🔵 Laser: +25% Length", "desc": "Extended beam reach", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "laser_beam", "key": "distance", "value": 0.50, "label": "🔵 Laser: +50% Length", "desc": "Massive beam range", "rarity": "rare"},
	{"type": "weapon", "weapon": "laser_beam", "key": "laser_width", "value": 0.30, "label": "🔵 Laser: +30% Width", "desc": "Wider beam coverage", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "laser_beam", "key": "laser_width", "value": 0.60, "label": "🔵 Laser: +60% Width", "desc": "Thick beam hits more enemies", "rarity": "rare"},
	{"type": "weapon", "weapon": "laser_beam", "key": "cone_mode", "value": true, "label": "🔵 Laser: Cone Mode", "desc": "Laser widens into a cone (3x wider at tip)", "rarity": "legendary"},

	# ==================== SUMMON SPACESHIPS UPGRADES ====================
	{"type": "weapon", "weapon": "summon_spaceships", "key": "damage", "value": 5, "label": "🚀 Spaceships: +5 Damage", "desc": "Ships hit harder on impact", "rarity": "common"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "damage", "value": 10, "label": "🚀 Spaceships: +10 Damage", "desc": "Powerful ship impacts", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "damage", "value": 20, "label": "🚀 Spaceships: +20 Damage", "desc": "Devastating ship crashes", "rarity": "rare"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "projectiles", "value": 1, "label": "🚀 Spaceships: +1 Ship", "desc": "Summon one more ship per cast", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "projectiles", "value": 2, "label": "🚀 Spaceships: +2 Ships", "desc": "Summon two more ships per cast", "rarity": "rare"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "projectiles", "value": 3, "label": "🚀 Spaceships: +3 Ships", "desc": "Massive ship swarm", "rarity": "legendary"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "attack_speed", "value": 0.10, "label": "🚀 Spaceships: +10% Spawn Rate", "desc": "Summon ships more frequently", "rarity": "common"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "attack_speed", "value": 0.20, "label": "🚀 Spaceships: +20% Spawn Rate", "desc": "Rapid ship deployment", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "attack_speed", "value": 0.35, "label": "🚀 Spaceships: +35% Spawn Rate", "desc": "Constant ship stream", "rarity": "rare"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "speed_mult", "value": 0.20, "label": "🚀 Spaceships: +20% Ship Speed", "desc": "Faster ship movement", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "speed_mult", "value": 0.40, "label": "🚀 Spaceships: +40% Ship Speed", "desc": "Lightning-fast ships", "rarity": "rare"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "size_mult", "value": 0.20, "label": "🚀 Spaceships: +20% Ship Size", "desc": "Larger ships, bigger hitbox", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "size_mult", "value": 0.40, "label": "🚀 Spaceships: +40% Ship Size", "desc": "Massive ships", "rarity": "rare"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "pierce", "value": 1, "label": "🚀 Spaceships: +1 Pierce", "desc": "Ships can hit 2 enemies before despawning", "rarity": "rare"},
	{"type": "weapon", "weapon": "summon_spaceships", "key": "pierce", "value": 2, "label": "🚀 Spaceships: +2 Pierce", "desc": "Ships can hit 3 enemies before despawning", "rarity": "legendary"},

	# ==================== ACID POOL UPGRADES ====================
	{"type": "weapon", "weapon": "acid_pool", "key": "damage", "value": 2, "label": "☣️ Acid Pool: +2 Damage/tick", "desc": "Stronger acid damage", "rarity": "common"},
	{"type": "weapon", "weapon": "acid_pool", "key": "damage", "value": 5, "label": "☣️ Acid Pool: +5 Damage/tick", "desc": "Potent acid damage", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "acid_pool", "key": "damage", "value": 10, "label": "☣️ Acid Pool: +10 Damage/tick", "desc": "Devastating acid damage", "rarity": "rare"},
	{"type": "weapon", "weapon": "acid_pool", "key": "duration", "value": 0.5, "label": "☣️ Acid Pool: +0.5s Duration", "desc": "Pools last longer", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "acid_pool", "key": "duration", "value": 1.0, "label": "☣️ Acid Pool: +1.0s Duration", "desc": "Long-lasting acid pools", "rarity": "rare"},
	{"type": "weapon", "weapon": "acid_pool", "key": "aoe", "value": 0.25, "label": "☣️ Acid Pool: +25% Radius", "desc": "Larger pool area", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "acid_pool", "key": "aoe", "value": 0.50, "label": "☣️ Acid Pool: +50% Radius", "desc": "Massive pool coverage", "rarity": "rare"},
	{"type": "weapon", "weapon": "acid_pool", "key": "tick_rate", "value": -0.1, "label": "☣️ Acid Pool: -0.1s Tick Rate", "desc": "Damage ticks 25% faster", "rarity": "uncommon"},
	{"type": "weapon", "weapon": "acid_pool", "key": "tick_rate", "value": -0.2, "label": "☣️ Acid Pool: -0.2s Tick Rate", "desc": "Damage ticks 50% faster", "rarity": "rare"},
	{"type": "weapon", "weapon": "acid_pool", "key": "attack_speed", "value": 0.10, "label": "☣️ Acid Pool: +10% Spawn Rate", "desc": "Spawn pools more frequently", "rarity": "common"},
	{"type": "weapon", "weapon": "acid_pool", "key": "attack_speed", "value": 0.20, "label": "☣️ Acid Pool: +20% Spawn Rate", "desc": "Rapid pool deployment", "rarity": "uncommon"},
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

	# Filter out banished options
	if banished_options_list.size() > 0:
		var filtered_pool = []
		for opt in available_pool:
			var is_banished = false
			for banished_opt in banished_options_list:
				if opt.label == banished_opt.label:
					is_banished = true
					break
			if not is_banished:
				filtered_pool.append(opt)
		available_pool = filtered_pool
		print("🚫 Filtered out %d banished options" % (banished_options_list.size()))

	# If player has 1 weapon and isn't at max capacity, make weapon unlocks COMMON rarity to appear often
	if player:
		var current_weapon_count = player.player_stats.current_weapons.size()
		var max_weapon_slots = player.player_stats.max_weapon_slots

		if current_weapon_count == 1 and current_weapon_count < max_weapon_slots:
			for opt in upgrade_options:
				if opt.type == "unlock" and not player.player_stats.current_weapons.has(opt.weapon):
					# Check character-specific signature weapons before offering
					# Skip Energy Sword if Sword Maiden not unlocked or player is Sword Maiden
					if opt.weapon == "sword":
						if not SaveManager.is_swordmaiden_unlocked():
							continue
						if player.player_stats.character_type == "swordmaiden":
							continue

					# Skip Lightning Spell if Alien Monk not unlocked or player is Alien Monk
					if opt.weapon == "lightning_spell":
						if not SaveManager.is_alien_monk_unlocked():
							continue
						if player.player_stats.character_type == "alien_monk":
							continue

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

	# Store selected options for banish/skip functionality
	current_upgrade_options = selected.duplicate()

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

	# Add Banish/Skip utility buttons if player has purchased them
	add_banish_skip_buttons()

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

	# Check if player is at max weapon capacity
	var at_max_weapons = false
	if player:
		var current_weapon_count = player.player_stats.current_weapons.size()
		var max_weapon_slots = player.player_stats.max_weapon_slots
		at_max_weapons = (current_weapon_count >= max_weapon_slots)

	for opt in upgrade_options:
		# Check if this is a weapon unlock
		if opt.type == "unlock":
			# Don't offer weapon unlocks if player is at max capacity
			if at_max_weapons:
				continue

			# Check character-specific signature weapons
			# Energy Sword: Only available if Sword Maiden is unlocked and player is not Sword Maiden
			if opt.weapon == "sword":
				if not SaveManager.is_swordmaiden_unlocked():
					continue
				if player and player.player_stats.character_type == "swordmaiden":
					continue

			# Lightning Spell: Only available if Alien Monk is unlocked and player is not Alien Monk
			if opt.weapon == "lightning_spell":
				if not SaveManager.is_alien_monk_unlocked():
					continue
				if player and player.player_stats.character_type == "alien_monk":
					continue

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

func add_banish_skip_buttons():
	# Add separator before utility buttons
	if banish_uses_remaining > 0 or skip_uses_remaining > 0:
		var separator = HSeparator.new()
		button_container.add_child(separator)

	# Add banish buttons (one for each upgrade option)
	if banish_uses_remaining > 0:
		var banish_label = Label.new()
		banish_label.text = "🚫 BANISH OPTIONS (Remove from appearing again) - %d uses left" % banish_uses_remaining
		banish_label.add_theme_font_size_override("font_size", 16)
		banish_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3, 1))
		banish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_container.add_child(banish_label)

		# Create a banish button for each upgrade option
		for i in range(current_upgrade_options.size()):
			var opt = current_upgrade_options[i]
			var banish_btn = Button.new()
			banish_btn.text = "🚫 Banish: " + opt.label.replace("🔫 ", "").replace("⚔️ ", "").replace("⚡ ", "").replace("💣 ", "").replace("☢️ ", "").replace("🎯 ", "").replace("💥 ", "")
			banish_btn.tooltip_text = "Permanently remove this option from appearing again this run"
			banish_btn.custom_minimum_size = Vector2(400, 50)
			banish_btn.add_theme_font_size_override("font_size", 16)
			banish_btn.add_theme_color_override("font_color", Color(1, 0.5, 0.3, 1))
			banish_btn.pressed.connect(_on_banish_pressed.bind(opt))
			button_container.add_child(banish_btn)

	# Add skip button
	if skip_uses_remaining > 0:
		var skip_label = Label.new()
		skip_label.text = "⏭️ SKIP LEVEL-UP (Get 25%% XP refund) - %d uses left" % skip_uses_remaining
		skip_label.add_theme_font_size_override("font_size", 16)
		skip_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1, 1))
		skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_container.add_child(skip_label)

		var skip_btn = Button.new()
		skip_btn.text = "⏭️ Skip Level-Up (Refund 25% XP)"
		skip_btn.tooltip_text = "Decline all upgrades and get 25% of required XP refunded"
		skip_btn.custom_minimum_size = Vector2(400, 60)
		skip_btn.add_theme_font_size_override("font_size", 18)
		skip_btn.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
		skip_btn.pressed.connect(_on_skip_pressed)
		button_container.add_child(skip_btn)

func _on_banish_pressed(option: Dictionary):
	print("🚫 Banishing option: %s" % option.label)
	option_banished.emit(option)
	# Screen will be closed by main_game after handling banish

func _on_skip_pressed():
	print("⏭️ Skipping level-up")
	option_skipped.emit()
	# Screen will be closed by main_game after handling skip
	
	# Remove self from scene
	queue_free()
