> **2.9.4 — Muralhas:** colisões sólidas, Corsário corrigido, vida dos tijolos com barras grandes animadas e músicas exclusivas dos bots. [Alterações](docs/MURALHAS-2.9.4.md).

> **2.9.3 — IA:** Normal/Difícil mais ativos, poderes sem esperar pelo tiro básico e compatibilidade dos saves da loja. [Alterações e testes](docs/IA-2.9.3.md).

> **2.9.1:** notificações compactas com retratos dos desbloqueios; LAB com Sentinela e Alfa com Arconte. [Detalhes](docs/NOTIFICACOES-2.9.1.md). APKs em `builds/charge-arena-2.9.1-sentinela-lab.apk` e `builds/charge-arena-2.9.1-alfa.apk`.

> **2.9 — Sentinela LAB Refinado:** skins arredondadas, MSAA 8×, masters das músicas originais e nova ordem da história com Aurora na admissão. [Alterações e validação](docs/REFINADO-2.9.md). APK local: `builds/charge-arena-2.9.0-sentinela-lab.apk`.

> **2.8 — Impacto:** novo passe de disparo, sons por skin, destruição, câmara e vibração configuráveis; tiro manual opcional. [Alterações e testes](docs/IMPACTO-2.8.md). APKs locais: `builds/charge-arena-2.8.0-impacto.apk` e `builds/charge-arena-2.8.0-teste.apk`.

> **Demo 2.3 — Taça Aurora:** o menu inicial agora abre uma campanha de 10 qualificatórias + Faroleiro, com chave paralela de 1 024 participantes, jornal e progresso próprio. Consulte [a documentação atual da demo](docs/TACA-AURORA.md). As secções históricas abaixo descrevem também sistemas e versões anteriores.

# Charge Arena — protótipo Godot para mobile

Projeto 3D em Godot 4.7.1, renderizador Compatibility. Direção visual indie sci-fi: arena flutuante, jade/coral, cerâmica clara e pequenos pilotos robóticos. A arena foi ampliada sem aumentar as colisões dos pilotos, tijolos ou projéteis, e a câmara aproxima o cenário para tornar os acabamentos e efeitos mais legíveis no telemóvel. Modelos, materiais, interface, sons e música são criados por código; o vídeo e screenshots originais continuam intactos na pasta acima.

## Jogar

1. Importar `project.godot` no Godot.
2. Carregar em **F5** para executar o projeto completo.
3. Escolher **CAMPANHA** (níveis) ou **JOGO RÁPIDO** (arena original contra a IA).

O menu foi pensado para o polegar: fica encostado ao fundo do ecrã, com a leitura em cima e os botões em baixo — dificuldade da IA, **SKINS** / **OPÇÕES**, **PvP** / **NÍVEIS** / **JOGO RÁPIDO** e, por último e maior, **JOGAR NÍVEL X**.

**Carrossel de níveis.** Por trás do menu aparece a arena do nível escolhido, com o boss e os seus tijolos, o nome e o desafio por cima e pontos de página por baixo. Deslizar o dedo para a esquerda ou direita sobre a arena muda de nível (no PC: arrastar com o rato ou setas ← / →). Um toque, um arrasto curto ou vertical e deslizes sobre os botões não mudam o nível. O nome muda de imediato e a arena é reconstruída quando o dedo pára (cerca de 0,1 s num PC). O menu abre no primeiro nível ainda não vencido e volta ao último nível jogado. O PvP (criar sala ou entrar por IP) abre num painel próprio. Na vertical, os painéis de níveis e PvP também ficam junto ao fundo.

**O disparo é automático:** o piloto dispara sempre em frente assim que a arma está pronta, por isso só há que apontar. No PC: **A / D ou setas esquerda / direita** para deslocar o personagem ao longo do arco e mudar a direção do disparo; as teclas **1, 2 e 3** lançam os poderes e Escape regressa ao menu. No telemóvel, em orientação vertical: arrastar o polegar no joystick, que fica à **direita** da faixa inferior, com as três teclas de poder à **esquerda**. Qualquer toque nessa faixa agarra o joystick, onde quer que o dedo caia. Há também **assistência de mira**: se o tiro como está apontado falha por pouco, sai no ângulo vizinho que acerta num tijolo (no máximo 0,045 rad, `ASSIST_ANGLE`), e desliga-se em OPÇÕES. W/S e deslocamento vertical do controlo esquerdo não permitem sair do arco. Em **OPÇÕES**, a sensibilidade do movimento tem cinco níveis, de Muito lenta a Muito rápida.

## Orientação vertical

No telemóvel o jogo fica bloqueado na vertical. A interface mantém todos os elementos da versão horizontal, reorganizados em coluna: cabeçalho com **OPÇÕES** e **MENU**; placar e modo de jogo; cartão do adversário junto à baliza de cima; arena a toda a largura; cartão do jogador junto à baliza de baixo (no cliente PvP os cartões trocam, porque joga na baliza de cima); controlos para os polegares no fundo, com os três botões de poderes, o contador de FPS e o aviso de paralisia entre eles. As dicas que antes ficavam sob os cartões laterais passam para o lado direito de cada cartão. Contagem, golos e vitória aparecem centrados na arena. No menu, a arena surge por cima do painel.

A escala do conteúdo acompanha a forma do ecrã: 720 unidades no lado curto, `content_scale_size` 720×1280 na vertical e 1280×720 na horizontal. No PC a janela continua horizontal e o layout é o mesmo de antes; redimensionar a janela para vertical mostra a versão de telemóvel. A câmara mede a extensão real do estádio (faróis laterais incluídos) e enquadra-o na faixa entre os cartões. Em telemóveis com recorte de câmara, cabeçalho e rodapé descem/sobem pela área segura do ecrã.

## Poderes

Cada piloto leva **três poderes** para a partida: **dois comprados** na aba PODERES e postos no kit, e um terceiro que é a **ultimate da skin equipada** (sete skins já a têm; nas outras o botão aparece como `ULTIMATE · EM BREVE`). Dentro da partida cada poder enche a sua própria carga: cada tijolo inimigo destruído dá **um ponto a cada um dos três**, e ao usar um só esse volta a zero.

