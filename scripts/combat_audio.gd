extends RefCounted
## Baked stereo cues; no synthesis or disk access on a gameplay frame.
const TRACKS = {
	"ability_air": preload("res://audio/sfx/premium/ability_air.wav"),
	"ability_blast": preload("res://audio/sfx/premium/ability_blast.wav"),
	"ability_freeze": preload("res://audio/sfx/premium/ability_freeze.wav"),
	"ability_ghost": preload("res://audio/sfx/premium/ability_ghost.wav"),
	"ability_laser": preload("res://audio/sfx/premium/ability_laser.wav"),
	"ability_magnet": preload("res://audio/sfx/premium/ability_magnet.wav"),
	"ability_mirror": preload("res://audio/sfx/premium/ability_mirror.wav"),
	"ability_pierce": preload("res://audio/sfx/premium/ability_pierce.wav"),
	"ability_rapid": preload("res://audio/sfx/premium/ability_rapid.wav"),
	"ability_rebuild": preload("res://audio/sfx/premium/ability_rebuild.wav"),
	"ability_stun": preload("res://audio/sfx/premium/ability_stun.wav"),
	"ability_thorns": preload("res://audio/sfx/premium/ability_thorns.wav"),
	"ability_walls": preload("res://audio/sfx/premium/ability_walls.wav"),
	"ability_weld": preload("res://audio/sfx/premium/ability_weld.wav"),
	"blast": preload("res://audio/sfx/premium/blast.wav"),
	"bloom": preload("res://audio/sfx/premium/bloom.wav"),
	"boost": preload("res://audio/sfx/premium/boost.wav"),
	"bounce": preload("res://audio/sfx/premium/bounce.wav"),
	"break_0": preload("res://audio/sfx/premium/break_0.wav"),
	"break_1": preload("res://audio/sfx/premium/break_1.wav"),
	"break_2": preload("res://audio/sfx/premium/break_2.wav"),
	"charging": preload("res://audio/sfx/premium/charging.wav"),
	"defense": preload("res://audio/sfx/premium/defense.wav"),
	"goal": preload("res://audio/sfx/premium/goal.wav"),
	"hit_0": preload("res://audio/sfx/premium/hit_0.wav"),
	"hit_1": preload("res://audio/sfx/premium/hit_1.wav"),
	"hit_2": preload("res://audio/sfx/premium/hit_2.wav"),
	"laser_tick": preload("res://audio/sfx/premium/laser_tick.wav"),
	"metal": preload("res://audio/sfx/premium/metal.wav"),
	"meteor": preload("res://audio/sfx/premium/meteor.wav"),
	"plating": preload("res://audio/sfx/premium/plating.wav"),
	"plunder": preload("res://audio/sfx/premium/plunder.wav"),
	"power": preload("res://audio/sfx/premium/power.wav"),
	"ready": preload("res://audio/sfx/premium/ready.wav"),
	"ricochet": preload("res://audio/sfx/premium/ricochet.wav"),
	"sentries": preload("res://audio/sfx/premium/sentries.wav"),
	"sentry": preload("res://audio/sfx/premium/sentry.wav"),
	"shield": preload("res://audio/sfx/premium/shield.wav"),
	"shot_0_0": preload("res://audio/sfx/premium/shot_0_0.wav"),
	"shot_0_1": preload("res://audio/sfx/premium/shot_0_1.wav"),
	"shot_0_2": preload("res://audio/sfx/premium/shot_0_2.wav"),
	"shot_10_0": preload("res://audio/sfx/premium/shot_10_0.wav"),
	"shot_10_1": preload("res://audio/sfx/premium/shot_10_1.wav"),
	"shot_10_2": preload("res://audio/sfx/premium/shot_10_2.wav"),
	"shot_11_0": preload("res://audio/sfx/premium/shot_11_0.wav"),
	"shot_11_1": preload("res://audio/sfx/premium/shot_11_1.wav"),
	"shot_11_2": preload("res://audio/sfx/premium/shot_11_2.wav"),
	"shot_1_0": preload("res://audio/sfx/premium/shot_1_0.wav"),
	"shot_1_1": preload("res://audio/sfx/premium/shot_1_1.wav"),
	"shot_1_2": preload("res://audio/sfx/premium/shot_1_2.wav"),
	"shot_2_0": preload("res://audio/sfx/premium/shot_2_0.wav"),
	"shot_2_1": preload("res://audio/sfx/premium/shot_2_1.wav"),
	"shot_2_2": preload("res://audio/sfx/premium/shot_2_2.wav"),
	"shot_3_0": preload("res://audio/sfx/premium/shot_3_0.wav"),
	"shot_3_1": preload("res://audio/sfx/premium/shot_3_1.wav"),
	"shot_3_2": preload("res://audio/sfx/premium/shot_3_2.wav"),
	"shot_4_0": preload("res://audio/sfx/premium/shot_4_0.wav"),
	"shot_4_1": preload("res://audio/sfx/premium/shot_4_1.wav"),
	"shot_4_2": preload("res://audio/sfx/premium/shot_4_2.wav"),
	"shot_5_0": preload("res://audio/sfx/premium/shot_5_0.wav"),
	"shot_5_1": preload("res://audio/sfx/premium/shot_5_1.wav"),
	"shot_5_2": preload("res://audio/sfx/premium/shot_5_2.wav"),
	"shot_6_0": preload("res://audio/sfx/premium/shot_6_0.wav"),
	"shot_6_1": preload("res://audio/sfx/premium/shot_6_1.wav"),
	"shot_6_2": preload("res://audio/sfx/premium/shot_6_2.wav"),
	"shot_7_0": preload("res://audio/sfx/premium/shot_7_0.wav"),
	"shot_7_1": preload("res://audio/sfx/premium/shot_7_1.wav"),
	"shot_7_2": preload("res://audio/sfx/premium/shot_7_2.wav"),
	"shot_8_0": preload("res://audio/sfx/premium/shot_8_0.wav"),
	"shot_8_1": preload("res://audio/sfx/premium/shot_8_1.wav"),
	"shot_8_2": preload("res://audio/sfx/premium/shot_8_2.wav"),
	"shot_9_0": preload("res://audio/sfx/premium/shot_9_0.wav"),
	"shot_9_1": preload("res://audio/sfx/premium/shot_9_1.wav"),
	"shot_9_2": preload("res://audio/sfx/premium/shot_9_2.wav"),
	"singularity": preload("res://audio/sfx/premium/singularity.wav"),
	"stun": preload("res://audio/sfx/premium/stun.wav"),
	"sun_ray": preload("res://audio/sfx/premium/sun_ray.wav"),
	"surge": preload("res://audio/sfx/premium/surge.wav"),
	"thunder": preload("res://audio/sfx/premium/thunder.wav"),
	"unleash": preload("res://audio/sfx/premium/unleash.wav"),
	"void_burst": preload("res://audio/sfx/premium/void_burst.wav"),
	"void_wave": preload("res://audio/sfx/premium/void_wave.wav"),
	"volley": preload("res://audio/sfx/premium/volley.wav"),
}

const BUS = &"ChargeCombat"
static func prepare_bus() -> StringName:
	var index = AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, &"Master")
		# Catch rare stacks of transients, leaving room for the untouched music bus.
		var limiter = AudioEffectHardLimiter.new()
		limiter.pre_gain_db = 0.0
		limiter.ceiling_db = -4.0
		limiter.release = 0.08
		AudioServer.add_bus_effect(index, limiter)
	return BUS
