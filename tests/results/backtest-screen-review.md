# Lecture du backtest fourni le 10 septembre 2026

Le rapport affiché ne valide pas la rentabilité monétaire du bot.

## Vérifications dans le journal du terminal

- Version exécutée : V4.30.
- Période demandée : 2021-01-01 à 2025-01-01.
- Initialisation effective de l'EA : 2023-01-07.
- Mode activé : `calculate profit in pips`, confirmé par `ProfitInPips=1` dans la configuration du test.
- Absence de vrais ticks : `no real ticks, every tick generation used`.
- Solde final : `1002.86 pips` ; résultat OnTester : -33.52357572965113.

## Lecture de la capture

55 positions ; facteur de profit 1,03 ; gain net affiché 2,86 ; drawdown des fonds 5,14 % ; 24 positions gagnantes (43,64 %) ; 31 perdantes (56,36 %). Gain moyen 3,53 contre perte moyenne 2,64. Qualité de l'historique : n/a.

Le bilan est presque à l'équilibre et repose sur peu de positions. Il ne démontre pas un avantage robuste. Les chiffres affichés ne doivent pas être présentés comme des dollars gagnés : le calcul en pips désactive notamment les commissions, le swap et le contrôle de marge, selon la [documentation MT5](https://www.metatrader5.com/en/terminal/help/algotrading/testing).

La série de huit pertes ne prouve pas à elle seule un défaut du coupe-circuit : une pause de 24 heures peut séparer plusieurs groupes de pertes sans interrompre leur succession dans le rapport global.

## Prochain contrôle

Utiliser `ProfitInPips=0`, une devise de dépôt explicite, les coûts du compte et vérifier dans le journal la présence effective des ticks réels et la période réellement couverte. Ne pas comparer directement les résultats en pips et en devise.

## Deuxième passage — calcul monétaire

Le passage fourni ensuite est bien calculé en USD avec la V4.30. Résultats affichés : dépôt 1 000 USD, solde final 1 002,60 USD, profit brut 84,60 USD, perte brute 82,00 USD, facteur de profit 1,03, drawdown maximal des fonds 5,16 %, 55 positions, 43,64 % gagnantes et score OnTester -33,77155.

Le journal complet confirme toutefois :

- période demandée : 2021-01-01 à 2026-01-01 ;
- données disponibles à partir du 2023-01-07 ;
- dernier événement du bot : 2024-08-21 ;
- `no real ticks, every tick generation used` malgré le mode demandé fondé sur les ticks réels ;
- 2 154 441 ticks générés et 6 576 barres ;
- 6 296 snapshots utilisables et 733 échecs de chargement de données.

Décision : résultat préliminaire rejeté pour validation réelle. Même pris au pied de la lettre, un gain de 0,26 % face à 5,16 % de drawdown, un facteur de profit de 1,03 et seulement 55 positions ne démontrent pas un avantage exploitable. Le score négatif du bot confirme ce rejet.

## Troisième passage — MetaQuotes-Demo, vrais ticks

Le journal du 11 septembre confirme une génération fondée sur les ticks réels, la V4.30, une période complète du 2021-01-01 au 2025-12-31, 32 937 snapshots utilisables et aucun échec de chargement. La qualité affichée est de 99 %.

La configuration exécutée restait toutefois combinée : Trend désactivé, Breakout activé et Spring activé. Les profils d'ablation n'avaient donc pas été appliqués. Parmi les 212 demandes d'entrée, 203 étaient des Breakouts, 6 des Springs et 3 des Upthrusts.

Résultats : perte nette 50,61 USD sur 1 000 USD, facteur de profit 0,83, espérance -0,24 USD par position, drawdown maximal des fonds 7,16 %, Sharpe -1,92, 91 positions gagnantes sur 212 (42,92 %) et score OnTester -29,51369. La commission configurée restait nulle.

Décision : la combinaison est rejetée. Le Breakout représente 95,8 % des entrées et constitue le principal suspect, sans que son résultat individuel puisse être déduit exactement. Les tests Breakout seul et Spring/Upthrust seul restent requis avec les profils dédiés.
