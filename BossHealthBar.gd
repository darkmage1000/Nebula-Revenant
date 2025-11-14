# BossHealthBar.gd - Prominent boss health display
extends CanvasLayer

var boss_name: String = "OMEGA DRAGON"
var current_health: float = 0.0
var max_health: float = 1.0
var health_percentage: float = 1.0

# UI elements
var background_panel: ColorRect = null
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null
var name_label: Label = null
var hp_label: Label = null

# Animation
var display_health: float = 1.0
var health_tween: Tween = null

# Pulse effect when low HP
var pulse_timer: float = 0.0

func _ready():
	# Set to always process (visible during pause)
	process_mode = PROCESS_MODE_ALWAYS

	# Position at top center of screen
	layer = 100  # Render on top of everything

	create_ui()

func create_ui():
	# Get screen size
	var screen_size = get_viewport().get_visible_rect().size

	# Container
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	container.position = Vector2(0, 10)
	container.size = Vector2(screen_size.x, 60)
	add_child(container)

	# Background panel (semi-transparent black)
	background_panel = ColorRect.new()
	background_panel.color = Color(0, 0, 0, 0.7)
	background_panel.size = Vector2(600, 50)
	background_panel.position = Vector2((screen_size.x - 600) / 2, 0)
	container.add_child(background_panel)

	# Boss name label
	name_label = Label.new()
	name_label.text = boss_name
	name_label.position = Vector2(10, 5)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # Orange
	background_panel.add_child(name_label)

	# Health bar background (dark red)
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.3, 0, 0, 1)
	health_bar_bg.size = Vector2(580, 20)
	health_bar_bg.position = Vector2(10, 25)
	background_panel.add_child(health_bar_bg)

	# Health bar fill (bright red)
	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(1.0, 0.2, 0.1, 1)
	health_bar_fill.size = Vector2(580, 20)
	health_bar_fill.position = Vector2(0, 0)
	health_bar_bg.add_child(health_bar_fill)

	# HP text label
	hp_label = Label.new()
	hp_label.text = "100,000 / 100,000"
	hp_label.position = Vector2(200, -2)
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 2)
	health_bar_bg.add_child(hp_label)

func _process(delta):
	# Smooth health bar animation
	if display_health != health_percentage:
		display_health = lerp(display_health, health_percentage, delta * 5.0)

		# Update health bar width
		if health_bar_fill:
			health_bar_fill.size.x = 580 * display_health

	# Pulse effect when low HP (below 25%)
	if health_percentage < 0.25:
		pulse_timer += delta
		var pulse = sin(pulse_timer * 5.0) * 0.3 + 0.7

		if health_bar_fill:
			health_bar_fill.color = Color(1.0, 0.2, 0.1, pulse)

		if background_panel:
			var border_color = Color(1.0, 0.3, 0.0, pulse * 0.5)
			background_panel.material = null  # Reset material if needed

func update_health(current: float, maximum: float):
	current_health = max(0, current)
	max_health = max(1, maximum)
	health_percentage = current_health / max_health

	# Update HP text
	if hp_label:
		hp_label.text = "%s / %s" % [format_number(current_health), format_number(max_health)]

	# Smooth tween animation
	if health_tween:
		health_tween.kill()

	health_tween = create_tween()
	health_tween.tween_property(self, "display_health", health_percentage, 0.3)

func format_number(num: float) -> String:
	# Format large numbers with commas
	var num_str = str(int(num))
	var result = ""
	var count = 0

	for i in range(num_str.length() - 1, -1, -1):
		result = num_str[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result

	return result

func set_boss_name(new_name: String):
	boss_name = new_name
	if name_label:
		name_label.text = boss_name
