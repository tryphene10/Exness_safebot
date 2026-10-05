# Validation V4.30

Les résultats courants sont produits par `tools/Invoke-TechnicalTests.ps1` dans `tests/results/v430-technical-summary.txt`.

- Compilation du bot et des scénarios : aucune erreur ni avertissement.
- Noyau : 93 assertions.
- Signaux : 26 assertions.
- Buffers : 7 assertions.
- Exécution avec API de courtier simulées : 28 assertions.
- Écriture puis lecture après redémarrage réel du terminal : 1 + 4 contrôles.
- Intégration des données synthétiques H1/H4 : 1 contrôle.

Total attendu : 160 réussites, aucun échec. Consulter le fichier généré pour confirmer le dernier passage.

Les tests d'exécution couvrent entrée protégée, rapprochement du budget, refus de clôture, temporisation, volume partiel, timeout sans renvoi aveugle, seuils de perte, plusieurs tickets, exclusion des positions manuelles et exposition externe non protégée. La persistance est également vérifiée entre deux processus distincts du terminal isolé.

Limites : le courtier simulé ne remplace pas le testeur natif ni le serveur du courtier. Certains anciens tests du moteur Trend restent exécutés avec le moteur désactivé et ne prouvent pas son fonctionnement actif. Les tests ne démontrent aucune rentabilité.

Le scénario natif `tests/execution-probe.ini` a ensuite réussi : 9 assertions, 0 échec, deux cycles ouverture/clôture sur données synthétiques et calcul en USD. Preuve : `tests/results/v430-native-summary.txt`. Total technique et natif : 169 contrôles. Ce passage hors ligne ne confirme pas une connexion active au courtier. Les backtests en vrais ticks, le hors-échantillon et le forward démo restent à effectuer.

La V4.30 n'est pas déployée dans le terminal du compte réel. Voir `CHANGES_V430.md` pour les changements et les limites de reprise.
