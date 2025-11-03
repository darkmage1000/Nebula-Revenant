# mob.gd – FIXED: 20 HP = 2 PISTOL SHOTS TO KILL
extends CharacterBody2D

signal died

const XP_VIAL_SCENE = preload("res://experience_vial.tscn")
const FLOATING_DMG_SCENE = preload("res://FloatingDmg.tscn")
const POISON_COLOR = Color(0.0, 0.8, 0.2)
const AURA_COLOR = Color(0.1, 0.6, 1.0)
const CRIT_COLOR = Color(1.0, 0.5, 0.0)
const WEAPON_COLOR = Color(1.0, 1.0, 0.0)

# BALANCED BASE STATS - 2 shots to kill with starting pistol (12 damage)
var speed = randf_range(200, 300)
var health: float = 20.0        # Perfect for 2 pistol shots
var max_health: float = 20.0
var xp_value: int = 10

var active_dots: Dictionary = {}

@onready var player = get_node("/root/MainGame/Player")

func _ready():
	add_to_group("mob")  # Important for grenades to find enemies!
	max_health = health

func _physics_process(delta):
	if not is_instance_valid(player):
		return
		
	var direction = global_position.direction_to(player.global_position)
	direction += Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	
	velocity = direction.normalized() * speed
	move_and_slide()
	
	_process_dots(delta)

func _process_dots(delta):
	var dots_to_remove = []
	
	for source_key in active_dots:
		var dot_data = active_dots[source_key]
		dot_data.tick_timer += delta
		
		take_damage(dot_data.damage_per_sec * delta, true)
		
		if dot_data.tick_timer >= 1.0:
			show_damage_number(dot_data.damage_per_sec, dot_data.color)
			
			if dot_data.ticks_remaining > 0:
				dot_data.ticks_remaining -= 1
				if dot_data.ticks_remaining == 0:
					dots_to_remove.append(source_key)
			dot_data.tick_timer = 0.0
	
	for key in dots_to_remove:
		active_dots.erase(key)

func take_damage(amount: float, is_dot: bool = false, is_crit: bool = false):
	health -= amount 
	
	if not is_dot:
		var color = WEAPON_COLOR
		if is_crit:
			color = CRIT_COLOR
		show_damage_number(amount, color)
	
	if health <= 0:
		died.emit()
		
		var vial = XP_VIAL_SCENE.instantiate()
		vial.global_position = global_position
		vial.value = xp_value
		get_parent().add_child(vial)
		
		queue_free()

func start_dot(source_key: String, damage_per_sec: float, num_ticks: int, color: Color):
	if damage_per_sec <= 0: return
	
	if active_dots.has(source_key):
		active_dots[source_key].ticks_remaining += num_ticks
	else:
		active_dots[source_key] = {
			"damage_per_sec": damage_per_sec,
			"ticks_remaining": num_ticks,
			"tick_timer": 0.0,
			"color": color
		}

func stop_dot(source_key: String):
	active_dots.erase(source_key)

func show_damage_number(amount: float, color: Color):
	if not FLOATING_DMG_SCENE:
		return
		
	var dmg = FLOATING_DMG_SCENE.instantiate()
	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if ui_layer:
		ui_layer.add_child(dmg)
	else:
		get_parent().add_child(dmg)
	
	dmg.global_position = global_position
	if dmg.has_method("set_damage_text"):
		dmg.set_damage_text(amount, color)

func apply_knockback(knockback_amount: float, source_position: Vector2):
	if knockback_amount <= 0.0:
		return
	
	var direction = global_position.direction_to(source_position).normalized()
	const KNOCKBACK_PUSH_VELOCITY = 1500.0
	velocity = direction * -1.0 * (knockback_amount / 50.0) * KNOCKBACK_PUSH_VELOCITY
