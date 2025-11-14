# EvolutionMenu.gd - Weapon Evolution Selection UI
extends CanvasLayer

signal evolution_selected(weapon_key: String, evolution_id: String)
signal skip_pressed

var player: CharacterBody2D = null
var available_evolutions: Array = []  # Array of {weapon_key, evolution_id, data}
var has_paused: bool = false  # Track if we've paused yet
var frames_since_ready: int = 0  # Count frames to ensure rendering

@onready var title_label: Label = $FullScreenControl/TitleLabel
@onready var button_container: VBoxContainer = $FullScreenControl/CenterContainer/ButtonContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works during pause
	visible = true  # Ensure visible
	layer = 100  # CanvasLayer renders on top

	print("🎮 EvolutionMenu _ready() called")
	print("   title_label valid: %s" % is_instance_valid(title_label))
	print("   button_container valid: %s" % is_instance_valid(button_container))
	print("   visible: %s" % visible)
	print("   layer: %s" % layer)

	if not is_instance_valid(button_container):
		push_error("EvolutionMenu: button_container is null! Check EvolutionMenu.tscn structure")
		return

	# Populate UI after @onready variables are initialized
	if available_evolutions.size() > 0:
		populate_ui()

func _process(_delta):
	# Wait 2 frames after UI is populated before pausing
	# This ensures the UI is fully rendered and visible
	if not has_paused and available_evolutions.size() > 0:
		frames_since_ready += 1
		if frames_since_ready >= 2:
			print("⏸️ PAUSING GAME (after %d frames rendered)" % frames_since_ready)
			get_tree().paused = true
			has_paused = true
			print("   Game paused: %s" % get_tree().paused)

func set_available_evolutions(evolutions: Array):
	available_evolutions = evolutions
	frames_since_ready = 0  # Reset frame counter when evolutions are set

	# Only populate if _ready() has already been called
	if is_instance_valid(button_container):
		populate_ui()
		print("🔄 Frame counter reset, will pause in 2 frames")

func populate_ui():
	print("🎨 populate_ui() called with %d evolutions" % available_evolutions.size())

	# Safety check - ensure nodes are ready
	if not is_instance_valid(button_container):
		print("⚠️ ERROR: button_container is null in populate_ui!")
		return

	# Clear existing buttons
	print("🗑️ Clearing existing buttons...")
	for child in button_container.get_children():
		child.queue_free()

	# Set title
	if title_label:
		print("📝 Setting title...")
		title_label.text = "WEAPON EVOLUTION AVAILABLE!"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 48)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0, 1))

	# Create up to 3 evolution option cards
	var count = min(3, available_evolutions.size())
	print("🃏 Creating %d evolution cards..." % count)
	for i in range(count):
		var evo = available_evolutions[i]
		print("   Card %d: %s" % [i, evo])
		create_evolution_card(evo)

	# Add skip button
	print("⏭️ Adding skip button...")
	var skip_btn = Button.new()
	skip_btn.process_mode = Node.PROCESS_MODE_ALWAYS  # CRITICAL: Button works during pause
	skip_btn.text = "Skip Evolution"
	skip_btn.custom_minimum_size = Vector2(600, 70)
	skip_btn.add_theme_font_size_override("font_size", 24)
	skip_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure button receives mouse events
	skip_btn.focus_mode = Control.FOCUS_ALL  # Allow keyboard/gamepad focus
	skip_btn.pressed.connect(_on_skip_pressed)
	button_container.add_child(skip_btn)

	print("✅ populate_ui() complete! %d buttons in container" % button_container.get_child_count())

func create_evolution_card(evo: Dictionary):
	var weapon_key = evo.weapon_key
	var evolution_id = evo.evolution_id
	var data = evo.data

	# Get current weapon name
	var current_weapon_name = "Unknown"
	if player and player.weapon_data.has(weapon_key):
		current_weapon_name = player.weapon_data[weapon_key]["name"]

	# Create button
	var btn = Button.new()
	btn.process_mode = Node.PROCESS_MODE_ALWAYS  # CRITICAL: Button works during pause
	btn.text = "%s\n%s → %s\n%s" % [data.icon, current_weapon_name, data.name, data.desc]
	btn.custom_minimum_size = Vector2(700, 120)
	btn.add_theme_font_size_override("font_size", 22)
	btn.tooltip_text = data.desc
	btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure button receives mouse events
	btn.focus_mode = Control.FOCUS_ALL  # Allow keyboard/gamepad focus
	btn.pressed.connect(_on_evolution_pressed.bind(weapon_key, evolution_id))

	# Color based on evolution
	btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))

	button_container.add_child(btn)
	print("   ✅ Button created: %s" % data.name)

func _on_evolution_pressed(weapon_key: String, evolution_id: String):
	print("🎯 BUTTON PRESSED! Evolution selected: %s → %s" % [weapon_key, evolution_id])
	print("   Emitting evolution_selected signal...")
	evolution_selected.emit(weapon_key, evolution_id)
	print("   Signal emitted!")

func _on_skip_pressed():
	print("⏭️ SKIP BUTTON PRESSED!")
	print("   Emitting skip_pressed signal...")
	skip_pressed.emit()
	print("   Signal emitted!")
