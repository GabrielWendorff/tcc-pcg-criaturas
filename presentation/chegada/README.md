# Chegada de ônibus

A abertura de uma partida nova. Acontece **dentro do mundo**: o ônibus sai de um túnel na
borda oeste da vila, para na estrada, o jogador desce, e a Mirela vem da praça até ele.
A câmera acompanha o ônibus e depois passa para o jogador.

```bash
godot --headless --path . res://tools/test_chegada.tscn
```

## O roteiro

```
ônibus sai do túnel ──▶ para ──▶ jogador desce ──▶ ônibus volta de ré
                                     │
                    Mirela vem da praça até ele
                                     │
   "chegada":      o que são as criaturas, todo mundo tem uma, "e a sua?"
   "sem_criatura": o choque, "isso não pode ficar assim"  ──▶ escolha inicial
   "apos_escolha": o kit, golpes e captura em poucas falas ──▶ fim
```

- **Só em partida nova:** sem posição gravada e sem a primeira criatura. Save carregado
  não repete a cena.
- **P pula, com confirmação.** "Não" vem primeiro, como no tutorial do Anselmo. Quem pula
  ainda recebe a escolha da criatura, só não ouve a explicação.
- **ESC na escolha** encerra a cena. A Mirela continua oferecendo na praça (nó `oferta`).
- **Primeira batalha contra selvagem:** um pergaminho no topo explica o menu e, ao abrir
  a roda, os dispositivos. Aparece uma vez por partida, para quem viu a cena, para quem a
  pulou e para quem vem de um save antigo.

## Onde está cada coisa

| o quê | onde |
|---|---|
| boca do túnel, parada, desembarque, caminho da Mirela | `autoral/mapas/mundo.json` → `chegada`, escrito e **validado** por `tools/mapas/gerar_mundo.py` (constantes em `tools/mapas/regioes/vila.py`) |
| arte do túnel e do ônibus | `tools/arte/gerar_mundo_props.py` (`tunel`, `onibus`) |
| durações, textos do pulo, dicas da batalha | `autoral/cutscenes/chegada.json` |
| falas | `autoral/dialogos/mirela.json`: `chegada`, `sem_criatura`, `apos_escolha` |
| a cena | `cutscene_chegada.gd` (`CutsceneChegada`) |
| ligação com o mundo | `presentation/exploracao/mundo.gd`: `_talvez_chegar_de_onibus` |

## Decisões

**Não é um sistema de cutscenes.** É uma cena escrita em código, porque é a única. Um
interpretador de roteiro genérico custaria mais que ela e não teria segundo uso. O que é
conteúdo fica em dados, como no resto do projeto.

**O ônibus é recortado na boca do túnel.** O sprite fica no mesmo y-sort dos props, com a
**frente** como chave de ordenação: assim ele passa na frente do paredão assim que sai. A
parte que ainda está dentro da rocha é cortada por `region_rect`, numa linha vertical na
tela. Como o ônibus anda no eixo x da grade sobre uma linha y fixa, a posição na tela basta
para saber o que está dentro do túnel, sem shader.

**A cena não conhece a equipe nem a tela de escolha.** Ela emite `escolha_pedida`; o mundo
abre a escolha e responde com `escolha_feita()` ou `escolha_cancelada()`. É o mesmo padrão
de "um dono da tela por vez" do resto de `mundo.gd`: durante o ônibus e a caminhada o dono é
`"chegada"`; na conversa, o diálogo; na escolha, a tela de escolha.

**No trade-off:** a cena é Camada 1 (autoral) e Camada 4 (apresentação). Não toca no
gerador, não sorteia nada e não muda o bestiário: escala, coerência e as métricas de RF08
ficam como estavam. A única ligação com a seed é a escolha das três iniciais, que já existia.