| Poder | Tipo | Carga | Preço | Efeito |
| --- | --- | --- | --- | --- |
| **Explosão** | ataque | 5 | inicial | Bala que rebenta ao acertar (ou ao fim dos 4 s): 2 de dano a tudo o que for inimigo num raio de 1,65. |
| **Metralhadora** | ataque | 10 | 200 | Uma rajada de 10 balas seguidas, umas atrás das outras, uma a cada 0,1 s. |
| **Rajada de Ar** | ataque | 12 | inicial | 5 balas de uma vez num leque de ±0,72 rad, cada uma com **2 de dano** e desvio aleatório. |
| **Balas Fantasma** | ataque | 4 | 250 | 8 s com as balas a atravessar pilares, barreiras e obstáculos; as paredes continuam a reflectir. Saem em roxo-claro. |
| **Raio Laser** | ataque | 18 | 800 | 3 s de feixe contínuo que atravessa tudo menos as paredes e morde duas vezes por segundo: 2 de vida por tijolo, seis dentadas ao todo. |
| **Reconstrução** | defesa | 15 | 600 | Devolve 7 tijolos inteiros ao teu campo, os mais próximos da baliza primeiro, cada um dentro de um anel de luz. |
| **Capa Espelho** | defesa | 12 | 700 | 4,5 s de capa nos teus tijolos: a bala inimiga volta como **bala de boost** — muda de dono e de cor, viaja mais depressa, tira 2 de vida e já não ricocheteia. |
| **Muralhas** | defesa | 10 | 300 | Uma muralha de cerâmica sobe à frente de cada banco de tijolos teus durante 6,5 s e volta à terra. Seguem a disposição do mapa e deixam frestas: o rival ainda acerta, mas tem de apontar. Os teus tiros atravessam-nas. |
| **Pulso de Choque** | defesa | 15 | 500 | Uma onda limpa **todas as balas do campo** e deixa o rival atordoado **4,5 s**. Os obstáculos móveis congelam no sítio durante o mesmo tempo, com estrelas a rodar por cima. |

**Ultimates** (`Powers.ULTIMATES`, uma por skin, custo de carga 20 e nunca à venda). Todas **brilham 2 segundos** antes de sair — um anel de latão fecha-se sobre o piloto enquanto faíscas são puxadas para dentro e a luz cresce, e a tecla conta o tempo —, por isso o adversário vê o golpe a chegar. Os efeitos usam partículas (CPUParticles3D com faísca redonda), luzes de impacto, marcas queimadas no chão e abalo de câmara; o raio de sol sai da própria arma, opaco, com núcleo branco, corpo dourado, coroa e anéis a descer pelo feixe. Nenhum outro poder pode ser lançado durante esse tempo. Na campanha o boss usa a sua: espera cerca de 42 s no nível 2 e apenas 7 s no nível 11 (`ultimate_wait`, encurtado no DIFÍCIL e alargado no FÁCIL), e cada uma tem o seu momento — o Arconte só alinha o raio com a muralha, o Jardineiro floresce com a sua ferida, o Sentinela abre o vórtice com o campo cheio de tiros, o Corsário só troca a muralha quando a dele é a pior, e o Relojoeiro põe as sentinelas assim que pode.

| Skin | Ultimate | Efeito |
| --- | --- | --- |
| Arconte Solar | **Coroa Solar** | Um raio de sol grosso, largo para quatro tijolos em fila, que atravessa a arena e segue para lá dela; morde três vezes, 2 de dano de cada vez. |
| Astrónomo | **Chuva de Meteoros** | 1 segundo com 14 meteoros roxos e âmbar a cair sobre o campo do rival, 1 de dano cada. |
| Caça-Trovões | **Trovoada** | 2 segundos com 8 raios a cair ao acaso no campo do rival, 2 de dano cada. |
| Jardineiro | **Florescer** | Cura 2 de vida em cada tijolo teu; os que já estão inteiros vão até 5 e ficam maiores, com anéis de luz e um +2 a subir. |
| Corsário | **Pilhagem** | Troca a tua muralha com a do rival, tijolo a tijolo e em espelho: os números e as posições passam para o outro lado. |
| Sentinela | **Singularidade** | Três ondas de choque caem do céu e varrem a arena inteira, uma atrás da outra: tudo o que apanham perde o rumo e é arrastado em câmara lenta até ao núcleo. Ao fim de 2,1 s o núcleo abre-se e devolve 26 a 44 projéteis num leque de 155° — os que têm um tijolo na sua faixa são deitados em cima dele —, à velocidade de bola turbinada, 2 de dano, sem ricochete e a atravessar os obstáculos móveis. |
| Relojoeiro | **Sentinelas** | Duas mini-guns automáticas ficam de pé no meio do ringue. Disparam sozinhas a cada 0,92 s, 2 de dano e sem ricochete, atacam a muralha do rival e metem golo se a baliza já estiver aberta (neste jogo só depois de a muralha cair). São frágeis — 2 vidas cada — e estão expostas: duas bolas em jogo bastam para abater uma. Juntas fazem cerca de 3 de dano por segundo enquanto vivas. |

**Loja e kit** (`scripts/powers.gd`, aba PODERES do menu). Cada poder escolhido mostra uma **demonstração animada** em ciclo — uma arena em miniatura onde se vê o efeito a acontecer: a bala a rebentar, o jorro da metralhadora, o feixe a comer tijolos, as muralhas a subir, a capa a devolver a bala como boost, a onda a limpar o campo, o vórtice a engolir os tiros e a cuspí-los em leque. A moeda são os **tijolos destruídos**, contados em qualquer modo e guardados em `user://powers.cfg` com as compras e o kit. A versão entregue vem com a **progressão ligada**: começas com um nível aberto, um piloto, a carteira a zero e os dois poderes de série. Cada chefe derrotado abre o nível seguinte e entrega a skin desse chefe — e com ela a ultimate dele. Uma partida rende cerca de 80 tijolos (119 nos níveis de chefe), portanto o primeiro poder comprado chega ao fim de umas três partidas e ter os sete custa perto de 40. Para um build de testes com tudo aberto, põe `UNLOCK_ALL_FOR_TESTS` a `true` em `powers.gd`, `skins.gd` e `campaign.gd`. Começas com Explosão e Rajada de Ar, que são de série e já vêm equipadas. Cada poder ocupa um slot de cada vez: equipá-lo no outro slot troca os dois.

