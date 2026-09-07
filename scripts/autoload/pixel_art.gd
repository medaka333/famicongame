extends Node
## ドット絵生成（Autoload 名: PixelArt）。§M8 / §M12 / §M14 / §M15
## 文字グリッド → ImageTexture。外部画像不要。'.' と未定義文字は透明。

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
	"........", "...WW...", "..WYYW..", "..WYYW..", "..WYYW..", "..WYYW..", "...YY...", "...YY...",
]
const PBULLET2 := [
	"...WW...", "..WWWW..", ".WWYYWW.", ".WYYYYW.", ".WYYYYW.", ".WWYYWW.", "..WWWW..", "...WW...",
]
const EBULLET := [
	"........", "..OOOO..", ".OOMMOO.", ".OMMMMO.", ".OMMMMO.", ".OOMMOO.", "..OOOO..", "........",
]
# フォーカス船。通常機より細身で、正面に伸びる青いコアを持つ「集中」の形。
# 通常機(PLAYER0)は翼が広いのに対し、こちらは縦に長い。
# フォーカス機(#10)。重厚な砲艦。左16列だけ描いて _mirror_h で32幅にする。
# 通常機を引き伸ばすとドットの粒が他の絵と揃わないので、32x32で描き起こしている。
const PLAYER_FOCUS_L := [
	".......KWK....", ".......KBK....", ".......KBK....", ".......KBK..KC",
	".......KBK..KC", ".......KBK.KCC", ".......KBK.KCC", ".......KBKKCCC",
	"......KKBKKCCC", "......KBBBKCCC", ".....KKBBBKCWW", ".....KCBBBKCWW",
	"....KKCBBBKCWW", "....KCCBBBKCWW", "...KKCCBBBKCWW", "...KCCCBBBKCCC",
	"..KKCCCBBBKCCC", "KKKCCCCBBBKCCC", "KCCCCCCBBBKCCC", "KCKKCCCBBBKCCC",
	"KCKKCCCBBBKCCC", "KCCCCCCBBBKCCC", "KKKKKKKBBBKCCC", "...KKCCBBBKCCC",
	"...KCCCBBBKCCC", "...KCCCBBBKCCC", "...KCCCBBBKCCC", "...KKKKKKKKKKK",
	"....KOOOK..KOO", ".....OOO....OO", ".....YY.....YY", "......Y......Y",
]

# アイテム: 種類が一目で分かるよう F / W の文字を入れる(#10)
const ITEM_FOCUS := [
	"................", "..BBBBBBBBBBBB..", "..BCCCCCCCCCCB..", "..BCCCCCCCCCCB..",
	"..BCCWWWWWWCCB..", "..BCCWWCCCCCCB..", "..BCCWWWWWCCCB..", "..BCCWWCCCCCCB..",
	"..BCCWWCCCCCCB..", "..BCCWWCCCCCCB..", "..BCCCCCCCCCCB..", "..BCCCCCCCCCCB..",
	"..BBBBBBBBBBBB..", "................", "................", "................",
]
const ITEM_WIDE := [
	"................", "..RRRRRRRRRRRR..", "..ROOOOOOOOOOR..", "..ROOOOOOOOOOR..",
	"..ROOWOOOOWOOR..", "..ROOWOOOOWOOR..", "..ROOWOOOOWOOR..", "..ROOWOWWOWOOR..",
	"..ROOWOWWOWOOR..", "..ROOWWOOWWOOR..", "..ROOOOOOOOOOR..", "..ROOOOOOOOOOR..",
	"..RRRRRRRRRRRR..", "................", "................", "................",
]

const ITEM := [
	"................", "....GGGGGGGG....", "...GGGGGGGGGG...", "..GGWWWWWWWWGG..",
	"..GGWWGGGGWWGG..", "..GGWWGGGGWWGG..", "..GGWWWWWWWGGG..", "..GGWWGGGGGGGG..",
	"..GGWWGGGGGGGG..", "..GGWWGGGGGGGG..", "...GGGGGGGGGG...", "....GGGGGGGG....",
	"................", "................", "................", "................",
]

