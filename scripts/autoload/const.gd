extends Node
## グローバル定数（Autoload 名: Const）。§4.3 / §5.1

# --- 衝突レイヤー（1-indexed のビット番号）---
const L_PLAYER        := 1
const L_PLAYER_BULLET := 2
const L_ENEMY         := 3
const L_ENEMY_BULLET  := 4
const L_ITEM          := 5

# --- グループ名 ---
const G_PLAYER  := "player"
const G_ENEMIES := "enemies"
const G_ITEMS   := "items"

# --- プレイフィールド（256x240 基準）---
const SCREEN_SIZE := Vector2(256, 240)
const FIELD_MIN   := Vector2(8, 8)
const FIELD_MAX   := Vector2(248, 232)

# --- レイヤー番号(1..32) → ビットマスク 変換ヘルパ ---
static func bit(layer_index: int) -> int:
	return 1 << (layer_index - 1)