No telemóvel os botões ficam em fila ao lado do joystick, na faixa livre por baixo da arena. Na horizontal essa faixa é o próprio estádio — e o teu piloto —, por isso passam para a bolsa por baixo do teu cartão, à esquerda da arena e acima do joystick, onde não tapam nada. O anel à volta de cada um mostra a carga (por exemplo `3/5`), acende quando o poder está pronto e, na metralhadora e no laser, passa a contar os segundos que faltam. No PC são as teclas **1, 2 e 3**.

As balas dos poderes seguem as mesmas regras das outras: ricocheteiam **até três vezes** (`MAX_BOUNCES`) antes de se apagarem, apanham aceleradores e atravessam os tijolos da própria equipa. A bala explosiva é maior e cor de âmbar, as da rajada mais pequenas e azul-claro, as fantasma roxo-claro, e as devolvidas pela capa espelho passam a douradas de boost. Um poder só pode ser lançado em jogo, com o piloto de pé e sem uma rajada ou um laser a decorrer.

**O boss também usa poderes**, com o kit próprio do seu nível (`Campaign.BOSS_KITS`): os primeiros só disparam, os últimos trazem laser e reconstrução. Ganha carga pela mesma regra e gasta-a com critério — os poderes pesados primeiro quando já tem um tiro certo num tijolo, a rajada de ar quando não tem ângulo nenhum, e os defensivos quando a muralha dele está a cair. Entre dois poderes espera um intervalo próprio: **8 / 5 / 3 segundos** em Fácil / Normal / Difícil no jogo rápido, e na campanha de **9,5 s no primeiro boss a 3 s no último**. O cartão do adversário mostra três pontos, um por poder, que acendem quando ele o tem pronto — e qualquer poder lançado, teu ou dele, faz som.

**PvP.** O cliente envia o pedido num canal fiável próprio, para não se perder com um pacote de movimento; as cargas, os temporizadores de cada efeito e o tipo de cada bala vão no estado sincronizado, e o cliente reproduz a explosão na posição onde a bala desapareceu.

**Valores ajustáveis**: preços, custos de carga e cores em `scripts/powers.gd`; em `scripts/arena_rules.gd`, `EXPLOSION_RADIUS`, `EXPLOSION_DAMAGE`, `RAPID_ROUNDS`, `RAPID_INTERVAL`, `AIR_PELLETS`, `AIR_DAMAGE`, `AIR_SPREAD`, `GHOST_SECONDS`, `LASER_SECONDS`, `LASER_TICK`, `LASER_DAMAGE`, `REBUILD_BRICKS`, `MIRROR_SECONDS`, `WALLS_SECONDS`, `WALL_CLEARANCE`, `WALL_GROUP_GAP`, `WALL_MAX_SPAN`, `WALL_SPLIT_GAP`, `STUN_POWER_SECONDS` e o `power_gap` de `AI_LEVELS`; na campanha, `Campaign.BOSS_KITS` e o `power_gap` de `Campaign.ai_profile`.

## Música

Sete faixas originais, todas sintetizadas localmente sem samples nem licenças de terceiros. O menu mantém sempre *Aurora Drift*; ao iniciar a partida, a música passa suavemente para o tema da skin equipada.

| Faixa | Onde | Estilo | Duração |
| --- | --- | --- | --- |
| `audio/music_menu.ogg` — *Aurora Drift* | Menu | Ambiente sci-fi, Ré dórico, 84 BPM: pads, arpejo, sinos FM | 45,7 s, 16 compassos |
| `audio/music_match.ogg` — *Charge Circuit* | Piloto Aurora | Synthwave, baixo pulsado, arpejo e lead | 64 s, 32 compassos |
| `audio/music_skin_1.ogg` | Faroleiro | Electro luminoso completo: bateria firme, baixo pulsado, sinos e ecos de farol | 64 s, 32 compassos |
| `audio/music_skin_2.ogg` | Astrónomo | Tema espacial completo: ritmo em meio-tempo, baixo orbital, pads e arpejos panorâmicos | 64 s, 32 compassos |
| `audio/music_skin_3.ogg` | Jardineiro | Tema orgânico completo: groove leve, baixo sincopado e percussão melódica de madeira | 64 s, 32 compassos |
| `audio/music_skin_4.ogg` | Mineiro | Tema industrial completo: bateria pesada, baixo áspero e impactos metálicos | 64 s, 32 compassos |
| `audio/music_skin_5.ogg` | Sentinela | Tema cinematográfico completo: ritmo grave em meio-tempo, baixo profundo e metais de eclipse | 64 s, 32 compassos |

Cada tema de skin é uma composição independente, com bateria, baixo, harmonia, melodia e arranjo próprios; nenhum contém a gravação de *Charge Circuit* por baixo. Todos começam com uma harmonia aberta compatível com o final do menu e repetem sem corte. `scripts/music_player.gd` faz a transição suave de 1,4 s entre menu e tema da skin, baixa 5 dB durante a contagem e 9 dB nos golos e no fim, e pausa quando a app vai para segundo plano. Em **OPÇÕES** há **Música de fundo** e **Volume**, guardados em `user://audio_settings.cfg`.

Para alterar a música, editar o script e regenerar (precisa de numpy, scipy e ffmpeg com libvorbis). Os ficheiros `.import` já têm o loop ativo:

```text
python tools/compose_music.py
python tools/compose_skin_music.py
```

As faixas foram verificadas objetivamente quanto à duração, repetição, independência do áudio e volume uniforme de −17,1 LUFS. O volume relativo entre música e efeitos deve ser afinado de ouvido num aparelho real; o ajuste está em `BASE_DB` e `DUCK_DB` no início de `music_player.gd`.

## Campanha

