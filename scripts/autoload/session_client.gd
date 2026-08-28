extends Node
## 祭り出店キオスクサーバーとの通信(Autoload名: SessionClient)。
## Webビルドで ?station=N 付きURLから開いた時だけ動作する。
## station未指定(通常の開発・単体プレイ・ネイティブ実行)では完全に無効化され、
## 通常のGameSelect等の画面遷移には一切影響しない。

var station_id: String = ""
var _base_url: String = ""
var _http: HTTPRequest

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	add_child(_http)
	if OS.has_feature("web"):
		station_id = JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('station') || ''", true)
		# HTTPRequestは相対URL("/api/...")を受け付けない(Invalid parameterで即失敗する)ため、
		# 現在のオリジンを取得して絶対URLを組み立てる。
		_base_url = JavaScriptBridge.eval("location.origin", true)

func is_active() -> bool:
	return station_id != ""

## 実プレイ開始時に呼ぶ(チュートリアル/カウントダウン後、本編が始まる瞬間)。
func begin_play() -> void:
	if not is_active():
		return
	_http.request("%s/api/session/%s/begin-play" % [_base_url, station_id], [], HTTPClient.METHOD_POST)

## 1プレイ終了時に呼ぶ(ゲームオーバー/オールクリア)。
func consume() -> void:
	if not is_active():
		return
	_http.request("%s/api/session/%s/consume" % [_base_url, station_id], [], HTTPClient.METHOD_POST)

## ゲーム終了後、キオスクシェル(受付連携画面)へ戻る。
func return_to_shell() -> void:
	if not is_active():
		return
	JavaScriptBridge.eval("location.href = '/?station=%s'" % station_id, true)
