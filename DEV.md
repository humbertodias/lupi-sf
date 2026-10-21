# Desenvolvimento

Tela 480×270, 60 fps, Lua. O cartucho é um zip chamado `sf.lupi`.

Vida 200, gravidade de pulo, comandos quarter-circle e dragon punch, bloqueio alto e baixo, empurrão e rounds. O pygame guarda o motor de framedata e as folhas de sprite; aqui os corpos são retângulos desenhados no `ui`. Não há PNG, então o `make lupi` não precisa de ImageMagick.

## Montar

Precisa de Lua 5.5, `zip` e do submódulo `lupi-codec`.

```sh
git submodule update --init
make lupi
lupinho sf.lupi
```

| Alvo | Resultado |
| --- | --- |
| `make lupi` | `sf.lupi` |
| `make web` | jogo web em `.build/webgame/`, via `hldtux/lupinho-sdk` |
| `make game/codec` | pasta aberta em `dist/current` |
| `make clean` | apaga `sf.lupi`, `dist/` e `.build/` |

`make game/codec` copia `game.lua`, os módulos em `src/` e `media/sfx/` para `.build/src` e roda `lupi-codec`. Os `.ogg` são recolocados no release se o codec não os mantiver.

Os `.lua`, os `.ogg` e o `lupi_manifest.txt` entram no zip sem compressão. O lupinho falha ao inflar o Lua quando fica muito comprimido, e o mesmo acontece com estes tons senoidais.

Cada push na `main` publica o cartucho em [sf.lupi](https://github.com/humbertodias/lupi-sf/releases/latest/download/sf.lupi) (`.github/workflows/release.yml`) e a versão web em [humbertodias.github.io/lupi-sf](https://humbertodias.github.io/lupi-sf/) (`.github/workflows/pages.yml`).

## Áudio

Efeitos em `sfx.fx`, músicas em `sfx.music`. Os arquivos ficam em `media/sfx/` e entram no cartucho como `sfx/*.ogg`, sem extensão na chamada.

| Chamada | Quando |
| --- | --- |
| `sfx.fx("sfx/swing")` | Golpe |
| `sfx.fx("sfx/hit")` | Acerto |
| `sfx.fx("sfx/block")` | Bloqueio |
| `sfx.fx("sfx/hadou")` | Hadouken |
| `sfx.fx("sfx/ko")` | Nocaute |
| `sfx.fx("sfx/dash")` | Corrida |
| `sfx.fx("sfx/land")` | Pouso |
| `sfx.fx("sfx/start")` | Luta |
| `sfx.fx("sfx/hover")` | Troca no menu |
| `sfx.fx("sfx/enter")` | Confirma no menu |
| `sfx.music("sfx/menu")` | Telas de fora da partida |
| `sfx.music("sfx/fight")` | Partida |

## Arquivos

- `game.lua` — monta os objetos e chama `update`
- `src/` — luta, partida e telas
- `media/sfx/` — sons
- `lupi-codec/` — converte o estágio em cartucho
