# SpaceBackground.gd - MASSIVE TILED space background for exploration
extends Node2D

# Map dimensions (matches main_game.gd)
const MAP_WIDTH = 70000.0
const MAP_HEIGHT = 70000.0

# Star layers for parallax effect
var star_layers: Array[Array] = [[], [], []]

# Darker, more menacing colors for nebula
var nebula_colors = [
	Color(0.15, 0.05, 0.2, 0.25),   # Dark purple
	Color(0.2, 0.05, 0.1, 0.2),     # Dark red
	Color(0.05, 0.1, 0.15, 0.2),    # Very dark blue
]

func _ready():
	generate_stars()
	generate_static_nebula()
	queue_redraw()

func generate_stars():
	# Generate stars across ENTIRE massive map
	for layer in range(3):
		var num_stars = 2000 - (layer * 500)  # Many more stars for massive map
		for i in range(num_stars):
			var star = {
				"pos": Vector2(randf() * MAP_WIDTH, randf() * MAP_HEIGHT),
				"size": randf_range(0.5, 2.0 - layer * 0.3),
				"brightness": randf_range(0.3, 0.7)  # Dimmer stars
			}
			star_layers[layer].append(star)

var static_nebula_positions: Array = []

func generate_static_nebula():
	# Generate nebula clouds scattered across the massive map
	var num_clouds = 100  # Many more clouds for massive map
	for i in range(num_clouds):
		var cloud_data = {
			"center": Vector2(
				randf() * MAP_WIDTH,
				randf() * MAP_HEIGHT
			),
			"color": nebula_colors[i % nebula_colors.size()]
		}
		static_nebula_positions.append(cloud_data)

func _draw():
	# Draw very dark space background covering entire map
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_WIDTH, MAP_HEIGHT)), Color(0.01, 0.01, 0.05))
	
	# Draw static nebula clouds
	draw_static_nebula()
	
	# Draw stars
	for layer_idx in range(3):
		for star in star_layers[layer_idx]:
			var brightness = star.brightness
			# Red tint to some stars for danger feel
			var color = Color(brightness * 0.9, brightness * 0.8, brightness * 0.9)
			if randf() < 0.2:  # 20% chance for red star
				color = Color(brightness, brightness * 0.3, brightness * 0.3)
			draw_circle(star.pos, star.size, color)

func draw_static_nebula():
	# Draw fixed nebula clouds (no animation)
	for cloud_data in static_nebula_positions:
		var cloud_center = cloud_data.center
		var color = cloud_data.color
		
		# Draw multiple circles to create cloud effect
		for j in range(10):
			var offset = Vector2(
				cos(j * PI / 5) * 300,
				sin(j * PI / 5) * 250
			)
			draw_circle(cloud_center + offset, 350, color)
