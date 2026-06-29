# ブロック崩し（BREAKOUT）―― 実装計画書

最終更新: 2026-06-22

位置づけ: famicongame（縦STG）に同梱する**独立ミニゲーム**。STG 資産（autoload・misaki フォント・手続き生成 SE/BGM・PixelArt）を再利用しつつ、**シーンは完全分離**。STG 本体（Title/Game/HUD/GameOver 等）は **一切改変しない**。

---

## 0. 確定事項（前提）

| 項目 | 決定 | 補足 |
|---|---|---|
| エンジン | Godot 4.6 / GDScript | 既存プロジェクトに準拠 |
| ジャンル | ブロック崩し（Breakout / Arkanoid 系） | パドルでボールを打ち返しブロック全消し |
| 解像度 | 256×240（NES） | STG と同ビューポート設定を流用 |
| 起動 | **単独シーン**（専用 Title→Game→Over の独立フロー） | STG の起動導線には出さない。STG 非破壊 |
| 見た目 | NES 寄せ。misaki 日本語 UI、整数スケール | STG と統一 |
| 難易度 | KIDS / ADULT（専用タイトルで選択） | `GameState.difficulty` を読むだけ |
| スコープ | **フル**：パワーアップ + 特殊ブロック + ボス + 演出 | §1.6〜1.9 |
| 音 | `AudioManager` の既存 SE/BGM を流用 | shot/explosion/powerup/miss/cursor、bgm: stage/boss |
| 入力 | 既存 InputMap（`move_left`/`move_right`/`shoot`/`pause`） | 追加バインド不要 |

### 設計の背骨（3 原則）
1. **STG を壊さない**。共有 autoload（特に `GameState`）への**書き込みを禁止**。読むのは `difficulty` / `is_demo` と難易度ヘルパ（`start_lives()` / `bullet_speed_mul()`）のみ。スコア・残機・ハイスコアは**ブロック崩し側で自前管理**。
2. **自己完結**。`scenes/breakout/` と `scripts/breakout/` で完結。ハイスコアは `user://save.cfg` の **別セクション `breakout`** に保存（STG の `score` セクションと非干渉）。
3. **物理は堅牢に**。ボールの反射は `area_entered` シグナル任せにせず、**サブステップ連続衝突 + 円-AABB 幾何判定**で自前計算（高速時のすり抜け・角の貫通・多重反射を防ぐ）。

---

## 0.5 参考と確定数値

参考: Arkanoid（Taito, 1986）。パドル端で反射角が変わる打ち返し、落下アイテムによる強化、ブロック耐久差、最終ステージのボス。

### 確定数値（実装の単一情報源）

| 項目 | 値 | 備考 |
|---|---|---|
| 解像度 / FPS | 256×240 / 60 | NES 準拠 |
| プレイ枠 | X∈[8,248]、上端 Y=8、底（ミス境界）Y=244 | 左右上で反射、底で落下 |
| パドル幅 | ADULT=32 / KIDS=44 | KIDS は広め。アイテム EXPAND で +16（上限 64） |
| パドル位置 / 高さ | Y=212 / 高さ 8 | 横移動のみ |
| パドル速度 | 175 px/s | キビキビ |
| ボール半径 | 3 px | |
| ボール初速 | base 116 × `bullet_speed_mul()`（KIDS 0.6 / ADULT 1.0） | KIDS=約70 / ADULT=116 |
| ボール加速 | ヒットごとに +2.5、上限 base×1.8 | 単調に速くなりすぎない |
| 反射角（パドル） | 端で最大 ±60°（中央=ほぼ垂直） | `off = (bx-px)/half_w` |
| 最小垂直成分 | speed×0.28 を下回らない | 水平ループ（無限往復）防止 |
| ブロック | 16×8 px、行ピッチ 8、上端 Y=40 | 文字グリッドで配置（§5.7） |
| ブロック耐久 | 通常=1 / 硬い(H)=2 / 鋼鉄(K)=∞（不壊・反射のみ） | K はクリア判定から除外 |
| ブロック得点 | 上段ほど高い（行で逓減）。硬い=+α | §5.6 |
| 残機 | `GameState.start_lives()`（KIDS=5 / ADULT=3） | 自前カウンタにコピー |
| ステージ数 | KIDS=3 / ADULT=5（最終はボス面） | ブロック崩し独自（`GameState.max_stages()` は使わない） |
| アイテムドロップ率 | 破壊可能ブロック撃破で 12% | 1 画面同時上限 3 個 |
| アイテム持続 | SLOW/THRU=8 秒、EXPAND=残ライフ間 | |
| コンボ | パドルに触れず連続破壊で倍率（×1→×2→…）。パドル接触でリセット | スコア稼ぎ |
| ボス HP | ADULT=40 / KIDS=22 | `bullet_speed_mul` 同様 KIDS 緩和 |
| ボス移動 | 上部で左右往復 45 px/s | |
| ボス攻撃 | 1.6 秒ごとに落下弾。命中でパドル 3 秒縮小（残機減らさない） | 理不尽死回避 |
| ボス撃破ボーナス | +5000 | |

