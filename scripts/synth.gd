extends Node
## Tiny procedural synth. Every boing, squelch, gulp and kaboom is generated in code
## from a handful of oscillator/noise voices, so there are no audio files to ship.

const RATE := 22050.0
const MAX_VOICES := 12
enum { SINE, SQUARE, SAW, TRI, NOISE }

var muted := false
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _voices: Array = []
var _last := {}


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -3.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback


## wave, start Hz, end Hz, seconds, volume, delay, vibrato depth Hz, vibrato rate, noise lowpass 0..1
func tone(wave: int, f0: float, f1: float, dur: float, vol: float, delay: float = 0.0, vib: float = 0.0, vib_f: float = 0.0, lp: float = 1.0) -> void:
	if muted:
		return
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	_voices.append({"w": wave, "f0": f0, "f1": f1, "dur": dur, "vol": vol, "t": -delay, "ph": 0.0, "vib": vib, "vf": vib_f, "lp": lp, "z": 0.0})


func play(sound: String, amt: float = 1.0) -> void:
	if muted:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _last.has(sound) and now - float(_last[sound]) < 0.045:
		return
	_last[sound] = now
	var a := clampf(amt, 0.1, 2.0)
	match sound:
		"boing":
			tone(SINE, 110, 420, 0.08, 0.32 * a)
			tone(SINE, 420, 90, 0.36, 0.28 * a, 0.07, 50, 22)
		"squelch":
			tone(NOISE, 1, 1, 0.22, 0.4, 0.0, 0, 0, 0.08)
			tone(SINE, 260, 70, 0.2, 0.25, 0.0, 30, 30)
		"gulp":
			tone(SINE, 340, 110, 0.16, 0.45)
			tone(SINE, 220, 80, 0.2, 0.3, 0.1)
		"plop":
			tone(SINE, 600, 180, 0.1, 0.3)
		"ptoo":
			tone(NOISE, 1, 1, 0.12, 0.45, 0.0, 0, 0, 0.35)
			tone(SINE, 300, 900, 0.12, 0.3)
		"pop":
			tone(SINE, 900, 300, 0.07, 0.3)
		"splat":
			tone(NOISE, 1, 1, 0.3, 0.55 * a, 0.0, 0, 0, 0.12)
			tone(SAW, 160, 50, 0.25, 0.22 * a)
		"zap":
			tone(SQUARE, 1200, 200, 0.18, 0.16, 0.0, 80, 40)
		"fizz":
			tone(NOISE, 1, 1, 0.4, 0.22, 0.0, 0, 0, 0.6)
		"sling":
			tone(SAW, 180, 900, 0.12, 0.18)
			tone(NOISE, 1, 1, 0.15, 0.2, 0.0, 0, 0, 0.3)
		"stretch":
			tone(TRI, 200, 320, 0.25, 0.15, 0.0, 10, 12)
		"grab":
			tone(SQUARE, 600, 900, 0.05, 0.08)
		"whoosh":
			tone(NOISE, 1, 1, 0.22, 0.3, 0.0, 0, 0, 0.18)
		"nom":
			tone(SINE, 400, 250, 0.08, 0.28)
			tone(SINE, 500, 300, 0.08, 0.28, 0.09)
		"slurp":
			tone(SINE, 200, 700, 0.25, 0.28, 0.0, 40, 18)
		"giggle":
			for i in 4:
				tone(SINE, 900 + i * 80, 1100 + i * 80, 0.06, 0.18, i * 0.07)
		"boop":
			tone(SINE, 500, 700, 0.09, 0.25)
		"squeak":
			tone(SAW, 1100, 1900, 0.1, 0.07, 0.0, 60, 30)
		"crank":
			tone(SQUARE, 220 * a, 330 * a, 0.12, 0.16)
			tone(SINE, 440 * a, 660 * a, 0.12, 0.15, 0.05)
		"burp":
			tone(SAW, 140, 60, 0.4, 0.35, 0.0, 25, 14)
		"bonk":
			tone(TRI, 380, 70, 0.14, 0.3 * a)
		"cry":
			tone(SAW, 520, 320, 0.3, 0.16, 0.0, 6, 5)
			tone(SAW, 470, 260, 0.4, 0.16, 0.28, 6, 5)
		"infect":
			tone(SQUARE, 500, 120, 0.35, 0.2, 0.0, 60, 30)
		"chime":
			tone(SINE, 660, 660, 0.3, 0.2)
			tone(SINE, 880, 880, 0.3, 0.2, 0.1)
			tone(SINE, 1320, 1320, 0.4, 0.2, 0.2)
		"mutate":
			tone(SAW, 200, 800, 0.5, 0.18, 0.0, 120, 9)
		"kaboom":
			tone(NOISE, 1, 1, 1.4, 0.9, 0.0, 0, 0, 0.05)
			tone(SINE, 160, 25, 1.2, 0.6)
			tone(SAW, 90, 30, 1.0, 0.3, 0.05)
		"blorp":
			tone(SINE, 300, 40, 1.4, 0.5, 0.0, 40, 6)
			tone(NOISE, 1, 1, 1.0, 0.25, 0.0, 0, 0, 0.04)
		"alarm":
			tone(SQUARE, 900, 900, 0.1, 0.12)
			tone(SQUARE, 700, 700, 0.1, 0.12, 0.13)


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var inv := 1.0 / RATE
	for v in _voices:
		var w: int = v["w"]
		var f0: float = maxf(1.0, v["f0"])
		var ratio: float = maxf(1.0, v["f1"]) / f0
		var dur: float = v["dur"]
		var vol: float = v["vol"]
		var vib: float = v["vib"]
		var vf: float = v["vf"]
		var lp: float = v["lp"]
		var t: float = v["t"]
		var ph: float = v["ph"]
		var z: float = v["z"]
		for i in n:
			if t >= 0.0 and t < dur:
				var k := t / dur
				var f := f0 * pow(ratio, k)
				if vib > 0.0:
					f += sin(t * TAU * vf) * vib
				ph = fposmod(ph + f * inv, 1.0)
				var s := 0.0
				if w == SINE:
					s = sin(ph * TAU)
				elif w == SQUARE:
					s = 1.0 if ph < 0.5 else -1.0
				elif w == SAW:
					s = 2.0 * ph - 1.0
				elif w == TRI:
					s = 4.0 * absf(ph - 0.5) - 1.0
				else:
					z += (randf() * 2.0 - 1.0 - z) * lp
					s = z
				var env := minf(1.0, t / 0.006) * (1.0 - k) * (1.0 - k)
				var o := s * env * vol
				buf[i] += Vector2(o, o)
			t += inv
		v["t"] = t
		v["ph"] = ph
		v["z"] = z
	_voices = _voices.filter(func(v): return float(v["t"]) < float(v["dur"]))
	for i in n:
		var s := buf[i]
		buf[i] = Vector2(clampf(s.x, -1.0, 1.0), clampf(s.y, -1.0, 1.0))
	_pb.push_buffer(buf)
