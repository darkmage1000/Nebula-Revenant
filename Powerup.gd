# Powerup.gd - Collectible powerups with proper sprites
extends Area2D

@export var powerup_type: String = "magnet"  # magnet, nuke, attack_speed, invincible

var time: float = 0.0
var start_y: float = 0.0
var collected: bool = false

# Magnetic pull settings
var being_pulled: bool = false
var pull_speed: float = 400.0
var player_ref: Node2D = null

# Sprite mapping
var sprite_map = {
	"magnet": "res://magnet.png",
	"nuke": "res://nuke.png",  # NEW: Using nuke sprite
	"attack_speed": "res://rapidfire.png",
	"invincible": "res://invincible.png"  # Custom invincible sprite
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

	print("🎮 Powerup _ready() called")
	print("   Type: ", powerup_type)
	print("   Position: ", global_position)

	# Set sprite based on powerup type
	var sprite_path = sprite_map.get(powerup_type, "res://gem.png")
	print("   Sprite path: ", sprite_path)
	print("   File exists: ", ResourceLoader.exists(sprite_path))

	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		sprite.texture = texture
		glow.texture = texture
		print("   ✅ Sprite loaded: ", texture)
	else:
		# Fallback to gem if sprite doesn't exist
		sprite.texture = load("res://gem.png")
		glow.texture = load("res://gem.png")
		print("   ⚠️ Using fallback gem.png")

	# Set color
	var color = color_map.get(powerup_type, Color.WHITE)
	sprite.modulate = color
	glow.modulate = Color(color.r, color.g, color.b, 0.5)
	print("   Color: ", color)

	# Scale down invincible powerup specifically (gem.png is larger than other sprites)
	# Adjust pulse animation accordingly
	var sprite_scale_min = Vector2(0.6, 0.6)
	var sprite_scale_max = Vector2(0.72, 0.72)
	var glow_scale_min = Vector2(0.8, 0.8)
	var glow_scale_max = Vector2(1.0, 1.0)

	if powerup_type == "invincible":
		sprite.scale = Vector2(0.4, 0.4)
		glow.scale = Vector2(0.6, 0.6)
		sprite_scale_min = Vector2(0.4, 0.4)
		sprite_scale_max = Vector2(0.48, 0.48)
		glow_scale_min = Vector2(0.6, 0.6)
		glow_scale_max = Vector2(0.7, 0.7)

	# Pulse animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", sprite_scale_max, 0.5)
	tween.tween_property(sprite, "scale", sprite_scale_min, 0.5)

	# Glow pulse
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(glow, "scale", glow_scale_max, 0.8)
	glow_tween.tween_property(glow, "scale", glow_scale_min, 0.8)

func _physics_process(delta):
	if being_pulled and is_instance_valid(player_ref):
		# Move towards player when being pulled by magnet
		var direction = global_position.direction_to(player_ref.global_position)
		global_position += direction * pull_speed * delta

		# Check if close enough to collect
		if global_position.distance_to(player_ref.global_position) < 30.0:
			collect(player_ref)
	else:
		# Float up and down when not being pulled
		time += delta * 2.0
		global_position.y = start_y + sin(time) * 15.0

func _on_area_entered(area):
	if not collected and area.get_parent().is_in_group("player_group"):
		collect(area.get_parent())

func _on_body_entered(body):
	if not collected and body.is_in_group("player_group"):
		collect(body)

func start_pull(player: Node2D):
	if not being_pulled:
		being_pulled = true
		player_ref = player
		# Visual effect when pull starts
		modulate = Color(1.2, 1.2, 1.2)

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
