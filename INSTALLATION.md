# Installation et test de la V4

1. Dans MetaTrader 5, ouvrez **Fichier > Ouvrir le dossier des données**.
2. Copiez `ExnessSafeBot.mq5`, `ExnessSafeBot.ex5` et le dossier `Include` dans `MQL5/Experts/ExnessSafeBot/`.
3. Ouvrez `ExnessSafeBot.mq5` dans MetaEditor et compilez avec **F7**. Le résultat attendu est `0 errors, 0 warnings`.
4. Dans le testeur de stratégie, sélectionnez uniquement **ExnessSafeBot**. N'utilisez plus une entrée portant `_v2`.
5. Choisissez EURUSD, H1, le modèle **Chaque tick basé sur des ticks réels**, puis chargez `profiles/EURUSD_conservative.set`.
6. Testez d'abord une période longue comprenant plusieurs régimes de marché. Utilisez un dépôt de 1 000 USD pour comparer avec le test précédent.
7. Dans le journal, vérifiez la présence de `V4.30` et de `DATA_READY`. Pendant le warmup, le compteur `failed` ne doit plus progresser à chaque tick.
8. Renseignez `InpCommissionPerLot` avec la commission aller-retour réelle du compte. Sur un compte sans commission séparée, laissez `0` ; le spread est déjà inclus dans le prix d'entrée.
9. Vérifiez que les entrées acceptées affichent `plannedRisk<=5.0000`, `plannedNetTP>=5.0000` et un `targetR` compris entre 1,6 et 3. `NET_TP_REFUSED` signifie que le volume et le TP maximal autorisés ne permettaient pas d'atteindre 5 unités de devise du compte nettes : le bot n'augmente alors pas le risque.
10. Exportez le rapport HTML, le graphe, le journal et le fichier d'audit `SB4` pour l'analyse.

Avant le réel, répétez le test sur une période hors échantillon, puis laissez tourner la même configuration plusieurs semaines sur démo.
