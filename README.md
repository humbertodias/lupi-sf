# SF

Luta 2D para o console Lupi. Ryu contra o Ken controlado pelo CPU. Socos, chutes, hadouken, shoryuken, tatsumaki, bloqueio e melhor de três rounds.

O jogo de origem é o [Reencor](https://github.com/Ranguel/Reencor), em pygame. Esta versão segue o molde do [lupi-asteroids](https://github.com/humbertodias/lupi-asteroids). Os sprites vêm dos mesmos pacotes do pygame, baixados com `make assets`. Sem eles, o cartucho desenha os lutadores com retângulos.

Versões: [web](https://humbertodias.github.io/lupi-sf/) | [desktop](https://github.com/humbertodias/lupi-sf/releases/latest/download/sf.lupi)

```sh
lupinho sf.lupi
```

<details>
  <summary>Controles</summary>

| Ação | Teclado |
| --- | --- |
| Mover | A D |
| Agachar | S |
| Pular | W |
| Socos fraco, médio, forte | J K L |
| Chutes fraco, médio, forte | M G H |
| Hadouken | baixo, diagonal, frente + soco |
| Shoryuken | frente, baixo, diagonal + soco |
| Tatsumaki | baixo, diagonal, trás + chute |
| Super | barra cheia e hadouken no L |
| Agarrão | J + M perto |
| Corrida | frente, frente |
| Bloqueio | segure trás. Agache para o golpe baixo |
| Menu | W S escolhe, J ou K confirma |

O rival é o CPU. O Lupi liga o teclado ao controle 1, então os dois lados não dividem o teclado.

</details>

Para montar o cartucho, veja [DEV.md](DEV.md).