# ボス（左半分16幅 → mirror で32幅）
const BOSS1_L := [
	"................", "................", "......MMMMMMMMMM", "....MMMMMMMMMMMM",
	"...MMMMMMMMMMMMM", "..MMMMMMMMMMMMMM", "..MMMMOMMMMMMMMM", "..MMMMMMMMMMMMMM",
	"...MMMMMMMMMMMMM", "....MMMMMMMMMMMM", ".....MMMMMMMMMMM", "R...O.MMMMMMMMM.",
	"RR.O...MMMMMMM..", ".O.O....MMMMM...", "O.O......MMM....", ".O........M.....",
	"O...............", "................", "................", "................",
	"................", "................", "................", "................",
]
const BOSS2_L := [
	"................", "...........BBB..", "..........BBBBB.", ".........BBBBBBB",
	"........BBBBBBBB", ".......BBBBBBBBB", "......BBBCCCCBBB", ".....BBCCCCCCCBB",
	".....BBCCWWWWCCB", ".....BBCCWGGWCCB", ".....BBCCWWWWCCB", "......BBBCCCCBBB",
	".......BBBBBBBBB", "........BBBBBBBB", ".........BBBBBBB", "........BBBKKBBB",
	".......BBB..BBBB", "......BBB....BBB", ".....BBB......BB", "....BBB.......BB",
	"...BB...........", "..BB............", "................", "................",
]
const BOSS3_L := [
	"................", ".....RRRRRR.....", "....RRRRRRRR....", "...RRMMMMMMRR...",
	"..RRMMOOOOMMRR..", ".RRMMOOOOOOMMRR.", ".RMMOOYYYYOOMMR.", "RRMMOOYWWYOOMMRR",
	"RMMOOOYWWYOOOMMR", "RMMOOOYWWYOOOMMR", "RRMMOOYWWYOOMMRR", ".RMMOOYYYYOOMMR.",
	".RRMMOOOOOOMMRR.", "..RRMMOOOOMMRR..", "...RRMMMMMMRR...", "...RRRRRRRRRR...",
	"..RRR.RRRR.RRR..", ".RRR...RR...RRR.", ".RR....RR....RR.", "RR.....RR.....RR",
	"R......RR......R", ".......RR.......", "................", "................",
]

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

const SPARK := [
	"..Y..Y..", "...YY...", ".YYWWYY.", "..WWWW..",
	"..WWWW..", ".YYWWYY.", "...YY...", "..Y..Y..",
]

# ゲーム選択画面用アイコン: ブロック+ボール+パドル
const ICON_BREAKOUT := [
	"................", "................", "..RRRROOOOYYYY..", "..RRRROOOOYYYY..",
	"................", "................", ".......WW.......", ".......WW.......",
	"................", "................", "................", "................",
	"................", "..CCCCCCCCCCCC..", "..CCCCCCCCCCCC..", "................",
]

var _cache: Dictionary = {}

func _ready() -> void:
	_cache["player0"] = _make(PLAYER0)
	_cache["player1"] = _make(PLAYER1)
	_cache["player_focus"] = _make(_mirror_h(PLAYER_FOCUS_L))
	_cache["item_focus"] = _make(ITEM_FOCUS)
	_cache["item_wide"] = _make(ITEM_WIDE)
	_cache["zako_red0"] = _make(ZAKO0)
	_cache["zako_red1"] = _make(ZAKO1)
	_cache["zako_purple0"] = _make(_recolor(ZAKO0, "R", "P"))
	_cache["zako_purple1"] = _make(_recolor(ZAKO1, "R", "P"))
	_cache["pbullet"] = _make(PBULLET)
	_cache["pbullet2"] = _make(PBULLET2)
	_cache["ebullet"] = _make(EBULLET)
	_cache["item"] = _make(ITEM)
	_cache["boss1"] = _make(_mirror_h(BOSS1_L))
	_cache["boss2"] = _make(_mirror_h(BOSS2_L))
	_cache["boss3"] = _make(_mirror_h(BOSS3_L))
	_cache["exp0"] = _make(_mirror_h(EXP0_L))
	_cache["exp1"] = _make(_mirror_h(EXP1_L))
	_cache["exp2"] = _make(_mirror_h(EXP2_L))
	_cache["spark"] = _make(SPARK)
	# 自機カラーの破片（敵弾のオレンジと区別するためシアン白）
	_cache["spark_blue"] = _make(_recolor(SPARK, "Y", "C"))
	_cache["icon_breakout"] = _make(ICON_BREAKOUT)

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
