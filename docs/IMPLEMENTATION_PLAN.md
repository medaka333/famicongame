# ファミコン風 縦スクロールシューティング ―― 実装計画書

最終更新: 2026-05-31

---

## 0. 確定事項（この計画の前提）

| 項目 | 決定 | 補足 |
|---|---|---|
| エンジン | **Godot 4.x**（4.3 以降推奨） | GDScript。無料・2D に強い・エクスポート容易 |
| 言語 | GDScript | C# も可だが本計画は GDScript 前提 |
| ジャンル | 縦スクロールシューティング | 自機が上方向へ進む（スターソルジャー／ゼビウス系） |
| 参考元 | **スターソルジャー**（主軸）＋ **ツインビー**（パワーアップ演出） | 数値・仕様の根拠 → §0.5 |
| 解像度 | **256 × 240**（NES 実解像度） | 整数倍スケールでウィンドウ表示 |
| 配色 | **NES 54 色パレット**に縛る | アセット制作時にパレット固定 |
| 再現方針 | 見た目は最大限 NES 寄せ／**ハード制約の厳密エミュは行わない** | スプライト 8 枚制限・CHR バンク等は再現しない＝実装を軽くする |
| 第1マイルストーン | **MVP + パワーアップ**（ボスは後回し） | 自機・敵・弾・当たり判定・爆発・スコア・ゲームオーバー・パワーアップ |
| 入力 | キーボード（初期）→ ファミコンパッド（将来 / USB-HID） | 最初から InputMap 抽象化し、後で差すだけにする |
| 配布 | まず Windows .exe / 将来 Web エクスポートも可 | Web なら Gamepad もブラウザ経由で動作 |

### 設計の背骨（3 原則）
1. **入力は必ず InputMap アクション経由**。スクリプト内でキーコードを直接参照しない → ファミコンパッド対応が「バインド追加」だけで済む。
2. **データ駆動**。敵・弾・ウェーブ・ステージを Resource（`.tres`）で定義 → 複数ステージ拡張時にコードを増やさない。
3. **小さく動かして積む**。マイルストーンごとに「遊べる状態」を保つ。

---

## 0.5 参考作品と確定数値

### 参考元
**スターソルジャー（Hudson, 1986 / NES）を主軸**、パワーアップ演出は**ツインビー（Konami, 1985）**を参照。

スターソルジャーから採用:
- **1 ボタン + オート連射**。デフォルトは遅いオート連射 → **最初のパワーアップ取得で連射が大幅高速化**（本作の肝）。
- 自機「シーザー(Caesar)」、8 方向移動、敵は画面上から出現。
- **P マークを撃つ → カプセル出現 → 取得で弾威力アップ**（集めるほど強化）。
- **潜行(dive)**: 背景に潜ると敵弾・接触が無効（撃てない／取得不可）。→ 本作の `special`(A ボタン) 枠を将来「潜行」に割当。
- 16 ステージ・2 種ボス交互 → 将来のステージ構成の参考。

ツインビーから採用（主に将来拡張）:
- 段階パワーアップ: 白=2 門 / 青=スピード(5 段) / 緑=分身(オプション) / 赤=バリア。
- ベル連鎖（100→10000 点）= 将来のスコア稼ぎ要素。

MVP への落とし込み:
- ショット = **オート連射（スターソルジャー式）**。アイテム取得ごとに連射速度↑・弾数↑・威力↑（Lv0→1→2）。
- アイテム出現 = MVP は**敵ドロップ**（実装が簡単）。将来 P マーク方式へ。
- 潜行・分身・スピード・バリア・ベル連鎖 = 将来マイルストーン。

### 確定数値（実装の単一情報源 = これを正とする）
| 項目 | 値 | 備考 |
|---|---|---|
| 解像度 / FPS | 256×240 / 60 | NES 準拠 |
| 自機スプライト | 16×16 | 2×2 タイル相当 |
| 弾スプライト | 8×8 | |
| 雑魚敵 | 16×16 | 中型 16×24 / ボス（将来）32×32〜 |
| 自機速度 | **140 px/s** | 8 方向。キビキビ移動 |
| 自機弾速度 | **-300 px/s** | 上方向。速め |
| オート連射間隔 | **Lv0:0.18 / Lv1:0.12 / Lv2:0.10 s** | 取得で高速化（スターソルジャー式） |
| ショット形状 | Lv0:1way / Lv1:2way / Lv2:3way | |
| 弾威力 | Lv0-1:1 / Lv2:2 | カプセル集積で威力↑ |
| パワー上限 | Lv2 | 将来引き上げ可 |
| 敵弾速度 | 140 px/s | |
| 背景スクロール | 40 px/s | 下方向へ流す |
| 残機 / 無敵時間 | 3 / 1.5 s | 被弾後点滅 |

> コード骨子（§5）内の個別数値は「例」。最終値は本表を正とする。

---

## 1. ゲーム設計（仕様）

### 1.1 コンセプト
- 自機が画面下部、上方向にスクロールする戦場を進む。
- 雑魚敵がウェーブ単位で出現。撃破でスコア加算。
- 一部の敵がパワーアップアイテムをドロップ。取得で攻撃力アップ。
- 被弾で残機減少 → 0 でゲームオーバー。
- ボスは将来マイルストーンで各ステージ末に追加。

