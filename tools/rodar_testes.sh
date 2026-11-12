#!/usr/bin/env bash
# Roda a suite inteira. Falha se um teste falhar OU abortar sem chegar ao resultado:
# um script que nao compila nao pode passar por teste verde.
#   GODOT=/caminho/do/godot tools/rodar_testes.sh [diretorio_de_logs]
set -u
GODOT="${GODOT:-godot}"
LOGS="${1:-$(mktemp -d)}"
LIMITE=280
mkdir -p "$LOGS"
cd "$(dirname "$0")/.."

CENAS="test_arco test_audio test_bolsa test_chegada test_encontro test_interacao test_pesca_integracao test_registro test_save"
PUROS="test_arte_criaturas test_batalha test_dialogo test_economia test_equipamento test_gerador test_gerador_v2 test_mundo test_pesca test_tutorial"

falhas=0
avaliar() {
	local nome="$1" codigo="$2"
	if [ "$codigo" -eq 0 ] && grep -q "TODOS OS TESTES PASSARAM" "$LOGS/$nome.log"; then
		echo "ok      $nome"
	else
		echo "FALHOU  $nome (saida $codigo; log em $LOGS/$nome.log)"
		grep -E "FALHA|FALHOU|SCRIPT ERROR" "$LOGS/$nome.log" | head -20
		falhas=$((falhas + 1))
	fi
}

for t in $CENAS; do
	timeout "$LIMITE" "$GODOT" --headless --path . "res://tools/$t.tscn" > "$LOGS/$t.log" 2>&1
	avaliar "$t" "$?"
done
for t in $PUROS; do
	timeout "$LIMITE" "$GODOT" --headless --path . -s "res://tools/$t.gd" > "$LOGS/$t.log" 2>&1
	avaliar "$t" "$?"
done

echo
if [ "$falhas" -eq 0 ]; then
	echo "SUITE: todos os testes passaram"
else
	echo "SUITE: $falhas teste(s) com problema"
fi
exit "$falhas"
