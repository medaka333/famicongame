extends Node
## SE/BGM（Autoload 名: AudioManager）。§7
## 8bit 風サウンドを手続き生成（矩形波/ノイズ）。音声アセット不要。

const RATE := 22050

var _se: Dictionary = {}
var _bgm_stream: AudioStreamWAV
var _se_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		p.volume_db = -4.0
		add_child(p)
		_se_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Master"
	_bgm_player.volume_db = -14.0
	add_child(_bgm_player)

	_se["shot"]      = _square(1000.0, 720.0, 0.06, 0.5, 55)
	_se["explosion"] = _noise(0.30, 95)
	_se["powerup"]   = _square(523.0, 1568.0, 0.22, 0.5, 80)
	_se["miss"]      = _square(440.0, 90.0, 0.45, 0.5, 95)
	_bgm_stream = _make_bgm()

func play_se(name: String) -> void:
	var s: AudioStreamWAV = _se.get(name)
	if s == null:
		return
	for p in _se_players:
		if not p.playing:
			p.stream = s
			p.play()
			return

func play_bgm() -> void:
	if _bgm_player.playing:
		return
	_bgm_player.stream = _bgm_stream
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()

# --- 手続き生成ヘルパ ---

func _square(fs: float, fe: float, dur: float, duty: float, vol: int) -> AudioStreamWAV:
	var n := maxi(1, int(RATE * dur))
	var d := PackedByteArray()
	d.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(fs, fe, t)
		phase = fmod(phase + f / RATE, 1.0)
		var s := 1.0 if phase < duty else -1.0
		var env := 1.0 - t
		d[i] = int(s * env * vol) & 0xff
	return _wav(d, false)

func _noise(dur: float, vol: int) -> AudioStreamWAV:
	var n := maxi(1, int(RATE * dur))
	var d := PackedByteArray()
	d.resize(n)
	for i in n:
		var env := 1.0 - float(i) / n
		d[i] = int((randf() * 2.0 - 1.0) * env * vol) & 0xff
	return _wav(d, false)

func _make_bgm() -> AudioStreamWAV:
	var notes := [523.0, 659.0, 784.0, 880.0, 784.0, 659.0, 587.0, 523.0]
	var note_dur := 0.16
	var ns := int(RATE * note_dur)
	var d := PackedByteArray()
	for note in notes:
		var phase := 0.0
		for i in ns:
			var t := float(i) / ns
			phase = fmod(phase + note / RATE, 1.0)
			var s := 1.0 if phase < 0.25 else -1.0
			var env := 1.0 - t * 0.3
			d.append(int(s * env * 45) & 0xff)
	return _wav(d, true)

func _wav(d: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = d.size()
	return w