### 1.2 プレイフィールド座標
- 論理解像度 256×240。原点 (0,0) は左上、+Y が下。
- 自機可動域: おおよそ X∈[8, 248]、Y∈[8, 232]（端 8px はマージン）。
- 上方向スクロール演出は「背景が下へ流れる」で表現（自機 Y は基本固定〜半固定）。

### 1.3 自機（Player）
- 8 方向移動（十字キー／スティック相当）。
- ショット: B ボタン押しっぱなしで連射（クールダウン制御）。
- パワーレベルに応じてショット形状変化（1way → 2way → 3way）。
- 被弾 → 1 ミス → 短時間の無敵＋点滅 → 復帰。残機 0 でゲームオーバー。
- （将来）A ボタン = ボム／特殊攻撃の枠を確保。

### 1.4 敵（Enemy）
- `EnemyDef` リソースで定義: HP・速度・移動パターン・射撃パターン・スコア・スプライト・ドロップ率。
- 移動パターン例: 直進／横振り（サイン）／追尾／編隊。
- 撃破時: 爆発エフェクト生成 → スコア加算 → 抽選でアイテムドロップ。

### 1.5 弾（Bullet）
- プレイヤー弾・敵弾を分離（衝突レイヤーで区別）。
- 画面外で自動消滅。大量発生に備えオブジェクトプール（§6）。

### 1.6 パワーアップ
- アイテム種別（初期）: `POWER`（ショット強化）。将来 `SPEED`／`OPTION`（オプション/子機）／`BOMB`。
- 取得でパワーレベル +1（上限あり）。被弾でレベル据え置き or 1 段階ダウン（要調整、初期は据え置き）。

### 1.7 画面・状態遷移
```
[Title] --Start--> [Game] --死亡--> [GameOver] --Start/一定時間--> [Title]
                      |--Pause--> [Pause]（オーバーレイ）
```

### 1.8 HUD
- スコア・ハイスコア・残機・（将来）パワーゲージ／ボム数。
- フォントは NES 風ビットマップフォント（後述）。

---

## 2. 「ファミコン風」の作り方（見た目の核心）

### 2.1 低解像度ビューポート（プロジェクト設定）
`Project > Project Settings` で以下を設定（`project.godot` に記録される）:

| 設定キー | 値 | 意味 |
|---|---|---|
| `display/window/size/viewport_width` | `256` | 論理幅 |
| `display/window/size/viewport_height` | `240` | 論理高 |
| `display/window/size/window_width_override` | `1024` | 実ウィンドウ幅（4×） |
| `display/window/size/window_height_override` | `960` | 実ウィンドウ高（4×） |
| `display/window/stretch/mode` | `viewport` | 低解像度を引き伸ばす |
| `display/window/stretch/aspect` | `keep` | アスペクト固定（レターボックス） |
| `display/window/stretch/scale_mode` | `integer` | 整数倍のみ（にじみ防止 / Godot 4.2+） |
| `rendering/textures/canvas_textures/default_texture_filter` | `Nearest` | ドット絵をぼかさない |
| `physics/common/max_physics_steps_per_frame` 等 | 既定 | 60fps 基準 |

> 補足: `viewport` ストレッチにより、スクリプトは常に 256×240 座標系で書ける。実ウィンドウ解像度は気にしなくてよい。

### 2.2 NES パレット縛り
- NES の実用色は約 54 色（エミュレータにより 52〜56）。`resources/palettes/nes.gpl`（GIMP/Aseprite パレット）を用意。
- **アセット制作時に**パレットを固定（Aseprite の "Palette" を nes.gpl にロードしてインデックスカラーで描く）。
- ゲーム側で色を強制する必要はない（描いた時点で縛られているため）。背景色・UI 色も同パレットから選ぶ。

### 2.3 ドット絵アセット方針
- スプライトサイズの目安: 自機 16×16、雑魚 16×16、弾 8×8、爆発 16×16、ボス（将来）32×32〜。
- アニメは `AnimatedSprite2D` + `SpriteFrames`（点滅・爆発・敵の羽ばたき等）。
- 制作ツール: Aseprite 推奨（パレット縛り・アニメ・タイル）。無料なら LibreSprite / Piskel。
- 仮アセットで先に実装を進め、後で差し替え可能な構成にする（パスを定数化）。

### 2.4 任意の追加演出（後回し可）
- スキャンライン／CRT シェーダー: 全画面 `ColorRect` + シェーダーで後付け。MVP では不要。
- 画面の微振動（被弾・爆発時のスクリーンシェイク）: カメラ or ルート Node2D のオフセットで実装。

### 2.5 「厳密エミュをしない」境界
- やらないこと: スプライト枚数上限・パレット 4 色/タイル制限・スキャンラインごとの色制限・NMI タイミング再現。
- やること: 見た目（解像度・配色・ドット・60fps・8bit 風 SE）の一致。
- → 結果: 見た目はファミコン、実装は現代的で軽い。

