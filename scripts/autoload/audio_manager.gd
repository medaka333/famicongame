extends Node
## SE/BGM（Autoload 名: AudioManager）。§7 / §M12
## 8bit 風サウンドを手続き生成。BGM はメロディ + ベースの 2 チャンネル合成。
## ステージ曲とボス曲を分離。音声アセット不要。

const RATE := 22050

# メロディ / ベース（Hz、0=休符）
const STAGE_MEL := [523, 0, 523, 659, 784, 0, 659, 587, 587, 0, 659, 587, 523, 0, 392, 523]
const STAGE_BASS := [131, 131, 196, 196, 131, 131, 196, 196, 175, 175, 196, 196, 131, 131, 196, 196]
const BOSS_MEL := [440, 440, 523, 440, 415, 415, 494, 415, 440, 523, 659, 523, 494, 440, 415, 440]
const BOSS_BASS := [110, 110, 110, 110, 104, 104, 104, 104, 110, 110, 110, 110, 117, 117, 117, 117]

var _se: Dictionary = {}
var _bgm: Dictionary = {}
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
	_bgm_player.volume_db = -12.0
	add_child(_bgm_player)

	_se["shot"]      = _square(1200.0, 800.0, 0.05, 0.5, 45)
	_se["explosion"] = _noise(0.30, 90)
	_se["powerup"]   = _arp([523.0, 659.0, 784.0, 1047.0], 0.05, 80)
	_se["miss"]      = _square(420.0, 80.0, 0.42, 0.5, 90)

	_bgm["stage"] = _compose(STAGE_MEL, STAGE_BASS, 0.15, 80, 40)
	_bgm["boss"]  = _compose(BOSS_MEL, BOSS_BASS, 0.12, 80, 42)

func play_se(name: String) -> void:
	var s: AudioStreamWAV = _se.get(name)
	if s == null:
		return
	for p in _se_players:
		if not p.playing:
			p.stream = s
			p.play()
			return

func play_bgm(name: String) -> void:
	var s: AudioStreamWAV = _bgm.get(name)
	if s == null:
		return
	if _bgm_player.stream == s and _bgm_player.playing:
		return
	_bgm_player.stream = s
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()

# --- 手続き生成 ---

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
		d[i] = int(s * (1.0 - t) * vol) & 0xff
	return _wav(d, false)

func _noise(dur: float, vol: int) -> AudioStreamWAV:
	var n := maxi(1, int(RATE * dur))
	var d := PackedByteArray()
	d.resize(n)
	for i in n:
		var env := 1.0 - float(i) / n
		d[i] = int((randf() * 2.0 - 1.0) * env * vol) & 0xff
	return _wav(d, false)

func _arp(freqs: Array, ndur: float, vol: int) -> AudioStreamWAV:
	var ns := int(RATE * ndur)
	var d := PackedByteArray()
	for f in freqs:
		for i in ns:
			var t := float(i) / ns
			var p := fmod(i * (f as float) / RATE, 1.0)
			var s := 1.0 if p < 0.5 else -1.0
			d.append(int(s * vol * (1.0 - t * 0.2)) & 0xff)
	return _wav(d, false)

func _compose(mel: Array, bass: Array, ndur: float, mvol: int, bvol: int) -> AudioStreamWAV:
	var ns := int(RATE * ndur)
	var total := mel.size() * ns
	var d := PackedByteArray()
	d.resize(total)
	for n in mel.size():
		var mf := mel[n] as float
		var bf := bass[n % bass.size()] as float
		for i in ns:
			var idx := n * ns + i
			var t := float(i) / ns
			var s := 0.0
			if mf > 0.0:
				var mp := fmod(idx * mf / RATE, 1.0)
				s += (1.0 if mp < 0.25 else -1.0) * mvol * (1.0 - t * 0.12)
			if bf > 0.0:
				var bp := fmod(idx * bf / RATE, 1.0)
				s += (1.0 if bp < 0.5 else -1.0) * bvol
			d[idx] = int(clampf(s, -124.0, 124.0)) & 0xff
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
