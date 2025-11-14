extends Area2D

# This value will be set by the mob that drops it
var value = 10

# Despawn timer variables
var lifetime: float = 0.0
const MAX_LIFETIME: float = 120.0  # 2 minutes in seconds
const WARNING_TIME: float = 10.0   # Start visual warning 10 seconds before despawn

func _process(delta: float):
	lifetime += delta

	# Despawn after max lifetime
	if lifetime >= MAX_LIFETIME:
		queue_free()
		return

	# Visual warning in the last 10 seconds - blinking effect
	if lifetime >= MAX_LIFETIME - WARNING_TIME:
		# Create a pulsing/blinking effect using sine wave
		# This creates a smooth fade in/out at 10Hz frequency
		modulate.a = 0.5 + 0.5 * sin(lifetime * 10.0)
