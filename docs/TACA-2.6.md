# Taça Aurora 2.6.0 — versão de teste

A campanha da Taça tem 110 combates: dez etapas com dez qualificatórias e um
confronto contra o vencedor da chave do setor. A primeira etapa mantém o Farol.
As oito etapas intermédias mudam de ordem entre novos percursos; a ordem é guardada
com a semente da competição. A última etapa termina frente ao Arconte Solar.

Os cem adversários comuns têm nomes distintos, dez modelos de pilotos não
equipáveis, dois poderes e uma ultimate simples relacionada com o kit. A carga,
a preparação luminosa, os efeitos e a utilização pela IA são funcionais.
Os dez grandes adversários incluem Sentinela; cada vitória entrega a respetiva skin.

Aurel ocupa o papel de favorito da imprensa, tetracampeão à procura do penta.
Tem modelo próprio em marfim e ouro, quatro insígnias, arma e skin na galeria.
O seu prémio desbloqueia-se ao conquistar a Taça. Na outra semifinal, depois da
jornada 109, Arconte Solar elimina-o numa partida efetivamente registada.
A edição dessa jornada publica a surpresa. As edições anteriores preservam o
que se sabia à data. Lira e Vértice mantêm a reviravolta do primeiro setor.

Percurso mostra apenas resultados do jogador e o seu próximo confronto confirmado.
Árvore mostra os participantes e resultados publicados. Jornal tem uma edição
de abertura e uma por vitória. Derrotas não avançam nenhuma das três áreas.
Os resultados regionais são simulados localmente: não são partidas online.

O ficheiro `cup_v1.cfg` continua compatível. Saves da antiga demo com onze vitórias
abrem a segunda etapa. As skins conquistadas são reconciliadas ao carregar.
O catálogo começa bloqueado, com apenas Aurora disponível; poderes e arenas do
modo antigo continuam abertos para testes. Não há promessa de 110 arenas ou
100 modelos únicos: são reutilizados mapas e dez modelos de pilotos comuns.

Android Teste: pacote `org.chargearena.playtest`, versão 2.6.0-taca, código 47.
Arquiteturas ARM32, ARM64 e x86_64. Usa a mesma assinatura dos APKs de teste
anteriores gerados neste PC. Não inclui o progresso de desenvolvimento.

Testes: `test_tournament.gd` cobre o percurso completo, ausência de antecipação,
reconstrução dos resultados, ultimates comuns e os prémios da final real.
`capture_tournament.gd` regista a imprensa, o favorito, a galeria e a final.
`test_scroll.gd` cobre o arrasto dos menus: a lista certa por baixo do dedo, o eixo
que cada lista permite, o toque curto que não rola, o lançamento com inércia até
parar, o painel que fecha a meio do gesto e o cursor de volume que mantém o seu
próprio arrasto. Uma barra de progresso deixou de abrir faixa morta na coluna.
Testes no PC não substituem a instalação e o desempenho num telemóvel físico.
