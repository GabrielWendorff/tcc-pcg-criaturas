# Encontro e captura de criaturas

Fecha o ciclo entre a exploração (Camada 4) e o bestiário gerado pela seed
(Camada 2): andar no mato encontra uma criatura, e o jogador decide o que fazer
com ela.

```bash
godot --path .                                                # F4 força um encontro
godot --headless --path . -s res://tools/test_encontro.gd     # regra + fluxo
DISPLAY=:0 SHOT_DIR="user://" godot --display-driver x11 \
  --rendering-driver opengl3 --path . -s res://tools/screenshot_encontro.gd
```

## Roteiro

```
andar dentro de uma zona
        ↓  sorteio por distância percorrida
       "!"  sobre a cabeça  +  tremor de câmera
        ↓
   escurecimento da tela
        ↓
   CRIATURA ENCONTRADA
        ↓
      menu ──── Abandonar
        ├────── Oferecer isca ──→ roda radial (iscas)
        ├────── Atacar          → derruba o vigor
        └────── Tentar capturar → roda radial (dispositivos)
                                        ↓
                                  lance → sucesso / falha
```

## Arquivos

### Regra — `regras/`, sem engine, testável fora de cena

| arquivo | papel |
|---|---|
| `tabelas_captura.gd` | `TabelasCaptura` — carrega `data/captura/*.json` |
| `item_captura.gd` | `ItemCaptura` — raiz comum de dispositivo e isca |
| `dispositivo_captura.gd` | `DispositivoCaptura` — multiplicador geral + eficácia por traço |
| `isca_captura.gd` | `IscaCaptura` — tipos preferidos (`animal_base`) + bônus |
| `afinidade_criatura.gd` | `AfinidadeCriatura` — evasão, vigor e estado a partir dos atributos |
| `calculo_captura.gd` | `CalculoCaptura` — **único** lugar que decide a chance |
| `inventario_jogador.gd` | `InventarioJogador` — quantidades + coleção de capturadas |
| `estado_encontro.gd` | `EstadoEncontro` — máquina de estados com tabela de transições |
| `configuracao_encontro.gd` | `ConfiguracaoEncontro` — tempos do roteiro e detecção |

### Apresentação

| arquivo | papel |
|---|---|
| `gerenciador_encontro.gd` | `GerenciadorEncontro` — orquestra tudo; único nó que conhece as partes |
| `interface_encontro.gd` | `InterfaceEncontro` — ficha da criatura, menu e animações do lance |
| `roda_captura.gd` | `RodaCaptura` — roda radial reutilizável (dispositivos **e** iscas) |
| `aviso_encontro.gd` | `AvisoEncontro` — o "!" sobre a cabeça do jogador |
| `transicao_encontro.gd` | `TransicaoEncontro` — escurecimento e cartão de texto |
| `icone_captura.gd` | `IconeCaptura` — recorta o ícone do item da folha `arte/itens/` |
| `medidor_chance.gd` | `MedidorChance` — barra segmentada de chance/vigor |
| `tema_encontro.gd` | `TemaEncontro` — fonte, molduras 9-slice e paleta |

## Direção visual

A interface é **pixel art**, na mesma política do resto do projeto: nenhum asset
comprado ou baixado — tudo sai de `tools/arte/gerar_ui.py`, `gerar_itens.py` e
`gerar_fonte.py`, versionado e regerável (ver `arte/README.md`).

Referência de linguagem: RPG aconchegante de coleta de criaturas — madeira,
pergaminho, molduras grossas, tachas nos cantos. **Referência, não cópia:** as
formas, a paleta e a fonte são originais deste projeto, e a esfera de captura foi
deliberadamente desenhada com coleira e argola para não repetir a forma registrada
de outra franquia.

O que separa esta tela de uma interface web genérica, ponto a ponto:

| antes | agora | por quê |
|---|---|---|
| `StyleBoxFlat` com canto arredondado | molduras 9-slice de madeira | retângulo de cor chapada com raio de borda é a assinatura visual de CSS |
| fonte padrão da engine | bitmap 5×7 em três corpos | tipografia é o maior denunciador de "isto não é um jogo" |
| ícones por primitivas em `_draw()` | folha `arte/itens/itens.png` | círculos e retângulos exatos leem como diagrama, não como objeto |
| cartão horizontal, ícone à esquerda | cartão vertical, ícone no topo | a leitura horizontal é a de uma linha de tabela |
| centro da roda vazio | ficha em pergaminho | numa roda o olho procura o eixo; ali tem de estar a resposta |
| chance como texto pequeno | barra segmentada + número + cor | uma decisão de um segundo precisa ser vista, não lida |
| sombra difusa | chanfro de 1px | sombra projetada lê como web; chanfro lê como objeto |
| escurecimento chapado | véu + vinheta tramada | degradê liso denuncia a interface como estranha ao jogo |

### Três planos

```
frente   a roda, quando aberta
meio     a ficha da criatura e o menu   (recuam para 34% quando a roda abre)
fundo    o mundo, sob véu + vinheta     (continua reconhecível — nunca some)
```

Sem o recuo do meio, três blocos de informação disputam o mesmo primeiro plano.

### Geometria da roda

O raio sai de quatro restrições, e a maior vence — as duas primeiras são o motivo
de uma roda "que parecia folgada" encavalar os cartões com 10 iscas:

1. **vizinhos na horizontal**: dois cartões vizinhos ao redor do topo se separam
   por `R·sin(2π/n)` no eixo x, não por `R`. Com n=10, `sin(36°)=0,59`;
