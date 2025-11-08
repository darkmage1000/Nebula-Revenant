# Powerup.gd - Collectible powerups with proper sprites
extends Area2D

@export var powerup_type: String = "magnet"  # magnet, nuke, attack_speed, invincible

var time: float = 0.0
var start_y: float = 0.0
var collected: bool = false

# Sprite mapping
var sprite_map = {
	"magnet": "res://magnet.png",
	"nuke": "res://grenade.png",  # Use grenade for nuke
	"attack_speed": "res://rapidfire.png",
	"invincible": "res://gem.png"  # Yellow gem for invincible
}

# Color mapping for glow effects
var color_map = {
	"magnet": Color(0, 1, 1, 1),          # Cyan
	"nuke": Color(1, 0.5, 0, 1),          # Orange
	"attack_speed": Color(1, 0, 1, 1),    # Magenta
	"invincible": Color(1, 1, 0, 1)       # Yellow
}

@onready var sprite = $Sprite2D
@onready var glow = $Glow

func _ready():
	add_to_group("powerup")
	start_y = global_position.y

	# Set sprite based on powerup type
	var sprite_path = sprite_map.get(powerup_type, "res://gem.png")
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
		glow.texture = load(sprite_path)
	else:
		# Fallback to gem if sprite doesn't exist
		sprite.texture = load("res://gem.png")
		glow.texture = load("res://gem.png")

	# Set color
	var color = color_map.get(powerup_type, Color.WHITE)
	sprite.modulate = color
	glow.modulate = Color(color.r, color.g, color.b, 0.5)

	# Pulse animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5)

	# Glow pulse
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(glow, "scale", Vector2(1.5, 1.5), 0.8)
	glow_tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.8)

func _physics_process(delta):
	# Float up and down
	time += delta * 2.0
	global_position.y = start_y + sin(time) * 15.0

func _on_area_entered(area):
	if not collected and area.get_parent().is_in_group("player_group"):
		collect(area.get_parent())

func _on_body_entered(body):
	if not collected and body.is_in_group("player_group"):
		collect(body)

func collect(player):
	if collected:
		return

	collected = true

	if player.has_method("pickup_powerup"):
		player.pickup_powerup(self)

	# Sparkle effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
