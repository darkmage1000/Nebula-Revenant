# Minimap.gd - Shows player position on the large map
extends Control

var player: CharacterBody2D = null
var main_game: Node2D = null

# Map constants (must match main_game.gd)
const MAP_WIDTH = 70000.0
const MAP_HEIGHT = 70000.0

# Minimap settings
const MINIMAP_SIZE = Vector2(200, 120)  # Minimap dimensions
const MINIMAP_SCALE = MINIMAP_SIZE.x / MAP_WIDTH  # Scale factor

@onready var minimap_rect: ColorRect = null

func _ready():
	# Create minimap background
	minimap_rect = ColorRect.new()
	minimap_rect.size = MINIMAP_SIZE
	# BOTTOM LEFT CORNER (was top-left)
	var viewport_size = get_viewport_rect().size
	minimap_rect.position = Vector2(10, viewport_size.y - MINIMAP_SIZE.y - 10)
	minimap_rect.color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	add_child(minimap_rect)
	
	# Set up for drawing
	set_process(true)

func _process(_delta):
	queue_redraw()

func _draw():
	if not is_instance_valid(player):
		return
	
	# Minimap position (BOTTOM-LEFT corner with padding)
	var viewport_size = get_viewport_rect().size
	var minimap_pos = Vector2(10, viewport_size.y - MINIMAP_SIZE.y - 10)
	
	# Draw minimap border
	draw_rect(Rect2(minimap_pos, MINIMAP_SIZE), Color(0.2, 0.2, 0.3, 0.9), false, 2.0)
	
	# Draw map boundaries
	draw_rect(Rect2(minimap_pos + Vector2(2, 2), MINIMAP_SIZE - Vector2(4, 4)), Color(0.1, 0.1, 0.15, 0.8), true)
	
	# Calculate player position on minimap
	var player_map_pos = minimap_pos + Vector2(
		(player.global_position.x / MAP_WIDTH) * MINIMAP_SIZE.x,
		(player.global_position.y / MAP_HEIGHT) * MINIMAP_SIZE.y
	)
	
	# Draw player dot (pulsing effect)
	var pulse = 0.7 + sin(Time.get_ticks_msec() * 0.005) * 0.3
	draw_circle(player_map_pos, 4, Color(0, 1, 0, pulse))  # Green pulsing dot
	draw_circle(player_map_pos, 2, Color(1, 1, 1, 1))  # White center
	
	# Draw nearby enemies on minimap
	if is_instance_valid(main_game):
		var enemies = main_game.get_tree().get_nodes_in_group("mob")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy is Node2D:
				var dist = player.global_position.distance_to(enemy.global_position)
				if dist < 1500:  # Only show enemies within 1500 units
					var enemy_map_pos = minimap_pos + Vector2(
						(enemy.global_position.x / MAP_WIDTH) * MINIMAP_SIZE.x,
						(enemy.global_position.y / MAP_HEIGHT) * MINIMAP_SIZE.y
					)
					
					# Color based on enemy type
					var enemy_color = Color(1, 0, 0, 0.8)  # Red for normal
					if enemy.is_in_group("boss"):
						enemy_color = Color(1, 0.5, 0, 1)  # Orange for boss
					elif enemy.is_in_group("elite"):
						enemy_color = Color(1, 1, 0, 0.9)  # Yellow for elite
					
					draw_circle(enemy_map_pos, 2, enemy_color)
	
	# Draw corner labels
	var label_color = Color(0.5, 0.5, 0.6, 0.9)
	var font_size = 10
	
	# Player coordinates (ABOVE minimap now since it's at bottom)
	var coord_text = "Pos: (%.0f, %.0f)" % [player.global_position.x, player.global_position.y]
	draw_string(ThemeDB.fallback_font, minimap_pos + Vector2(5, -5), 
		coord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
