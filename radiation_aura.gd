# radiation_aura.gd – FULL: FIXED 0 DAMAGE + CRIT + BURN + POISON + AOE
extends Area2D

var player: CharacterBody2D = null
var stats: Dictionary = {}
var visual_radius: float = 0.0

var _shape: CollisionShape2D = null
var overlapping_mobs: Dictionary = {}
var aura_key: String = ""
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.25  # FASTER! Was 0.5, now 0.25 (4 ticks/sec instead of 2)
const FLOATING_DMG_SCENE = preload("res://FloatingDmg.tscn")

func _ready() -> void:
	add_to_group("weapon")
	aura_key = "aura_" + str(get_instance_id())
	collision_mask = 2
	set_physics_process(true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_shape = $CollisionShape2D

func _exit_tree() -> void:
	for mob in overlapping_mobs.values():
		if is_instance_valid(mob) and mob.has_method("stop_dot"):
			mob.stop_dot(aura_key)

func _physics_process(delta: float) -> void:
	queue_redraw()
	_tick_damage(delta)

func _tick_damage(delta: float) -> void:
	if not is_instance_valid(player) or stats.is_empty() or not stats.has("damage") or not stats.has("attack_speed"):
		return
	
	tick_timer += delta
	if tick_timer < TICK_INTERVAL:
		return
	tick_timer = 0.0
	
	var base_dps = stats.damage * stats.attack_speed
	var final_dps = base_dps * player.player_stats.damage_mult
	var tick_damage = final_dps * TICK_INTERVAL
	
	for mob_id in overlapping_mobs:
		var mob = overlapping_mobs[mob_id]
		if is_instance_valid(mob):
			var is_crit = false
			var dmg = tick_damage
			if randf() < player.player_stats.crit_chance:
				is_crit = true
				dmg *= player.player_stats.crit_damage
			
			_show_blue_damage(mob, dmg)
			mob.take_damage(dmg, false, is_crit)
			
			# LIFESTEAL
			player.report_weapon_damage("aura", dmg)
			
			# POISON
			if stats.get("poison", false):
				var key = aura_key + "_poison_" + str(mob_id)
				mob.start_dot(key, stats.damage, 1, Color(0.0, 0.8, 0.2))
			
			# BURN + SLOW
			if stats.get("burn", false):
				var key = aura_key + "_burn_" + str(mob_id)
				mob.start_dot(key, stats.damage * 0.5, 1, Color(1.0, 0.3, 0.0))
				mob.active_dots[key]["is_burn"] = true

func _show_blue_damage(mob: Node2D, amount: float):
	var dmg = FLOATING_DMG_SCENE.instantiate()
	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if ui_layer:
		ui_layer.add_child(dmg)
		# Convert world position to screen position for CanvasLayer
		var viewport = get_viewport()
		if viewport:
			var canvas_transform = viewport.get_canvas_transform()
			var world_pos = mob.global_position + Vector2(0, -20)
			var screen_pos = canvas_transform * world_pos
			dmg.global_position = screen_pos
	else:
		get_parent().add_child(dmg)
		dmg.global_position = mob.global_position + Vector2(0, -20)

	if dmg.has_method("set_damage_text"):
		dmg.set_damage_text(amount, Color(0.1, 0.6, 1.0))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mob"):
		var id = body.get_instance_id()
		overlapping_mobs[id] = body

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mob"):
		var id = body.get_instance_id()
		overlapping_mobs.erase(id)
		if body.has_method("stop_dot"):
			body.stop_dot(aura_key)

func _draw() -> void:
	if visual_radius <= 0: return
	var t = Time.get_ticks_msec() * 0.001
	var pulse = 0.3 + 0.2 * sin(t * 4.0)
	var color = Color(0.1, 1.0, 0.1, pulse)
	draw_arc(Vector2.ZERO, visual_radius, 0, TAU, 128, color, 4.0, true)
	draw_circle(Vector2.ZERO, visual_radius * 0.9, Color(0.1, 1.0, 0.1, pulse * 0.4))

func set_player_ref(p: CharacterBody2D) -> void:
	player = p
	_update_size()

func set_stats(s: Dictionary) -> void:
	stats = s.duplicate()
	_update_size()

func _update_size() -> void:
	if not stats.has("aoe") or not is_instance_valid(player):
		return
	
	var r = stats.aoe * player.player_stats.aoe_mult
	if _shape and _shape.shape is CircleShape2D:
		_shape.shape.radius = r
	visual_radius = r