Onze níveis PvE. Cada um tem arena, desafio e boss próprios; vencer desbloqueia o seguinte e o progresso fica em `user://campaign.cfg`. **Nesta versão de testes todos os níveis estão abertos** (`UNLOCK_ALL_FOR_TESTS = true` em `scripts/campaign.gd`); as vitórias continuam a ser guardadas, e pôr a constante a `false` repõe o desbloqueio nível a nível. **Nesta versão de testes todos os níveis estão abertos** (`UNLOCK_ALL_FOR_TESTS = true` em `scripts/campaign.gd`); as vitórias continuam a ser guardadas, e pôr a constante a `false` repõe o desbloqueio nível a nível. O ecrã de níveis mostra o boss, o desafio, o estado (concluído / bloqueado) e o progresso. No início de cada nível a contagem mostra o nome e o desafio; no fim aparecem **PRÓXIMO NÍVEL**, **REPETIR NÍVEL** / **TENTAR DE NOVO** e **NÍVEIS**.

| Nível | Arena | Contorno | Tijolos | Desafio | Boss |
| --- | --- | --- | --- | --- | --- |
| 1 | Circuito Aurora | hexágono | bancos | treino | Piloto Aurora (cópia de série) |
| 2 | Oficina do Relógio | hexágono | bancos | deslizadores | Relojoeiro |
| 3 | Baía do Farol | octógono | muralha | pilares e muralha | Faroleiro |
| 4 | Estufa Suspensa | cintura estreita | arcos | cintura estreita | Jardineiro |
| 5 | Observatório Lunar | hexágono | ilhas | duas luas | Astrónomo |
| 6 | Mina Profunda | bojo largo | chevron | vagonetas | Mineiro |
| 7 | Santuário Eclipse | octógono | bancos | monólito central | Sentinela |
| 8 | Torre da Tempestade | cintura estreita | ilhas | defletores | Caça-Trovões |
| 9 | Laboratório de Cristal | bojo largo | arcos | losango de pilares | Alquimista |
| 10 | Recife dos Corsários | hexágono | muralha | órbita e barreira | Corsário |
| 11 | Coroa Solar | octógono | chevron | tudo junto | Arconte Solar |

O nível 1 é um treino contra uma cópia do piloto de série, sem obstáculos. Cada um dos dez níveis seguintes tem o seu próprio boss, com skin, tijolos e tema musical próprios: vencê-lo desbloqueia essa skin. A força do boss sobe de nível para nível (menos pausa entre disparos, mais velocidade, esquiva a partir do terceiro, poderes cada vez mais seguidos e kits melhores) e a dificuldade escolhida no menu desloca toda a curva: FÁCIL abranda cada boss, DIFÍCIL acelera-o.

**Mapas por dados.** `scripts/arena_rules.gd` guarda o mapa ativo (`map`): contorno, aceleradores, disposição dos tijolos, obstáculos (`fixed`, `slide` com eixo, `orbit`) e barreiras interiores (muros arredondados que gastam ricochete como uma parede). Balizas e arcos dos pilotos nunca mudam, por isso regras de golo, IA, guia de mira e rede são as mesmas. O mapa de omissão reproduz exatamente a arena original, usada no jogo rápido e no PvP. `scripts/campaign.gd` tem os onze níveis; a arena 3D é reconstruída só quando o mapa muda. Pilares fixos têm tampa dourada e obstáculos móveis tampa escura; deslizadores e órbitas mostram o percurso pintado no chão.

Todos os mapas são verificados em `tests/test_campaign.gd`: tijolos dentro das paredes e sem sobreposição, obstáculos que nunca tocam tijolos, arcos, balizas ou barreiras, e 12 s de jogo em cada mapa sem nenhuma bola a escapar. Capturas: `tests/capture_levels.gd` (as onze arenas) e `tests/capture_campaign_ui.gd` (menu, níveis, PvP, início e fim de nível).

## Skins

Cada boss da campanha veste uma skin. Durante o nível luta todo vermelho, na cor da equipa; ao derrotá-lo a skin revela as cores originais ali mesmo no campo e fica desbloqueada na aba SKINS, com **NOVA SKIN DESBLOQUEADA** e o nome no ecrã de vitória. São dez bosses (níveis 2 a 11) mais o Piloto Aurora, de série. **Nesta versão de testes todas as skins estão abertas** (`UNLOCK_ALL_FOR_TESTS = true` em `scripts/skins.gd`); as vitórias continuam guardadas em `user://skins.cfg` com a skin equipada.

Cada skin muda o piloto, a arma, as cores dos disparos **e os tijolos da sua equipa**.

| Tijolos | Skin | Arma | Tema dos tijolos | Cores |
| --- | --- | --- | --- | --- |
| 0 | **Piloto Aurora** | Manopla de energia | Baterias Aurora | cores da equipa |
| 10 | **Faroleiro** — cúpula com aro de latão, gema de farol, lanterna às costas | Lança-Farol | Farolins: torre creme, faixa da equipa, janela de luz, tampa de latão | luz e disparos azul-farol |
| 20 | **Astrónomo** — anéis orbitais a rodar, luneta, tubo de mapas | Sextante Estelar | Observatórios: bloco índigo, aro de latão, estrela em cada face | corpo índigo, disparos violeta |
| 30 | **Jardineiro** — cúpula de vidro com rebento, avental, vaso às costas | Semeador | Estufas: vaso de cerâmica vidrada com folhas | corpo musgo, disparos verde-folha |
| 40 | **Mineiro** — capacete de obra com lanterna, carga de cristais | Perfuradora de Cristal | Veios de cristal: pedra, cinta de aço, cristais rosa | corpo carvão, disparos magenta |
| 50 | **Sentinela** — capa de obsidiana, halo de eclipse dourado | Lança Eclipse | Monólitos Eclipse: obsidiana em plinto dourado, eclipse em cada face | corpo obsidiana, disparos pérola |

**Visualizador.** O botão **SKINS** abre um painel com o piloto em 3D num pedestal, junto de dois tijolos do tema em exposição (o segundo com uma vida perdida, mais pequeno e com uma luz apagada). Arrastar roda o pedestal, que volta a girar sozinho após 1,5 s; o piloto dispara de vez em quando para mostrar a cor do raio. Ao lado ficam nome, arma, tema dos tijolos, descrição, amostras de cor (corpo, luz, disparo), progresso e uma grelha de miniaturas para pré-visualizar qualquer skin — também as bloqueadas. **EQUIPAR** só fica ativo quando a skin está desbloqueada; caso contrário mostra que nível é preciso vencer.