> §5 のコード骨子内の個別数値は「例」。最終値は本表を正とする。

---

## 1. ゲーム設計（仕様）

### 1.1 コンセプト
パドルでボールを打ち返し、上部のブロックを全消ししてステージクリア。最終ステージはボス。ボールを底に落とすとミス（残機 −1）、残機 0 でゲームオーバー。

### 1.2 状態遷移
```
[BreakoutTitle] --決定--> [Breakout(Game)] --残機0--> [BreakoutOver] --3秒/決定--> [BreakoutTitle]
       |--放置12秒--> デモ(任意)                      ^
       └ C キー: STG KeyConfig（任意）                |
[Breakout] --全ステージクリア--> ALL CLEAR 表示 ------┘
```
※ STG の Title.tscn には戻らない（独立フロー）。

### 1.3 パドル（Paddle）
- `move_left`/`move_right` で横移動。可動域 X∈[8+half_w, 248−half_w]。
- アイテムで一時拡張（EXPAND）/ 縮小（ボス被弾）。
- `Area2D`（mask=ITEM）で落下アイテムを取得。

### 1.4 ボール（Ball）
- パドルに「くっついた」状態で開始 → `shoot` で発射。
- 反射: 左右上の壁、パドル、ブロック、ボス。底（Y>244）で `lost`。
- サブステップ CCD（§6）。複数同時所持（MULTI で分裂）に対応。

### 1.5 ブロック（Block）
- 種別: 通常（1HP・色＝得点）/ 硬い H（2HP・ヒットで色変化）/ 鋼鉄 K（不壊・反射のみ）。
- 破壊で得点・エフェクト・抽選ドロップ。残数 0（K を除く）でステージクリア。

### 1.6 得点
- 通常ブロック: `base = 10 + (最下行からの段数)×10`（上段ほど高い）。
- 硬いブロック: 上記 +20、最初のヒットでも小加点（+5）。
- コンボ倍率: 連続破壊数に応じ `score × combo`（パドル接触で combo=1 にリセット）。
- ボス: ヒット +50、撃破 +5000。

### 1.7 パワーアップ（落下アイテム）
| 記号 | 種別 | 効果 |
|---|---|---|
| E | EXPAND | パドル幅 +16（上限 64）。残ライフ間持続 |
| M | MULTI | 現存ボールを各 3 分裂（上限 8 個） |
| S | SLOW | 全ボール速度 0.6×（8 秒） |
| T | THRU | ボールが破壊可能ブロックを貫通（反射せず連鎖破壊、8 秒） |
| U | 1UP | 残機 +1 |

- ブロック破壊時に抽選（12%）。種別は均等抽選。
- パドルで受けると取得。SE `powerup`。落下中に底へ落ちたら消滅。

### 1.8 ボス（最終ステージ）
- ブロックの上に大型ボス（PixelArt `boss3` 流用＝赤・巨大）。
- 上部を左右往復。ボール命中で HP −1、HP ゲージ表示。
- 1.6 秒ごとに落下弾（PixelArt `ebullet` 流用）。パドル命中で 3 秒間パドル縮小（残機は減らさない）。
- HP 0 で連続爆発 → +5000 → ステージクリア（=ALL CLEAR）。