---

## 3. 入力システム（キーボード → ファミコンパッド）

### 3.1 InputMap アクション定義
`Project Settings > Input Map` に以下を作成。**キーボードとジョイパッドの両方を最初からバインド**しておく。

| アクション | キーボード | ジョイパッド（汎用） | 用途 |
|---|---|---|---|
| `move_up` | ↑ / W | D-Pad Up / 左スティック上 | 移動 |
| `move_down` | ↓ / S | D-Pad Down / 下 | 移動 |
| `move_left` | ← / A | D-Pad Left / 左 | 移動 |
| `move_right` | → / D | D-Pad Right / 右 | 移動 |
| `shoot` | Z | ボタン B 相当 | ショット |
| `special` | X | ボタン A 相当 | ボム（将来） |
| `pause` | Enter | Start | ポーズ |
| `ui_select_start` | Enter / Space | Start | 画面決定 |

> ファミコン実機ボタン配置: B(左) A(右) Select Start + 十字。USB アダプタはボタン番号が機種依存のため、初期は「それっぽい」割当 → §7 のリマップ画面で確定させる。

### 3.2 スクリプト側の読み方（直接キー参照しない）
```gdscript
# 移動: get_vector が -1..1 のベクトルを返す（4 アクションをまとめて処理）
var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

# ショット: 押しっぱなし判定
if Input.is_action_pressed("shoot"):
    ...

# 決定など: 押した瞬間
if Input.is_action_just_pressed("pause"):
    ...
```

### 3.3 ファミコンパッド対応の布石（今やること）
- すべての入力をアクション経由にする（§3.2）。
- アクションにジョイパッドのデフォルトイベントを入れておく。
- `InputManager`（オートロード）にリマップ用 API を用意（実画面化は §7 / M6）。
- → これだけで、ファミコンパッド接続時は「ボタン番号を合わせる」作業に限定される。

---

## 4. アーキテクチャ / シーン構成

### 4.1 オートロード（シングルトン）
`Project Settings > Autoload` に登録:

| 名前 | スクリプト | 責務 |
|---|---|---|
| `GameState` | `scripts/autoload/game_state.gd` | スコア・ハイスコア・残機・パワーレベル・状態フラグ。シグナル発火源 |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | SE/BGM 再生、同時再生プール |
| `InputManager` | `scripts/autoload/input_manager.gd` | デバイス検出、リマップ、設定保存 |
| `BulletPool` | `scripts/autoload/bullet_pool.gd` | 弾の使い回しプール（§6） |
| `Const` | `scripts/autoload/const.gd` | 衝突レイヤー定数・グループ名・パス定数 |

### 4.2 シーンツリー（Game 実行中）
```
Game (Node2D)
├── Background (ParallaxBackground or 自前スクロール)
├── EnemyContainer (Node2D)        # 敵をここに add_child
├── BulletContainer (Node2D)       # 弾をここに add_child
├── ItemContainer (Node2D)         # アイテム
├── FXContainer (Node2D)           # 爆発など
├── Player (Area2D)
├── WaveDirector (Node)            # ウェーブ進行・敵スポーン
└── HUD (CanvasLayer)              # UI は CanvasLayer で常に最前面
```

### 4.3 衝突レイヤー設計
Godot のレイヤーは 1〜32 のビット。以下を `Const` に定数化し、各ノードの layer/mask をエディタ or コードで設定。

| ビット | レイヤー名 | 配置するもの |
|---|---|---|
| 1 | `PLAYER` | 自機の被弾判定 |
| 2 | `PLAYER_BULLET` | 自機弾 |
| 3 | `ENEMY` | 敵本体 |
| 4 | `ENEMY_BULLET` | 敵弾 |
| 5 | `ITEM` | アイテム |

マスク（何と当たるか）:
- 自機(PLAYER): mask = ENEMY | ENEMY_BULLET | ITEM
- 自機弾(PLAYER_BULLET): mask = ENEMY
- 敵(ENEMY): mask =（自機弾はプレイヤー弾側で検知するなら不要 / 接触ダメージ用に PLAYER）
- 敵弾(ENEMY_BULLET): mask = PLAYER
- アイテム(ITEM): mask = PLAYER

> 方針: 当たり判定は **Area2D の `area_entered` シグナル**で取る（CharacterBody より軽く、弾幕向き）。

### 4.4 グループ
- `enemies` / `player_bullets` / `enemy_bullets` / `items` をグループ登録。一括処理（画面クリア時の `get_tree().call_group(...)`）に使う。

---

## 5. 各機能の実装詳細（コード骨子）

> 以下はスケルトン。数値は目安（256×240 / 60fps 基準、px・px/sec）。`@export` で後から調整可能にする。

### 5.1 定数（`const.gd`）
```gdscript
extends Node
# 衝突レイヤー（1-indexed のビット番号）
const L_PLAYER        := 1
const L_PLAYER_BULLET := 2
const L_ENEMY         := 3
const L_ENEMY_BULLET  := 4
const L_ITEM          := 5

# グループ名
const G_ENEMIES := "enemies"
const G_ITEMS   := "items"

# プレイフィールド
const FIELD_MIN := Vector2(8, 8)
const FIELD_MAX := Vector2(248, 232)
```