2. **vizinhos na vertical**: nas laterais é `R·sin(2π/n)·ACHATAMENTO`, ainda
   menor — a elipse comprime justamente o eixo em que os cartões são mais altos;
3. **o miolo**: o cartão mais próximo começa depois do pergaminho central;
4. **a tela**: teto, para o cartão mais alto não sair pela borda.

Verificado em 1152×648, 1600×900 e 1024×576.

### O trilho e o raio

Os pontos do trilho são distribuídos por **comprimento de arco**, não por ângulo
igual. Numa elipse as duas coisas não coincidem: com passo angular constante os
pontos se amontoam em cima e embaixo e se afastam nas laterais — e o desenho que
existia para dizer "isto é uma roda" acabava lendo como sujeira espalhada.

Só o cartão **selecionado** recebe raio, e ele é dourado. A primeira versão
desenhava um raio para cada cartão; somados ao trilho eram dezesseis fileiras de
pontos disputando a mesma área. Com um raio só, ele deixa de ser enfeite e passa a
carregar informação: amarra o que o miolo mostra ao cartão de onde aquilo veio.

### Estados do cartão

| estado | moldura | extra |
|---|---|---|
| normal | madeira | — |
| selecionado | dourada | escala 1,06 + flutuação lenta + raio dourado até o miolo |
| indisponível | escura | ícone a 35%, `×0` apagado, navegação pula |
| confirmado | — | pulso rápido, depois os cartões se recolhem para o centro |

O recolhimento não é enfeite: é o intervalo que liga a escolha ao arremesso. Sem
ele a roda some entre um quadro e o outro e o lance começa sem que nada na tela
tenha dito que a roda acabou.

### Reação da criatura

Ao receber a isca certa a criatura dá um pulinho; ao receber a errada, encolhe.
Custa quatro linhas e responde sem texto à pergunta que o jogador acabou de fazer
ao mundo — "ela gostou?". A mensagem no pergaminho diz o mesmo por escrito; ver as
duas juntas é o que faz a escolha da isca parecer uma conversa com a criatura em
vez de uma soma de bônus.

## A fórmula

```
p = clamp(base × dispositivo × afinidade × isca × estado, piso, teto)
```

Produto e não soma, pelo mesmo motivo pelo qual as tabelas do gerador são
condicionais: cada fator responde a uma pergunta independente e precisa poder
**anular** o ganho dos outros. Uma rede contra garras (×0,80) tem de estragar o
lance mesmo com a isca certa; com soma, bastaria acumular bônus.

Todos os números vivem em `data/captura/balanceamento.json`.

| fator | vem de | pergunta |
|---|---|---|
| `dispositivo` | `dispositivos.json` | o aparelho serve contra os traços **desta** criatura? |
| `afinidade` | `conditional_morphology.json`, via `balanceamento.json` | o que ela tem para se defender? |
| `isca` | `iscas.json` | a comida casa com o `animal_base`? |
| `estado` | vigor corrente | ela já está machucada? |

O teto (0,85) impede captura garantida mesmo com tudo certo; o piso (0,03)
impede criatura impossível. São os mesmos clamps que `conditional_morphology.json`
aplica na geração, pela mesma razão: manter o sistema estocástico nas pontas.

## A afinidade não é uma tabela nova

É o ponto de contato entre a mecânica e a contribuição do trabalho. A dificuldade
de captura **não** está declarada por espécie em lugar nenhum: cada traço
morfológico tem um fator de evasão, e quais traços a criatura tem foi decidido
pela tabela condicionada ao par (animal, elemento) na geração.

O resultado emerge:

- `água + peixe` recebe `escamas` (0,90) e `nadadeiras` (0,92) com alta
  probabilidade → blindada e escorregadia → evasão ×0,58 → pede a **Redoma
  Aquática**;
- `fogo + gato` recebe `garras` (0,85 + 0,10) → reage → pede a **Armadilha de
  Aço**;
- uma criatura que saiu sem apêndice nenhum tem evasão ×1,00 — presa fácil.

Ler a criatura na tela (a ficha lista *Defesas* com o fator de cada traço) é ler
a saída do gerador. É a coerência semântica virando decisão de jogo.

## Determinismo (RF03)

Todo sorteio — encontro, qual criatura, captura, dano, fuga — sai de **um**
`RandomNumberGenerator` semeado a partir da `world_seed`. Nenhuma chamada a
`randi()`/`randf()` globais. Mesma seed e mesma sequência de ações reproduzem a
partida lance a lance, como o bestiário se reproduz criatura a criatura.

## O que a região faz — e o que ela não faz

`PontoDeEncontro.elementos_provaveis` (que o mapa já trazia e nenhum código lia)
agora filtra **quem aparece onde**, por filtro com mistura
(`chance_fora_da_regiao`) sobre o bestiário já gerado: um `randf()` decide se o
filtro vale (0,85) ou é ignorado (0,15), e um `randi()` sorteia uniforme no
conjunto escolhido (só os do elemento da região, ou o bestiário inteiro). Sem
laço e sem re-sorteio.

Isso **não** muda o modelo generativo: as tabelas condicionais, o bestiário e as
métricas de RF04/RF08 são exatamente os mesmos de antes. Ver
`docs/mudancas-estruturais.md`.

## Batalha

`Atacar` derruba um valor de vigor e nada mais — não é um sistema de combate. É o
mínimo para que a ação tenha consequência mecânica (vigor é um dos fatores da
fórmula) e para que exista uma decisão real: enfraquecer melhora a chance, mas
zerar o vigor perde a criatura. Quando `presentation/batalha/` (RF06) existir, ele
substitui `GerenciadorEncontro._atacar()` e o resto do encontro não muda.
