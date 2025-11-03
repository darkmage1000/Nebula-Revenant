extends Node2D

@export var mob_scene: PackedScene = preload("res://mob.tscn")
@export var spawn_rate: float = 1.5  # Mobs per second

var timer: float = 0.0

func _process(delta):
	timer += delta
	if timer >= spawn_rate:
		timer = 0.0
		spawn_mob()

func spawn_mob():
	var mob = mob_scene.instantiate()
	var screen_size = get_viewport_rect().size
	mob.global_position = Vector2(
		randf_range(100, screen_size.x - 100),
		randf_range(100, screen_size.y - 100)
	)
	get_parent().add_child(mob)
