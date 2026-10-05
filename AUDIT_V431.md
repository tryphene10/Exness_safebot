# Audit et traçabilité V4.31 — 14 septembre 2026

## Conclusion actuelle

La stratégie n'a pas d'avantage démontré. Le seul backtest long acceptable disponible est le scénario combiné V4.30 sur EURUSD H1, vrais ticks, 2021-2025 : -50,61 USD sur 1 000 USD, PF 0,83, drawdown 7,16 %, Sharpe -1,92 et 212 trades. Il est rejeté. Breakout représente 203 des 212 demandes d'entrée ; les résultats individuels Breakout et Spring ne peuvent pas être déduits de ce run.

Les trois nouvelles baselines V4.31 ne sont pas inventées : elles restent à exécuter. Le terminal principal est ouvert (PID 35648 lors de l'audit) et la commission aller-retour réelle du compte ciblé n'a pas été fournie. Le lanceur refuse ces deux ambiguïtés.

## Diagnostic racine avec preuves

1. Le 12 septembre, `Tester/logs/20260912.log` charge explicitement `profiles/EURUSD_conservative.set`, puis échoue avec `EURUSD: history check timeout` et `no history data, stop testing`. Aucun profil d'ablation n'a donc produit de résultat.
2. Le profil testeur actif externe daté du 12 septembre contient `InpBreakoutEngine=true`, `InpSpringEngine=true`, `InpTrendEngine=false` et `InpCommissionPerLot=0.0`.
3. Avant correction, les `.mq5` et `SafeBotCore.mqh` du projet et du terminal étaient identiques, mais le `.ex5` du projet (`124164` octets, SHA-256 `B9B01A...E6826BB5`) différait de celui du terminal (`125532` octets, `3143A9...0EF298FF`). Le binaire testé n'avait donc pas de provenance reproductible.
4. `SB_SetupScore` utilisait un `+10` constant après le veto de volume. Le ratio de volume ne classait pas les candidats. Un second bonus de 10 était réservé aux structures, rendant un seuil commun non comparable.
5. Le CSV V4.30 était un journal d'événements. Il ne produisait ni une ligne agrégée par trade ni un fichier structuré de tous les candidats refusés.
6. La persistance du testeur était déjà isolée en mémoire. Les Global Variables ne traversaient pas les runs testeur, mais aucun identifiant de run/configuration ne permettait de le prouver dans les artefacts.

## Corrections livrées

- Build `SB4.31-TRACE-20260914`, visible dans `OnInit`, `OnTester`, les logs et tous les CSV.
- Configuration canonique et empreinte déterministe hexadécimale de 16 caractères couvrant moteurs, signaux, sorties, risque, coûts, sessions et critère testeur.
- Entrée `InpExpectedScenario`. Un test échoue à l'initialisation si `BREAKOUT_ONLY`, `SPRING_ONLY` ou `COMBINED` ne correspond pas aux moteurs réellement actifs. `AUTO` reste disponible pour un usage manuel mais génère `TEST_SCENARIO_UNASSERTED`.
- Journal de démarrage : moteurs, symbole, timeframes, paramètres Breakout/Spring, sorties, risque, commission et critère testeur. `OnTester` ajoute scénario, empreinte, snapshots et couverture observée.
- Trois fichiers distincts par run : journal d'événements, trades agrégés et candidats refusés. Le CSV trade contient moteur, direction, heures/prix, SL/TP initiaux, risque, R réalisé, score, volume relatif, efficacité, ADX, ATR, spread/ATR, régime, MFE, MAE, durée et sortie.
- Score de volume monotone et borné de 0 à 20 entre le minimum et le plafond climatique. Le bonus structurel a été supprimé de l'échelle ; deux seuils explicites par moteur ont été ajoutés.
- Lanceur `tools/Invoke-ReproducibleBacktests.ps1` : compilation stricte, preuve taille/date/hash, déploiement vérifié, `.set` unique, testeur uniquement, rapport non écrasé, vérification de l'empreinte/scénario/snapshots/vrais ticks et arrêt explicite en cas d'historique absent ou de ticks générés.

## Vérification technique

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Invoke-TechnicalTests.ps1 -ValidationRoot "D:\Mes_projets_ia\Exness_MT5_SafeBot\.validation\terminal"
```

Résultat : 10 compilations avec 0 erreur et 0 avertissement ; Core 97/97, Signal 26/26, Buffers 7/7, exécution simulée 28/28, persistance 5/5, intégration synthétique 1/1. Total 164/164. Ces tests ne prouvent pas la rentabilité.

| Fichier | Taille | SHA-256 |
|---|---:|---|
| `ExnessSafeBot.mq5` | 83 785 | `098D65050430DD93F66B00CBD68749D9FD1B5969C95633F92E9FCC2A98CD12D5` |
| `Include/SafeBotCore.mqh` | 11 898 | `F1EE4BDCAE6D4F2BA35C43A54325ADF450599A828F253E9DC9D9178555DCE227` |
| `ExnessSafeBot.ex5` | 156 672 | `743EB37665B2B7600E865A81E79E1099B4CA19D9F2FB602BF312D9FCB8B8440A` |

## Commandes reproductibles

Compte avec commission séparée, exemple à remplacer par la commission RAW aller-retour exacte :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Invoke-ReproducibleBacktests.ps1 -CommissionPerLot 7
```

Compte réellement sans commission séparée :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Invoke-ReproducibleBacktests.ps1 -ZeroCommissionAccount
```

Le terminal principal doit être fermé. Les sorties sont placées sous `backtests/<horodatage>/<scenario>/`. `To=2026-01-01` est la borne exclusive qui couvre jusqu'au 31 décembre 2025.

## Baseline et décision provisoire

| Version/scénario | Échantillon | Statut | Net | PF | DD | Trades | Décision |
|---|---|---|---:|---:|---:|---:|---|
| V4.30 combiné | 2021-2025 vrais ticks | mesuré | -50,61 USD | 0,83 | 7,16 % | 212 | rejeter |
| V4.31 Breakout seul | 2021-2023 puis 2024-2025 | non exécuté | — | — | — | — | retravailler / mesurer |
| V4.31 Spring seul | 2021-2023 puis 2024-2025 | non exécuté | — | — | — | — | mesurer ; échantillon probablement insuffisant |
| V4.31 combiné | 2021-2023 puis 2024-2025 | non exécuté | — | — | — | — | ne pas conserver sans OOS admissible |

Après les trois baselines complètes, relancer séparément 2021-2023 et 2024-2025. Les ablations break-even (désactivé, 1,2R, 1,5R), cible adaptative et formule de volume doivent modifier un seul groupe à la fois. Aucun candidat ne peut être retenu si l'OOS échoue aux critères PF >= 1,15, DD <= 8 %, espérance positive, stabilité mensuelle et voisinages stables. Pour Spring, l'insuffisance de 100 trades doit être déclarée, jamais compensée par une optimisation plus agressive.

## Fichiers modifiés

`ExnessSafeBot.mq5`, `ExnessSafeBot.ex5`, `Include/SafeBotCore.mqh`, les cinq profils `.set`, `tests/SafeBotCoreTests.mq5`, `tools/Invoke-TechnicalTests.ps1`, `tools/Invoke-ReproducibleBacktests.ps1`, la documentation V4.31 et les résultats de compilation/tests. Sauvegarde pré-édition : `backups/20260914-075821`.
