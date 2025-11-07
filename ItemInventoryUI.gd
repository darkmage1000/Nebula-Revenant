# ItemInventoryUI.gd - Shows collected chest items
extends Control

var main_game: Node2D = null
var last_item_count: int = 0  # Track when to update

@onready var items_container: VBoxContainer = null

# Tier colors
var tier_colors = {
	"yellow": Color(1.0, 0.9, 0.3),
	"blue": Color(0.3, 0.6, 1.0),
	"green": Color(0.2, 1.0, 0.3),
	"purple": Color(0.8, 0.3, 1.0)
}

func _ready():
	# Create background panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	add_child(panel)

	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.4, 1)
	panel.add_theme_stylebox_override("panel", style)

	# Create container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	items_container = VBoxContainer.new()
	items_container.add_theme_constant_override("separation", 3)
	margin.add_child(items_container)

	# Title
	var title = Label.new()
	title.text = "Items"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	items_container.add_child(title)

	var separator = HSeparator.new()
	items_container.add_child(separator)

	# Initial display
	update_items()

func _process(_delta):
	if not is_instance_valid(main_game):
		return

	# Only update when item count changes (not every frame!)
	if "items_collected" in main_game:
		var current_count = main_game.items_collected.size()
		if current_count != last_item_count:
			last_item_count = current_count
			update_items()

func update_items():
	if not main_game or not "items_collected" in main_game:
		return

	var items = main_game.items_collected

	# Clear old items (keep title and separator)
	while items_container.get_child_count() > 2:
		items_container.get_child(2).queue_free()

	# Show "No items" if empty
	if items.size() == 0:
		var no_items = Label.new()
		no_items.text = "No items yet"
		no_items.add_theme_font_size_override("font_size", 10)
		no_items.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		items_container.add_child(no_items)
		return

	# Show each item as colored box
	for item in items:
		var item_box = HBoxContainer.new()
		item_box.add_theme_constant_override("separation", 5)

		# Colored square indicator
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(12, 12)
		color_rect.color = tier_colors.get(item.tier, Color.WHITE)
		item_box.add_child(color_rect)

		# Item name
		var name_label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", tier_colors.get(item.tier, Color.WHITE))
		name_label.custom_minimum_size.x = 175
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_box.add_child(name_label)

		items_container.add_child(item_box)
