extends Node
## ドット絵生成（Autoload 名: PixelArt）。§M8 / §M12 / §M14
## 文字グリッド → ImageTexture。外部画像不要。'.' と未定義文字は透明。
## アニメは <base>0 / <base>1 の 2 フレーム、爆発は exp0..2。

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

const PLAYER0 := [
	"................", "................", ".......WW.......", "......WCCW......",
	"......WCCW......", ".....WCCCCW.....", ".....WCCCCW.....", "....WCCCCCCW....",
	"....WCCBBCCW....", "...WCCCBBCCCW...", "..WWCCCBBCCCWW..", ".WW.WCCCCCCW.WW.",
	"WW..RRWCCWRR..WW", "....RRR..RRR....", ".....RR..RR.....", "......R..R......",
]
const PLAYER1 := [
	"................", "................", ".......WW.......", "......WCCW......",
	"......WCCW......", ".....WCCCCW.....", ".....WCCCCW.....", "....WCCCCCCW....",
	"....WCCBBCCW....", "...WCCCBBCCCW...", "..WWCCCBBCCCWW..", ".WW.WCCCCCCW.WW.",
	"WW..RYWCCWYR..WW", "....RR....RR....", ".....R....R.....", "................",
]
const ZAKO0 := [
	"................", "..R..........R..", "..RR........RR..", "...RR.RRRR.RR...",
	"...RRRRRRRRRR...", "..RRRWWRRWWRRR..", "..RRRWWRRWWRRR..", "..RRRRRRRRRRRR..",
	"..RRRRRRRRRRRR..", "...RRRRRRRRRR...", "...RR.RRRR.RR...", "..RR..R..R..RR..",
	"..R...R..R...R..", "......R..R......", "................", "................",
]
const ZAKO1 := [
	"................", "...R........R...", "..RR........RR..", "...RR.RRRR.RR...",
	"...RRRRRRRRRR...", "..RRRWWRRWWRRR..", "..RRRWWRRWWRRR..", "..RRRRRRRRRRRR..",
	"..RRRRRRRRRRRR..", "...RRRRRRRRRR...", "..RR..RRRR..RR..", ".RR...R..R...RR.",
	".R....R..R....R.", ".....RR..RR.....", "................", "................",
]

const PBULLET := [
	"........", "...WW...", "..WYYW..", "..WYYW..",
	"..WYYW..", "..WYYW..", "...YY...", "...YY...",
]
# Lv2 強化弾（大きく明るい）
const PBULLET2 := [
	"...WW...", "..WWWW..", ".WWYYWW.", ".WYYYYW.",
	".WYYYYW.", ".WWYYWW.", "..WWWW..", "...WW...",
]
const EBULLET := [
	"........", "..OOOO..", ".OOMMOO.", ".OMMMMO.",
	".OMMMMO.", ".OOMMOO.", "..OOOO..", "........",
]
const ITEM := [
	"................", "....GGGGGGGG....", "...GGGGGGGGGG...", "..GGWWWWWWWWGG..",
	"..GGWWGGGGWWGG..", "..GGWWGGGGWWGG..", "..GGWWWWWWWGGG..", "..GGWWGGGGGGGG..",
	"..GGWWGGGGGGGG..", "..GGWWGGGGGGGG..", "...GGGGGGGGGG...", "....GGGGGGGG....",
	"................", "................", "................", "................",
]
const BOSS_L := [
	"................", ".......PPP......", "......PPPPP.....", "......PPPPP.....",
	".....PPPPPPP....", "....PPPPPPPPP...", "...PPPPPPPPPPP..", "..PPPPPPPPPPPPP.",
	".PPPPPPPPPPPPPPP", ".PPPPKKKPPPPPPPP", ".PPPKKKKKPPPPOOO", ".PPPKKKKKPPPOOYY",
	".PPPKKKKKPPPOOYY", ".PPPKKKKKPPPPOOO", ".PPPPPPPPPPPPPPP", "..PPPPPPPPPPPPPP",
	"...PPPPPPPPPPPPP", "....PPPPP...PPPP", "...PPPP.....PPPP", "..PPPP......PPPP",
	"..PPP...........", ".PP.............", "................", "................",
]

# 爆発 3 フレーム（左半分8幅 → mirror で16幅）
const EXP0_L := [
	"........", "........", "........", "........", "........", "......YY",
	".....YOO", ".....OOM", ".....OOM", ".....YOO", "......YY", "........",
	"........", "........", "........", "........",
]
const EXP1_L := [
	"........", "........", "......YY", ".....YOO", "....YOOM", "...YOOMM",
	"...OOMMM", "...OMMMM", "...OMMMM", "...OOMMM", "...YOOMM", "....YOOM",
	".....YOO", "......YY", "........", "........",
]
const EXP2_L := [
	"Y.......", "..Y...OY", "....OO..", "...OM..Y", "..OM....", "....M...",
	"...M..O.", ".....OM.", "..O...M.", ".O..OM..", "....M...", "...O...Y",
	"..Y..O..", ".....M.Y", "Y...Y...", "........",
]

var _cache: Dictionary = {}

func _ready() -> void:
	_cache["player0"] = _make(PLAYER0)
	_cache["player1"] = _make(PLAYER1)
	_cache["zako_red0"] = _make(ZAKO0)
	_cache["zako_red1"] = _make(ZAKO1)
	_cache["zako_purple0"] = _make(_recolor(ZAKO0, "R", "P"))
	_cache["zako_purple1"] = _make(_recolor(ZAKO1, "R", "P"))
	_cache["pbullet"] = _make(PBULLET)
	_cache["pbullet2"] = _make(PBULLET2)
	_cache["ebullet"] = _make(EBULLET)
	_cache["item"] = _make(ITEM)
	_cache["boss"] = _make(_mirror_h(BOSS_L))
	_cache["exp0"] = _make(_mirror_h(EXP0_L))
	_cache["exp1"] = _make(_mirror_h(EXP1_L))
	_cache["exp2"] = _make(_mirror_h(EXP2_L))

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
