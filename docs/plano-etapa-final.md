# Plano da etapa final

Levantamento de 03/11/2026 (terça-feira) contra o
[The Portfolio Playbook](https://github.com/CatolicaSC-Portfolio/The-Portfolio-Playbook)
(revisão `ce005fe`), linha de **Jogos Digitais**. O quadro de execução é o
[Trello](https://trello.com/b/nPQmonFA/pac-vii-viii-pcg-rpg-2d), lista
"Etapa Final (até 30/11)". `docs/pendencias.md` continua sendo o registro técnico.

Faltam **27 dias** para a entrega de 30/11/2026 (segunda-feira).

---

## 1. Gates: não viram nota, impedem de apresentar

| Gate | Prazo | Estado | Ação |
|---|---|---|---|
| 2 orientações evidenciadas | 30/09/2026 | **a confirmar** | juntar as evidências |
| Playtest com ≥ 10 pessoas | 30/10/2026 | **sem evidência no repositório; prazo vencido** | confirmar com o professor |
| Relatório do playtest | 30/10/2026 | **sem evidência no repositório; prazo vencido** | confirmar com o professor |
| 5 orientações evidenciadas | 30/11/2026 | **a confirmar** | agendar as restantes |
| Jogo do início ao fim, com vitória e derrota | 30/11/2026 | **não atende** | seção 3 |
| Build pública (Itch.io, loja, WebGL, APK) | 30/11/2026 | não existe | CI + itch.io |
| GDD (mínimo: visão, loop, mecânicas, tecnologias) | 30/11/2026 | não existe | template de 19 seções |
| Wiki | 30/11/2026 | desligada; repositório privado | ver decisão D3 |
| CI/CD com build automatizado | 30/11/2026 | não existe | GitHub Actions |
| Análise estática | 30/11/2026 | não existe | `gdlint` no CI |
| Monitoramento (log de erros ou telemetria) | 30/11/2026 | não existe | log de sessão e erros |
| Pôster A0 em PDF com QR Code | 30/11/2026 | não existe | template oficial |
| Prova de autoria | 30/11/2026 (2ª tentativa: 03/12/2026) | a preparar | ensaio das 25 perguntas |
| PAC VIII: release, peer review, aceite | 30/11/2026 | **a confirmar** | ver decisão D4 |
| Visitar outra noite do Demo Day e avaliar colegas | 10, 15 ou 16/12/2026 | futuro | requisito de aprovação |

"Sem condição de vitória/derrota" está em *O que não pode ter* da linha: hoje o
jogo incorre nisso, e é o maior risco técnico.

## 2. Nota: o que falta para o 5 em cada critério

A nota é a média dos 6 critérios (Likert 1–5) × 2. **Tirar 10 exige 5 nos seis,
com os três professores.** O critério 5 é eliminatório.

| Critério | O que já sustenta | O que falta |
|---|---|---|
| 1. Relevância e complexidade | contribuição original (atributos correlacionados), RF08 medido contra baseline | jogo completo que mostre isso, com escopo declarado no GDD |
| 2. Documentação | READMEs por módulo, `mudancas-estruturais.md`, `pendencias.md` | README raiz, GDD, Wiki, diagrama C4 |
| 3. Qualidade do código | regras puras em `regras/`, dados em JSON, testes de lógica | corrigir os testes da seção 2.1; PRs revisados; lint |
| 4. Infra e engenharia | Git | CI/CD, deploy automatizado, monitoramento, ambientes dev/produção |
| 5. Ética e autoria | arte gerada por scripts próprios | créditos, uso de IA declarado, domínio do código, origem das referências (D5) |
| 6. Apresentação | — | pôster, demo estável, vídeo, QR Code, ensaio |

*Destaque* pede ainda polimento e **evidência de iteração a partir de playtests**;
playtest com público externo é diferencial.

### 2.1 Estado dos testes (Godot 4.7, 03/11/2026)

| Teste | Resultado |
|---|---|
| `test_dialogo`, `test_equipamento`, `test_gerador`, `test_mundo`, `test_pesca`, `test_tutorial` | passam |
| `test_pesca_integracao.tscn` (como cena) | passa (153 verificações) |
| `test_encontro` | **imprime que passou, mas o fluxo completo aborta**: sob `-s`, `Opcoes` não resolve e a linha 341 quebra. Falso positivo |
| `test_interacao` | **aborta** pelo mesmo motivo (autoload sob `-s`) |
| `test_bolsa` | **não compila** (`detalhe()` sem argumento, linha 125) |
| `test_save` | **2 falhas**: `autoload registrado` (efeito do `-s`) e `sorteio de seed não se repete` |

Antes do CI, os testes que tocam autoloads precisam rodar como cena, e o
executor precisa falhar quando um teste aborta.

### 2.2 Requisitos funcionais

| RF | Estado |
|---|---|
| RF01 mundo por seed, RF02 bestiário, RF03 reprodutibilidade, RF05 exploração, RF08 métricas | entregues |
| RF04 atributos correlacionados | entregue no dado; **escamas, asas e nadadeiras não são desenhadas** (`pendencias.md`, itens 1 e 2), e são os exemplos centrais da tese |
| RF06 batalhas | **não existe**: `presentation/batalha/` está vazia |
| RF07 stats e visual | parcial: mesma lacuna de arte; sem tela de coleção |
| Camada 3 (ambientação pela seed) | **não implementada**: `procedural/ambiance/` só tem README; a vegetação atual é autoral |

## 3. Proposta de jogo com começo, meio e fim

Sessão-alvo de 15 a 20 minutos, reaproveitando o que existe.

- **Início:** nova partida com seed → vila → Anselmo dá o objetivo e a primeira
  criatura. Objetivo sempre visível no HUD.
- **Meio:** capturar e pescar para montar uma equipe de até 3; cada uma das 3
  regiões fora da vila tem um **guardião** (NPC autoral, ao ar livre) que dá um
  selo ao ser vencido.
- **Vitória:** com os 3 selos, o duelo final na vila → tela de encerramento com
  os dados da seed (capturas, coerência do bestiário).
- **Derrota:** equipe inteira sem HP → tela de derrota, com retorno ao último save.

**Batalha (RF06):** por turnos, 1×1, com tabela de elementos em
`data/batalha/*.json`. Stats **derivados** da morfologia e do porte já sorteados,
sem tocar no `GeradorCriaturas`: é o mesmo caminho da pesca e da afinidade de
captura. RNG próprio (`world_seed` + deslocamento), regra pura em
`presentation/batalha/regras/` e `tools/test_batalha.gd`.

**No trade-off:** derivar custa quase nada em tempo real e não altera o bestiário
(coerência e métricas preservadas), enquanto uma busca ao estilo de Togelius et
al. (2011) pagaria desempenho sem ganho para este objetivo. A escala continua
limitada às ~100 criaturas por seed.

**Fora do escopo final, salvo sobra de prazo:** loja, interiores de casa, missões
paralelas, agenda de NPCs. Vão para a seção 16 do GDD como limitações.

**Sincronia com o artigo:** equipes de guardião lidas do bestiário da seed são
conteúdo autoral condicionado à saída do gerador, o caso previsto em
`mudancas-estruturais.md` (2026-09-16). A Camada 3 também. **Os dois exigem
registro lá e atualização da Seção 3.**

## 4. Cronograma

| Até | Entrega |
|---|---|
| 04/11 | gates confirmados com o professor |
| 05/11 | arco do jogo decidido |
| 08/11 | testes corrigidos, CI com testes e `gdlint` |
| 10/11 | batalha e equipe (RF06); GDD v0.5 |
| 11/11 | build web no itch.io pelo CI, com log de erros |
| 14/11 | arte de escamas, asas e nadadeiras |
| 16/11 | guardiões, vitória e derrota: **jogável de ponta a ponta** |
| 18/11 | Camada 3 mínima; nota da Seção 3 do artigo |
| 19/11 | playtest da versão completa (≥ 10, com público externo) |
| 22/11 | melhorias do playtest, áudio, game feel |
| 24/11 | GDD v1.0, Wiki, README, peer review do PAC VIII |
| 26/11 | pôster, vídeo, QR Code; artigo final |
| 27/11 | ensaio da prova de autoria; congelar a release |
| 30/11 | **entrega** e prova de autoria |
| 10, 15, 16/12 | Poster + Demo Day |

## 5. Decisões pendentes

- **D1. Playtest vencido.** Foi feito? Se não, o que o professor aceita agora?
- **D2. Arco do jogo.** Aprovar ou ajustar a seção 3.
- **D3. Repositório público?** O GitHub só oferece Wiki em repositório privado em
  plano pago. Recomendação: tornar público, se a origem das referências (D5) estiver
  esclarecida.
- **D4. PAC VIII.** Modalidade (Parceiro ou Comunidade), squad e estado dos NPs.
- **D5. Origem de `autoral/_ref_*.png`.** Ficaram fora do repositório; o gerador do
  protagonista cita uma "folha de referência". Plágio é eliminatório: é preciso
  saber a fonte e declará-la.
- **D6. Artigo.** O `.tex` não está neste repositório: onde fica e qual o estado.
