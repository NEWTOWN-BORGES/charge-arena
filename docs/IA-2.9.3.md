# IA Normal/Difícil — 2.9.3

Integra e conclui o trabalho local de dificuldade encontrado após a 2.9.1/2.9.2.

- Normal e Difícil movem-se e disparam com maior frequência; a História e os níveis mantêm uma progressão dentro de cada dificuldade.
- As decisões sobre poderes têm relógio próprio, independente da recarga do tiro básico. Ultimates prontas têm prioridade; defesa urgente pode antecedê-las.
- Cura reage cedo a uma muralha danificada. Defesas e ultimates defensivas podem ser usadas durante esquivas. Cura numa muralha intacta e uma troca desfavorável do Corsário continuam a ser evitadas.
- Laser e Coroa Solar verificam um alvo direto. Projéteis normais continuam a prever ricochetes e a procurar blocos inimigos/baliza. A previsão considera a velocidade de movimento do bot.
- Carga passiva também funciona no jogo rápido contra IA. Só comandos internos de bot a ativam fora da campanha: jogadores humanos no PvP não recebem esta ajuda.
- A procura mantém quatro trajetórias por passo (40–50 ms), substituindo a proposta local de 14 por frame para conter o custo em telemóveis.

Nos cenários determinísticos de teste, a primeira preparação de ultimate ocorreu entre 8,3–8,6 s no Normal e 6,2–7,2 s no Difícil; estes tempos incluem a carga obtida ao destruir blocos, não são prazos garantidos para todas as partidas. Uma simulação de 90 s produziu 178 impactos produtivos e dois golos. Não houve dano aos próprios blocos.

## Alterações locais da loja integradas

No Alfa, instalações novas começam com o kit inicial e saldo zero. O LAB mantém os poderes abertos. A versão 3 do save da loja aceita compras, saldo e equipamento da versão 2 e cria uma cópia `.before-v3`; não apaga progresso para fechar a loja. Saves antigos sem versão continuam com o tratamento anterior.

## Validação

`test_ai_readiness.gd`: poderes durante a recarga da arma, cura contextual, carga exclusiva do bot e primeira ultimate nos dois modos/dificuldades. Suites existentes: pontaria tática, poderes, ultimates, campanha, progresso e acesso LAB. Desempenho físico e equilíbrio subjetivo ainda dependem de teste no aparelho.

APKs: `builds/charge-arena-2.9.3-alfa.apk` e `builds/charge-arena-2.9.3-sentinela-lab.apk`, versão Android 56, mantendo pacotes/assinaturas anteriores.
