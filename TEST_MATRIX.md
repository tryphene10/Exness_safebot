# Matrice de tests V4.30

| Domaine | Contrôles attendus | Preuve / statut |
|---|---:|---|
| Compilation EA et scénarios | 0 erreur, 0 avertissement | Journaux `.validation/compile-*.log` |
| Noyau | 93 | Résumé généré V4.30 |
| Signaux | 26 | Résumé généré V4.30 |
| Buffers | 7 | Résumé généré V4.30 |
| Exécution, courtier simulé | 28 | Résumé généré V4.30 |
| Persistance entre processus | 5 | Résumé généré V4.30 |
| Intégration H1/H4 synthétique | 1 | Résumé généré V4.30 |
| Exécution MT5 native | 9 réussis | `tests/results/v430-native-summary.txt` — données synthétiques, calcul USD |
| Backtest en vrais ticks du courtier | — | À exécuter |
| Hors échantillon | — | À exécuter |
| Forward démo | — | À exécuter |
| Traçabilité V4.31 | 164 réussis | `tests/results/v431-technical-summary.txt`; baselines réelles en attente |

La commande reproductible est documentée dans `CHANGES_V430.md`. Les résultats techniques ne constituent pas une validation du passage en réel.
