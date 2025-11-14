# radiation_aura.gd – FULL: FIXED 0 DAMAGE + CRIT + BURN + POISON + AOE
extends Area2D

var player: CharacterBody2D = null
var stats: Dictionary = {}
var visual_radius: float = 0.0

# Evolution flags
var toxic_field: bool = false
var nuclear_pulse: bool = false

var _shape: CollisionShape2D = null
var overlapping_mobs: Dictionary = {}
var aura_key: String = ""
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.25  # FASTER! Was 0.5, now 0.25 (4 ticks/sec instead of 2)
const FLOATING_DMG_SCENE = preload("res://FloatingDmg.tscn")

# Nuclear Pulse timing
var pulse_timer: float = 0.0
const PULSE_INTERVAL: float = 3.0

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

	# NUCLEAR PULSE: Pulse every 3s
	if nuclear_pulse:
		pulse_timer += delta
		if pulse_timer >= PULSE_INTERVAL:
			pulse_timer = 0.0
			trigger_nuclear_pulse()

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
			# Skip damage tick if Nuclear Pulse (only pulse damages)
			if not nuclear_pulse:
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

			# TOXIC FIELD: Apply poison DOT + 30% slow
			if toxic_field:
				# Poison DOT (30% damage per second for 5 seconds)
				if mob.has_method("start_dot"):
					var key = aura_key + "_toxic_" + str(mob_id)
					mob.start_dot(key, tick_damage * 0.3, 5, Color(0.5, 1.0, 0.3))

				# 30% slow (70% speed)
				if mob.has_method("get") and mob.has_method("set"):
					var original_speed = mob.get("base_speed")
					if original_speed == null:
						original_speed = mob.get("speed")
						if original_speed != null:
							mob.set("base_speed", original_speed)

					if original_speed != null:
						mob.speed = original_speed * 0.7  # 30% slow

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
	# Detect mobs, asteroids, and flowers
	if body.is_in_group("mob") or body.is_in_group("asteroid") or body.is_in_group("flower"):
		var id = body.get_instance_id()
		overlapping_mobs[id] = body

func _on_body_exited(body: Node) -> void:
	# Remove mobs, asteroids, and flowers from tracking
	if body.is_in_group("mob") or body.is_in_group("asteroid") or body.is_in_group("flower"):
		var id = body.get_instance_id()
		overlapping_mobs.erase(id)
		if body.has_method("stop_dot"):
			body.stop_dot(aura_key)

		# TOXIC FIELD: Restore original speed
		if toxic_field and is_instance_valid(body):
			restore_enemy_speed(body)

func _draw() -> void:
	if visual_radius <= 0: return
	var t = Time.get_ticks_msec() * 0.001
	var pulse = 0.3 + 0.2 * sin(t * 4.0)

	# Color based on evolution
	var color: Color
	if toxic_field:
		color = Color(0.5, 1.0, 0.3, pulse)  # Bright lime green for toxic
	elif nuclear_pulse:
		color = Color(1.0, 0.5, 0.0, pulse)  # Orange for nuclear
	else:
		color = Color(0.1, 1.0, 0.1, pulse)  # Default green

	draw_arc(Vector2.ZERO, visual_radius, 0, TAU, 128, color, 4.0, true)
	draw_circle(Vector2.ZERO, visual_radius * 0.9, Color(color.r, color.g, color.b, pulse * 0.4))

func set_player_ref(p: CharacterBody2D) -> void:
	player = p
	_update_size()

func set_stats(s: Dictionary) -> void:
	stats = s.duplicate()
	toxic_field = stats.get("toxic_field", false)
	nuclear_pulse = stats.get("nuclear_pulse", false)
	_update_size()

func _update_size() -> void:
	if not stats.has("aoe") or not is_instance_valid(player):
		return

	# Apply both aoe_mult and attack_range_mult to radius
	var r = stats.aoe * player.player_stats.aoe_mult * player.player_stats.get("attack_range_mult", 1.0)

	# NUCLEAR PULSE: +100px radius
	if nuclear_pulse:
		r += 100.0

	if _shape and _shape.shape is CircleShape2D:
		_shape.shape.radius = r
	visual_radius = r

func trigger_nuclear_pulse():
	# NUCLEAR PULSE: Deal 200% damage to all enemies in aura
	if not is_instance_valid(player) or stats.is_empty():
		return

	# Calculate pulse damage (200% bonus = 3x total)
	var base_dps = stats.damage * stats.attack_speed
	var final_dps = base_dps * player.player_stats.damage_mult
	var pulse_damage = final_dps * 3.0  # 200% bonus

	# Visual pulse effect
	create_pulse_visual()

	# Damage all enemies in aura
	for mob_id in overlapping_mobs:
		var mob = overlapping_mobs[mob_id]
		if is_instance_valid(mob):
			var is_crit = false
			var dmg = pulse_damage
			if randf() < player.player_stats.crit_chance:
				is_crit = true
				dmg *= player.player_stats.crit_damage

			_show_blue_damage(mob, dmg)
			mob.take_damage(dmg, false, is_crit)
			player.report_weapon_damage("aura", dmg)

func create_pulse_visual():
	# Create expanding ring visual for nuclear pulse
	var pulse = Node2D.new()
	pulse.global_position = global_position
	get_parent().add_child(pulse)

	# Create expanding rings
	for i in range(3):
		var ring_drawer = Node2D.new()
		pulse.add_child(ring_drawer)

		var delay = i * 0.05
		var ring_color = Color(1.0, 0.5, 0.0, 0.8 - i * 0.2)  # Orange

		# Delayed ring expansion
		await get_tree().create_timer(delay).timeout

		ring_drawer.draw.connect(func():
			ring_drawer.draw_arc(Vector2.ZERO, visual_radius, 0, TAU, 64, ring_color, 8.0, true)
		)
		ring_drawer.queue_redraw()

		var tween = ring_drawer.create_tween()
		tween.tween_property(ring_drawer, "scale", Vector2(1.5, 1.5), 0.4)
		tween.parallel().tween_property(ring_drawer, "modulate:a", 0.0, 0.4)

	# Delete pulse visual
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(pulse):
		pulse.queue_free()

func restore_enemy_speed(enemy: Node):
	# Restore enemy to original speed
	if enemy.has_method("get"):
		var base_speed = enemy.get("base_speed")
		if base_speed != null:
			enemy.speed = base_speed
