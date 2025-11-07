# PowerupDisplay.gd - Shows active powerups with timers
extends Control

var powerup_type: String = ""
var powerup_name: String = ""
var time_remaining: float = 0.0
var powerup_color: Color = Color.WHITE

@onready var icon_rect: ColorRect = null
@onready var timer_label: Label = null
@onready var name_label: Label = null

func _ready():
	# Create colored icon box
	icon_rect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.color = powerup_color
	add_child(icon_rect)

	# Create timer label inside icon
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 16)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.add_child(timer_label)

	# Create name label below icon
	name_label = Label.new()
	name_label.text = powerup_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", powerup_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 42)
	name_label.custom_minimum_size = Vector2(40, 12)
	add_child(name_label)

func _process(delta):
	time_remaining -= delta

	if time_remaining <= 0:
		queue_free()
		return

	# Update timer display
	timer_label.text = "%d" % int(ceil(time_remaining))

	# Flash when almost done
	if time_remaining <= 3.0:
		var alpha = 0.5 + abs(sin(time_remaining * 5.0)) * 0.5
		modulate.a = alpha

func setup(type: String, duration: float):
	powerup_type = type
	time_remaining = duration

	# Set name and color based on type
	match type:
		"invincible":
			powerup_name = "Shield"
			powerup_color = Color(1, 1, 0, 0.9)
		"magnet":
			powerup_name = "Magnet"
			powerup_color = Color(0, 1, 1, 0.9)
		"attack_speed":
			powerup_name = "Rapid Fire"
			powerup_color = Color(1, 0, 1, 0.9)
		"nuke":
			powerup_name = "Nuke"
			powerup_color = Color(1, 0.5, 0, 0.9)