### 1.9 演出
- スクリーンシェイク（ミス・ブロック破壊・ボス撃破）。
- 破壊パーティクル（PixelArt `spark`/`exp0..2` 流用、`World/FX` に生成しトゥイーンで消す）。
- 中央メッセージ（「ステージ 1」「ステージクリアー！」「オールクリアー！」「ゲームオーバー」）。
- BGM: 通常面 `stage`、ボス面 `boss`。

### 1.10 HUD（専用・GameState 非依存）
- スコア / ハイスコア / 残機 / ステージ / コンボ / ボス HP ゲージ / 操作ヘルプ（「← → うごく  J はっしゃ」）。
- `GameState` のシグナルには繋がない。`breakout.gd` が直接 Label を更新。

---

## 2. ファミコン風（流用）
- ビューポート 256×240・integer・Nearest は `project.godot` 既存設定をそのまま使用（変更不要）。
- フォントは既存テーマの misaki。色は NES 風（PixelArt の PAL と同系統）。
- 追加のプロジェクト設定変更は**なし**。

## 3. 入力（流用）
| アクション | 用途 | 備考 |
|---|---|---|
| `move_left` / `move_right` | パドル移動 | 既存 |
| `shoot` | ボール発射 / キャッチ放出 | 既存（キーボード J / パッド B） |
| `move_up` / `move_down` | タイトルの難易度選択 | 既存 |
| `pause` | ポーズ | 既存 |

追加バインドなし。直接キーコード参照はしない（タイトルの C キー＝STG KeyConfig 遷移のみ例外、既存踏襲）。

---

## 4. アーキテクチャ / シーン構成

### 4.1 シーンツリー（Breakout.tscn 実行中）
```
Breakout (Node2D)            [breakout.gd]  ← 進行・状態・HUD更新・shake
├── BG (ColorRect)           背景色（ステージで可変）
├── World (Node2D)           ← shake 対象。子に paddle/ball/block/item/boss
│   └── FX (Node2D)          爆発・スパーク
├── HUD (CanvasLayer)        ← breakout.gd が直接 Label/Bar を更新
│   ├── Score / HiScore / Lives / Stage / Combo (Label)
│   ├── BossBarBack / BossBar (ColorRect)
│   ├── CenterMsg (Label)
│   └── Help (Label)
```

### 4.2 ファイル一覧
```
scenes/breakout/
├── BreakoutTitle.tscn       難易度選択・ハイスコア・操作説明
├── Breakout.tscn            ゲーム本体（上記ツリー）
└── BreakoutOver.tscn        スコア表示 → BreakoutTitle へ
scripts/breakout/
├── breakout_title.gd        Node2D
├── breakout.gd              Node2D（ルート。ステージデータ const も保持）
├── breakout_over.gd         Node2D
├── bk_paddle.gd             Area2D（preload, class_name なし）
├── bk_ball.gd               Node2D
├── bk_block.gd              Node2D
├── bk_item.gd               Area2D
└── bk_boss.gd               Node2D
```

> `class_name` は STG 側（Player/Enemy/Boss 等）との衝突を避けるため**付けない**。相互参照は `preload()` で行う。

### 4.3 衝突レイヤー（最小利用）
- 自前幾何判定が主。**物理エンジンの当たり判定はアイテム取得のみ**に使う。
- パドル: `Area2D`、layer=`L_PLAYER`、mask=`L_ITEM`。
- アイテム: `Area2D`、layer=`L_ITEM`、mask=0（パドル側から拾う）。`area_entered` で取得。
- ボール / ブロック / ボス: `Node2D`（当たりは `breakout.gd` 集約の幾何判定）。

### 4.4 GameState 非干渉ポリシー（重要）
- **読むだけ**: `difficulty`, `Diff`, `is_demo`, `start_lives()`, `bullet_speed_mul()`。
- **書かない**: `score`/`lives`/`power_level`/`hi_score` に触れない。`add_score`/`lose_life`/`reset_run` は**呼ばない**。
- ブロック崩しの `score`/`lives`/`hi_score` は `breakout.gd` のメンバ変数。ハイスコアは `user://save.cfg` `[breakout] hi=` に保存。

