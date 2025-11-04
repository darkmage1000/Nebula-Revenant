# SpaceBackground.gd - Static space background (no animations)
extends Node2D

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
	var screen_size = get_viewport_rect().size
	
	# Fewer, dimmer stars for darker atmosphere
	for layer in range(3):
		var num_stars = 60 - (layer * 15)  # Fewer stars overall
		for i in range(num_stars):
			var star = {
				"pos": Vector2(randf() * screen_size.x * 1.5, randf() * screen_size.y * 1.5),
				"size": randf_range(0.5, 2.0 - layer * 0.3),
				"brightness": randf_range(0.3, 0.7)  # Dimmer stars
			}
			star_layers[layer].append(star)

var static_nebula_positions: Array = []

func generate_static_nebula():
	var screen_size = get_viewport_rect().size
	
	# Generate fixed nebula cloud positions
	var num_clouds = 4
	for i in range(num_clouds):
		var cloud_data = {
			"center": Vector2(
				(i * screen_size.x / num_clouds) + randf_range(-100, 100),
				screen_size.y / 2 + randf_range(-200, 200)
			),
			"color": nebula_colors[i % nebula_colors.size()]
		}
		static_nebula_positions.append(cloud_data)

func _draw():
	var screen_size = get_viewport_rect().size
	
	# Draw very dark space background
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.01, 0.01, 0.05))
	
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