### 5.2 GameState（`game_state.gd`）
```gdscript
extends Node

signal score_changed(value: int)
signal hiscore_changed(value: int)
signal lives_changed(value: int)
signal power_changed(value: int)
signal game_over

var score: int = 0
var hi_score: int = 0
var lives: int = 3
var power_level: int = 0          # 0..MAX_POWER
const MAX_POWER := 2

func reset_run() -> void:
    score = 0
    lives = 3
    power_level = 0
    score_changed.emit(score)
    lives_changed.emit(lives)
    power_changed.emit(power_level)

func add_score(amount: int) -> void:
    score += amount
    score_changed.emit(score)
    if score > hi_score:
        hi_score = score
        hiscore_changed.emit(hi_score)

func add_power() -> void:
    power_level = min(power_level + 1, MAX_POWER)
    power_changed.emit(power_level)

func lose_life() -> void:
    lives -= 1
    lives_changed.emit(lives)
    if lives <= 0:
        game_over.emit()
```

### 5.3 Player（`player.gd`、ルート = Area2D）
```gdscript
extends Area2D
class_name Player

@export var speed: float = 140.0          # px/sec（スターソルジャー基準: §0.5）
@export var invincible_time: float = 1.5
const FIRE_COOLDOWN := [0.18, 0.12, 0.10] # 連射間隔 Lv0/Lv1/Lv2（取得で高速化・§0.5）

@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _fire_timer: float = 0.0
var _invincible: bool = false

func _ready() -> void:
    collision_layer = 1 << (Const.L_PLAYER - 1)
    collision_mask  = (1 << (Const.L_ENEMY - 1)) \
                    | (1 << (Const.L_ENEMY_BULLET - 1)) \
                    | (1 << (Const.L_ITEM - 1))
    area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    position += dir * speed * delta
    position = position.clamp(Const.FIELD_MIN, Const.FIELD_MAX)

    _fire_timer -= delta
    if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
        _fire_timer = FIRE_COOLDOWN[clampi(GameState.power_level, 0, 2)]
        _shoot()

func _shoot() -> void:
    var p := GameState.power_level
    match p:
        0: _spawn_bullet(Vector2(0, -260))
        1:
            _spawn_bullet_at(muzzle.global_position + Vector2(-4, 0), Vector2(0, -260))
            _spawn_bullet_at(muzzle.global_position + Vector2( 4, 0), Vector2(0, -260))
        _:
            _spawn_bullet(Vector2(0, -260))
            _spawn_bullet(Vector2(-60, -250))
            _spawn_bullet(Vector2( 60, -250))
    AudioManager.play_se("shot")

func _spawn_bullet(vel: Vector2) -> void:
    _spawn_bullet_at(muzzle.global_position, vel)

func _spawn_bullet_at(pos: Vector2, vel: Vector2) -> void:
    BulletPool.spawn_player_bullet(pos, vel)

func _on_area_entered(area: Area2D) -> void:
    if _invincible:
        return
    if area.is_in_group(Const.G_ITEMS):
        area.pickup()          # アイテム取得
        return
    # 敵 or 敵弾 → 被弾
    _hit()

func _hit() -> void:
    GameState.lose_life()
    if GameState.lives > 0:
        _start_invincible()
    else:
        # ゲームオーバー処理は GameState.game_over シグナル受信側で

func _start_invincible() -> void:
    _invincible = true
    # 点滅
    var t := create_tween().set_loops(int(invincible_time / 0.1))
    t.tween_property(sprite, "modulate:a", 0.2, 0.05)
    t.tween_property(sprite, "modulate:a", 1.0, 0.05)
    await get_tree().create_timer(invincible_time).timeout
    _invincible = false
    sprite.modulate.a = 1.0
```

### 5.4 Bullet（`bullet.gd`、ルート = Area2D）+ プール
```gdscript
extends Area2D
class_name Bullet

var velocity: Vector2 = Vector2.ZERO
var is_player_bullet: bool = true
var _active: bool = false

func activate(pos: Vector2, vel: Vector2, player_side: bool) -> void:
    global_position = pos
    velocity = vel
    is_player_bullet = player_side
    var layer := Const.L_PLAYER_BULLET if player_side else Const.L_ENEMY_BULLET
    var target := Const.L_ENEMY if player_side else Const.L_PLAYER
    collision_layer = 1 << (layer - 1)
    collision_mask  = 1 << (target - 1)
    _active = true
    show()
    set_physics_process(true)

func _physics_process(delta: float) -> void:
    global_position += velocity * delta
    if not _on_screen():
        _despawn()

func _on_screen() -> bool:
    var r := Rect2(Vector2(-16, -16), Vector2(256 + 32, 240 + 32))
    return r.has_point(global_position)

func _ready() -> void:
    area_entered.connect(_on_hit)

func _on_hit(area: Area2D) -> void:
    if is_player_bullet and area.has_method("take_damage"):
        area.take_damage(1)
        _despawn()
    elif not is_player_bullet:
        _despawn()   # 自機側の被弾判定は Player 側で処理

func _despawn() -> void:
    _active = false
    hide()
    set_physics_process(false)
    BulletPool.recycle(self)
```