---

## 5. 実装詳細（コード骨子）

> 数値は §0.5 を正とする。骨子は要点のみ。

### 5.1 ルート `breakout.gd`（抜粋）
```gdscript
extends Node2D
const Paddle := preload("res://scripts/breakout/bk_paddle.gd")
const Ball   := preload("res://scripts/breakout/bk_ball.gd")
const Block  := preload("res://scripts/breakout/bk_block.gd")
const Item   := preload("res://scripts/breakout/bk_item.gd")
const Boss   := preload("res://scripts/breakout/bk_boss.gd")

const SAVE_PATH := "user://save.cfg"
var score := 0
var hi := 0
var lives := 3
var combo := 1
var stage := 1
var balls: Array = []      # 現存ボール
var blocks: Array = []     # 破壊可能 + 鋼鉄。クリア判定は breakable のみ数える
var _remaining := 0        # 破壊可能ブロック残数
var boss = null
var _trauma := 0.0
var _trans := false

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    lives = GameState.start_lives()
    _load_hi()
    _start_stage(1)
```
- ステージ進行・残数管理・スコア/コンボ・HUD 更新・shake・ボス制御をここに集約。
- ボールはブロック衝突判定のために**親（breakout）の API** を呼ぶ:
  - `func ball_hit_blocks(pos, r, thru) -> Dictionary`（最近接ブロックの法線等を返す）
  - `func notify_paddle_touch()`（combo リセット）
  - `func ball_lost(ball)` / `func spawn_split(...)`（MULTI）

### 5.2 パドル `bk_paddle.gd`（抜粋）
```gdscript
extends Area2D
var half_w := 16.0
var base_half := 16.0
func _physics_process(d):
    var dir := 0.0
    if not GameState.is_demo:
        dir = Input.get_axis("move_left", "move_right")
    position.x = clampf(position.x + dir*175.0*d, 8.0+half_w, 248.0-half_w)
func hit_offset(bx): return clampf((bx-position.x)/half_w, -1.0, 1.0)
func _on_area_entered(a):    # アイテム取得
    if a.has_method("pickup"): a.pickup()
```
- EXPAND/縮小は `half_w` を変え `queue_redraw()` + CollisionShape を更新。

### 5.3 ボール `bk_ball.gd` ―― 反射の核（§6 と対）
```gdscript
extends Node2D
const R := 3.0
var velocity := Vector2.ZERO
var speed := 116.0
var base := 116.0
var stuck := true
var thru := false
var _root          # breakout
var _paddle
signal lost

func _physics_process(d):
    if stuck:
        global_position = Vector2(_paddle.position.x, _paddle.position.y-8.0); return
    var steps := 1 + int(velocity.length()*d / R)   # 1 ステップ移動 < 半径
    var sub := d/steps
    for _i in steps:
        position += velocity*sub
        _walls()
        _paddle_bounce()
        _root.ball_hit_blocks(self)   # ブロック/ボス反射 + ダメージ
        if position.y - R > 244.0:
            lost.emit(); return

func bounce(n: Vector2):               # 法線 n（正規化）で反射、近づく時のみ
    if velocity.dot(n) < 0.0:
        velocity = velocity.bounce(n)
        _accelerate(); _enforce_min_vy()
```
- `bounce(n)`・`_enforce_min_vy()`（最小垂直成分）・`_accelerate()`（加速上限）を持つ。
- 円-AABB の最近接点計算は `breakout.gd` 側のブロック走査で行い、法線を ball に渡して `bounce()`。

### 5.4 ブロック `bk_block.gd`（抜粋）
```gdscript
extends Node2D
var rect: Rect2          # World 座標の当たり矩形（16×8）
var hp := 1
var breakable := true    # K=false
var score := 50
var color := Color.WHITE
func hit() -> bool:       # true=破壊された
    if not breakable: return false
    hp -= 1
    if hp <= 0: return true
    color = color.lightened(0.25); queue_redraw(); return false
```

