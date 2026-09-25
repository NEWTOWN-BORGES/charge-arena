# Pilotos modelados no Blender

O Piloto Aurora (skin 0) deixou de ser montado com primitivas no código e passou a ser um modelo
feito no Blender: `art/pilots/aurora.glb`, gerado por `tools/blender/aurora_pilot.py`. As restantes
skins continuam por código e podem migrar uma a uma com o mesmo método.

## O que mudou no Aurora

- Capacete com a abertura do visor recortada (boolean) e aro de cerâmica à volta, em vez de um disco
  escuro colado por cima.
- Crista de equipa em quilha com luz, auscultadores de latão com anel embutido e antena lateral.
- Tronco com placa de peito, núcleo luminoso, grelhas, gola, cinto e fivela.
- Mochila com tampa em cor de equipa, depósitos dourados e bocais.
- Ombros com friso dourado, antebraços com punho de cerâmica e mão esquerda.
- Botas com biqueira em cor de equipa, sola e anel no joelho.
- Manopla com risca de equipa, calhas laterais, cano, anel dourado na boca e emissor luminoso.

A silhueta, a origem do disparo (`Gun/Flash` em `0.29, 0.70, -0.88`), as pernas animadas e as
colisões ficam iguais.

| | Antes | Depois |
|---|---|---|
| Malhas no piloto | 30 | 23 |
| Triângulos | 12 280 | 12 956 |

O Blender junta as peças por material dentro de cada parte móvel (corpo, `LegL`, `LegR`, `Gun`),
por isso há menos chamadas de desenho apesar de haver muito mais detalhe.

## Como editar

```sh
pip install bpy                                  # Blender 5.0 como módulo Python
python3 tools/blender/aurora_pilot.py            # reescreve art/pilots/aurora.glb
python3 tools/blender/aurora_pilot.py --preview /tmp/aurora.png   # e renderiza no Cycles
godot --headless --import                        # reimporta no Godot
godot -s tests/capture_pilot.gd -- 0 preview-pilot.png            # frente, costas, lado e jogo
godot -s tests/capture_pilot.gd -- 0 preview-pilot.png ef947e     # com outra cor de equipa
```

O script escreve as posições em coordenadas do Godot (Y para cima, frente em -Z); `g()` converte-as.

## Contrato com o jogo

- O `.glb` tem um nó `Body` com os vazios `LegL`, `LegR` e `Gun` nas mesmas origens do modelo por
  código. O `Flash` do disparo continua a ser criado no Godot, dentro de `Gun`.
- Cada malha tem um único material, cujo nome é o papel: `team`, `cream`, `dark`, `gold`,
  `chest_light`, `eyes` e `muzzle`. `add_modelled_pilot()` troca-os pelos materiais da cena.
  Assim a cor de equipa, as cores das skins, o perfil gráfico Leve e o verniz da cerâmica funcionam
  como nas peças feitas por código.
- As cores do Blender servem só para a pré-visualização.