**Legibilidade.** A aura e o rasto dos disparos usam a cor da skin, mas o brilho no chão por baixo de cada tiro, o anel aos pés do piloto, os braços e as três luzes de vida de cada tijolo mantêm a cor da equipa. Disparos acelerados continuam dourados com qualquer skin. No PvP cada jogador envia a skin ao ligar-se e o rival vê piloto, disparos e tijolos. A skin muda só o aspeto: colisões e regras são iguais.

**Desempenho.** Todos os temas usam o mesmo tamanho de tijolo. Trocar de skin reconstrói os 40 tijolos dessa equipa e reagrupa as peças; com duas equipas de temas diferentes os 80 tijolos continuam em 7–11 grupos de desenho.

**Acrescentar uma skin:** nova entrada em `CATALOG` (`scripts/skins.gd`: `weapon`, `bricks`, `unlock`, `body`, `light`, `shot`; cores vazias usam a cor da equipa), um ramo em `build_player` e outro em `make_brick` (`indie_arena_view.gd`; o piloto precisa dos nós `LegL`, `LegR`, `Gun/Flash`, o tijolo das luzes `HP0`–`HP2`) e um avatar em `portrait` (`game_hud.gd`). Capturas de controlo: `tests/capture_skins.gd` (pilotos e tijolos) e `tests/capture_skins_ui.gd` (visualizador e disparos).

## Gráficos e som

Abrir **GRÁFICOS E SOM** no menu, ou **OPÇÕES** durante a partida. Escolher o limite de **60, 90 ou 120 FPS**, a qualidade, VSync e o contador de **FPS reais**. As preferências são guardadas em `user://video_settings.cfg`. O padrão móvel é Leve / 60 FPS / VSync ligado. Instalações anteriores são migradas uma vez para este perfil, evitando que uma preferência antiga pesada continue ativa após a atualização. Escape fecha primeiro este painel. O PvE pausa enquanto as opções estão abertas; no PvP a partida continua, com o movimento e disparo locais libertados.

| Qualidade | Suavização dos contornos | Máximo de efeitos visuais |
| --- | --- | --- |
| Leve | Sem MSAA, iluminação plana, resolução 3D 68% | 20 |
| Equilibrado | MSAA 2×, resolução 3D 84% | 48 |
| Refinado | MSAA 4×, resolução 3D 100% | 96 |

No telemóvel, um controlador acompanha o desempenho durante a partida. Em **Refinado** e **Equilibrado**, conserva exatamente a resolução e os efeitos escolhidos e reduz apenas o alvo de 120 para 90 e depois 60 FPS quando necessário. Só o perfil **Leve**, destinado a aparelhos mais fracos, pode reduzir gradualmente a resolução 3D e recorrer a 45/30 FPS. A interface permanece à resolução nativa. A simulação continua a 60 passos por segundo; o desenho interpola personagens, obstáculos e projéteis entre esses passos. No cliente PvP, a interpolação usa as duas últimas atualizações recebidas (intervalo nominal de 50 ms).

## Ajuda de jogabilidade

Em **OPÇÕES** também se escolhe a dificuldade da IA — Fácil, Normal ou Difícil —, ativa-se o guia de mira e regula-se a sensibilidade do joystick entre cinco níveis. O guia desenha a trajetória prevista, incluindo ricochetes, e marca o tijolo, jogador ou baliza que será atingido. A mira e a IA usam a mesma simulação de trajetória. A curva suave continua a permitir pequenos ajustes; a sensibilidade muda a velocidade resultante sem alterar o arco.

Os sons das seis armas usam canais simultâneos: disparos, ricochetes e impactos podem sobrepor-se sem cortar a cauda do som anterior. O acelerador tem um sinal ascendente próprio, diferente do clique de ricochete, e também é detetado no cliente PvP.