### 5.5 EnemyDef（`enemy_def.gd`、カスタム Resource）
```gdscript
extends Resource
class_name EnemyDef

@export var id: String = "grunt"
@export var max_hp: int = 1
@export var speed: float = 50.0
@export var score: int = 100
@export var frames: SpriteFrames                # 見た目
@export_enum("straight", "sine", "homing") var move_pattern: String = "straight"
@export var fire_interval: float = 0.0          # 0 なら撃たない
@export var item_drop_chance: float = 0.0       # 0..1
```

### 5.6 Enemy（`enemy.gd`、ルート = Area2D）
```gdscript
extends Area2D
class_name Enemy

@export var def: EnemyDef
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _hp: int
var _t: float = 0.0
var _fire_t: float = 0.0
var _base_x: float

func setup(d: EnemyDef, pos: Vector2) -> void:
    def = d
    position = pos

func _ready() -> void:
    add_to_group(Const.G_ENEMIES)
    collision_layer = 1 << (Const.L_ENEMY - 1)
    collision_mask  = 0   # 当たりは弾/自機側から検知
    _hp = def.max_hp
    _base_x = position.x
    if def.frames:
        sprite.sprite_frames = def.frames
        sprite.play("idle")
    _fire_t = def.fire_interval

func _physics_process(delta: float) -> void:
    _t += delta
    match def.move_pattern:
        "straight":
            position.y += def.speed * delta
        "sine":
            position.y += def.speed * delta
            position.x = _base_x + sin(_t * 3.0) * 24.0
        "homing":
            var p := get_tree().get_first_node_in_group("player")
            var dir := (p.global_position - global_position).normalized() if p else Vector2.DOWN
            position += dir * def.speed * delta

    if def.fire_interval > 0.0:
        _fire_t -= delta
        if _fire_t <= 0.0:
            _fire_t = def.fire_interval
            BulletPool.spawn_enemy_bullet(global_position, Vector2(0, 160))

    if position.y > 256:   # 画面下に抜けたら消す
        queue_free()

func take_damage(amount: int) -> void:
    _hp -= amount
    if _hp <= 0:
        _die()

func _die() -> void:
    GameState.add_score(def.score)
    FX.spawn_explosion(global_position)   # FX はオートロード or 親経由
    if randf() < def.item_drop_chance:
        ItemSpawner.drop_power(global_position)
    AudioManager.play_se("explosion")
    queue_free()
```

### 5.7 WaveDirector（`wave_director.gd`、敵スポーン進行）
```gdscript
extends Node
# 最小実装: 一定間隔で敵を湧かせる。後で WaveDef リソース駆動に置換。

@export var enemy_scene: PackedScene
@export var enemy_defs: Array[EnemyDef] = []
@export var spawn_interval: float = 1.2

var _t: float = 0.0

func _process(delta: float) -> void:
    _t -= delta
    if _t <= 0.0:
        _t = spawn_interval
        _spawn_one()

func _spawn_one() -> void:
    if enemy_defs.is_empty():
        return
    var d: EnemyDef = enemy_defs.pick_random()
    var e: Enemy = enemy_scene.instantiate()
    e.setup(d, Vector2(randf_range(16, 240), -16))
    get_parent().get_node("EnemyContainer").add_child(e)
```

> 将来: `WaveDef`（出現タイミング・敵種・座標の配列）→ `StageDef`（WaveDef の列 + 背景 + BGM）にデータ駆動化。コードは触らずリソース追加だけでステージが増える。

### 5.8 爆発 FX（`explosion.gd`、ルート = AnimatedSprite2D）
```gdscript
extends AnimatedSprite2D
func _ready() -> void:
    play("boom")
    animation_finished.connect(queue_free)
```

### 5.9 HUD（`hud.gd`、ルート = CanvasLayer）
```gdscript
extends CanvasLayer
@onready var score_label: Label = $Score
@onready var lives_label: Label = $Lives

func _ready() -> void:
    GameState.score_changed.connect(_on_score)
    GameState.lives_changed.connect(_on_lives)
    _on_score(GameState.score)
    _on_lives(GameState.lives)

func _on_score(v: int) -> void:
    score_label.text = "SCORE %06d" % v

func _on_lives(v: int) -> void:
    lives_label.text = "x%d" % v
```

---

## 6. オブジェクトプール（弾・敵の使い回し）

弾は毎フレーム大量生成・破棄され得る。`instantiate()`/`queue_free()` の連発は GC とノード生成コストを生む。事前生成 → 非アクティブ化で使い回す。

