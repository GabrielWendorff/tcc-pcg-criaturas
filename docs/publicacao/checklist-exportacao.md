# Checklist de exportação e publicação

Plataformas: **Web** (jogar no navegador, é o link do QR Code e da demonstração) e
**Windows** (download, para máquina sem navegador confiável). Linux sai junto, sem custo.

## 1. Antes de exportar

- [ ] `GODOT=godot tools/rodar_testes.sh` passa inteiro.
- [ ] `godot --headless --path . -s res://tools/simular_batalha.gd -- --seeds 200` atende os critérios.
- [ ] `gdlint procedural presentation sistemas` sem problemas.
- [ ] Nenhuma tecla de desenvolvimento na build de entrega (F2, F3, F4 só em debug: `OS.is_debug_build()`).

## 2. Presets (`export_presets.cfg`, versionado)

| Preset | Saída | Observação |
|---|---|---|
| Linux | `exports/linux/rpg-pcg.x86_64` | |
| Windows | `exports/windows/rpg-pcg.exe` | sem assinatura de código: o Windows avisa "editor desconhecido" |
| Web | `exports/web/index.html` | sem threads: dispensa os cabeçalhos COOP/COEP, e o itch.io roda direto |

- [ ] Os três presets têm `exclude_filter` com `autoral/_*` (referências locais fora da build).
- [ ] Conferir o binário: `grep -ac '_ref_direcoes\|autoral/_ref' exports/*/*` dá 0.

## 3. Tamanho (medido em 12/11/2026)

| Build | Tamanho |
|---|---|
| Web | cerca de 41 MB (39,5 MB de `index.wasm`, que é o motor; o jogo é 1,5 MB) |
| Windows | 111 MB, um `.exe` com o jogo embutido |
| Linux | 75 MB |

O itch.io aceita até 1 GB por arquivo. Para a Web, o primeiro carregamento baixa os 41 MB uma vez.

## 4. Testar a build exportada

- [ ] **Web local:** `cd exports/web && python3 -m http.server 8000` e abrir `http://localhost:8000`.
  Conferido em 12/11 no Chrome: o menu carrega e renderiza.
- [ ] **Windows:** abrir o `.exe` numa máquina Windows e seguir o roteiro de
  `roteiro-de-teste.md` até o primeiro duelo.
- [ ] **Linux:** conferido em 12/11: abre, roda e o log de sessão não tem erro.
- [ ] Na Web, salvar, recarregar a aba e conferir que **CONTINUAR** aparece: o save vai para o
  armazenamento do navegador.

## 5. Página no itch.io

- [ ] Criar o projeto: *Kind of project* **HTML**, preço **sem pagamento**, visibilidade
  **Restricted** ou **Draft** até conferir, depois **Public**.
- [ ] Enviar o zip da Web marcado "This file will be played in the browser".
- [ ] *Embed options*: 1152 × 648, **Fullscreen button** ligado, **Mobile friendly** desligado,
  **SharedArrayBuffer** desligado (a build não usa threads).
- [ ] Enviar o zip do Windows (e do Linux) como download.
- [ ] Capa 630 × 500 e banner: `arte/divulgacao/`.
- [ ] Descrição, controles e tags: copiar de `itch-pagina.md`.
- [ ] 3 a 5 capturas de tela: menu, chegada de ônibus, batalha com a linha SORTEIO, bestiário com o sorteio (E), vitória.
- [ ] Abrir a página numa aba anônima e jogar 2 minutos.
- [ ] Gerar o QR Code com a URL final e atualizar o pôster (`tools/poster/config.json`).

## 6. Publicação automática (opcional)

O job `publicar-itch` do CI envia Web, Windows e Linux a cada merge na `master`, se existirem:

- segredo `BUTLER_API_KEY` (chave em itch.io → *Settings* → *API keys*);
- variável `ITCH_ALVO`, por exemplo `usuario/coerencia-semantica`.

Sem os dois, o job passa sem publicar. O primeiro envio pode ser manual, pela página.
