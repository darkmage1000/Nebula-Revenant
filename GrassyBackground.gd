# GrassyBackground.gd - Grassy field themed background with realistic grass texture
extends Node2D

# Map dimensions (matches main_game.gd and SpaceBackground.gd)
const MAP_WIDTH = 70000.0
const MAP_HEIGHT = 70000.0

# Base grass color - solid green background
var base_grass_color = Color(0.25, 0.55, 0.2, 1.0)  # Medium grass green

# Grass tuft colors for texture
var grass_tuft_colors = [
	Color(0.2, 0.5, 0.15, 1.0),   # Dark green
	Color(0.3, 0.6, 0.25, 1.0),   # Bright green
	Color(0.28, 0.58, 0.22, 1.0), # Medium green
	Color(0.22, 0.52, 0.18, 1.0), # Forest green
]

# Dirt patch colors
var dirt_colors = [
	Color(0.4, 0.3, 0.2, 1.0),   # Brown
	Color(0.45, 0.35, 0.25, 1.0), # Light brown
	Color(0.35, 0.25, 0.15, 1.0), # Dark brown
]

# Flower colors for visual variety
var flower_colors = [
	Color(1.0, 0.9, 0.2),  # Yellow
	Color(0.9, 0.3, 0.3),  # Red
	Color(0.8, 0.5, 1.0),  # Purple
	Color(1.0, 1.0, 1.0),  # White
]

# Static decorations
var grass_tufts: Array = []
var dirt_patches: Array = []
var flowers: Array = []
var rocks: Array = []

func _ready():
	generate_grass_field()
	queue_redraw()

func generate_grass_field():
	# Generate grass tufts for texture - MUCH DENSER grass for lush field
	var tuft_density = 8000  # Increased from 3000 - dense, lush grass field
	for i in range(tuft_density):
		var tuft = {
			"pos": Vector2(randf() * MAP_WIDTH, randf() * MAP_HEIGHT),
			"color": grass_tuft_colors[randi() % grass_tuft_colors.size()],
			"blades": randi_range(3, 7),  # Number of grass blades in this tuft
			"height": randf_range(15, 35)
		}
		grass_tufts.append(tuft)

	# Generate dirt patches - irregular shapes, not circles
	for i in range(150):
		var patch = {
			"pos": Vector2(randf() * MAP_WIDTH, randf() * MAP_HEIGHT),
			"color": dirt_colors[randi() % dirt_colors.size()],
			"points": generate_irregular_shape(randf_range(80, 150))
		}
		dirt_patches.append(patch)

	# Generate flowers scattered across the map - MANY MORE flowers for colorful field
	for i in range(1500):  # Increased from 400 - vibrant flower field
		var flower = {
			"pos": Vector2(randf() * MAP_WIDTH, randf() * MAP_HEIGHT),
			"color": flower_colors[randi() % flower_colors.size()],
			"size": randf_range(8, 15)
		}
		flowers.append(flower)

	# Generate rocks - irregular shapes
	for i in range(150):
		var rock = {
			"pos": Vector2(randf() * MAP_WIDTH, randf() * MAP_HEIGHT),
			"size": randf_range(25, 60),
			"points": generate_irregular_shape(randf_range(20, 40)),
			"color": Color(0.4, 0.4, 0.42)
		}
		rocks.append(rock)

func generate_irregular_shape(base_size: float) -> PackedVector2Array:
	# Generate an irregular polygon instead of a circle
	var points = PackedVector2Array()
	var num_points = randi_range(5, 8)

	for i in range(num_points):
		var angle = (i * TAU / num_points) + randf_range(-0.3, 0.3)
		var distance = base_size * randf_range(0.7, 1.3)
		points.append(Vector2(cos(angle), sin(angle)) * distance)

	return points

func _draw():
	# Draw solid base grass color (no gradient, solid green like a real field)
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_WIDTH, MAP_HEIGHT)), base_grass_color)

	# Draw dirt patches first (they're under the grass)
	for patch in dirt_patches:
		var transformed_points = PackedVector2Array()
		for point in patch.points:
			transformed_points.append(patch.pos + point)
		draw_colored_polygon(transformed_points, patch.color)

	# Draw rocks
	for rock in rocks:
		var transformed_points = PackedVector2Array()
		for point in rock.points:
			transformed_points.append(rock.pos + point)

		# Draw main rock
		draw_colored_polygon(transformed_points, rock.color)

		# Add highlight for 3D effect (smaller irregular shape)
		var highlight_points = PackedVector2Array()
		for point in rock.points:
			highlight_points.append(rock.pos + point * 0.4 + Vector2(-5, -5))
		draw_colored_polygon(highlight_points, Color(0.6, 0.6, 0.62))

	# Draw grass tufts - make them look like actual grass blades
	for tuft in grass_tufts:
		for blade in range(tuft.blades):
			var blade_angle = randf_range(-0.3, 0.3)  # Slight angle variation
			var blade_offset = Vector2(randf_range(-5, 5), 0)
			var blade_start = tuft.pos + blade_offset
			var blade_end = blade_start + Vector2(sin(blade_angle) * tuft.height, -tuft.height)

			# Draw grass blade as a thin line
			draw_line(blade_start, blade_end, tuft.color, 2.0, true)

	# Draw flowers
	for flower in flowers:
		# Draw flower petals (5 petals in a circle)
		for petal in range(5):
			var angle = (petal * TAU / 5.0)
			var petal_pos = flower.pos + Vector2(cos(angle), sin(angle)) * (flower.size * 0.5)
			draw_circle(petal_pos, flower.size * 0.4, flower.color)

		# Draw flower center
		draw_circle(flower.pos, flower.size * 0.3, Color(0.9, 0.8, 0.2))

		# Draw stem
		draw_line(flower.pos, flower.pos + Vector2(0, 12), Color(0.2, 0.5, 0.15), 2.0)