### 5.5 アイテム `bk_item.gd` / ボス `bk_boss.gd`
- Item: 種別（E/M/S/T/U）を持ち 70 px/s で落下。`pickup()` で `_root.apply_item(kind)`。画面下で消滅。テクスチャは PixelArt `item`（色を種別で tint）。
- Boss: PixelArt `boss3`、左右往復・落下弾・HP・被弾ヒット判定（breakout から `boss_hit()`）・撃破演出。

### 5.6 ステージデータ（`breakout.gd` 内 const）
```gdscript
const COLORS := { "R":..., "O":..., "Y":..., "G":..., "C":..., "B":..., "P":... }  # 得点色
# 特殊: "H"=硬い(2HP) "K"=鋼鉄(不壊) "."=空
const STAGES := [
  # stage1: 全面
  {"layout":[...], "boss":false, "bg":Color(...)},
  # stage2: 隙間/硬いブロック
  {"layout":[...], "boss":false, "bg":Color(...)},
  # stage3: 鋼鉄混じり
  {"layout":[...], "boss":false, "bg":Color(...)},
  # ...（ADULT は 4 面追加）...
  # 最終: ボス面（ブロック少 + boss=true）
  {"layout":[...], "boss":true,  "bg":Color(...)},
]
```
- KIDS は先頭 3 要素（最後がボス面）/ ADULT は 5 要素を使用。

### 5.7 ブロック配置
- 1 行 = 文字列。`.` 空、その他は COLORS or 特殊。1 文字 = 16 px。
- `start_x = (256 - cols*16)/2 + 8` で中央寄せ。`y = 40 + row*8`。
- `rect = Rect2(x-8, y-4, 16, 8)`（中心基準）。`breakable && hp>0` を残数に数える。

---

## 6. 物理：ボール反射アルゴリズム（最重要）

### 6.1 サブステップ連続衝突（CCD）
1 フレームの移動量がボール直径を超えるとブロックをすり抜ける。`steps = 1 + floor(|v|·dt / R)` に分割し、各サブステップで「移動 → 壁 → パドル → ブロック/ボス」の順に判定。

### 6.2 円-AABB 反射
ブロック矩形 `rect`、ボール中心 `C`、半径 `R`:
```
closest = C.clamp(rect.position, rect.end)
delta   = C - closest
dist    = delta.length()
if dist > R: 当たっていない
if dist > ε:
    n = delta / dist                      # 外向き法線
else:                                      # 中心が矩形内（深いめり込み）
    # 各面までの貫通量を比較し最小軸で押し出す
    n = 最小貫通軸の単位ベクトル
C = closest + n*R                          # めり込み解消（ボールを面外へ）
if v·n < 0: v = v.bounce(n)                # 近づいている時のみ反射（多重反射防止）
```
- **多重反射防止**: `v·n < 0` ガードで、同じ面を 2 回弾かない。
- **複数同時ヒット**: サブステップ内で全ブロックを走査し、`dist` 最小（最深）の 1 個を処理 → 次サブステップで残りを処理。1 フレームに複数破壊もこの繰り返しで自然に解決。
- **角の処理**: `closest` が角点になり `n` が対角線方向 → 自然に角反射。

### 6.3 パドル反射
```
if ball が paddle 矩形に重なり and v.y > 0:
    off = paddle.hit_offset(ball.x)        # -1..1
    a   = deg_to_rad(off * 60)
    v   = Vector2(sin(a), -cos(a)) * speed # 常に上向き
    速度加算・最小角適用・combo リセット
```

### 6.4 壁・底・最小角
- 左 x<8 / 右 x>248 / 上 y<8: 該当軸の符号反転（`v·n<0` ガード）。SE `cursor`。
- 底 y−R>244: `lost`。
- 最小垂直成分: `|v.y| < speed*0.28` なら `v.y` を符号付きで持ち上げ、`v = v.normalized()*speed` で再正規化（水平無限往復を防止）。

### 6.5 THRU（貫通）
- `thru==true` の間、破壊可能ブロックは**反射せず破壊のみ**（鋼鉄 K は反射する）。ボスは常に反射。

---

