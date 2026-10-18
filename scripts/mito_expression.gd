extends RefCounted
## MitoExpressionController: Mito's reactive face.
##
## The face is painted inside Mito's body shader (shaders/mito_body.gdshader), so this
## controller never moves geometry. It just tweens that shader's expression uniforms and
## kicks the organelle's squash spring.
##
##   IDLE    wide nervous yellow eyes, small open "o" mouth with the buck tooth, random blinks
##   HAPPY   big toothy D grin, "^" squint, relaxed brows, stretch-pop (scale.y ~1.15).
##           Lasts HAPPY_TIME (1.35 s) after the last feed.
##   SCARED  trembling screaming "O", tiny jittering pupils, brows shot up.
##           Holds while threatened, then SAFE_DELAY after the threat clears.
##
## Public API (call from gameplay):
##   on_fuel_consumed()                    sugar reached the mito / ATP landed in the nucleus
##   on_hazard_threat(is_threatened: bool) every frame from threat detection
##   on_hurt()                             one-shot: infection, radical hit, etc.

signal expression_changed(state: String)

enum State { IDLE, HAPPY, SCARED }

const HAPPY_TIME := 1.35
const SAFE_DELAY := 0.6
const HURT_TIME := 1.0
const NAMES := ["IDLE", "HAPPY", "SCARED"]
const TARGETS := {
	State.IDLE: {"mouth_open": 0.38, "smile": 0.0, "teeth": 0.0, "tremble": 0.0, "pupil": 1.0, "jitter": 0.0, "brow": 0.0, "squint": 0.0},
	State.HAPPY: {"mouth_open": 0.62, "smile": 1.0, "teeth": 1.0, "tremble": 0.0, "pupil": 1.15, "jitter": 0.0, "brow": -1.0, "squint": 1.0},
	State.SCARED: {"mouth_open": 1.0, "smile": 0.0, "teeth": 0.0, "tremble": 1.0, "pupil": 0.42, "jitter": 1.0, "brow": 1.0, "squint": 0.0},
}
## per-uniform tween speed (1/s): the mouth snaps, the brows ease
const SPEED := {"mouth_open": 16.0, "smile": 12.0, "teeth": 18.0, "tremble": 10.0, "pupil": 14.0, "jitter": 12.0, "brow": 8.0, "squint": 14.0}

var mat: ShaderMaterial
var organelle            # EngineRoom.Organelle (has sq / sqv squash spring)
var state: State = State.IDLE
var current := {}
var _happy_t := 0.0
var _hurt_t := 0.0
var _safe_t := 0.0
var _threat := false
var _blink_t := 2.5
var _blink := 0.0


func _init(body_material: ShaderMaterial, mito_organelle) -> void:
	mat = body_material
	organelle = mito_organelle
	current = TARGETS[State.IDLE].duplicate()
	_apply()


func on_fuel_consumed() -> void:
	_happy_t = HAPPY_TIME
	organelle.sqv -= 9.0          # negative squash = stretch-pop, scale.y peaks ~1.15


func on_hazard_threat(is_threatened: bool) -> void:
	_threat = is_threatened
	if is_threatened:
		_safe_t = SAFE_DELAY


func on_hurt() -> void:
	_hurt_t = HURT_TIME
	organelle.sqv += 8.0          # flinch squash


func update(dt: float) -> void:
	_happy_t = maxf(0.0, _happy_t - dt)
	_hurt_t = maxf(0.0, _hurt_t - dt)
	if not _threat:
		_safe_t = maxf(0.0, _safe_t - dt)
	var want: State = State.IDLE
	if _hurt_t > 0.0 or _threat or _safe_t > 0.0:
		want = State.SCARED
	elif _happy_t > 0.0:
		want = State.HAPPY
	if want != state:
		state = want
		expression_changed.emit(NAMES[state])
	var target: Dictionary = TARGETS[state]
	for k in target:
		var spd: float = SPEED[k]
		current[k] = lerpf(current[k], target[k], minf(1.0, dt * spd))
	# idle / happy blinks (never mid-panic: scared eyes stay wide open)
	_blink_t -= dt
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.0, 4.5)
		_blink = 1.0
	_blink = maxf(0.0, _blink - dt * 9.0) if state != State.SCARED else 0.0
	_apply()


func _apply() -> void:
	for k in current:
		mat.set_shader_parameter(k, current[k])
	mat.set_shader_parameter("blink", 1.0 - absf(_blink * 2.0 - 1.0) if _blink > 0.0 else 0.0)
