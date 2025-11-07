# game_state.gd - Global game state manager
# Add this as an autoload: Project > Project Settings > Autoload
extends Node

# Character selection
var selected_character: String = "ranger"  # Default

# Set the selected character
func set_character(char_type: String):
	selected_character = char_type
	print("🎮 Character selected: %s" % char_type)

# Get the selected character
func get_character() -> String:
	return selected_character