## 7. 音（流用）
- `AudioManager.play_se("cursor")` 壁/パドル反射、`"explosion"` ブロック/ボス破壊、`"powerup"` アイテム取得、`"miss"` 落球、`"shot"` 発射。
- `play_bgm("stage")` 通常面 / `play_bgm("boss")` ボス面 / `stop_bgm()` クリア・オーバー。
- 追加音源の作成は不要。

---

## 8. ハイスコア永続化（STG 非干渉）
```gdscript
func _load_hi():
    var c := ConfigFile.new()
    if c.load(SAVE_PATH) == OK: hi = int(c.get_value("breakout", "hi", 0))
func _save_hi():
    var c := ConfigFile.new(); c.load(SAVE_PATH)   # 既存（STG の score）を保持
    c.set_value("breakout", "hi", hi); c.save(SAVE_PATH)
```
- STG は `[score] hi=`、ブロック崩しは `[breakout] hi=`。同ファイル・別セクションで衝突しない。

---

## 9. マイルストーン

各 M 末で「実行して遊べる」状態にする。

### BM0 ―― 基盤クリーンアップ
- [ ] 欠陥 `make_breakout.ps1` を削除。
- [ ] 壊れた `scripts/breakout/breakout.gd`・`scenes/breakout/Breakout.tscn` を本計画で作り直す前提に。
- **完了条件**: 旧生成物が正しい構成に置き換わる準備が整う。

### BM1 ―― コア（パドル・ボール・ブロック）
- [ ] Breakout.tscn（World/HUD/BG）、breakout.gd、bk_paddle、bk_ball、bk_block。
- [ ] サブステップ CCD + 円-AABB 反射（§6）。パドル端で角度変化。
- [ ] 1 面分のブロック配置、全消しでクリア、落球でミス、残機。
- **完了条件**: パドルでボールを打ち返しブロックを全部消せる／落とすとミス。

### BM2 ―― ゲームフロー・HUD・複数ステージ
- [ ] BreakoutTitle（KIDS/ADULT 選択・ハイスコア）／ BreakoutOver。
- [ ] 専用 HUD（スコア/ハイスコア/残機/ステージ/コンボ/中央メッセージ/ヘルプ）。
- [ ] 複数ステージ（KIDS3/ADULT5）、ステージクリア演出、ALL CLEAR、ハイスコア保存。
- [ ] SE/BGM 接続、スクリーンシェイク、破壊パーティクル。
- **完了条件**: タイトル→数面プレイ→クリア/オーバー→タイトルが一周する。

### BM3 ―― 特殊ブロック・パワーアップ
- [ ] 硬いブロック H（2HP・色変化）、鋼鉄 K（不壊・クリア除外）。
- [ ] 落下アイテム 5 種（E/M/S/T/U）、抽選ドロップ、パドル取得、効果適用。
- [ ] MULTI のマルチボール、THRU 貫通、SLOW 減速、EXPAND 拡張、1UP。
- **完了条件**: ブロック耐久差とアイテム強化が機能する。

### BM4 ―― ボス・仕上げ
- [ ] 最終面ボス（往復・HP ゲージ・落下弾でパドル一時縮小・撃破演出 +5000）。
- [ ] コンボ倍率、放置デモ（任意）、難易度バランス調整。
- **完了条件**: 最終面でボスを倒すと ALL CLEAR → タイトル。

---

## 10. テスト方針
- 手動: 各 M の完了条件を Godot 実機（PC）で確認。
- 重点検証: ①高速ボールのすり抜けゼロ ②角・複数同時ヒットで挙動破綻なし ③水平ループに陥らない ④STG 側のスコア/ハイスコアが汚れない（save.cfg のセクション分離）。
- 構文: Godot 実行ファイルがあれば `--check-only` でスクリプト検査、無ければエディタ起動時のパースで確認。

## 11. STG への影響（保証）
- 変更ファイルは `scenes/breakout/*`・`scripts/breakout/*`・`docs/BREAKOUT_PLAN.md` のみ。
- `project.godot`（main_scene 含む）・autoload・STG の各シーン/スクリプトは**無改変**。
- 共有 `user://save.cfg` はセクション分離で非干渉。