```gdscript
extends Node   # BulletPool オートロード
@export var bullet_scene: PackedScene
var _pool: Array[Bullet] = []
var _container: Node2D

func setup(container: Node2D, prewarm: int = 128) -> void:
    _container = container
    for i in prewarm:
        var b: Bullet = bullet_scene.instantiate()
        b.hide(); b.set_physics_process(false)
        _container.add_child(b)
        _pool.append(b)

func _take() -> Bullet:
    if _pool.is_empty():
        var b: Bullet = bullet_scene.instantiate()
        _container.add_child(b)
        return b
    return _pool.pop_back()

func spawn_player_bullet(pos: Vector2, vel: Vector2) -> void:
    _take().activate(pos, vel, true)

func spawn_enemy_bullet(pos: Vector2, vel: Vector2) -> void:
    _take().activate(pos, vel, false)

func recycle(b: Bullet) -> void:
    _pool.append(b)
```

> MVP の弾数が少なければプールなしでも動く。ただし最初から噛ませておくとパワーアップ／弾幕増加でも破綻しない。敵にも同パターンを適用可能。

---

## 7. 音（SE / BGM）

### 7.1 SE
- `AudioManager` に複数の `AudioStreamPlayer` を持たせ、空きを探して再生（同時発音）。
- 8bit 風 SE は **jsfxr / sfxr / Bfxr** でその場生成 → `.wav` 書き出し → `assets/audio/se/` に配置。
- 最低限: `shot`（自機ショット）、`explosion`（撃破）、`powerup`（取得）、`miss`（被弾）。

### 7.2 BGM（将来 / M5 以降）
- `FamiStudio`（無料・NES 音源そのもの）でループ曲を作成 → `.ogg`/`.wav` エクスポート。
- `AudioManager.play_bgm(stream, loop=true)`。ステージ切替でクロスフェード可。

```gdscript
extends Node   # AudioManager
var _se_players: Array[AudioStreamPlayer] = []
@onready var _bgm := AudioStreamPlayer.new()
var _se_table := {}    # name -> AudioStream

func _ready() -> void:
    add_child(_bgm)
    for i in 8:
        var p := AudioStreamPlayer.new(); add_child(p); _se_players.append(p)
    _se_table = {
        "shot": preload("res://assets/audio/se/shot.wav"),
        "explosion": preload("res://assets/audio/se/explosion.wav"),
        "powerup": preload("res://assets/audio/se/powerup.wav"),
        "miss": preload("res://assets/audio/se/miss.wav"),
    }

func play_se(name: String) -> void:
    if not _se_table.has(name): return
    for p in _se_players:
        if not p.playing:
            p.stream = _se_table[name]; p.play(); return

func play_bgm(stream: AudioStream) -> void:
    _bgm.stream = stream; _bgm.play()
```

---

## 8. ファミコンパッド対応（将来 / M6 で実装、布石は最初から）

### 8.1 接続の実際
- USB-NES アダプタ（8bitdo / RetroLink / 汎用アダプタ等）は **HID ゲームパッド**として OS に認識される。
- Godot 4 は内部で SDL のゲームコントローラ DB を使用。`Input.get_connected_joypads()` に出れば認識成功。
- 注意: 汎用アダプタは「標準ゲームパッド」として正しくマップされず、**ボタン番号が生（0,1,2…）**で来ることがある。十字キーが button だったり hat 軸だったりも機種依存。

### 8.2 対策 = リマップ画面
`InputManager`（オートロード）に動的バインド機能を持たせ、設定画面で「各アクションのボタンを実際に押して登録」させる。

```gdscript
extends Node   # InputManager
const ACTIONS := ["move_up","move_down","move_left","move_right","shoot","special","pause"]

func _ready() -> void:
    Input.joy_connection_changed.connect(_on_joy_changed)
    load_bindings()

func _on_joy_changed(device: int, connected: bool) -> void:
    print("joypad %d %s" % [device, "connected" if connected else "disconnected"])

# リマップ: 次に押されたジョイパッドイベントを action に割当
func start_rebind(action: String, event: InputEvent) -> void:
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        # 既存のジョイパッドイベントを消してから追加
        for e in InputMap.action_get_events(action):
            if e is InputEventJoypadButton or e is InputEventJoypadMotion:
                InputMap.action_erase_event(action, e)
        InputMap.action_add_event(action, event)
        save_bindings()

func save_bindings() -> void:
    # ConfigFile に device/button を書き出して永続化（略）
    pass

func load_bindings() -> void:
    pass
```

### 8.3 今やる布石（再掲）
1. 入力は全部アクション経由（§3.2）。
2. アクションにジョイパッドのデフォルトイベントを入れておく。
3. `InputManager` のリマップ API を先に用意（UI は M6）。
→ ファミコンパッドが来たら「設定画面で各ボタンを押して登録」で完了。

---

## 9. ディレクトリ構成

