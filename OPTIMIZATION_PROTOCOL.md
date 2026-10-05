# Protocole d'optimisation V4

Les moteurs Breakout et Spring/Upthrust sont évalués séparément avant leur combinaison. Le moteur Trend reste désactivé tant qu'une validation indépendante ne démontre pas une espérance positive.

1. Utiliser 2021-2023 pour l'exploration, 2024-2025 pour la validation et une période récente séparée pour le forward démo.
2. Employer de vrais ticks, un spread variable, le swap et les commissions du compte visé.
3. Modifier un groupe logique à la fois : seuil ADX, distance de cassure, stop ATR et ratio rendement/risque.
4. Conserver des plages larges et rechercher des plateaux stables, pas un meilleur paramètre isolé.
5. Rejeter toute configuration avec moins de 100 positions, drawdown supérieur à 8 %, facteur de profit inférieur à 1,15 ou concentration mensuelle excessive.
6. Comparer chaque candidat à la configuration V4 par défaut et répéter sur EURUSD, GBPUSD et XAUUSD sans supposer qu'un même réglage convient partout.
7. Ne réactiver trailing, sortie temporelle, invalidation ou moteur Trend qu'au moyen de tests d'ablation séparés.
8. Tester séparément le score expert, la limite supérieure de volume, la réduction du risque et la sortie de pattern ; ne jamais optimiser ces modules simultanément.
