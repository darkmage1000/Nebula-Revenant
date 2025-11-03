# GameHUD.gd – COMPLETE UI: TIMER + HEALTH + XP + LEVEL
extends CanvasLayer

# References set by main_game
var player: CharacterBody2D = null
var main_game: Node2D = null

# UI Elements
@onready var timer_label = $TimerLabel
@onready var health_bar = $HealthBar
@onready var health_label = $HealthBar/HealthLabel
@onready var xp_bar = $XPBar
@onready var level_label = $LevelLabel

func _ready():
	# Will be set by main_game
	pass

func _process(delta: float):
	if not is_instance_valid(player) or not is_instance_valid(main_game):
		return
	
	update_timer()
	update_health()
	update_xp()
	update_level()

# Update timer display (00:00 format)
func update_timer():
	var time = main_game.game_time
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Change color as time progresses
	if time >= 1500:  # 25+ min
		timer_label.modulate = Color(1.0, 0.3, 0.3)  # Red
	elif time >= 900:  # 15+ min
		timer_label.modulate = Color(1.0, 0.8, 0.3)  # Orange
	else:
		timer_label.modulate = Color(1.0, 1.0, 1.0)  # White

# Update health bar and label
func update_health():
	var current = player.player_stats.current_health
	var max_hp = player.player_stats.max_health
	
	health_bar.max_value = max_hp
	health_bar.value = current
	health_label.text = "%d / %d" % [int(current), int(max_hp)]
	
	# Color based on health percentage
	var health_percent = current / max_hp
	if health_percent > 0.6:
		health_bar.modulate = Color(0.2, 1.0, 0.2)  # Green
	elif health_percent > 0.3:
		health_bar.modulate = Color(1.0, 0.8, 0.2)  # Yellow
	else:
		health_bar.modulate = Color(1.0, 0.2, 0.2)  # Red

# Update XP bar
func update_xp():
	var current_xp = player.player_stats.current_xp
	var xp_needed = player.player_stats.xp_to_next_level
	
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp

# Update level display
func update_level():
	if not player:
		level_label.text = "Level ?"
		return
	level_label.text = "Level %d" % player.player_stats.level