```
famicongame/
├── project.godot
├── docs/
│   └── IMPLEMENTATION_PLAN.md        # 本書
├── scenes/
│   ├── main/    Main.tscn  Game.tscn
│   ├── player/  Player.tscn
│   ├── enemies/ Enemy.tscn
│   ├── bullets/ Bullet.tscn
│   ├── items/   PowerUp.tscn
│   ├── fx/      Explosion.tscn
│   └── ui/      Title.tscn  GameOver.tscn  HUD.tscn  KeyConfig.tscn
├── scripts/
│   ├── autoload/  const.gd  game_state.gd  audio_manager.gd
│   │              input_manager.gd  bullet_pool.gd
│   ├── player/    player.gd
│   ├── enemies/   enemy.gd  enemy_def.gd
│   ├── bullets/   bullet.gd
│   ├── items/     power_up.gd
│   ├── fx/        explosion.gd
│   ├── ui/        hud.gd  title.gd  game_over.gd
│   └── stage/     wave_director.gd  wave_def.gd  stage_def.gd
├── resources/
│   ├── enemy_defs/   grunt.tres  diver.tres ...
│   ├── wave_defs/    stage1_waves.tres ...
│   └── palettes/     nes.gpl
└── assets/
    ├── sprites/   player.png  enemies.png  bullets.png  explosion.png
    ├── audio/     se/*.wav   bgm/*.ogg
    └── fonts/     nes_font.png（ビットマップフォント）
```

> Godot 慣習では `.tscn` と `.gd` を同フォルダに置く流儀もある。上記は「シーン」と「スクリプト」を分離した構成。どちらでも可。チームが自分一人なら好みで統一。

---

## 10. 開発ロードマップ（マイルストーン）

各マイルストーンの末で必ず「実行して遊べる／確認できる」状態にする。

### M0 ―― 環境構築（半日）
- [ ] Godot 4.x インストール、プロジェクト作成。
- [ ] §2.1 のビューポート設定（256×240 / integer / Nearest）。
- [ ] §3.1 の InputMap 全アクション登録（キーボード＋ジョイパッド両方）。
- [ ] オートロード（Const / GameState）の空実装を登録。
- [ ] Git リポジトリ初期化、`.gitignore`（Godot 用）、初回コミット。
- **完了条件**: 空の 256×240 画面が整数スケールで表示される。

### M1 ―― 自機（1〜2 日）
- [ ] Player.tscn（Area2D + AnimatedSprite2D + Marker2D + CollisionShape2D）。
- [ ] 8 方向移動 + 可動域クランプ。
- [ ] ショット（クールダウン連射、まず 1way）。Bullet.tscn + 直進・画面外消滅。
- [ ] 仮スプライトで可。
- **完了条件**: 自機を動かして弾を撃てる。

### M2 ―― 敵・当たり判定・爆発（2〜3 日）
- [ ] Enemy.tscn + `EnemyDef`（grunt.tres）。直進移動。
- [ ] WaveDirector で一定間隔スポーン。
- [ ] 自機弾 ↔ 敵の当たり判定（`take_damage` → 撃破）。
- [ ] 爆発 FX、撃破でスコア加算（GameState）。
- [ ] 敵 or 敵弾 ↔ 自機の被弾 → 残機減少 → 無敵点滅。
- **完了条件**: 敵を撃って消し、被弾でミスになる。スコアが増える。

### M3 ―― ゲームフロー・HUD（1〜2 日）
- [ ] HUD（スコア・ハイスコア・残機）。
- [ ] Title 画面 → Game → GameOver → Title のシーン遷移。
- [ ] 残機 0 で GameOver、リスタート。
- [ ] SE 4 種（shot / explosion / miss / powerup 枠）。
- **完了条件**: タイトルから始めて死んで戻る、一周遊べる。

### M4 ―― パワーアップ（1〜2 日）★第1マイルストーンのゴール
- [ ] PowerUp アイテム（ドロップ・落下・取得）。
- [ ] 取得で `GameState.add_power()` → ショット形状変化（1→2→3way）。
- [ ] 敵 `item_drop_chance` で抽選ドロップ。
- [ ] 弾オブジェクトプール導入（弾数増に備える）。
- **完了条件**: アイテム取得で攻撃が強化される。**ここで「MVP + パワーアップ」完成。**

### M5 ―― 仕上げ（1〜2 日 / 任意）
- [ ] スクロール背景（星・地形）。
- [ ] BGM（FamiStudio）1 曲。
- [ ] ポーズ、簡易タイトル演出、スクリーンシェイク。

### M6 ―― ファミコンパッド対応（1〜2 日 / 実機入手後）
- [ ] 接続検出（`get_connected_joypads` / `joy_connection_changed`）。
- [ ] KeyConfig 画面（各アクションを押して登録、`InputManager` で永続化）。
- [ ] 実アダプタでボタン番号を確認・調整。
- **完了条件**: ファミコンパッドだけで全操作できる。

### M7 ―― ボス（2〜3 日）★ステージの締め
参考: スターソルジャーの「各ステージ末ボス」。出現フロー:

```
ザコウェーブ（一定時間）→ "WARNING!!" 表示・ザコ停止 → ボス登場
  → HP ゲージを削る → 撃破 → 連続爆発 → "STAGE CLEAR" → タイトル（スコア保持）
```

- [ ] WaveDirector にフェーズ管理（ZAKO → WARNING → BOSS）
- [ ] Boss.tscn / boss.gd: 大型・HP 40・画面上部で左右往復
- [ ] 攻撃パターン 3 種、HP 残量でフェーズ遷移（66% / 33% で激化）
  - P1 = 自機狙い単発 / P2 = 3way 拡散 / P3 = 全方位 8 発（EnemyBullet 再利用）
