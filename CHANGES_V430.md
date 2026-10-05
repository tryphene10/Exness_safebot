# V4.30 — reprise, clôtures et risque

## Comportement corrigé

- La boîte de compression est sauvegardée avec un marqueur de validation. Un redémarrage restaure la même boîte ; une écriture interrompue désarme la boîte au lieu de restaurer des valeurs incohérentes.
- L'heure de la bougie et le compteur d'invalidation sont enregistrés dans une même valeur. Une bougie déjà comptée ne peut plus provoquer une seconde confirmation après redémarrage.
- Les demandes de clôture persistent par identifiant de position. Un refus explicite est retenté après au moins 10 secondes, sans attendre la prochaine bougie H1. Une exécution partielle conserve la demande pour le volume restant.
- Une réponse inconnue (timeout, déconnexion, ordre placé) n'autorise pas de renvoi aveugle. Le bot attend l'absence d'ordre en cours et la preuve d'une réduction de volume accompagnée d'une sortie dans l'historique. Sans preuve, `CLOSE_UNCERTAIN` nécessite une réconciliation manuelle ; le SL existant reste en place.
- La gestion parcourt un instantané des tickets propres au bot. Une clôture ne décale plus les indices des positions encore à traiter. Les positions manuelles ne sont pas liquidées. Des positions mixtes en netting restent soumises à revue.
- Le budget et le contexte d'entrée sont rattachés à l'identifiant de la position. Un ancien contexte ne doit pas être attribué à une position supplémentaire. Une position ancienne sans budget identifiable bloque les entrées ; si elle est protégée, sa gestion reste possible.
- Une nouvelle entrée est plafonnée par le budget journalier et le budget de drawdown encore disponibles. Le risque estimé des positions externes protégées est réservé ; une exposition sans SL calculable ou un ordre en attente bloque l'entrée. Les frais externes restent estimés avec la commission configurée.
- Le franchissement d'un seuil de perte demande la clôture des positions propres au bot, en plus du blocage des entrées. Cette politique ne garantit pas un plafond de perte exécutée : gaps, slippage supérieur aux hypothèses et frais futurs peuvent le dépasser.
- Le calcul initial prévoit désormais une tolérance de slippage à l'entrée et au stop.
- Le verrou de compte est partagé entre terminaux sur la même machine via `FILE_COMMON`. Il ne coordonne pas des machines différentes ni une ancienne version utilisant un verrou local.
- Les clés longues de persistance sont abrégées pour respecter la [limite de 63 caractères de MetaQuotes](https://www.mql5.com/en/docs/globals/globalvariableset). Les clés courtes existantes sont conservées.

## Vérification reproductible

Depuis le dossier du projet :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Invoke-TechnicalTests.ps1
```

Le script compile le bot et les scénarios, puis utilise uniquement `.validation/terminal`. Il refuse de démarrer si ce terminal isolé est déjà ouvert. Le terminal de trading existant n'est pas modifié. Le résultat est enregistré dans `tests/results/v430-technical-summary.txt` ; le binaire principal n'est remplacé qu'après réussite des tests techniques.

Les scénarios d'exécution appellent les fonctions de production `Enter`, `VerifyExecution`, `Manage` et `ClosePosition` avec les API de courtier simulées : refus, timeout, exécution partielle, absence de SL, volume excessif, multi-ticket et seuils de risque. Deux scripts distincts vérifient la persistance entre deux processus MT5 successifs.

`tests/SafeBotExecutionProbe.mq5` et `tests/execution-probe.ini` préparent également deux cycles dans le testeur MT5 natif, sur un symbole synthétique. Le probe refuse de fonctionner hors du testeur. Les candidats sont imposés pour exercer l'exécution : ce scénario ne mesure pas la rentabilité de la stratégie. Le dépôt est de 1 000 USD ; le gain net minimal et le délai entre entrées sont désactivés uniquement dans ce scénario.

Le premier lancement natif a été refusé : `tester not started because the account is not specified`. Le lancement suivant avec un profil de compte local a réussi 9 assertions sur 9, avec deux cycles sur données synthétiques en USD. Voir `tests/results/v430-native-summary.txt`. Le journal avertit que le terminal est hors synchronisation du serveur : ce succès hors ligne ne prouve pas une connexion au courtier.

## Déploiement

La correction n'est pas installée dans le terminal du compte réel. Valider ensuite le testeur natif, les vrais ticks du courtier, le hors-échantillon et le forward démo avant toute utilisation réelle. Éviter de migrer avec une position ouverte ; les contextes V4.20 incomplets sont traités prudemment et peuvent nécessiter une revue.
