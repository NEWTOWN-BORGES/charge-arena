# Sentinela LAB 2.9 — Refinado

APK local: `builds/charge-arena-2.9.0-sentinela-lab.apk`. Mesmo pacote e assinatura do LAB 2.8.1: instalar por cima, sem desinstalar, conserva o seu armazenamento. A aplicação principal continua independente.

## Apresentação

- Refinado usa resolução nativa e MSAA 8×. O FXAA anterior não era suportado pelo renderizador Compatibility; foi retirado.
- Galeria, retratos e fotografias do jornal também usam MSAA 8×. O retrato do Percurso passou a 640×560.
- Troncos, armaduras, botas e peças maiores têm bordas curvas e normais suaves. As malhas são partilhadas em cache; não foram acrescentadas luzes ou draw calls por peça. Rostos e identidades mantêm-se.
- O LAB seleciona Refinado na primeira utilização desta atualização. Escolhas posteriores em Opções são respeitadas. O perfil alto reduz a taxa de quadros quando necessário, mantendo a resolução e os efeitos; o perfil Leve continua disponível.

## História e saves

Nova partida: Aurora como teste de entrada, depois cinco qualificatórias por etapa e os bosses nesta ordem:

Faroleiro → Mineiro → Alquimista → Relojoeiro → Jardineiro → Astrónomo → Caça-Trovões → Corsário → Sentinela → Arconte Solar.

A admissão é um combate separado dos 60 da Taça. Não simula resultados de outros participantes nem desbloqueia prémios de boss. O tutorial interativo fica para uma atualização futura.

Saves avançados conservam as vitórias e os bosses já derrotados. A nova ordem aplica-se aos restantes; não exige repetir a admissão. A migração guarda uma cópia `.before-story-order` antes de converter o ficheiro. Saves após a admissão mas antes da primeira qualificatória também são restaurados.

## Música

Os ficheiros originais em `audio/` permanecem intactos. `tools/master_music.py` cria os masters em `audio/polished/`, preservando duração, notas, arranjo e ritmo. Reforça graves e ataques já existentes, reduz médios graves que encobrem a melodia e dá presença às linhas principais. Menu recebe tratamento mais suave. Pré-escuta das skins e transições continuam funcionais.

`master_report.json` contém medições dos 13 ficheiros: duração igual à fonte, correlação superior a 0,95 e picos abaixo de −1,8 dBFS. São verificações técnicas, não uma avaliação de audição em colunas de telemóvel.

## Validação

Testes de história completa, migração, admissão real, árvore, Percurso, jornal, vídeo, música, desbloqueios LAB e feedback passaram. `test_refinado.gd` verifica também orientação/normais das superfícies e cache de geometria. `preview-skins-sheet.png` foi renderizado em Refinado e inspecionado.

Alguns testes de integração ainda reportam recursos não libertados no encerramento do processo, sem falhas nas verificações funcionais. A máquina de validação usa uma GeForce 210 e não dispõe de saída de áudio: desempenho Android, intensidade das vibrações e equilíbrio musical precisam de avaliação no aparelho.