- [ ] ボス HP ゲージ（HUD 上部の赤バー）＋ WARNING / STAGE CLEAR 表示
- [ ] 撃破演出（連続爆発・大ボーナス +5000）→ クリア → タイトル
- [ ] 状態通知: GameState に `boss_warning` / `boss_appeared` / `boss_hp_changed` / `boss_defeated` を追加、HUD が受信
- [ ] （任意 / 将来）制限時間: 時間切れで激化 or やり直し

完了条件: ザコ後にボスが出現し、HP ゲージを削り切ると STAGE CLEAR が出てタイトルへ戻る。

### M8 ―― ドット絵アセット（1〜2 日）
仮 Polygon2D を 16×16 ドット絵スプライトに差替。NES パレット縛り。

方式: **コード内ピクセルマップ（文字グリッド）→ Image → ImageTexture** を `PixelArt`(autoload) が生成。外部画像ファイル不要・アセット管理ツール不要。

- [ ] PixelArt autoload: 文字グリッド→テクスチャ生成、NES 風パレット辞書
- [ ] 自機・ザコ(赤/紫)・自機弾・敵弾・アイテム をドット絵化
- [ ] 各 .tscn の Visual を Polygon2D → Sprite2D、`_ready` で texture 設定
- [ ] EnemyDef に `sprite_name`、grunt/shooter で出し分け
- [ ] （次回）ボス・爆発のドット絵化

完了条件: 主要エンティティが 16×16 等のドット絵で表示され、見た目が NES らしくなる。

### M9 ―― ハイスコア永続保存（半日）
- [ ] GameState: `user://save.cfg` に hi_score を保存/復元
- [ ] 起動時ロード、ラン終了（game_over / boss_defeated）時に保存
- [ ] タイトル・HUD のハイスコア表示が永続値を反映

完了条件: ハイスコアがゲーム再起動後も残る。

### M10 ―― 複数ステージ（1〜2 日）
`StageDef` リソースでステージをデータ化。ボス撃破で次ステージ、最終クリアで ALL CLEAR。

- [ ] StageDef: enemy_defs / spawn_interval / zako_duration / boss_hp / bg_color
- [ ] stage1〜3.tres（難度・背景・ボス HP を段階的に）
- [ ] WaveDirector: stages 配列、boss_defeated で次ステージ、最後は all_clear
- [ ] Boss: HP をステージ毎に可変（setup_hp）
- [ ] HUD: "STAGE n" 表示、最終クリアで "ALL CLEAR!"
- [ ] 背景色をステージで変更

完了条件: 3 ステージを連戦し、各ボス撃破で次へ、最後に ALL CLEAR → タイトル。

### M11 ―― 配布（Windows exe）（半日）
- [ ] Project > Export で「Windows Desktop」プリセット追加
- [ ] Export Templates を DL（初回のみ・エディタが促す・バージョン一致）
- [ ] Embed PCK を有効化（単一 exe で配布）
- [ ] `build/famicongame.exe` を書き出し
- [ ] exe 単体起動を確認 → zip で配布
- [ ]（任意）`config/version`、Windows 用 `.ico` アイコン

完了条件: ダブルクリックで起動する `.exe` ができる。

### 将来 ―― 拡張
- [ ] 追加パワーアップ（オプション子機・ボム・スピード）。
- [ ] Web エクスポート版公開。

---

## 11. パフォーマンス指針
- 解像度が極小（256×240）なので描画負荷はほぼゼロ。ボトルネックは**ノード数**（弾・敵）。
- 弾はプール（§6）。敵も多数化するならプール化。
- 当たり判定は Area2D シグナル駆動。毎フレーム全探索しない。
- `_process`/`_physics_process` は必要なノードのみ。消滅予定は `set_physics_process(false)`。

## 12. テスト方針
- 手動: 各マイルストーンの「完了条件」を実機（PC）で確認。
- 自動（任意 / M4 以降）: **GUT (Godot Unit Test)** でロジック単体テスト。
  - 対象例: `GameState.add_score`/`lose_life`、パワーレベル遷移、ドロップ抽選の境界。
  - 当たり判定や入力は手動確認中心（GUI 依存のため）。

## 13. エクスポート（配布）
- M3 以降いつでも: `Project > Export > Windows Desktop` で `.exe` 生成（要 export テンプレート DL）。
- 配布は zip（exe + .pck）。Steam 等は将来。
- Web 版: `Web` プリセットで HTML5 出力 → 静的ホスティング（Vercel 等）。Gamepad はブラウザの Gamepad API 経由で動作。

---

## 14. 最初の一歩（M0 の具体作業順）
1. Godot 4.x をインストール、新規プロジェクト `famicongame` を**このフォルダ**に作成。
2. §2.1 の設定を Project Settings に入力。
3. §3.1 の InputMap を登録。
4. `scripts/autoload/const.gd`・`game_state.gd` を作り、Autoload 登録。
5. 空の `Main.tscn` を実行 → 256×240 が整数スケールで出れば M0 完了。

> 本書は生きた文書。実装で判明した調整（速度・クールダウン・ドロップ率等）は随時この計画書へ反映する。
