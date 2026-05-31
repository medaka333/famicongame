extends Node
## ドット絵生成（Autoload 名: PixelArt）。§M8
## 文字グリッドのピクセルマップから ImageTexture を生成。外部画像ファイル不要。
## 文字 = NES 風パレット色。'.' と未定義文字は透明。
## 左右対称のものは左半分だけ定義し _mirror_h で 2 倍化。

const PAL := {
	"W": Color8(252, 252, 252),
	"C": Color8(60, 188, 252),
	"B": Color8(0, 120, 248),
	"R": Color8(248, 56, 0),
	"M": Color8(168, 16, 0),
	"O": Color8(252, 160, 68),
	"Y": Color8(248, 216, 0),
	"G": Color8(0, 184, 0),
	"P": Color8(152, 80, 248),
	"K": Color8(60, 60, 60),
}

const PLAYER := [
	"................",
	"................",
	".......WW.......",
	"......WCCW......",
	"......WCCW......",
	".....WCCCCW.....",
	".....WCCCCW.....",
	"....WCCCCCCW....",
	"....WCCBBCCW....",
	"...WCCCBBCCCW...",
	"..WWCCCBBCCCWW..",
	".WW.WCCCCCCW.WW.",
	"WW..RRWCCWRR..WW",
	"....RRR..RRR....",
	".....RR..RR.....",
	"......R..R......",
]

const ZAKO := [
	"................",
	"..R..........R..",
	"..RR........RR..",
	"...RR.RRRR.RR...",
	"...RRRRRRRRRR...",
	"..RRRWWRRWWRRR..",
	"..RRRWWRRWWRRR..",
	"..RRRRRRRRRRRR..",
	"..RRRRRRRRRRRR..",
	"...RRRRRRRRRR...",
	"...RR.RRRR.RR...",
	"..RR..R..R..RR..",
	"..R...R..R...R..",
	"......R..R......",
	"................",
	"................",
]

const PBULLET := [
	"........",
	"...WW...",
	"..WYYW..",
	"..WYYW..",
	"..WYYW..",
	"..WYYW..",
	"...YY...",
	"...YY...",
]

const EBULLET := [
	"........",
	"..OOOO..",
	".OOMMOO.",
	".OMMMMO.",
	".OMMMMO.",
	".OOMMOO.",
	"..OOOO..",
	"........",
]

const ITEM := [
	"................",
	"....GGGGGGGG....",
	"...GGGGGGGGGG...",
	"..GGWWWWWWWWGG..",
	"..GGWWGGGGWWGG..",
	"..GGWWGGGGWWGG..",
	"..GGWWWWWWWGGG..",
	"..GGWWGGGGGGGG..",
	"..GGWWGGGGGGGG..",
	"..GGWWGGGGGGGG..",
	"...GGGGGGGGGG...",
	"....GGGGGGGG....",
	"................",
	"................",
	"................",
	"................",
]

# 左半分のみ（16幅）。_mirror_h で 32幅の左右対称ボスになる。
const BOSS_L := [
	"................",
	".......PPP......",
	"......PPPPP.....",
	"......PPPPP.....",
	".....PPPPPPP....",
	"....PPPPPPPPP...",
	"...PPPPPPPPPPP..",
	"..PPPPPPPPPPPPP.",
	".PPPPPPPPPPPPPPP",
	".PPPPKKKPPPPPPPP",
	".PPPKKKKKPPPPOOO",
	".PPPKKKKKPPPOOYY",
	".PPPKKKKKPPPOOYY",
	".PPPKKKKKPPPPOOO",
	".PPPPPPPPPPPPPPP",
	"..PPPPPPPPPPPPPP",
	"...PPPPPPPPPPPPP",
	"....PPPPP...PPPP",
	"...PPPP.....PPPP",
	"..PPPP......PPPP",
	"..PPP...........",
	".PP.............",
	"................",
	"................",
]

# 左半分のみ（8幅）。_mirror_h で 16幅の爆発になる。
const EXPLOSION_L := [
	"........",
	"......YY",
	"...Y.YOO",
	"....OOOO",
	"..YOOMMR",
	".YOOMMMM",
	"...OOMMM",
	"....OMMR",
	"....OMMR",
	"...OOMMM",
	".YOOMMMM",
	"..YOOMMR",
	"....OOOO",
	"...Y.YOO",
	"......YY",
	"........",
]

var _cache: Dictionary = {}

func _ready() -> void:
	_cache["player"] = _make(PLAYER)
	_cache["zako_red"] = _make(ZAKO)
	_cache["zako_purple"] = _make(_recolor(ZAKO, "R", "P"))
	_cache["pbullet"] = _make(PBULLET)
	_cache["ebullet"] = _make(EBULLET)
	_cache["item"] = _make(ITEM)
	_cache["boss"] = _make(_mirror_h(BOSS_L))
	_cache["explosion"] = _make(_mirror_h(EXPLOSION_L))

func get_tex(name: String) -> Texture2D:
	return _cache.get(name)

func _recolor(rows: Array, from_ch: String, to_ch: String) -> Array:
	var out: Array = []
	for r in rows:
		out.append((r as String).replace(from_ch, to_ch))
	return out

func _mirror_h(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append((r as String) + _reverse(r))
	return out

func _reverse(s: String) -> String:
	var r := ""
	for i in range(s.length() - 1, -1, -1):
		r += s[i]
	return r

func _make(rows: Array) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if PAL.has(ch):
				img.set_pixel(x, y, PAL[ch])
	return ImageTexture.create_from_image(img)
