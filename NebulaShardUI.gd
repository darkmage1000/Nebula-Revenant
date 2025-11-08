# NebulaShardUI.gd - Shows nebula shard counts (total permanent + run shards)
# Displays both total permanent shards and shards collected this run
extends Control

var save_manager: Node = null
var player: CharacterBody2D = null
var last_total_shards: int = -1
var last_run_shards: int = -1

var total_label: Label = null
var run_label: Label = null

func _ready():
	# Get SaveManager reference
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")

	# Create background panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	add_child(panel)

	# Style panel with nebula theme (dark purple/blue)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.2, 0.8)  # Dark purple
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.3, 0.8, 1)  # Purple border
	panel.add_theme_stylebox_override("panel", style)

	# Create container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Title with icon
	var title_box = HBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	vbox.add_child(title_box)

	# Nebula icon (diamond shape)
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(12, 12)
	icon.color = Color(0.6, 0.4, 1.0)  # Purple nebula color
	title_box.add_child(icon)

	var title = Label.new()
	title.text = "Nebula Shards"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0, 1))
	title_box.add_child(title)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	# Total shards (permanent)
	var total_box = HBoxContainer.new()
	total_box.add_theme_constant_override("separation", 4)
	vbox.add_child(total_box)

	var total_icon = ColorRect.new()
	total_icon.custom_minimum_size = Vector2(10, 10)
	total_icon.color = Color(1.0, 0.9, 0.3)  # Gold for permanent
	total_box.add_child(total_icon)

	total_label = Label.new()
	total_label.text = "Total: 0"
	total_label.add_theme_font_size_override("font_size", 12)
	total_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))
	total_box.add_child(total_label)

	# Run shards (this run only)
	var run_box = HBoxContainer.new()
	run_box.add_theme_constant_override("separation", 4)
	vbox.add_child(run_box)

	var run_icon = ColorRect.new()
	run_icon.custom_minimum_size = Vector2(10, 10)
	run_icon.color = Color(0.3, 0.8, 1.0)  # Cyan for run
	run_box.add_child(run_icon)

	run_label = Label.new()
	run_label.text = "This Run: 0"
	run_label.add_theme_font_size_override("font_size", 12)
	run_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1))
	run_box.add_child(run_label)

	# Initial update
	update_display()

func _process(_delta):
	update_display()

func update_display():
	if not is_instance_valid(save_manager):
		return

	# Get total shards from SaveManager
	var total_shards = save_manager.get_shards()

	# Get run shards from player
	var run_shards = 0
	if is_instance_valid(player) and "run_stats" in player:
		run_shards = player.run_stats.get("shards_collected", 0)

	# Only update if values changed (avoid unnecessary updates)
	if total_shards != last_total_shards:
		last_total_shards = total_shards
		total_label.text = "Total: %d" % total_shards

	if run_shards != last_run_shards:
		last_run_shards = run_shards
		run_label.text = "This Run: %d" % run_shards
