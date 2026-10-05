#ifndef SAFEBOT_CORE_MQH
#define SAFEBOT_CORE_MQH
// Remaining loss capacity is measured from current equity, with cash-adjusted anchors.
double SB_RemainingBudget(double normal,double equity,double dayAnchor,double peakAnchor,
                          double dailyPercent,double drawdownPercent)
{
   if(!MathIsValidNumber(normal) || !MathIsValidNumber(equity) ||
      !MathIsValidNumber(dayAnchor) || !MathIsValidNumber(peakAnchor) ||
      normal<=0 || equity<=0 || dayAnchor<=0 || peakAnchor<=0) return 0;
   return MathMax(0,MathMin(normal,MathMin(equity-dayAnchor*(1-dailyPercent/100),
                                        equity-peakAnchor*(1-drawdownPercent/100))));
}
// One scalar commits the candle identity and counter together (exact within double).
double SB_ConfirmState(double previous,datetime closedBar,bool invalid,int maximum)
{
   if(closedBar<=0 || maximum<1 || maximum>1000) return previous;
   datetime last=(datetime)MathFloor(previous/1024.0);
   if(closedBar<=last) return previous;
   int count=(int)MathRound(previous-(double)last*1024.0);
   return (double)closedBar*1024.0+(invalid ? MathMin(count+1,maximum) : 0);
}
int SB_ConfirmCount(double state) { return (int)MathRound(state-MathFloor(state/1024.0)*1024.0); }
// Pure functions shared by the EA and the executable MQL5 self-test.
double SB_CashAnchor(double anchor,double cashTotal,double cashAtAnchor)
{
   return anchor+cashTotal-cashAtAnchor;
}
bool SB_MarginAllows(double equity,double margin,double floorPercent)
{
   if(!MathIsValidNumber(equity) || !MathIsValidNumber(margin) || equity<=0 || margin<0 || floorPercent<=0) return false;
   return margin==0 || 100*equity/margin>=floorPercent;
}
bool SB_ExecutionSafe(double sl,double tp,double risk,double budget,double volume,double requested)
{
   return sl>0 && tp>0 && MathIsValidNumber(risk) && risk>=0 && budget>0 &&
          risk<=budget+1e-8 && volume>0 && volume<=requested+1e-8;
}
datetime SB_Day(datetime value)
{
   MqlDateTime t; TimeToStruct(value,t);
   t.hour=0; t.min=0; t.sec=0;
   return StructToTime(t);
}
bool SB_EntrySession(int dayOfWeek,int hour,int startHour,int endHour,
                     bool allowMonday,bool allowFriday,int fridayCutoff)
{
   return dayOfWeek!=0 && dayOfWeek!=6 && (dayOfWeek!=1 || allowMonday) &&
          (dayOfWeek!=5 || (allowFriday && hour<fridayCutoff)) &&
          hour>=startHour && hour<endHour;
}
bool SB_FridayClose(int dayOfWeek,int hour,int closeHour)
{
   return dayOfWeek==5 && hour>=closeHour;
}
bool SB_DataRetryAllowed(datetime currentBar,datetime attemptedBar,datetime now,
                         datetime retryAt,bool warmup)
{
   if(currentBar<=0) return false;
   if(currentBar!=attemptedBar) return true;
   if(warmup) return false;
   return now>=retryAt;
}
double SB_RiskScale(double drawdownPercent,double reductionStart,double stopPercent,double minimumScale)
{
   if(drawdownPercent<=reductionStart) return 1.0;
   if(stopPercent<=reductionStart || minimumScale<=0 || minimumScale>1) return 0;
   if(drawdownPercent>=stopPercent) return minimumScale;
   double progress=(drawdownPercent-reductionStart)/(stopPercent-reductionStart);
   return 1.0-progress*(1.0-minimumScale);
}
double SB_RiskBudget(double equity,double riskPercent,double riskScale,double maximumMoney)
{
   if(!MathIsValidNumber(equity) || !MathIsValidNumber(riskPercent) ||
      !MathIsValidNumber(riskScale) || !MathIsValidNumber(maximumMoney) ||
      equity<=0 || riskPercent<=0 || riskScale<=0 || riskScale>1 || maximumMoney<=0) return 0;
   // The drawdown scale also reduces the cash cap; it can never restore risk above it.
   return MathMin(equity*riskPercent/100.0,maximumMoney)*riskScale;
}
bool SB_NetProfitAllows(double grossProfit,double estimatedCosts,double minimumNetProfit)
{
   return MathIsValidNumber(grossProfit) && MathIsValidNumber(estimatedCosts) &&
          MathIsValidNumber(minimumNetProfit) && grossProfit>0 && estimatedCosts>=0 &&
          minimumNetProfit>=0 && grossProfit-estimatedCosts+1e-8>=minimumNetProfit;
}
double SB_AdaptiveRewardRisk(double baseRR,double maximumRR,double score,double minimumScore,
                             double efficiency,bool structural)
{
   if(baseRR<=0 || maximumRR<baseRR || minimumScore<0 || minimumScore>=100 ||
      !MathIsValidNumber(score) || !MathIsValidNumber(efficiency)) return 0;
   double quality=MathMax(0.0,MathMin(1.0,(score-minimumScore)/(100.0-minimumScore)));
   double cleanMove=MathMax(0.0,MathMin(1.0,efficiency));
   double participation=0.70*quality+0.30*cleanMove+(structural ? 0.10 : 0.0);
   return MathMin(maximumRR,baseRR+(maximumRR-baseRR)*MathMin(1.0,participation));
}
double SB_MarketRewardRisk(int engine,int direction,double entry,double initialRisk,
                           double boxHigh,double boxLow,double rangeHigh,double rangeLow,
                           double qualityRR,double maximumRR)
{
   if((direction!=1 && direction!=-1) || entry<=0 || initialRisk<=0 ||
      qualityRR<=0 || maximumRR<qualityRR) return 0;
   double target=entry;
   if(engine==1 && boxHigh>boxLow)
      target=direction>0 ? boxHigh+(boxHigh-boxLow) : boxLow-(boxHigh-boxLow);
   else if(engine==2 && direction>0 && rangeHigh>rangeLow) target=rangeHigh;
   else if(engine==3 && direction<0 && rangeHigh>rangeLow) target=rangeLow;
   else if(engine==4 && direction>0 && rangeHigh>rangeLow) target=rangeHigh+(rangeHigh-rangeLow);
   else if(engine==5 && direction<0 && rangeHigh>rangeLow) target=rangeLow-(rangeHigh-rangeLow);
   double structuralRR=direction*(target-entry)/initialRisk;
   return MathMin(maximumRR,MathMax(qualityRR,structuralRR));
}
double SB_DirectionalEfficiency(double displacement,double path)
{
   if(path<=0 || displacement<0 || !MathIsValidNumber(displacement) || !MathIsValidNumber(path)) return 0;
   return MathMin(1.0,displacement/path);
}
double SB_CloseStrength(int direction,double high,double low,double close)
{
   if((direction!=1 && direction!=-1) || high<=low) return 0;
   double value=direction>0 ? (close-low)/(high-low) : (high-close)/(high-low);
   return MathMax(0.0,MathMin(1.0,value));
}
// Participation contributes continuously once the minimum veto is cleared.
// The contribution is monotone and bounded: 0 at the configured minimum,
// 20 at the climatic-volume ceiling, and the caller still vetoes outside it.
double SB_VolumeScore(double volumeRatio,double minimumVolume,double maximumVolume)
{
   if(!MathIsValidNumber(volumeRatio) || minimumVolume<=0 || maximumVolume<=minimumVolume ||
      volumeRatio<minimumVolume || volumeRatio>maximumVolume) return 0;
   return 20.0*MathMax(0.0,MathMin(1.0,(volumeRatio-minimumVolume)/(maximumVolume-minimumVolume)));
}
double SB_SetupScore(bool aligned,double volumeRatio,double minimumVolume,double maximumVolume,
                     double closeStrength,double efficiency,bool structural)
{
   if(volumeRatio<minimumVolume || volumeRatio>maximumVolume || closeStrength<0 || efficiency<0) return 0;
   // `structural` is intentionally not a bonus. Keeping the same 0..100 scale
   // makes Breakout and Spring/Upthrust scores comparable; engines may still
   // use distinct acceptance thresholds at the EA level.
   double score=25.0+(aligned ? 20.0 : 10.0)+20.0*MathMin(1.0,closeStrength)+
                15.0*MathMin(1.0,efficiency)+
                SB_VolumeScore(volumeRatio,minimumVolume,maximumVolume);
   return MathMin(100.0,score);
}
bool SB_PatternInvalidated(int engine,int direction,double close,double boxHigh,double boxLow,
                           double rangeHigh,double rangeLow,double buffer)
{
   if(direction!=1 && direction!=-1) return false;
   if(engine==1 && boxHigh>boxLow) return direction>0 ? close<boxHigh-buffer : close>boxLow+buffer;
   if((engine==2 || engine==4) && rangeHigh>rangeLow) return close<rangeLow-buffer;
   if((engine==3 || engine==5) && rangeHigh>rangeLow) return close>rangeHigh+buffer;
   return false;
}
bool SB_TradingRange(double high,double low,double atr,double minWidthATR,double maxWidthATR,
                     int highTouches,int lowTouches,int minimumTouches,double driftRatio,double maxDriftRatio)
{
   if(!MathIsValidNumber(high) || !MathIsValidNumber(low) || !MathIsValidNumber(atr) ||
      high<=low || atr<=0 || minWidthATR<=0 || maxWidthATR<=minWidthATR || minimumTouches<1)
      return false;
   double widthATR=(high-low)/atr;
   return widthATR>=minWidthATR && widthATR<=maxWidthATR &&
          highTouches>=minimumTouches && lowTouches>=minimumTouches &&
          driftRatio>=0 && driftRatio<=maxDriftRatio;
}
// +1 Spring buy, -1 Upthrust sell, +2 failed Upthrust buy, -2 failed Spring sell.
// The range is established before the sweep; sweep and confirmation are closed candles.
int SB_SpringPattern(double rangeHigh,double rangeLow,double atr,
                     double sweepOpen,double sweepHigh,double sweepLow,double sweepClose,
                     double confirmOpen,double confirmHigh,double confirmLow,double confirmClose,
                     double penetrationATR,double wickBodyRatio,double volumeRatio,double minimumVolumeRatio)
{
   if(rangeHigh<=rangeLow || atr<=0 || penetrationATR<0 || wickBodyRatio<0 ||
      volumeRatio<minimumVolumeRatio || minimumVolumeRatio<=0) return 0;
   double minimumWick=MathMax(MathAbs(sweepClose-sweepOpen)*wickBodyRatio,atr*0.05);
   bool lowerSweep=sweepLow<=rangeLow-penetrationATR*atr && sweepClose>rangeLow &&
                   MathMin(sweepOpen,sweepClose)-sweepLow>=minimumWick;
   bool upperSweep=sweepHigh>=rangeHigh+penetrationATR*atr && sweepClose<rangeHigh &&
                   sweepHigh-MathMax(sweepOpen,sweepClose)>=minimumWick;
   if(lowerSweep)
   {
      if(confirmClose<rangeLow) return -2;
      if(confirmClose>sweepClose && confirmClose>confirmOpen && confirmLow>=sweepLow) return 1;
   }
   if(upperSweep)
   {
      if(confirmClose>rangeHigh) return 2;
      if(confirmClose<sweepClose && confirmClose<confirmOpen && confirmHigh<=sweepHigh) return -1;
   }
   return 0;
}
double SB_Price(double price,double tick,int digits,bool upward)
{
   if(tick<=0) return 0;
   return NormalizeDouble((upward ? MathCeil(price/tick-1e-9) : MathFloor(price/tick+1e-9))*tick,digits);
}
double SB_Volume(double budget,double unitLoss,double minimum,double maximum,double step)
{
   if(budget<=0 || unitLoss<=0 || minimum<=0 || maximum<minimum || step<=0) return 0;
   double raw=MathMin(budget/unitLoss,maximum);
   if(raw<minimum) return 0;
   double volume=NormalizeDouble(MathFloor(raw/step)*step,8);
   if(volume<minimum || volume*unitLoss>budget+1e-9) return 0;
   return volume;
}
void SB_Loss(double net,int maximum,int &streak,bool &blocked)
{
   streak=net<0 ? streak+1 : 0;
   if(streak>=maximum) blocked=true; // Latch survives a later external winning exit.
}
void SB_LossSequence(double net,datetime closed,int maximum,int pauseSeconds,
                     int &streak,datetime &pauseUntil,datetime &sequenceStart)
{
   if(closed<sequenceStart || maximum<1 || pauseSeconds<1) return;
   streak=net<0 ? streak+1 : 0;
   if(streak>=maximum)
   {
      pauseUntil=closed+pauseSeconds;
      sequenceStart=pauseUntil;
      streak=0;
   }
}
bool SB_Tightens(int direction,double oldSL,double newSL,double initialSL)
{
   if(newSL<=0 || initialSL<=0) return false;
   return direction>0 ? (newSL>=initialSL && newSL>oldSL) :
                        (newSL<=initialSL && (oldSL==0 || newSL<oldSL));
}
double SB_Score(double profit,double deposit,double pf,double dd,double trades,
                double target,double concentration)
{
   if(deposit<=0 || trades<=0) return -1000000;
   double sample=MathMin(1.0,trades/target);
   double quality=MathMin(2.0,MathMax(0.0,pf));
   double reward=100.0*profit/deposit;
   return reward*sample+10.0*quality-2.0*dd-40.0*(1.0-sample)
          -50.0*MathMax(0.0,1.20-pf)-30.0*MathMax(0.0,concentration-0.35);
}
#endif
