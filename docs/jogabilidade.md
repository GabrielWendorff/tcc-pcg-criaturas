# Jogabilidade: o que falta para ser divertido de ponta a ponta

Varredura de 12/11/2026, depois do jogo completo (4 guardiões, vitória e derrota). Critério:
uma pessoa que nunca viu o jogo consegue jogar do ônibus até a vitória, entende o que fazer e
percebe o gerador de criaturas no caminho.

## Estado do loop

| Parte | Estado |
|---|---|
| Explorar | 4 regiões, mapa (M), objetivo sempre no card, bolsas perdidas sorteadas pela seed |
| Capturar e pescar | dispositivos, iscas, chance visível; pesca com minigame |
| Batalhar | por turnos, equipe de 3, golpes do corpo, vantagem de elemento |
| Montar time | equipe, troca, cura na praça, lojas com gold |
| Onboarding | chegada de ônibus, Mirela explica, dicas na primeira batalha, lição de pesca |
| Progressão | Dulce → Anselmo e Otávio → Mirela; selos abrem caminho |
| Gerador à vista | ficha da batalha, bestiário (N), sorteio de cada criatura (E), tela de vitória |
| Bugs bloqueantes | nenhum conhecido; suíte de 20 testes passa, inclusive o jogo de ponta a ponta |

## Lista priorizada

### Essencial para a apresentação

| Item | Por quê | Estado |
|---|---|---|
| Som: efeitos de menu, golpe, captura, gold, selo, vitória e derrota | sem som, o jogo parecia mudo; é o maior ganho de "game feel" por esforço | ✅ 23 efeitos gerados por script |
| Música de fundo: vila e batalha, em laço | ritmo e troca de clima ao entrar em batalha | ✅ 2 faixas geradas por script |
| Volume de música e efeitos nas opções | quem apresenta precisa baixar ou desligar | ✅ |
| Golpe com resposta: pulo de quem ataca, clarão no alvo, número de dano | o alvo só tremia | ✅ número dourado no golpe eficaz |
| Linha SORTEIO na ficha da batalha | o núcleo da tese aparece no meio do combate, não só no bestiário | ✅ nota e os 2 derivados mais esperados |
| Dica da primeira batalha fora de cima do nome da criatura | cobria o título da ficha | ✅ movida para a esquerda |
| Ambientação pela seed (Camada 3) com bolsas perdidas | explorar passa a ter recompensa e cada seed muda o lugar | ✅ |
| Build publicada e testada | requisito do Playbook e da demonstração | ver `docs/publicacao/` |

### Desejável

| Item | Por quê |
|---|---|
| Calibrar a Mirela depois do playtest | 27,7% contra uma equipe mediana da IA; pessoas usam itens e trocas, mas pode frustrar |
| Animação própria por elemento no golpe (partículas de fogo, gotas) | reforça a leitura elemento → corpo |
| Passos e som ambiente por região | imersão; hoje a vila e a fábrica soam iguais |
| Tela de "nova espécie registrada" na captura, com o sorteio | celebra a coleção e mostra o gerador de novo |
| Indicador de vantagem de elemento antes de escolher o golpe | hoje aparece no texto do golpe ("MUITO EFICAZ") |

### Depois

| Item | Por quê |
|---|---|
| Silhueta do anfíbio | ainda lê como bloco (`pendencias.md`, item 3) |
| Par de asas visível | só a asa de perto é desenhada |
| Interiores de casa, missões, agenda | fora do escopo declarado no GDD |
| Música por região e para guardião | variedade sonora |

## Como verificar

```bash
GODOT=godot tools/rodar_testes.sh       # inclui test_audio e test_ambientacao
```

O roteiro manual de ponta a ponta está em `docs/publicacao/roteiro-de-teste.md`.
