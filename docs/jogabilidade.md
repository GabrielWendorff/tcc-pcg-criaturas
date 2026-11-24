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
| Tela de "nova espécie registrada" na captura, com o sorteio | ✅ cartaz NOVA ESPÉCIE com "BESTIÁRIO n/100" e a raridade |
| Indicador de vantagem de elemento antes de escolher o golpe | ✅ selo EFICAZ / FRACO colorido ao lado do nome de cada golpe |

### Depois

| Item | Por quê |
|---|---|
| Silhueta do anfíbio | ainda lê como bloco (`pendencias.md`, item 3) |
| Par de asas visível | só a asa de perto é desenhada |
| Interiores de casa, missões, agenda | fora do escopo declarado no GDD |
| Música por região e para guardião | variedade sonora |

## Coleção e "jogar de novo" (24/11/2026)

Pesquisa de referência: o que prende em Pokémon (raridade do shiny, completar a Pokédex), Stardew
Valley (ciclo curto, pouca punição) e Roube um Ovo / Steal an Egg do Roblox (raridades de Comum a
Divino, coleção que rende). Do que coube no prazo:

| Item | Inspiração | Como liga ao TCC |
|---|---|---|
| Raridade do sorteio: COMUM, RARA, LENDÁRIA (`RaridadeSorteio`, `data/captura/colecao.json`) | shiny, ovos raros | a raridade **é** a surpresa −log2 P(derivados \| primários): rara = atípica, lendária = as 3 maiores surpresas da seed. A ficha mostra "1 em N" |
| Encontro raro: cartaz "CRIATURA LENDÁRIA!", som, título na cor e moldura pulsando | aparição do shiny | o jogador sente o gerador antes de ler a ficha |
| Nova espécie + marcos de 3, 6, 10, 15, 25, 40, 60 e 100 espécies com itens e gold | Pokédex, Shiny Charm | a coleção é o bestiário da seed |
| Bestiário (N) com REGISTRADAS, RARAS e LENDÁRIAS, números coloridos | Pokédex | mostra o que ainda falta caçar |
| Vitória com o resumo da coleção e a opção OUTRA SEED | ciclo curto | cada seed sorteia outras lendárias |
| Pesca tranquila: linha parada até recolher | Stardew (pouca punição) | — |
| Joystick e botões na tela | jogar no celular | — |

Ficam como trabalho futuro: mural de pedidos tirados do bestiário (Stardew) e viveiro em que as
criaturas guardadas rendem gold pela raridade (Roube um Ovo).

## Como verificar

```bash
GODOT=godot tools/rodar_testes.sh       # inclui test_audio e test_ambientacao
```

O roteiro manual de ponta a ponta está em `docs/publicacao/roteiro-de-teste.md`.