Referências técnicas: [antialiasing do Godot](https://docs.godotengine.org/en/4.6/tutorials/3d/3d_antialiasing.html) e [limite de FPS e taxa da simulação](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-fps). Esta versão Compatibility usa MSAA; não depende de TAA ou de efeitos exclusivos do Forward+.

## Regras desta versão

- Mapa hexagonal baseado em `Drawing3-Layout1.pdf`, com uma baliza em cada ponta e quatro grupos de tijolos nas paredes inclinadas.
- Cada personagem desloca-se exclusivamente no seu arco, à frente da respetiva baliza. A orientação é determinada pela posição no arco: dispara sempre em frente. Jogador, IA e cliente PvP obedecem à mesma regra.
- Cada piloto tem uma barra de **5 vidas**. Cada bola inimiga retira uma vida; ao chegar a zero, o piloto fica paralisado durante **0,5 segundo** e recupera as cinco vidas ao voltar. Os próprios projéteis nunca atingem o atirador, mesmo depois de ricochetes.
- **A bola ricocheteia até acertar no alvo.** Paredes, escudos, barreiras, aceleradores e obstáculos refletem-na sempre, sem limite de ricochetes. O disparo só acaba ao atingir um tijolo inimigo, o piloto adversário ou a baliza aberta. Já não existe orçamento de ricochetes nem o bónus de +1 dos obstáculos: a bola simplesmente continua.
- Como salvaguarda, uma bola que nunca chegue a um alvo desaparece ao fim de **12 segundos** (`BALL_LIFE`). Serve só para limpar um disparo preso num trajeto que se repete; na prática quase todos acertam muito antes. Se a arena chegar ao limite de 128 bolas, a mais antiga sai para dar lugar ao novo disparo, em vez de o tiro falhar.
- Dois obstáculos circulares atravessam a região central na horizontal, em pistas separadas e sentidos opostos. Refletem a bola sobre a superfície em movimento, mantendo a velocidade do disparo. A colisão considera o movimento do obstáculo durante o frame para evitar atravessamentos.
- Os arcos dourados nas paredes laterais são aceleradores: refletem a bola, reproduzem um som de carga próprio, aumentam a velocidade para **1,65×** e o dano para **2**. Velocidade e dano não se multiplicam com boosts sucessivos.
- Os próprios tijolos são imunes e transparentes aos disparos da sua equipa: a bola atravessa-os e pode continuar até uma parede, obstáculo ou alvo inimigo. Esta regra aplica-se igualmente ao jogador, à IA e ao PvP.
- Cada tijolo tem **3 vidas**. Um disparo normal tira 1 vida e um acelerado tira 2. O tamanho e a colisão diminuem de 100% para 76% e depois 52%; com zero vidas, o tijolo desaparece. As três marcas no topo mostram as vidas restantes.
- Existem 20 tijolos em cada grupo (filas de 6, 5, 4, 3 e 2), totalizando 40 por jogador. Destruir os dois grupos adversários desbloqueia a baliza. Enquanto há tijolos, um escudo de energia protege a entrada.
- A baliza aberta fica verde; acertar dentro dela marca um golo.
- Após um golo, os tijolos e posições são repostos, preservando o placar. Vence o primeiro a 3 golos.
- O atirador fica protegido do próprio projétil durante toda a trajetória.
- A IA procura posições no arco que permitam atingir os tijolos adversários, favorecendo destruir os mais frágeis e aproveitar o dano dos boosts. Prevê colisões e movimento dos obstáculos, verifica novamente a trajetória antes de disparar e procura marcar quando a baliza abre. Evita tiros sem objetivo e desvia-se de ameaças próximas; a previsão não conhece decisões futuras do adversário. A pesquisa é repartida por vários frames.

**Valores ajustáveis:** 5 vidas por piloto, paralisia de 0,5 s, velocidade do boost 1,65×, 20 tijolos por grupo, todos os tijolos necessários para desbloquear a baliza e limite de 3 golos. O PDF não inclui cotas; as dimensões e o comprimento dos arcos foram adaptados para manter o mapa legível no ecrã. Constantes principais em `scripts/arena_rules.gd`: `PLAYER_LIVES`, `TRACK_RADIUS`, `TRACK_LIMIT`, `FACING_FACTOR`, `OBSTACLE_RADIUS`, `OBSTACLE_TRAVEL`, `OBSTACLE_FREQUENCY`, `BRICK_ROWS`, `BRICK_LIVES`, `BOOST_SPEED`, `BOOST_DAMAGE`, `STUN_SECONDS`, `BALL_LIFE` e `WIN_SCORE`.

## PvP por ligação direta

Nos dois dispositivos, executar a mesma versão. Um escolhe **Criar partida** e passa o IP apresentado ao outro. O segundo introduz esse IP e escolhe **Entrar**. O anfitrião controla a simulação; o cliente envia apenas movimento e disparo. As regras e o placar são sincronizados. Ao sair um jogador, a partida termina com uma mensagem.

A porta utilizada é UDP **27940**. Na mesma rede Wi-Fi, o router precisa de permitir comunicação entre os dispositivos e a firewall do anfitrião precisa de permitir o Godot. Pela internet é necessário um anfitrião acessível; este projeto **ainda não inclui servidor público, matchmaking, relay, contas ou salas por código**. Não foram alteradas regras de firewall nem configurações do router.

## Android

Preset **Android** com `arm64-v8a` (aparelhos reais) e `x86_64` (emulador), orientação vertical e permissão de internet. A saída é `builds/charge-arena.apk`.

O ambiente já está preparado: templates de exportação 4.7.1, caminhos do SDK e do JDK nas definições do editor, e keystore de depuração em `%APPDATA%/Godot/keystores/debug.keystore`.

Gerar o APK:

```text
godot --headless --path . --export-debug "Android" builds/charge-arena.apk
```

Instalar e correr num telemóvel ligado por USB, com **Depuração USB** ativa nas Opções de programador:

```text
adb devices
adb install -r builds/charge-arena.apk
adb logcat -s godot
```

O APK foi gerado, instalado e lançado no emulador: o motor arranca, cria contexto OpenGL ES 3.0 e entra no ciclo principal sem erros de script.

### Testes em dispositivos Android

O **Charge Arena já foi testado em vários smartphones Android reais de gama média moderna**, para além dos testes realizados em PC e emulador.

Os testes em dispositivos físicos apresentaram **resultados muito positivos de desempenho e estabilidade**, incluindo partidas com os principais sistemas do jogo ativos: projéteis e ricochetes, obstáculos móveis, destruição de tijolos, poderes, ultimates, partículas, animações, música, efeitos sonoros e interface tátil.

Durante estes testes, o jogo manteve uma experiência fluida e estável nos dispositivos utilizados, sem terem sido identificados problemas graves de desempenho que impedissem a jogabilidade. Os controlos por toque, a orientação vertical e a interface adaptada a ecrãs de telemóvel também foram testados em utilização real.

Os resultados observados são consistentes com o trabalho de otimização já aplicado ao projeto, incluindo reutilização de geometria, MultiMeshes para os tijolos, limites de efeitos visuais, perfis de qualidade e ajuste dinâmico de desempenho.

> Os resultados podem variar conforme o dispositivo, resolução, temperatura, versão do Android e perfil gráfico selecionado. Ainda não foi estabelecido um requisito mínimo oficial de hardware.

### Estado atual do projeto

O **Charge Arena encontra-se numa fase avançada de desenvolvimento**, com o ciclo principal de jogo e grande parte dos sistemas previstos já funcionais.

A versão atual inclui campanha PvE, bosses com comportamentos e poderes próprios, progressão, skins, ultimates, loja e kit de poderes, jogo rápido, PvP por ligação direta, diferentes arenas, Taça Aurora, sistema de torneio, jornal narrativo, música e efeitos sonoros próprios, configurações gráficas e controlos táteis.

A prioridade atual está concentrada em **polimento, game feel, equilíbrio, clareza da interface, feedback audiovisual, experiência de novos jogadores e testes numa variedade maior de dispositivos** antes de expandir significativamente o conteúdo ou avançar para uma distribuição pública mais ampla.

A compatibilidade Android continuará a ser avaliada para estabelecer requisitos mínimos, comportamento em sessões prolongadas, consumo de bateria, temperatura e desempenho em hardware mais modesto.

Notas sobre o emulador: com `-gpu host` o jogo desenha na janela do emulador, mas `adb exec-out screencap` devolve preto porque não captura a SurfaceView; com `-gpu swiftshader_indirect` a captura funciona mas os shaders não compilam (`GL_MAX_FRAGMENT_UNIFORM_VECTORS` insuficiente). Para prova visual, usar um aparelho real.

iOS requer a sua própria configuração e ferramentas de exportação, e um Mac.

## Testes

Teste determinístico de regras:

```text
godot --headless --path . --script res://tests/test_rules.gd
godot --headless --path . --script res://tests/test_touch.gd
godot --headless --path . --script res://tests/test_map_view.gd
godot --headless --path . --script res://tests/test_forward_obstacles.gd
godot --headless --path . --script res://tests/test_tactical_ai.gd
godot --headless --path . --script res://tests/test_video.gd
godot --headless --path . --script res://tests/test_mobile_input.gd
godot --headless --path . --script res://tests/test_portrait.gd
godot --headless --path . --script res://tests/test_music.gd
godot --headless --path . --script res://tests/test_skins.gd
godot --headless --path . --script res://tests/test_gameplay_aids.gd
godot --headless --path . --script res://tests/test_campaign.gd
godot --headless --path . --script res://tests/test_powers.gd
```

Validação gráfica das instâncias e captura com medição dos perfis (precisa de GPU; omitir `--headless`):

```text
godot --path . --audio-driver Dummy --script res://tests/test_video.gd
godot --path . --audio-driver Dummy --script res://tests/test_polish_visual.gd
godot --path . --audio-driver Dummy --script res://tests/test_portrait_visual.gd
```

Teste de rede em dois processos: iniciar o anfitrião, depois o cliente (antes de 12 s):

```text
godot --headless --path . --script res://tests/test_network.gd -- --host
godot --headless --path . --script res://tests/test_network.gd -- --client
godot --headless --path . --script res://tests/test_pvp_powers.gd -- --host
godot --headless --path . --script res://tests/test_pvp_powers.gd -- --client
```

O carril do piloto é uma **elipse** (4,6 de largura por 2,6 de profundidade), não um círculo: um círculo de raio 2,6 nunca deixaria o piloto afastar-se mais do que isso do centro, por mais larga que fosse a arena. Cada arena mede o seu próprio arco contra as suas paredes (`track_limit_for`), e as cinco da campanha — estádio, lente, desfiladeiro, octógono e coliseu — têm todas um fundo largo atrás das balizas, o que dá ao piloto 3,5 a 4,35 de alcance lateral (era 1,47). A mira acompanha: em vez de virar um múltiplo fixo do ângulo do carril, o piloto olha para um ponto que varre o fundo da arena, por isso aponta sempre para dentro do campo. Os obstáculos vivem junto às paredes e aos cantos, nunca na rota central: servem para ricochete, não para tapar.

As muralhas crescem com a campanha. A maioria dos níveis traz 40 tijolos por lado com 3 vidas cada; os níveis de chefe trazem o **baluarte** (3 fileiras, 54 tijolos) ou a **fortaleza** (5 fileiras, 60 tijolos), e o mapa decide quantas vidas cada tijolo começa com (`lives`, até 5). A muralha final vale 240 contra os 120 da primeira, e um teste garante que dobra sem virar maratona.

## Ficheiros

- `scripts/arena_rules.gd`: movimento, tiros, colisões contínuas, paralisia, tijolos, golos e IA.
- `scripts/indie_arena_view.gd`: arena com bordas chanfradas, personagens articulados, animações e efeitos 3D procedurais.
- `shaders/`: chão pintado, sombras suaves, balizas de energia e fundo atmosférico.
- `scripts/game_hud.gd`: menus, placar, controlos de toque e layouts horizontal/vertical.
- `scripts/main.gd`: execução, efeitos sonoros, escala do ecrã, enquadramento da câmara e ligação ENet.
- `scripts/music_player.gd`: música de fundo, transições, atenuação e preferências de som.
- `scripts/skins.gd`: catálogo de skins, contagem de tijolos destruídos e progresso guardado.
- `scripts/game_settings.gd`: dificuldade, guia de mira e sensibilidade do joystick.
- `scripts/campaign.gd`: os onze níveis (mapa, desafio, boss, força da IA) e o progresso guardado.
- `scripts/video_settings.gd`: limites de FPS, qualidade, VSync e preferências locais.
- `audio/`: música do menu, seis temas de partida e efeitos de armas.
- `tools/compose_music.py` e `tools/compose_skin_music.py`: composição e mistura da música (excluídos do APK).
- `tests/`: testes de regras e comunicação entre anfitrião e cliente.

Os personagens finais do vídeo ainda não fazem parte deste protótipo. O objetivo é validar o ciclo de movimentar-se para apontar, disparar, usar os poderes ganhos, paralisar, abrir a baliza e marcar.

## Visual indie — mapa hexagonal / revisão 06

- Plataforma hexagonal com bordas chanfradas, grelhas, faróis flutuantes e detalhes em latão.
- Chão com linhas pintadas, arcos das balizas, textura subtil e sombreamento consistente, sem o artefacto quadriculado da primeira versão.
- Pilotos Nova e Ember com capacete arredondado, viseira, olhos, mochila, movimento das pernas e recuo da arma.
- Quatro grupos de tijolos em forma de baterias que encolhem, balizas curvas com energia animada, arcos de movimento visíveis e dois aceleradores laterais dourados. Disparos acelerados ganham uma aura maior e um rasto dourado.
- Dois obstáculos circulares de cerâmica com anéis luminosos, deslocamento horizontal e pistas discretas desenhadas no chão.
- Fragmentos na destruição, faíscas no ricochete, estrelas de paralisia e efeitos de golo.
- Interface com retratos que reagem à paralisia, contagem de defesas e controlos de toque na mesma paleta.
- Cerâmica com brilho suave, latão com acabamento metálico, iluminação quente/fria equilibrada, capacetes mais redondos e sombras de contacto sob os tijolos.
- Arcos e aceleradores são superfícies contínuas, sem junções entre pequenos blocos. As linhas do chão usam suavização pela dimensão do píxel; a textura e as linhas animadas dos escudos foram ajustadas para reduzir cintilação.
- Renderizador Compatibility, materiais e geometria reutilizados. A arquitetura opaca foi agrupada em 19 conjuntos e as 560 peças dos tijolos em 7 MultiMeshes. Tijolos só atualizam as transformações quando perdem vidas ou são repostos. Partículas pequenas usam menos geometria; o HUD atualiza a 30 Hz e reutiliza estilos.
- Sem MSAA/MSAA 2×/MSAA 4× e limites de efeitos configuráveis. Movimento visual interpolado sem alterar a velocidade da partida. Refinado preserva os gráficos completos durante o ajuste automático de FPS.

O protocolo de rede desta revisão sincroniza as posições em arco, orientação fixa, obstáculos móveis, projéteis acelerados e vidas dos 80 tijolos. O estado usa vetores numéricos compactos sem executar compressão DEFLATE na thread principal a cada atualização, reduzindo picos de CPU durante o PvP. O cliente envia apenas movimento e disparo; não pode enviar uma direção de mira. As posições dos tijolos são reconstruídas de forma determinística; apenas as vidas são enviadas, mantendo os pacotes pequenos. Usar esta mesma versão nos dois dispositivos. O ficheiro `scripts/arena_view.gd` contém apenas o visual antigo, mantido como referência; o projeto executa `indie_arena_view.gd`.

## Verificação realizada

- 40 verificações das regras passaram, incluindo movimento em arco, os dois aceleradores, dano 1/2, colisão com tijolos rodados e encolhidos, balizas e reposição de rondas.
- 19 verificações de orientação fixa, colisão com obstáculos móveis, imunidade ao próprio disparo e entrada do rato passaram.
- 20 verificações de IA por objetivos, proteção dos tijolos aliados, ricochetes adicionais, previsão sem alterar o estado e desvio de ameaças. A simulação de 90 segundos mede os disparos, acertos nos tijolos e golos; também é testada uma baliza já aberta.
- 7 verificações de eventos de toque passaram, incluindo agarrar o joystick em qualquer ponto da faixa e o disparo automático a continuar sem botão.
- 7 verificações dos modelos passaram, incluindo encolhimento, marcas de vidas, aura do boost, escudo aberto e reposição dos tijolos.
- 22 verificações de vídeo passaram com renderização gráfica: nove combinações de qualidade/FPS, persistência, valores inválidos, controlos, pausa PvE, interpolação e encolhimento/destruição/reposição dos MultiMeshes. Em modo headless executam-se 19; as três leituras de transformações na GPU exigem o renderizador gráfico, pois o renderizador dummy devolve matrizes identidade.
- Duas instâncias em localhost ligaram-se por ENet e confirmaram disparos, projéteis acelerados, ricochetes adicionais, movimento em arco, orientação fixa, obstáculos móveis, vidas e tamanhos dos tijolos nos dois lados. Isto não equivale a testar dois telemóveis ou uma ligação pela internet.
- Menu, painel de vídeo e partida foram renderizados e revistos. Capturas atuais em `preview-menu-r06.png`, `preview-settings-r06.png`, `preview-gameplay-r06.png` (1280 × 720) e `preview-mobile-r06.png` (1200 × 554).
- Ensaio local na NVIDIA GeForce 210, a 1200 × 554, VSync desligado, três segundos por perfil após aquecimento: Leve/limite 60 = **25,9 FPS**, Equilibrado/limite 90 = **19,7 FPS**, Refinado/limite 120 = **12,8 FPS**; cerca de 389–394 chamadas de desenho por frame para a cena completa e interface. É uma medição curta neste PC, não um benchmark de telemóvel. Não foram atingidos nem validados 60/90/120 FPS reais neste hardware. Log em `polish-visual.log`.
- O dispositivo de áudio do ambiente de teste estava indisponível; a verificação visual utilizou o driver Dummy. Sons sintetizados incluídos, mas a reprodução audível ainda precisa de verificação.
- **Poderes: 89 verificações passaram** em `tests/test_powers.gd` — cargas e limites, dano em área dentro e fora do raio, uma bala explosiva disparada pelo arco até detonar, as 30 balas da rajada, o leque de 9 balas sempre diferente, o boss a ganhar e gastar poderes com ritmos distintos por dificuldade e por nível, o estado que viaja na rede e os botões nas duas orientações (sem tapar cartões, contador de FPS, aviso de paralisia nem o estádio). Os outros 13 scripts de teste foram repetidos e passam todos.
- Dois ajustes saíram destes testes: a rajada usava um intervalo de 0,10 s que na grelha de 60 Hz escorregava para 7 frames e dava só 26 balas (`RAPID_INTERVAL` passou a 0,09, que dá 6 frames certos), e o resíduo do float no cronómetro da rajada oferecia uma 31.ª bala.
- **Ricochete sem limite:** os 14 scripts de teste voltaram a passar depois da mudança. As verificações que descreviam o orçamento de ricochetes foram reescritas para a regra nova — uma bola atravessa a arena doze vezes seguidas (24 contactos com parede) e continua viva, o acelerador volta a carregar uma bola já ressaltada sem acumular velocidade nem dano, e a salvaguarda dos 12 s continua a limpar um disparo que nunca chega a um alvo. Na simulação de 45 s com a IA havia **18 bolas em jogo** no fim, ou seja a mudança não enche a arena: os disparos passam a acertar mais cedo, não a durar mais.
- APK gerado e assinado: `outputs/charge-arena-0.7.0-ricochete.apk` (94,5 MB, `org.chargearena.playtest`, versionCode 13, arm64-v8a + armeabi-v7a + x86_64, minSdk 24). O projeto já foi **testado em vários smartphones Android reais de gama média moderna**, com resultados muito positivos de desempenho e estabilidade nos dispositivos utilizados. A validação continua numa variedade maior de hardware para definir requisitos mínimos e avaliar sessões prolongadas.
