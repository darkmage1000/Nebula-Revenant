extends Label

const FLOAT_SPEED = 100.0
const LIFETIME = 0.8 # Seconds until disappearance

var time_elapsed: float = 0.0

func _ready():
	set_process(true)
	z_index = 200 # Should draw over everything
	
	# Ensure the text is centered for better visual effect
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# Function called to set the text and color (accepts both numbers and strings)
func set_damage_text(amount, color_override: Color = Color(1.0, 1.0, 0.0)):
	# Handle both float (damage) and String (powerup text)
	if amount is float or amount is int:
		text = str(round(amount))
	else:
		text = str(amount)

	# Set color based on override (defaulting to yellow)
	modulate = color_override
	
func _process(delta: float):
	time_elapsed += delta
	
	# Move the number upward
	global_position.y -= FLOAT_SPEED * delta
	
	# Fade the number out 
	# over time
	var alpha = 1.0 - (time_elapsed / LIFETIME)
	
	# Clamp alpha to ensure it doesn't go below 0
	modulate.a = clampf(alpha, 0.0, 1.0)
	
	if time_elapsed >= LIFETIME:
		queue_free()
