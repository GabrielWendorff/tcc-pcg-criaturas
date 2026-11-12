class_name Som
extends RefCounted

## Porta de entrada do som para o resto do codigo. Procura o autoload Audio em tempo de
## execucao: quem toca um efeito nao depende dele para compilar, e num teste sem
## autoload a chamada simplesmente nao faz nada.


static func tocar(nome: String, variacao_tom: float = 0.0) -> void:
	var audio := _audio()
	if audio != null:
		audio.tocar(nome, variacao_tom)


static func musica(nome: String) -> void:
	var audio := _audio()
	if audio != null:
		audio.musica(nome)


static func _audio() -> Node:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null or arvore.root == null:
		return null
	return arvore.root.get_node_or_null("Audio")
