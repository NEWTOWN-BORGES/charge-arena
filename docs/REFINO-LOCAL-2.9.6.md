# Refino local 2.9.6 — apresentação e som

Trabalho local sobre `674a24ce7af07390ee49fdd4abe443ea31b77a12` (2.9.5), preparado em 25 de setembro de 2026. Publicado no GitHub no mesmo dia, com autorização do utilizador, incluindo as capturas em `previews/premium`; os APKs seguem como anexos da release v2.9.6.

## Resultado

- As 12 skins e os dez modelos intermédios recebem armaduras curvas, juntas, acabamento de viseira e peças de arma específicas. Os acessórios acompanham a animação das pernas/corpo/recuo da arma. Olhos e identidade original das skins preservados.
- Materiais de cerâmica, liga metálica e grafite, com nove mapas locais de 512×512, mipmaps e normais suaves. Reflexos de ambiente, iluminação quente/fria, contraste e saturação revistos. Piso com painéis, juntas e desenho central; detalhes adicionais no perímetro fora da área de colisão.
- Novas frentes de choque: fogo com brasas, eletricidade ramificada, cura em pétalas, núcleo de singularidade e revestimento luminoso dos lasers. Complementam os efeitos existentes e seguem os eventos de combate, incluindo PvP.
- 83 efeitos sonoros pré-produzidos: três disparos por skin, impactos e quebras, ativação de habilidades e vozes próprias de ultimates. Disparos com mais corpo e reflexos estéreo curtos; compatibilidade mono verificada. A demonstração da arma no menu usa o mesmo som do combate.
- Canal `ChargeCombat` com limitador a −4 dBFS para conter sobreposições ocasionais. Mantém as 12 vozes para tiros e 16 para os restantes efeitos. Música e respetivas transições sem alterações.

## Perfis e custo

Refinado mantém resolução nativa, MSAA 8×, texturas de detalhe, normais, clearcoat e brilho. Equilibrado usa só a textura de cor. Leve remove texturas de superfície e brilho e usa acabamento dos pilotos sem iluminação PBR. Trocar Leve → Refinado recupera os parâmetros originais, incluindo materiais de novas skins.

As novas peças são agrupadas por material quando se cria o modelo. As frentes de choque usam 28 superfícies reutilizáveis de dois triângulos, limitadas a 8/18/28 conforme qualidade e debitadas no orçamento global de efeitos. Mantêm-se as reservas anteriores de partículas e luzes. Não há geração de texturas nem síntese de áudio durante um disparo.

Não se altera a simulação, colisões, dificuldade, progressão, pausa ou controlos. Mantêm-se os três modos de disparo, posição/tamanho do botão e respetiva pré-visualização.

## Validação local

- `test_premium.gd`: 22 modelos com nós de animação, acabamentos agrupados, geometria finita; transições de qualidade; saturação/reciclagem sem novos nós; dimensão e reutilização de lasers; cura; 83 sons e canal de áudio único.
- `test_controls_fx.gd`, `test_feedback_integration.gd`, `test_ultimate_sound.gd` e `test_feedback_parity.gd`: aprovados. A paridade cobre 1 200 ticks da simulação.
- `tools/master_combat_audio.py --check`: 83 ficheiros distintos, 5,60 MiB PCM antes da compressão QOA, pico máximo −2,05 dBFS, início/fim suaves e compatibilidade mono.
- Capturas reais no Godot 4.7.1 Compatibility: arena, combate, três pilotos em detalhe e coleção completa em `previews/premium`. Os shaders foram compilados numa execução gráfica real.
- `test_gameplay_aids.gd`: as verificações de sons, sobreposição, boost/PvP e demonstração da skin passaram. Subsiste uma asserção antiga que exige mais disparos em Difícil do que em Normal (18/59/54 em Fácil/Normal/Difícil). `arena_rules.gd` está idêntico ao commit de base; este passe não modifica a IA. Não se alterou essa asserção para esconder a falha.

Sem ensaio físico num Galaxy S23/A15. As contagens/limites acima não são medições de FPS Android. O PC de validação não conseguiu abrir o dispositivo WASAPI; a validação de áudio foi objetiva e de encaminhamento, faltando ouvir a mistura final num aparelho real.

## APKs locais e preservação de dados

Código Android 59, versão identificada como refino local. LAB usa `org.chargearena.sentinellab` e o ícone Sentinela; Alfa usa `org.chargearena.prototype` e o ícone Arconte. Mantêm-se as chaves de assinatura anteriores. Instalar sobre a mesma edição, sem desinstalar, conserva os dados desse pacote. Não há migração nem limpeza de saves neste passe.

Os APKs não entram no repositório (o LAB passa o limite de 100 MB do GitHub); ficam na release v2.9.6. O motor necessário é Godot 4.7.1; o shader utiliza `CLEARCOAT_ROUGHNESS` da série 4.7.
