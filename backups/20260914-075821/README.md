# Exness MT5 SafeBot V4

Expert Advisor prudent et explicable pour MetaTrader 5. La version active est `ExnessSafeBot.mq5`, version 4.30. Les corrections de reprise, de clôture et de risque sont décrites dans `CHANGES_V430.md`.

## Stratégie par défaut

- moteur Breakout activé ;
- filtre de participation par volume relatif activé, avec volume réel lorsqu'il est entièrement disponible et tick volume sinon ;
- moteur structurel Spring/Upthrust activé après confirmation d'un trading range ;
- Failed Spring et Failed Upthrust détectés et journalisés, mais non tradés par défaut ;
- warmup limité à une tentative par nouvelle bougie H1 lorsque l'historique H4 est insuffisant ;
- score de qualité explicable avant chaque entrée et journal fantôme des candidats refusés ;
- veto sur les volumes climatiques et mesure de l'efficacité directionnelle ;
- réduction progressive du risque lorsque le compte entre en drawdown ;
- sortie confirmée lorsque le pattern d'origine est invalidé ;
- moteur Trend désactivé, car il était la principale source de pertes du test V2 ;
- risque prévisionnel limité au plus petit de 0,50 % des fonds propres, 5 unités de devise du compte et des budgets de perte restants, puis réduit en drawdown ;
- entrée refusée si le TP ne prévoit pas au moins 5 USD nets après la commission configurée et le slippage prévu ;
- TP adaptatif entre 1,6R et 3R selon le score, l'efficacité du mouvement et les objectifs structurels du breakout ou du range ;
- une seule position à la fois ;
- seuils de perte journalière de 1,5 % et de drawdown de 8 % : blocage des entrées et demande de clôture des positions propres au bot ; les gaps et frais peuvent entraîner un dépassement ;
- après 3 pertes consécutives, pause de 24 heures persistante entre les journées ;
- aucune nouvelle entrée le vendredi après 15 h et clôture de sécurité à 20 h ;
- passage au break-even activé ; trailing stop, sortie temporelle et sortie d'invalidation désactivés par défaut ;
- niveau de marge minimal de 300 % ;
- utilisation recommandée uniquement sur compte démo pendant la validation.

## Fichiers utiles

- `ExnessSafeBot.mq5` : source unique du bot ;
- `ExnessSafeBot.ex5` : version compilée ;
- `Include/SafeBotCore.mqh` : fonctions de contrôle et de risque ;
- `profiles/` : profils prudents EURUSD, GBPUSD et XAUUSD ;
- `tests/` : tests automatiques MQL5 ;
- `INSTALLATION.md` : installation et premier backtest ;
- `VALIDATION_V4.md` : état de validation et limites connues.

La V4 n'est pas encore validée pour un compte réel. Elle doit d'abord réussir des backtests en vrais ticks, des tests hors échantillon et une période forward sur démo.
