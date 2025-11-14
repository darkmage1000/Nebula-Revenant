# ItemUI.gd – BEAUTIFUL LOOT DISPLAY
extends Control

var item_data: Dictionary = {}
var tier: String = "yellow"

@onready var panel = $Panel
@onready var tier_label = $Panel/TierLabel
@onready var item_name_label = $Panel/ItemName
@onready var description_label = $Panel/Description
@onready var icon = $Panel/Icon
@onready var take_button = $Panel/TakeButton

func _ready():
	# Set process mode to always so it works while paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	take_button.pressed.connect(_on_take_pressed)

	# Set up UI based on tier
	update_ui()

func update_ui():
	# Tier colors
	var tier_colors = {
		"yellow": {"color": Color(1.0, 0.9, 0.3), "name": "COMMON"},
		"blue": {"color": Color(0.3, 0.6, 1.0), "name": "UNCOMMON"},
		"green": {"color": Color(0.2, 1.0, 0.3), "name": "RARE"},
		"purple": {"color": Color(0.8, 0.3, 1.0), "name": "LEGENDARY"}
	}
	
	var tier_info = tier_colors.get(tier, tier_colors["yellow"])
	
	# Update labels
	tier_label.text = tier_info.name
	tier_label.modulate = tier_info.color
	
	item_name_label.text = item_data.get("name", "Unknown Item")
	item_name_label.modulate = tier_info.color
	
	description_label.text = item_data.get("description", "")
	
	# Color the icon
	if icon:
		icon.modulate = tier_info.color
	
	# Color the panel border
	panel.modulate = Color(1.0, 1.0, 1.0, 0.95)
	
	# Animate entrance
	panel.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func set_item(data: Dictionary, item_tier: String):
	item_data = data
	tier = item_tier

func _on_take_pressed():
	# Animate exit
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func(): queue_free())
