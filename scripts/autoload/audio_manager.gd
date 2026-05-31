extends Node
## SE/BGM 再生（Autoload 名: AudioManager）。§7
## M5 で本実装。今は無音スタブ（呼んでも落ちないようにしておく）。

func play_se(_name: String) -> void:
	# TODO(M5): assets/audio/se/*.wav を同時発音プールで再生
	pass

func play_bgm(_stream: AudioStream) -> void:
	# TODO(M5): ループ BGM 再生
	pass
