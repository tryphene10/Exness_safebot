#property copyright "Rufus Melachi"
#property version "4.30"
#property strict
#include "Include/SafeBotCore.mqh"

input group "Universe and operating mode"
input string InpSymbols="EURUSD";
input ulong InpMagic=17092026;
input bool InpDemoOnly=true;
input ENUM_TIMEFRAMES InpEntryTF=PERIOD_H1;
input ENUM_TIMEFRAMES InpTrendTF=PERIOD_H4;

input group "Signal - eligible for controlled optimization"
input bool InpTrendEngine=false;
input bool InpBreakoutEngine=true;
input bool InpSpringEngine=true;
input bool InpTradeFailedSpring=false;
input int InpFastEMA=20;
input int InpSlowEMA=50;
input int InpTrendEMA=200;
input int InpRSIPeriod=14;
input int InpATRPeriod=14;
input int InpADXPeriod=14;
input int InpSlopeBars=3;
input double InpADXMin=20;
input double InpSlopeMinATR=0.02;
input double InpRSIBuy=52;
input double InpRSISell=48;
input double InpPullbackToleranceATR=0.25;
input int InpBreakoutBars=12;
input int InpCompressionBars=6;
input int InpVolatilityBars=30;
input double InpCompressionRatio=0.80;
input double InpATRExpansion=1.05;
input double InpMaxATRRatio=2.0;
input double InpMaxATRPricePercent=2.0;
input double InpBreakoutBufferATR=0.10;
input bool InpVolumeFilter=true;
input int InpVolumeLookback=20;
input double InpBreakoutMinVolumeRatio=1.10;
input int InpRangeBars=24;
input int InpRangeMinTouches=2;
input double InpRangeTouchATR=0.25;
input double InpRangeMinWidthATR=1.50;
input double InpRangeMaxWidthATR=6.00;
input double InpRangeMaxDriftRatio=0.35;
input double InpSpringPenetrationATR=0.05;
input double InpSpringWickBodyRatio=1.00;
input double InpSpringMinVolumeRatio=1.00;
input double InpSpringStopBufferATR=0.10;
input double InpMaximumSignalVolumeRatio=4.00;
input int InpEfficiencyBars=6;
input bool InpExpertDecision=true;
input double InpMinimumSetupScore=68.0;
input double InpATRStopMultiplier=1.8;
input double InpRewardRisk=1.6;
input bool InpAdaptiveProfitTarget=true;
input double InpMaximumRewardRisk=3.0;

input group "Position management"
input bool InpBreakEven=true;
input double InpBreakEvenR=1.0;
input double InpBreakEvenOffsetR=0.05;
input bool InpTrailing=false;
input double InpTrailingStartR=1.5;
input double InpTrailingATR=2.0;
input bool InpTimeExit=false;
input int InpNoProgressBars=12;
input double InpProgressStepR=0.10;
input bool InpInvalidationExit=false;
input bool InpPatternExit=true;
input int InpInvalidationConfirmBars=2;
input double InpInvalidationBufferATR=0.05;

input group "Risk and execution - NEVER optimize"
input double InpRiskPercent=0.50;
input double InpMaximumRiskMoney=5.0; // Account currency; hard cap before drawdown reduction.
input double InpMinimumPlannedNetProfit=5.0; // Account currency; otherwise the entry is refused.
input bool InpAdaptiveDrawdownRisk=true;
input double InpRiskReductionStartDD=2.0;
input double InpMinimumRiskScale=0.50;
input double InpMaxDailyLossPercent=1.50;
input double InpMaxDrawdownPercent=8.0;
input int InpMaxConsecutiveLosses=3;
input int InpLossPauseHours=24;
input double InpMaxSpreadATRRatio=0.08;
input int InpSlippagePoints=20;
input double InpCommissionPerLot=0.0; // Round trip, account currency; set from broker costs.
input double InpMarginReservePercent=20;
input double InpMinMarginLevelPercent=300;
input int InpMinEntryMinutes=240;
input int InpMaxQuoteAgeSeconds=30;
input bool InpCorrelationGuard=true;

input group "Server session"
input int InpStartHour=7;
input int InpEndHour=20;
input bool InpAllowMonday=true;
input bool InpAllowFriday=true;
input int InpFridayEntryCutoffHour=15;
input int InpFridayCloseHour=20;
input int InpTesterMinTrades=150;

enum MarketRegime { REG_RANGE,REG_TREND,REG_BREAKOUT,REG_EXCESS_VOL };
struct SymbolState
{
   string symbol;
   int fast,slow,rsi,atr,adx,htFast,htSlow,htADX,htATR;
   datetime lastBar,lastEntry,attemptBar,lastManageBar,compressionID,usedCompression;
   datetime dataAttemptBar,dataRetryAt,manageAttemptBar,manageRetryAt;
   double boxHigh,boxLow;
   bool armed;
   ulong positionID;
   double initialSL,initialR,progressR;
   datetime progressTime;
   string lastLog;
   datetime lastLogTime;
   double entryBudget,requestedVolume,mfe,mae,auditedMFE,auditedMAE;
   double manageATR,manageADX;
   int manageDirection,positionEngine,invalidationBars;
   double entryBoxHigh,entryBoxLow,entryRangeHigh,entryRangeLow,entryScore;
   datetime budgetTime,lastEmergency;
   string dataReason;
   datetime lastDataLog;
   long dataFailures,dataSnapshots;
};
struct Snapshot
{
   MqlRates bars[];
   double fast[],slow[],rsi[],atr[],adx[];
   double hf[],hs[],ha[],hv[];
   double baseline,compression;
   double rangeHigh,rangeLow,rangeWidthATR,breakoutVolumeRatio,springVolumeRatio;
   double efficiency;
   int rangeHighTouches,rangeLowTouches,structurePattern;
   bool rangeValid,breakoutRealVolume,springRealVolume;
   int direction;
   MarketRegime regime;
};
struct ClosedTrade
{
   ulong id;
   double net;
   datetime closed;
   bool own,foreign,open;
};
SymbolState States[];
datetime Day=0;
double DayEquity=0,Peak=0;
bool DayBlocked=false,DrawdownBlocked=false,LossBlocked=false,HistoryOK=false,Busy=false;
int LossStreak=0;
string Prefix;
int LockHandle=INVALID_HANDLE;
bool Tester=false;
string MemoryKeys[];
double MemoryValues[];
bool ExecutionHold=false;
bool PersistenceOK=true;
datetime LastHistoryScan=0;
datetime LossPauseUntil=0,LossSequenceStart=0;
int AuditHandle=INVALID_HANDLE;
double DayCash=0,PeakCash=0,CashTotal=0;
bool CashReady=false,CashOK=false;

// Semicolon-delimited event journal. IDs remain strings to avoid precision loss.
void Audit(int i,string event,ulong id=0,double volume=0,double price=0,
           double risk=0,double costs=0,string detail="")
{
   if(AuditHandle==INVALID_HANDLE) return;
   StringReplace(detail,";","|"); StringReplace(detail,"\r"," "); StringReplace(detail,"\n"," ");
   if(FileWrite(AuditHandle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),event,
      i<0 ? "ACCOUNT" : States[i].symbol,StringFormat("%I64u",id),
      DoubleToString(volume,8),DoubleToString(price,8),DoubleToString(risk,8),
      DoubleToString(costs,8),i<0 ? 0 : States[i].mfe,i<0 ? 0 : States[i].mae,detail)==0)
      PersistenceOK=false;
   FileFlush(AuditHandle);
}

// Recompute cash totals: idempotent across restarts, no ticket cursor rounding.
bool RefreshCash()
{
   if(!HistorySelect(0,TimeCurrent())) return false;
   double total=0;
   for(int k=0;k<HistoryDealsTotal();k++)
   {
      ulong t=HistoryDealGetTicket(k);
      if(t==0) return false;
      ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(t,DEAL_TYPE);
      if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT || type==DEAL_TYPE_BONUS)
         total+=HistoryDealGetDouble(t,DEAL_PROFIT);
   }
   if(!CashReady)
   {
      DayCash=ReadState(-1,"daycash",total);
      PeakCash=ReadState(-1,"peakcash",total);
      PutState(-1,"daycash",DayCash); PutState(-1,"peakcash",PeakCash);
      CashReady=true;
   }
   if(total!=CashTotal) Audit(-1,"CASH_TOTAL",0,0,0,0,0,DoubleToString(total,8));
   CashTotal=total;
   return true;
}

void Log(int i,string code,string detail)
{
   if(i>=0)
   {
      string msg=code+" "+detail;
      if(States[i].lastLog==msg && TimeCurrent()-States[i].lastLogTime<60) return;
      States[i].lastLog=msg; States[i].lastLogTime=TimeCurrent();
      PrintFormat("SB4 | %s | %s | %s",States[i].symbol,code,detail);
   }
   else PrintFormat("SB4 | ACCOUNT | %s | %s",code,detail);
}
string Key(int i,string suffix)
{
   string key=Prefix+(i<0 ? "" : States[i].symbol+".")+suffix;
   if(StringLen(key)<=63) return key;
   // Terminal global names have a 63-character limit. Retain legacy short keys.
   uint first=2166136261,second=5381;
   for(int k=0;k<StringLen(key);k++)
   { uint c=(uint)StringGetCharacter(key,k); first=(first^c)*16777619; second=second*33+c; }
   return StringFormat("SB4K.%08X%08X.",first,second)+suffix;
}
double ReadState(int i,string suffix,double fallback=0)
{
   string key=Key(i,suffix);
   if(Tester)
   {
      for(int k=0;k<ArraySize(MemoryKeys);k++) if(MemoryKeys[k]==key) return MemoryValues[k];
      return fallback;
   }
   return GlobalVariableCheck(key) ? GlobalVariableGet(key) : fallback;
}
void PutState(int i,string suffix,double value)
{
   if(Tester)
   {
      int k=0; for(;k<ArraySize(MemoryKeys);k++) if(MemoryKeys[k]==Key(i,suffix)) break;
      if(k==ArraySize(MemoryKeys)) { ArrayResize(MemoryKeys,k+1); ArrayResize(MemoryValues,k+1); MemoryKeys[k]=Key(i,suffix); }
      MemoryValues[k]=value; return;
   }
   if(!Tester && GlobalVariableSet(Key(i,suffix),value)==0)
   { PersistenceOK=false; Log(-1,"PERSISTENCE_ERROR","Cannot save safety state; entries blocked"); }
}
void SaveCompression(int i)
{
   // Clear the commit marker first: interrupted writes cannot restore a mixed box.
   PutState(i,"boxready",0);
   if(!Tester) GlobalVariablesFlush();
   PutState(i,"boxhigh",States[i].boxHigh); PutState(i,"boxlow",States[i].boxLow);
   PutState(i,"boxtime",(double)States[i].compressionID);
   if(!Tester) GlobalVariablesFlush();
   PutState(i,"boxready",States[i].armed ? 1 : 0);
   if(!Tester) GlobalVariablesFlush();
}
void RestoreCompression(int i)
{
   States[i].boxHigh=ReadState(i,"boxhigh"); States[i].boxLow=ReadState(i,"boxlow");
   States[i].compressionID=(datetime)ReadState(i,"boxtime");
   States[i].armed=ReadState(i,"boxready")>0 && States[i].boxHigh>States[i].boxLow &&
                   States[i].compressionID>States[i].usedCompression;
}
void SaveRisk()
{
   PutState(-1,"day",(double)Day); PutState(-1,"equity",DayEquity);
   PutState(-1,"peak",Peak); PutState(-1,"daily",DayBlocked ? 1 : 0);
   PutState(-1,"dd",DrawdownBlocked ? 1 : 0); PutState(-1,"loss",LossBlocked ? 1 : 0);
   PutState(-1,"losspause",(double)LossPauseUntil);
   PutState(-1,"lossstart",(double)LossSequenceStart);
   PutState(-1,"daycash",DayCash); PutState(-1,"peakcash",PeakCash);
   if(!Tester) GlobalVariablesFlush();
}
bool ValidateInputs()
{
   return InpMagic>0 && InpFastEMA>1 && InpSlowEMA>InpFastEMA && InpTrendEMA>InpSlowEMA &&
      InpRSIPeriod>1 && InpATRPeriod>1 && InpADXPeriod>1 && InpSlopeBars>=1 && InpSlopeBars<=50 &&
      PeriodSeconds(InpTrendTF)>PeriodSeconds(InpEntryTF) && PeriodSeconds(InpEntryTF)>0 &&
      InpADXMin>0 && InpADXMin<100 && InpSlopeMinATR>=0 &&
      InpRSIBuy>=50 && InpRSIBuy<100 && InpRSISell>0 && InpRSISell<=50 &&
      InpPullbackToleranceATR>=0 && InpBreakoutBars>=3 && InpBreakoutBars<=300 &&
      InpCompressionBars>=2 && InpVolatilityBars>InpCompressionBars && InpVolatilityBars<=300 &&
      InpCompressionRatio>0 && InpCompressionRatio<1 && InpATRExpansion>1 &&
      InpMaxATRRatio>1 && InpMaxATRPricePercent>0 && InpBreakoutBufferATR>=0 &&
      InpVolumeLookback>=5 && InpVolumeLookback<=300 && InpBreakoutMinVolumeRatio>0 &&
      InpRangeBars>=8 && InpRangeBars<=300 && InpRangeMinTouches>=1 &&
      InpRangeTouchATR>=0 && InpRangeMinWidthATR>0 && InpRangeMaxWidthATR>InpRangeMinWidthATR &&
      InpRangeMaxDriftRatio>=0 && InpRangeMaxDriftRatio<=1 && InpSpringPenetrationATR>=0 &&
      InpSpringWickBodyRatio>=0 && InpSpringMinVolumeRatio>0 && InpSpringStopBufferATR>=0 &&
      InpMaximumSignalVolumeRatio>InpBreakoutMinVolumeRatio && InpMaximumSignalVolumeRatio>InpSpringMinVolumeRatio &&
      InpEfficiencyBars>=2 && InpEfficiencyBars<=50 && InpMinimumSetupScore>=0 && InpMinimumSetupScore<100 &&
      InpATRStopMultiplier>0 && InpRewardRisk>0 && InpMaximumRewardRisk>=InpRewardRisk &&
      InpRiskPercent>0 && InpRiskPercent<=0.5 && InpMaximumRiskMoney>0 && InpMinimumPlannedNetProfit>=0 &&
      InpMaxDailyLossPercent>0 && InpMaxDailyLossPercent<=1.5 &&
      InpMaxDrawdownPercent>0 && InpMaxDrawdownPercent<=8 && InpMaxConsecutiveLosses>=1 && InpLossPauseHours>=1 &&
      InpMaxSpreadATRRatio>0 && InpSlippagePoints>=0 && InpCommissionPerLot>=0 &&
      InpMarginReservePercent>=0 && InpMarginReservePercent<100 && InpMinEntryMinutes>=0 &&
      InpMinMarginLevelPercent>=300 &&
      InpMaxQuoteAgeSeconds>0 && InpBreakEvenR>0 && InpBreakEvenOffsetR>=0 &&
      InpBreakEvenOffsetR<InpBreakEvenR && InpTrailingStartR>0 && InpTrailingATR>0 &&
       InpNoProgressBars>=1 && InpProgressStepR>0 && InpInvalidationConfirmBars>=1 && InpInvalidationConfirmBars<=1000 && InpInvalidationBufferATR>=0 &&
      InpRiskReductionStartDD>=0 && InpRiskReductionStartDD<InpMaxDrawdownPercent &&
      InpMinimumRiskScale>0 && InpMinimumRiskScale<=1 &&
      InpStartHour>=0 && InpStartHour<24 && InpEndHour>InpStartHour && InpEndHour<=24 &&
      InpFridayEntryCutoffHour>=0 && InpFridayEntryCutoffHour<=24 &&
      InpFridayCloseHour>InpFridayEntryCutoffHour && InpFridayCloseHour<24 && InpTesterMinTrades>=1;
}
int OnInit()
{
   Tester=(bool)MQLInfoInteger(MQL_TESTER);
   if(!ValidateInputs()) return INIT_PARAMETERS_INCORRECT;
   // Account-wide exclusive file handle prevents competing instances, even with different magics.
   uint serverHash=2166136261;
   string server=AccountInfoString(ACCOUNT_SERVER);
   for(int k=0;k<StringLen(server);k++) serverHash=(serverHash^(uint)StringGetCharacter(server,k))*16777619;
   Prefix=StringFormat("SB4.%I64d.%u.",AccountInfoInteger(ACCOUNT_LOGIN),serverHash);
   if(!Tester)
   {
      LockHandle=FileOpen(Prefix+"lock",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
      if(LockHandle==INVALID_HANDLE) { Log(-1,"INIT_REFUSED","Another SB4 instance owns this account lock"); return INIT_FAILED; }
   }
   string auditName=Prefix+StringFormat("audit-%I64u.csv",GetMicrosecondCount());
   AuditHandle=FileOpen(auditName,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,';',CP_UTF8);
   if(AuditHandle==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(AuditHandle,"server_time","event","symbol","position_or_deal_id","volume","price",
             "risk_money","costs_money","mfe_R_sampled","mae_R_sampled","detail");
   Log(-1,"AUDIT_FILE",auditName);
   string names[];
   int n=StringSplit(InpSymbols,',',names);
   if(n<=0) return INIT_PARAMETERS_INCORRECT;
   ArrayResize(States,n);
   for(int i=0;i<n;i++)
   {
      States[i].fast=States[i].slow=States[i].rsi=States[i].atr=States[i].adx=INVALID_HANDLE;
      States[i].htFast=States[i].htSlow=States[i].htADX=States[i].htATR=INVALID_HANDLE;
   }
   for(int i=0;i<n;i++)
   {
      StringTrimLeft(names[i]); StringTrimRight(names[i]);
      if(StringLen(names[i])==0 || StringLen(names[i])>24) return INIT_PARAMETERS_INCORRECT;
      for(int j=0;j<i;j++) if(names[j]==names[i]) return INIT_PARAMETERS_INCORRECT;
      States[i].symbol=names[i];
      if(!SymbolSelect(names[i],true)) { Log(i,"INIT_REFUSED","Symbol unavailable; check broker suffix"); return INIT_FAILED; }
      States[i].fast=iMA(names[i],InpEntryTF,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
      States[i].slow=iMA(names[i],InpEntryTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
      States[i].rsi=iRSI(names[i],InpEntryTF,InpRSIPeriod,PRICE_CLOSE);
      States[i].atr=iATR(names[i],InpEntryTF,InpATRPeriod);
      States[i].adx=iADX(names[i],InpEntryTF,InpADXPeriod);
      States[i].htFast=iMA(names[i],InpTrendTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
      States[i].htSlow=iMA(names[i],InpTrendTF,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
      States[i].htADX=iADX(names[i],InpTrendTF,InpADXPeriod);
      States[i].htATR=iATR(names[i],InpTrendTF,InpATRPeriod);
      if(States[i].fast<0 || States[i].slow<0 || States[i].rsi<0 || States[i].atr<0 || States[i].adx<0 ||
         States[i].htFast<0 || States[i].htSlow<0 || States[i].htADX<0 || States[i].htATR<0) return INIT_FAILED;
      States[i].lastBar=(datetime)ReadState(i,"bar");
      States[i].attemptBar=(datetime)ReadState(i,"attempt");
      States[i].lastEntry=(datetime)ReadState(i,"entry");
      States[i].usedCompression=(datetime)ReadState(i,"used");
      RestoreCompression(i);
      States[i].entryBudget=ReadState(i,"budget");
      States[i].requestedVolume=ReadState(i,"requested");
      States[i].budgetTime=(datetime)ReadState(i,"budgettime");
   }
   Day=(datetime)ReadState(-1,"day"); DayEquity=ReadState(-1,"equity");
   Peak=ReadState(-1,"peak",AccountInfoDouble(ACCOUNT_EQUITY));
   DayBlocked=ReadState(-1,"daily")>0; DrawdownBlocked=ReadState(-1,"dd")>0; LossBlocked=ReadState(-1,"loss")>0;
   LossPauseUntil=(datetime)ReadState(-1,"losspause");
   LossSequenceStart=(datetime)ReadState(-1,"lossstart");
   ExecutionHold=ReadState(-1,"uncertain")>0;
   UpdateRisk();
   if(!EventSetTimer(2)) return INIT_FAILED;
   Log(-1,"INIT","V4.30; persistent ticket exits; remaining daily/drawdown risk budgets");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   for(int i=0;i<ArraySize(States);i++)
   {
      Log(i,"DATA_SUMMARY",StringFormat("ready=%I64d failed=%I64d last=%s",States[i].dataSnapshots,States[i].dataFailures,States[i].dataReason));
      int handles[]={States[i].fast,States[i].slow,States[i].rsi,States[i].atr,States[i].adx,
                     States[i].htFast,States[i].htSlow,States[i].htADX,States[i].htATR};
      for(int j=0;j<ArraySize(handles);j++) if(handles[j]!=INVALID_HANDLE) IndicatorRelease(handles[j]);
   }
   if(LockHandle!=INVALID_HANDLE) FileClose(LockHandle);
   if(AuditHandle!=INVALID_HANDLE) FileClose(AuditHandle);
}

// DATA: series index 0 always means the latest CLOSED bar (copy starts at shift 1).
bool DataFailure(int i,string stage,string detail)
{
   States[i].dataFailures++;
   if(States[i].dataReason!=stage || TimeCurrent()-States[i].lastDataLog>=3600)
   {
      Log(i,"DATA_WAIT",stage+" "+detail);
      States[i].lastDataLog=TimeCurrent();
   }
   States[i].dataReason=stage;
   return false;
}
bool Buffer(int handle,int count,double &values[],string &error)
{
   ArraySetAsSeries(values,true);
   // In nonvisual testing indicators calculate on demand. CopyBuffer must be
   // called BEFORE inspecting BarsCalculated, otherwise calculation never starts.
   ResetLastError();
   int copied=CopyBuffer(handle,0,1,count,values);
   int code=GetLastError();
   if(copied!=count)
   { error=StringFormat("copied=%d required=%d calculated=%d error=%d",copied,count,BarsCalculated(handle),code); return false; }
   for(int k=0;k<count;k++) if(!MathIsValidNumber(values[k]) || values[k]==EMPTY_VALUE)
   { error=StringFormat("invalid closed value index=%d",k); return false; }
   return true;
}
bool NamedBuffer(int handle,int count,double &values[],string name,string &firstError)
{
   string error="";
   bool ok=Buffer(handle,count,values,error);
   if(!ok && firstError=="") firstError=name+" "+error;
   return ok;
}
double BarVolume(const MqlRates &bar,bool useReal)
{
   return useReal ? (double)bar.real_volume : (double)bar.tick_volume;
}
bool RealVolumeReady(Snapshot &d,int start,int count)
{
   for(int k=0;k<count;k++) if(d.bars[start+k].real_volume<=0) return false;
   return true;
}
double MedianVolume(Snapshot &d,int start,int count,bool useReal)
{
   double values[]; ArrayResize(values,count);
   for(int k=0;k<count;k++) values[k]=BarVolume(d.bars[start+k],useReal);
   ArraySort(values);
   if(count%2==1) return values[count/2];
   return (values[count/2-1]+values[count/2])/2.0;
}
bool LoadData(int i,Snapshot &d)
{
   string s=States[i].symbol;
   datetime entryBar=iTime(s,InpEntryTF,0),trendBar=iTime(s,InpTrendTF,0);
   if(entryBar<=0 || trendBar<=0) return DataFailure(i,"BAR_TIME",StringFormat("entry=%I64d trend=%I64d error=%d",(long)entryBar,(long)trendBar,GetLastError()));
   int n=MathMax(InpBreakoutBars+2,InpVolatilityBars+InpCompressionBars+2);
   n=MathMax(n,InpRangeBars+2);
   n=MathMax(n,InpVolumeLookback+2);
   n=MathMax(n,InpEfficiencyBars+1);
   ArraySetAsSeries(d.bars,true);
   int trendBars=Bars(s,InpTrendTF),entryBars=Bars(s,InpEntryTF);
   if(trendBars<InpTrendEMA+InpSlopeBars+10 || entryBars<InpSlowEMA+n)
      return DataFailure(i,"WARMUP",StringFormat("%s=%d/%d %s=%d/%d",EnumToString(InpTrendTF),trendBars,InpTrendEMA+InpSlopeBars+10,EnumToString(InpEntryTF),entryBars,InpSlowEMA+n));
   ResetLastError();
   int copied=CopyRates(s,InpEntryTF,1,n,d.bars);
   if(copied!=n) return DataFailure(i,"RATES",StringFormat("copied=%d required=%d error=%d",copied,n,GetLastError()));
   string error=""; bool ready=true;
   // Request every handle even if one is still loading; no short-circuit starvation.
   ready=NamedBuffer(States[i].fast,3,d.fast,"entry EMA fast",error) && ready;
   ready=NamedBuffer(States[i].slow,3,d.slow,"entry EMA slow",error) && ready;
   ready=NamedBuffer(States[i].rsi,3,d.rsi,"entry RSI",error) && ready;
   ready=NamedBuffer(States[i].atr,n,d.atr,"entry ATR",error) && ready;
   ready=NamedBuffer(States[i].adx,2,d.adx,"entry ADX",error) && ready;
   ready=NamedBuffer(States[i].htFast,InpSlopeBars+1,d.hf,"trend EMA fast",error) && ready;
   ready=NamedBuffer(States[i].htSlow,2,d.hs,"trend EMA slow",error) && ready;
   ready=NamedBuffer(States[i].htADX,2,d.ha,"trend ADX",error) && ready;
   ready=NamedBuffer(States[i].htATR,2,d.hv,"trend ATR",error) && ready;
   if(!ready) return DataFailure(i,"INDICATOR",error);
   if(d.atr[0]<=0 || d.hv[0]<=0 || d.bars[0].close<=0) return DataFailure(i,"NONPOSITIVE","ATR or close <= 0");
   d.baseline=0; d.compression=0;
   for(int k=1;k<=InpCompressionBars;k++) d.compression+=d.atr[k];
   d.compression/=InpCompressionBars;
   for(int k=InpCompressionBars+1;k<=InpCompressionBars+InpVolatilityBars;k++) d.baseline+=d.atr[k];
   d.baseline/=InpVolatilityBars;
   if(d.baseline<=0) return DataFailure(i,"BASELINE","ATR baseline <= 0");
   double rangeATR=0;
   d.rangeHigh=d.bars[2].high; d.rangeLow=d.bars[2].low;
   for(int k=2;k<InpRangeBars+2;k++)
   {
      d.rangeHigh=MathMax(d.rangeHigh,d.bars[k].high);
      d.rangeLow=MathMin(d.rangeLow,d.bars[k].low);
      rangeATR+=d.atr[k];
   }
   rangeATR/=InpRangeBars;
   d.rangeHighTouches=0; d.rangeLowTouches=0;
   double touch=InpRangeTouchATR*rangeATR;
   for(int k=2;k<InpRangeBars+2;k++)
   {
      if(d.bars[k].high>=d.rangeHigh-touch) d.rangeHighTouches++;
      if(d.bars[k].low<=d.rangeLow+touch) d.rangeLowTouches++;
   }
   double rangeWidth=d.rangeHigh-d.rangeLow;
   double drift=rangeWidth>0 ? MathAbs(d.bars[2].close-d.bars[InpRangeBars+1].close)/rangeWidth : DBL_MAX;
   d.rangeWidthATR=rangeATR>0 ? rangeWidth/rangeATR : DBL_MAX;
   d.rangeValid=SB_TradingRange(d.rangeHigh,d.rangeLow,rangeATR,InpRangeMinWidthATR,InpRangeMaxWidthATR,
                                d.rangeHighTouches,d.rangeLowTouches,InpRangeMinTouches,drift,InpRangeMaxDriftRatio);
   d.breakoutRealVolume=RealVolumeReady(d,0,InpVolumeLookback+1);
   d.springRealVolume=RealVolumeReady(d,1,InpVolumeLookback+1);
   double breakoutMedian=MedianVolume(d,1,InpVolumeLookback,d.breakoutRealVolume);
   double springMedian=MedianVolume(d,2,InpVolumeLookback,d.springRealVolume);
   d.breakoutVolumeRatio=breakoutMedian>0 ? BarVolume(d.bars[0],d.breakoutRealVolume)/breakoutMedian : 0;
   d.springVolumeRatio=springMedian>0 ? BarVolume(d.bars[1],d.springRealVolume)/springMedian : 0;
   double path=0;
   for(int k=0;k<InpEfficiencyBars;k++) path+=MathAbs(d.bars[k].close-d.bars[k+1].close);
   d.efficiency=SB_DirectionalEfficiency(MathAbs(d.bars[0].close-d.bars[InpEfficiencyBars].close),path);
   d.structurePattern=d.rangeValid ? SB_SpringPattern(d.rangeHigh,d.rangeLow,rangeATR,
      d.bars[1].open,d.bars[1].high,d.bars[1].low,d.bars[1].close,
      d.bars[0].open,d.bars[0].high,d.bars[0].low,d.bars[0].close,
      InpSpringPenetrationATR,InpSpringWickBodyRatio,d.springVolumeRatio,InpSpringMinVolumeRatio) : 0;
   double slope=(d.hf[0]-d.hf[InpSlopeBars])/d.hv[0];
   d.direction=0;
   if(d.hf[0]>d.hs[0] && slope>InpSlopeMinATR) d.direction=1;
   if(d.hf[0]<d.hs[0] && slope<-InpSlopeMinATR) d.direction=-1;
   d.regime=REG_RANGE;
   if(d.atr[0]/d.baseline>InpMaxATRRatio || 100*d.atr[0]/d.bars[0].close>InpMaxATRPricePercent)
      d.regime=REG_EXCESS_VOL;
   else if(d.compression/d.baseline<=InpCompressionRatio) d.regime=REG_BREAKOUT;
   else if(d.direction!=0 && d.ha[0]>=InpADXMin && d.adx[0]>=InpADXMin) d.regime=REG_TREND;
   // Reject a mixed snapshot if a timeframe rolled over while buffers were copied.
   if(iTime(s,InpEntryTF,0)!=entryBar || iTime(s,InpTrendTF,0)!=trendBar || d.bars[0].time>=entryBar)
      return DataFailure(i,"ROLLOVER","Timeframe changed during snapshot; retry");
   if(States[i].dataSnapshots==0 || States[i].dataReason!="") Log(i,"DATA_READY","Closed entry/trend snapshot available");
   States[i].dataReason=""; States[i].dataSnapshots++;
   return true;
}

// HISTORY: aggregate complete position lifecycles, including entry costs and split fills.
bool BuildClosed(ClosedTrade &rows[])
{
   ArrayResize(rows,0);
   if(!HistorySelect(0,TimeCurrent())) return false;
   for(int k=0;k<HistoryDealsTotal();k++)
   {
      ulong t=HistoryDealGetTicket(k),id=(ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID);
      ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(t,DEAL_TYPE);
      if(id==0 || (type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)) continue;
      int j=0; for(;j<ArraySize(rows);j++) if(rows[j].id==id) break;
      if(j==ArraySize(rows)) { ArrayResize(rows,j+1); ZeroMemory(rows[j]); rows[j].id=id; }
      rows[j].net+=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_SWAP)+
                   HistoryDealGetDouble(t,DEAL_COMMISSION)+HistoryDealGetDouble(t,DEAL_FEE);
      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY);
      if(entry==DEAL_ENTRY_IN || entry==DEAL_ENTRY_INOUT)
      {
         if((ulong)HistoryDealGetInteger(t,DEAL_MAGIC)==InpMagic) rows[j].own=true;
         else rows[j].foreign=true;
      }
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY || entry==DEAL_ENTRY_INOUT)
         rows[j].closed=(datetime)HistoryDealGetInteger(t,DEAL_TIME);
   }
   for(int k=0;k<PositionsTotal();k++)
   {
      if(PositionGetTicket(k)==0) continue;
      ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      for(int j=0;j<ArraySize(rows);j++) if(rows[j].id==id) rows[j].open=true;
   }
   // Closing order, not entry order, determines consecutive losses.
   for(int k=1;k<ArraySize(rows);k++)
   {
      ClosedTrade value=rows[k]; int j=k-1;
      while(j>=0 && rows[j].closed>value.closed) { rows[j+1]=rows[j]; j--; }
      rows[j+1]=value;
   }
   return true;
}
void RefreshLosses()
{
   ClosedTrade rows[];
   HistoryOK=BuildClosed(rows); LastHistoryScan=TimeCurrent();
   if(!HistoryOK) { Log(-1,"HISTORY_UNAVAILABLE","New entries blocked"); return; }
   bool previous=LossBlocked;
   datetime previousPause=LossPauseUntil,previousStart=LossSequenceStart;
   LossStreak=0;
   if(LossSequenceStart==0) LossSequenceStart=Day>0 ? Day : SB_Day(TimeCurrent());
   for(int k=0;k<ArraySize(rows);k++)
      if(rows[k].own && !rows[k].open && rows[k].closed>=LossSequenceStart)
         SB_LossSequence(rows[k].net,rows[k].closed,InpMaxConsecutiveLosses,
            InpLossPauseHours*3600,LossStreak,LossPauseUntil,LossSequenceStart);
   LossBlocked=TimeCurrent()<LossPauseUntil;
   if(!previous && LossBlocked)
      Log(-1,"LOSS_PAUSE_START",StringFormat("Consecutive losses; resume after %s",TimeToString(LossPauseUntil,TIME_DATE|TIME_MINUTES)));
   if(previous && !LossBlocked)
      Log(-1,"LOSS_PAUSE_END","Configured pause elapsed; new loss sequence started");
   if(previous!=LossBlocked || previousPause!=LossPauseUntil || previousStart!=LossSequenceStart) SaveRisk();
}
void UpdateRisk()
{
   CashOK=RefreshCash();
   if(!CashOK) { Log(-1,"CASH_HISTORY_UNAVAILABLE","Entries blocked; anchors unchanged"); return; }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   datetime today=SB_Day(TimeCurrent());
   bool changed=false;
   if(today!=Day)
   {
      if(DayBlocked) Log(-1,"DAILY_PAUSE_END","New server day; session filter still applies");
      Day=today; DayEquity=eq; DayCash=CashTotal; DayBlocked=false;
      LastHistoryScan=0; changed=true;
   }
   double peakAnchor=SB_CashAnchor(Peak,CashTotal,PeakCash);
   double dayAnchor=SB_CashAnchor(DayEquity,CashTotal,DayCash);
   if(eq>peakAnchor) { Peak=eq; PeakCash=CashTotal; peakAnchor=eq; changed=true; }
   if(dayAnchor<=0 || peakAnchor<=0)
   { CashOK=false; Log(-1,"CASH_ANCHOR_INVALID","Capital reference nonpositive; manual review required"); return; }
   if(100*(dayAnchor-eq)/dayAnchor>=InpMaxDailyLossPercent && !DayBlocked)
   { DayBlocked=true; changed=true; Log(-1,"DAILY_PAUSE_START","Daily equity loss limit reached"); }
   if(100*(peakAnchor-eq)/peakAnchor>=InpMaxDrawdownPercent && !DrawdownBlocked)
   { DrawdownBlocked=true; changed=true; Log(-1,"DRAWDOWN_STOP","Persistent stop; manual review required"); }
   if(changed) SaveRisk();
   if(LastHistoryScan==0 || TimeCurrent()-LastHistoryScan>=60) RefreshLosses();
}
bool Session()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(),t);
   return SB_EntrySession(t.day_of_week,t.hour,InpStartHour,InpEndHour,
                          InpAllowMonday,InpAllowFriday,InpFridayEntryCutoffHour);
}
bool RiskGate(int i)
{
   if(ExecutionHold)
   { Log(i,"EXECUTION_HOLD","Uncertain previous send; reconcile broker history before clearing hold"); return false; }
   if(!CashOK || !PersistenceOK || !HistoryOK || DayBlocked || DrawdownBlocked || LossBlocked || AccountInfoDouble(ACCOUNT_EQUITY)<=0)
   { Log(i,"RISK_REFUSED",StringFormat("history=%d daily=%d drawdown=%d losses=%d",HistoryOK,DayBlocked,DrawdownBlocked,LossBlocked)); return false; }
   if(!Tester && InpDemoOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)
   { Log(i,"DEMO_ONLY","Real/contest entries disabled"); return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   { Log(i,"PERMISSION_REFUSED","Algorithmic trading not authorized"); return false; }
   return true;
}

// SIGNALS: freeze a compression box until consumed/expired; no repeated rolling breakout.
int EngineCode(string engine)
{
   if(engine=="BREAKOUT") return 1;
   if(engine=="SPRING") return 2;
   if(engine=="UPTHRUST") return 3;
   if(engine=="FAILED_UPTHRUST") return 4;
   if(engine=="FAILED_SPRING") return 5;
   if(engine=="TREND") return 6;
   return 0;
}
double SetupScore(Snapshot &d,string engine,int direction)
{
   bool structural=engine=="SPRING" || engine=="UPTHRUST" ||
                   engine=="FAILED_SPRING" || engine=="FAILED_UPTHRUST";
   double volume=structural ? d.springVolumeRatio : d.breakoutVolumeRatio;
   double minimum=structural ? InpSpringMinVolumeRatio : InpBreakoutMinVolumeRatio;
   bool aligned=d.direction==direction;
   double strength=SB_CloseStrength(direction,d.bars[0].high,d.bars[0].low,d.bars[0].close);
   return SB_SetupScore(aligned,volume,minimum,InpMaximumSignalVolumeRatio,strength,d.efficiency,structural);
}
int Signal(int i,Snapshot &d,string &engine)
{
   if(States[i].armed && (d.bars[0].time-States[i].compressionID)>InpBreakoutBars*PeriodSeconds(InpEntryTF))
   { States[i].armed=false; SaveCompression(i); }
   if(!States[i].armed && d.regime==REG_BREAKOUT && d.bars[1].time>States[i].usedCompression)
   {
      States[i].armed=true; States[i].compressionID=d.bars[1].time;
      States[i].boxHigh=d.bars[1].high; States[i].boxLow=d.bars[1].low;
      for(int k=2;k<=InpBreakoutBars;k++)
      { States[i].boxHigh=MathMax(States[i].boxHigh,d.bars[k].high); States[i].boxLow=MathMin(States[i].boxLow,d.bars[k].low); }
      SaveCompression(i);
   }
   if(d.regime==REG_EXCESS_VOL) return 0;
   if(InpSpringEngine && d.rangeValid && d.structurePattern!=0 && d.springVolumeRatio<=InpMaximumSignalVolumeRatio)
   {
      int structuralDirection=d.structurePattern>0 ? 1 : -1;
      bool failed=MathAbs(d.structurePattern)==2;
      bool aligned=d.direction==0 || d.direction==structuralDirection;
      if(aligned && (!failed || InpTradeFailedSpring))
      {
         if(d.structurePattern==1) engine="SPRING";
         else if(d.structurePattern==-1) engine="UPTHRUST";
         else if(d.structurePattern==2) engine="FAILED_UPTHRUST";
         else engine="FAILED_SPRING";
         return structuralDirection;
      }
   }
   if(d.direction==0) return 0;
   if(InpBreakoutEngine && States[i].armed && d.atr[0]>=d.atr[1]*InpATRExpansion &&
      d.breakoutVolumeRatio<=InpMaximumSignalVolumeRatio &&
      (!InpVolumeFilter || d.breakoutVolumeRatio>=InpBreakoutMinVolumeRatio))
   {
      bool up=d.bars[0].close>States[i].boxHigh+InpBreakoutBufferATR*d.atr[0];
      bool down=d.bars[0].close<States[i].boxLow-InpBreakoutBufferATR*d.atr[0];
      if((up && d.direction==1) || (down && d.direction==-1)) { engine="BREAKOUT"; return d.direction; }
   }
   if(!InpTrendEngine || d.regime!=REG_TREND) return 0;
   double low=MathMin(d.fast[1],d.slow[1])-InpPullbackToleranceATR*d.atr[1];
   double high=MathMax(d.fast[1],d.slow[1])+InpPullbackToleranceATR*d.atr[1];
   bool touch=d.bars[1].low<=high && d.bars[1].high>=low;
   if(!touch) return 0;
   if(d.direction==1 && d.fast[0]>d.slow[0] && d.rsi[1]<=InpRSIBuy && d.rsi[0]>InpRSIBuy &&
      d.bars[0].close>d.fast[0] && d.bars[0].close>d.bars[0].open) { engine="TREND"; return 1; }
   if(d.direction==-1 && d.fast[0]<d.slow[0] && d.rsi[1]>=InpRSISell && d.rsi[0]<InpRSISell &&
      d.bars[0].close<d.fast[0] && d.bars[0].close<d.bars[0].open) { engine="TREND"; return -1; }
   return 0;
}
bool Quote(int i,MqlTick &q)
{
   if(!SymbolInfoTick(States[i].symbol,q) || q.ask<=0 || q.bid<=0 || q.ask<q.bid ||
      TimeCurrent()-q.time>InpMaxQuoteAgeSeconds)
   { Log(i,"QUOTE_REFUSED","Missing, invalid or stale quote"); return false; }
   return true;
}
bool Filling(string s,ENUM_ORDER_TYPE_FILLING &mode)
{
   long flags=SymbolInfoInteger(s,SYMBOL_FILLING_MODE);
   long execution=SymbolInfoInteger(s,SYMBOL_TRADE_EXEMODE);
   if(execution==SYMBOL_TRADE_EXECUTION_INSTANT || execution==SYMBOL_TRADE_EXECUTION_REQUEST || (flags&SYMBOL_FILLING_FOK)!=0)
      mode=ORDER_FILLING_FOK;
   else if((flags&SYMBOL_FILLING_IOC)!=0) mode=ORDER_FILLING_IOC;
   else if(execution!=SYMBOL_TRADE_EXECUTION_MARKET) mode=ORDER_FILLING_RETURN;
   else return false;
   return true;
}
bool ExposureAllows(int i,int direction)
{
   string s=States[i].symbol;
   bool fx=StringFind(s,"EURUSD")>=0 || StringFind(s,"GBPUSD")>=0;
   for(int k=0;k<PositionsTotal();k++)
   {
      if(PositionGetTicket(k)==0) continue;
      string other=PositionGetString(POSITION_SYMBOL);
      if(other==s || (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)
      { Log(i,"EXPOSURE_REFUSED","Existing symbol position or bot position"); return false; }
      bool otherFX=StringFind(other,"EURUSD")>=0 || StringFind(other,"GBPUSD")>=0;
      int dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1;
      if(InpCorrelationGuard && fx && otherFX && direction==dir)
      { Log(i,"CORRELATION_REFUSED","Same USD direction in existing EURUSD/GBPUSD position"); return false; }
   }
   for(int k=0;k<OrdersTotal();k++)
   {
      if(OrderGetTicket(k)==0) continue;
      string other=OrderGetString(ORDER_SYMBOL);
      if(other==s || (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic ||
         (InpCorrelationGuard && fx && (StringFind(other,"EURUSD")>=0 || StringFind(other,"GBPUSD")>=0)))
      { Log(i,"ORDER_PENDING","Existing order could create competing exposure"); return false; }
   }
   return true;
}
bool StopsValid(string s,int dir,MqlTick &q,double sl,double tp,bool modify)
{
   double point=SymbolInfoDouble(s,SYMBOL_POINT),tick=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);
   long points=SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL);
   if(modify) points=MathMax(points,SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL));
   double gap=points*point+tick;
   if(sl<=0 || tp<=0 || tick<=0) return false;
   return dir==1 ? q.bid-sl>=gap && tp-q.bid>=gap : sl-q.ask>=gap && q.ask-tp>=gap;
}
bool ReservedRisk(double &reserved)
{
   reserved=0;
   // Pending external orders have no dependable current-equity SL budget.
   if(OrdersTotal()>0) return false;
   for(int k=0;k<PositionsTotal();k++)
   {
      if(PositionGetTicket(k)==0) return false;
      string symbol=PositionGetString(POSITION_SYMBOL);
      double sl=PositionGetDouble(POSITION_SL),volume=PositionGetDouble(POSITION_VOLUME);
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      MqlTick quote;
      if(sl<=0 || !SymbolInfoTick(symbol,quote) || quote.bid<=0 || quote.ask<quote.bid ||
         TimeCurrent()-quote.time>InpMaxQuoteAgeSeconds) return false;
      double pnl=0;
      double adverse=InpSlippagePoints*SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,symbol,volume,
                          buy ? quote.bid : quote.ask,sl+(buy ? -adverse : adverse),pnl)) return false;
      reserved+=MathMax(0,-pnl)+volume*InpCommissionPerLot;
   }
   return MathIsValidNumber(reserved);
}
bool SendChecked(int i,MqlTradeRequest &req,MqlTradeResult &res)
{
   MqlTradeCheckResult check={};
   if(!OrderCheck(req,check) || (check.retcode!=0 && check.retcode!=TRADE_RETCODE_DONE))
   { res.retcode=TRADE_RETCODE_INVALID; Log(i,"ORDER_CHECK_REFUSED",StringFormat("ret=%u %s free=%.2f",check.retcode,check.comment,check.margin_free)); return false; }
   if(req.action==TRADE_ACTION_DEAL && req.position==0 &&
      !SB_MarginAllows(check.equity,check.margin,InpMinMarginLevelPercent))
   { res.retcode=TRADE_RETCODE_NO_MONEY; Log(i,"MARGIN_LEVEL_REFUSED","Projected account margin level below floor"); return false; }
   bool sent=OrderSend(req,res);
   if(req.action==TRADE_ACTION_DEAL) LastHistoryScan=0;
   Log(i,"EXECUTION",StringFormat("action=%d sent=%d ret=%u order=%I64u deal=%I64u %s",req.action,sent,res.retcode,res.order,res.deal,res.comment));
   Audit(i,"SEND_RESULT",res.deal,res.volume,res.price,0,0,StringFormat("ret=%u %s",res.retcode,req.comment));
   return sent && (res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_DONE_PARTIAL || res.retcode==TRADE_RETCODE_PLACED);
}
void Enter(int i,int dir,Snapshot &d,string engine,datetime bar,double setupScore)
{
   if(!Session()) { Log(i,"SESSION_REFUSED","Outside allowed server hours/day"); return; }
   if(!RiskGate(i) || !ExposureAllows(i,dir)) return;
   if(States[i].attemptBar==bar || TimeCurrent()-States[i].lastEntry<InpMinEntryMinutes*60)
   { Log(i,"COOLDOWN_REFUSED","Entry attempt already consumed or entry interval not elapsed"); return; }
   string s=States[i].symbol; MqlTick q;
   if(!Quote(i,q)) return;
   if((q.ask-q.bid)/d.atr[0]>InpMaxSpreadATRRatio) { Log(i,"SPREAD_REFUSED",StringFormat("spread/ATR=%.4f",(q.ask-q.bid)/d.atr[0])); return; }
   long allowed=SymbolInfoInteger(s,SYMBOL_ORDER_MODE);
   long mode=SymbolInfoInteger(s,SYMBOL_TRADE_MODE);
   if((allowed&SYMBOL_ORDER_MARKET)==0 || (allowed&SYMBOL_ORDER_SL)==0 || (allowed&SYMBOL_ORDER_TP)==0 ||
      mode==SYMBOL_TRADE_MODE_DISABLED || mode==SYMBOL_TRADE_MODE_CLOSEONLY ||
      (dir>0 && mode==SYMBOL_TRADE_MODE_SHORTONLY) || (dir<0 && mode==SYMBOL_TRADE_MODE_LONGONLY))
   { Log(i,"SYMBOL_MODE_REFUSED","Market entry with SL/TP not allowed in this direction"); return; }
   double tick=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE),point=SymbolInfoDouble(s,SYMBOL_POINT);
   int digits=(int)SymbolInfoInteger(s,SYMBOL_DIGITS);
   double entry=dir==1 ? q.ask : q.bid,dist=d.atr[0]*InpATRStopMultiplier;
   bool structural=engine=="SPRING" || engine=="UPTHRUST" ||
                   engine=="FAILED_SPRING" || engine=="FAILED_UPTHRUST";
   if(structural)
   {
      double structuralStop=dir==1 ? d.bars[1].low-InpSpringStopBufferATR*d.atr[0]
                                   : d.bars[1].high+InpSpringStopBufferATR*d.atr[0];
      dist=MathMax(dist,dir==1 ? entry-structuralStop : structuralStop-entry);
   }
   double sl=SB_Price(entry-dir*dist,tick,digits,dir<0);
   double qualityRR=InpRewardRisk;
   double targetRR=InpRewardRisk;
   if(InpAdaptiveProfitTarget)
   {
      qualityRR=SB_AdaptiveRewardRisk(InpRewardRisk,InpMaximumRewardRisk,setupScore,
                                      InpMinimumSetupScore,d.efficiency,structural);
      targetRR=SB_MarketRewardRisk(EngineCode(engine),dir,entry,dist,
                                   States[i].boxHigh,States[i].boxLow,d.rangeHigh,d.rangeLow,
                                   qualityRR,InpMaximumRewardRisk);
   }
   double tp=SB_Price(entry+dir*dist*targetRR,tick,digits,dir>0);
   if(!StopsValid(s,dir,q,sl,tp,false)) { Log(i,"STOPS_REFUSED","Initial ATR stops violate broker distance/tick rules"); return; }
   ENUM_ORDER_TYPE type=dir==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double loss=0;
   // Allow adverse execution at both entry and stop; gaps can still exceed this estimate.
   if(!OrderCalcProfit(type,s,1.0,entry+dir*InpSlippagePoints*point,sl-dir*InpSlippagePoints*point,loss) || loss>=0)
   { Log(i,"RISK_CALC_REFUSED","Cannot calculate monetary SL loss"); return; }
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double peakAnchor=SB_CashAnchor(Peak,CashTotal,PeakCash);
   double drawdown=peakAnchor>0 ? MathMax(0,100*(peakAnchor-equity)/peakAnchor) : InpMaxDrawdownPercent;
   double riskScale=InpAdaptiveDrawdownRisk ? SB_RiskScale(drawdown,InpRiskReductionStartDD,
                                                           InpMaxDrawdownPercent,InpMinimumRiskScale) : 1.0;
   double budget=SB_RiskBudget(equity,InpRiskPercent,riskScale,InpMaximumRiskMoney);
   double reserved=0;
   if(!ReservedRisk(reserved)) { Log(i,"RISK_UNBOUNDED","Existing exposure lacks a calculable stop budget"); return; }
   budget=SB_RemainingBudget(budget,equity-reserved,SB_CashAnchor(DayEquity,CashTotal,DayCash),peakAnchor,
                             InpMaxDailyLossPercent,InpMaxDrawdownPercent);
   double unitLoss=-loss+InpCommissionPerLot;
   double minimum=SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
   double volume=SB_Volume(budget,unitLoss,minimum,SymbolInfoDouble(s,SYMBOL_VOLUME_MAX),SymbolInfoDouble(s,SYMBOL_VOLUME_STEP));
   if(volume<=0) { Log(i,"VOLUME_REFUSED",StringFormat("budget=%.4f minimum=%.8f minimumRisk=%.4f %s",budget,minimum,minimum*unitLoss,AccountInfoString(ACCOUNT_CURRENCY))); return; }
   double grossTP=0;
   double plannedEntry=entry+dir*InpSlippagePoints*point;
   double estimatedCosts=volume*InpCommissionPerLot;
   bool profitCalculated=OrderCalcProfit(type,s,volume,plannedEntry,tp,grossTP);
   if(profitCalculated && !SB_NetProfitAllows(grossTP,estimatedCosts,InpMinimumPlannedNetProfit) &&
      InpAdaptiveProfitTarget && targetRR<InpMaximumRewardRisk)
   {
      double maximumTP=SB_Price(entry+dir*dist*InpMaximumRewardRisk,tick,digits,dir>0);
      double maximumGross=0;
      if(OrderCalcProfit(type,s,volume,plannedEntry,maximumTP,maximumGross) &&
         SB_NetProfitAllows(maximumGross,estimatedCosts,InpMinimumPlannedNetProfit))
      {
         double lowRR=targetRR,highRR=InpMaximumRewardRisk;
         for(int search=0;search<24;search++)
         {
            double middleRR=(lowRR+highRR)/2.0;
            double middleTP=SB_Price(entry+dir*dist*middleRR,tick,digits,dir>0);
            double middleGross=0;
            if(OrderCalcProfit(type,s,volume,plannedEntry,middleTP,middleGross) &&
               SB_NetProfitAllows(middleGross,estimatedCosts,InpMinimumPlannedNetProfit)) highRR=middleRR;
            else lowRR=middleRR;
         }
         targetRR=highRR;
         tp=SB_Price(entry+dir*dist*targetRR,tick,digits,dir>0);
         profitCalculated=OrderCalcProfit(type,s,volume,plannedEntry,tp,grossTP);
      }
   }
   if(!profitCalculated || !SB_NetProfitAllows(grossTP,estimatedCosts,InpMinimumPlannedNetProfit))
   {
      Log(i,"NET_TP_REFUSED",StringFormat("grossTP=%.4f costs=%.4f netTP=%.4f minimum=%.4f %s lots=%.8f risk=%.4f budget=%.4f",
         grossTP,estimatedCosts,grossTP-estimatedCosts,InpMinimumPlannedNetProfit,
         AccountInfoString(ACCOUNT_CURRENCY),volume,volume*unitLoss,budget));
      return;
   }
   double margin=0,free=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(type,s,volume,entry,margin) || margin>free*(1-InpMarginReservePercent/100))
   { Log(i,"MARGIN_REFUSED",StringFormat("required=%.4f available=%.4f",margin,free)); return; }
   if(!SB_MarginAllows(AccountInfoDouble(ACCOUNT_EQUITY),AccountInfoDouble(ACCOUNT_MARGIN)+margin,InpMinMarginLevelPercent))
   { Log(i,"MARGIN_LEVEL_REFUSED","Estimated total margin exceeds ceiling"); return; }
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL; req.symbol=s; req.magic=InpMagic; req.type=type;
   req.volume=volume; req.price=entry; req.sl=sl; req.tp=tp; req.deviation=InpSlippagePoints; req.comment="SB4 "+engine;
   if(!Filling(s,req.type_filling)) { Log(i,"FILLING_REFUSED","No supported market filling policy"); return; }
   // Persist before sending, including unknown/timeout outcomes: never blindly retry an order.
   States[i].attemptBar=bar; States[i].lastEntry=TimeCurrent();
   States[i].entryBudget=budget; States[i].requestedVolume=volume; States[i].budgetTime=TimeCurrent();
   States[i].positionEngine=EngineCode(engine); States[i].entryScore=setupScore;
   States[i].entryBoxHigh=States[i].boxHigh; States[i].entryBoxLow=States[i].boxLow;
   States[i].entryRangeHigh=d.rangeHigh; States[i].entryRangeLow=d.rangeLow; States[i].invalidationBars=0;
   States[i].mfe=0; States[i].mae=0;
   States[i].auditedMFE=0; States[i].auditedMAE=0;
   PutState(i,"budget",budget); PutState(i,"requested",volume); PutState(i,"budgettime",(double)States[i].budgetTime);
   PutState(i,"planbound",0);
   PutState(i,"planengine",States[i].positionEngine); PutState(i,"planscore",setupScore);
   PutState(i,"planboxhigh",States[i].entryBoxHigh); PutState(i,"planboxlow",States[i].entryBoxLow);
   PutState(i,"planrangehigh",States[i].entryRangeHigh); PutState(i,"planrangelow",States[i].entryRangeLow);
   Audit(i,"ENTRY_PLAN",0,volume,entry,volume*unitLoss,volume*InpCommissionPerLot,
      StringFormat("engine=%s score=%.2f riskScale=%.3f drawdown=%.3f regime=%d range=%d rangeATR=%.4f volume=%.4f volumeType=%s springVolume=%.4f springVolumeType=%s efficiency=%.4f spread=%.8f ATR=%.8f SL=%.8f TP=%.8f baseRR=%.4f qualityRR=%.4f targetRR=%.4f budget=%.8f grossTP=%.8f costs=%.8f netTP=%.8f",
         engine,setupScore,riskScale,drawdown,
         d.regime,d.rangeValid,d.rangeWidthATR,d.breakoutVolumeRatio,d.breakoutRealVolume ? "real" : "tick",
         d.springVolumeRatio,d.springRealVolume ? "real" : "tick",d.efficiency,
         q.ask-q.bid,d.atr[0],sl,tp,InpRewardRisk,qualityRR,targetRR,budget,grossTP,estimatedCosts,grossTP-estimatedCosts));
   PutState(i,"attempt",(double)bar); PutState(i,"entry",(double)States[i].lastEntry);
   if(engine=="BREAKOUT")
   {
      // Require an entirely fresh compression window before another breakout entry.
      States[i].usedCompression=d.bars[0].time+InpCompressionBars*PeriodSeconds(InpEntryTF);
      States[i].armed=false; PutState(i,"used",(double)States[i].usedCompression);
      SaveCompression(i);
   }
   if(!Tester) GlobalVariablesFlush();
   Log(i,"ENTRY_REQUEST",StringFormat("%s dir=%d lots=%.8f SL=%.*f TP=%.*f targetR=%.3f plannedRisk=%.4f budget=%.4f plannedNetTP=%.4f",engine,dir,volume,digits,sl,digits,tp,targetRR,volume*unitLoss,budget,grossTP-estimatedCosts));
   ExecutionHold=true; PutState(-1,"uncertain",1);
   if(!Tester) GlobalVariablesFlush();
   if(!PersistenceOK) { Log(i,"ENTRY_REFUSED","Safety state could not be persisted"); return; }
   SendChecked(i,req,res);
   if(res.retcode!=0 && res.retcode!=TRADE_RETCODE_TIMEOUT && res.retcode!=TRADE_RETCODE_CONNECTION &&
      res.retcode!=TRADE_RETCODE_PLACED)
      { ExecutionHold=false; PutState(-1,"uncertain",0); }
   if(!Tester) GlobalVariablesFlush();
}

// Position snapshot is authoritative; transaction event ordering is not assumed.
bool VerifyExecution(int i,ulong ticket,ulong id)
{
   if(!HistorySelectByPosition(id))
   { ExecutionHold=true; PutState(-1,"uncertain",1); return false; }
   bool own=false,mixed=false;
   double paid=0;
   for(int k=0;k<HistoryDealsTotal();k++)
   {
      ulong t=HistoryDealGetTicket(k);
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY);
      paid+=MathMax(0,-HistoryDealGetDouble(t,DEAL_COMMISSION))+MathMax(0,-HistoryDealGetDouble(t,DEAL_FEE));
      if(e==DEAL_ENTRY_IN || e==DEAL_ENTRY_INOUT)
      {
         if((ulong)HistoryDealGetInteger(t,DEAL_MAGIC)!=InpMagic || e==DEAL_ENTRY_INOUT) mixed=true;
         else own=true;
      }
   }
   if(!own || mixed)
   { ExecutionHold=true; PutState(-1,"uncertain",1); Log(i,"NETTING_CONFLICT","Manual review required; no automatic liquidation of mixed position"); return false; }
   if(!PositionSelectByTicket(ticket)) return false;
   double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   double volume=PositionGetDouble(POSITION_VOLUME),entry=PositionGetDouble(POSITION_PRICE_OPEN);
   int dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1;
   double pnl=0;
   bool calculated=sl>0 && OrderCalcProfit(dir==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,States[i].symbol,volume,entry,sl,pnl);
   double risk=MathMax(0,-pnl)+MathMax(paid,volume*InpCommissionPerLot)+MathMax(0,-PositionGetDouble(POSITION_SWAP));
   string tag=StringFormat("p%I64u",id);
   datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
   if(ReadState(i,tag+"bound")==0 && ReadState(i,"planbound")==0 &&
      States[i].budgetTime>0 && opened>=States[i].budgetTime && opened<=States[i].budgetTime+120)
   {
      PutState(i,tag+"budget",States[i].entryBudget); PutState(i,tag+"requested",States[i].requestedVolume);
      string fields[]={"planengine","planscore","planboxhigh","planboxlow","planrangehigh","planrangelow"};
      for(int k=0;k<ArraySize(fields);k++) PutState(i,tag+fields[k],ReadState(i,fields[k]));
      if(!Tester) GlobalVariablesFlush();
      PutState(i,"planbound",1);
      if(!Tester) GlobalVariablesFlush();
      PutState(i,tag+"bound",1);
      if(!Tester) GlobalVariablesFlush();
   }
   bool matched=ReadState(i,tag+"bound")>0;
   double budget=ReadState(i,tag+"budget"),requested=ReadState(i,tag+"requested");
   // Existing pre-upgrade positions lack a trustworthy original budget. Manage their
   // stops, but suspend entries for review instead of inventing a budget.
   if(!matched)
   {
      ExecutionHold=true; PutState(-1,"uncertain",1);
      Log(i,"LEGACY_BUDGET_UNKNOWN","Original budget unavailable; entries suspended");
      if(sl>0 && tp>0) return true;
   }
   bool safe=matched && calculated && SB_ExecutionSafe(sl,tp,risk,budget,volume,requested);
   if(States[i].positionID!=id)
      Audit(i,"EXECUTION_AUDIT",id,volume,entry,risk,paid,StringFormat("SL=%.8f TP=%.8f budget=%.8f safe=%d",sl,tp,States[i].entryBudget,safe));
   if(safe) return true;
   ExecutionHold=true; PutState(-1,"uncertain",1);
   if(!Tester) GlobalVariablesFlush();
   Log(i,"EXECUTION_BREACH","Missing protection, excessive risk/volume or calculation failure; emergency close requested");
   MqlTick q;
   if(Quote(i,q)) ClosePosition(i,ticket,dir,q,"SAFETY");
   return false;
}

// POSITION MANAGEMENT: always runs before any entry gate. Never increases initial risk.
bool RestorePosition(int i,ulong id)
{
   if(States[i].positionID==id) return States[i].initialR>0;
   if(!HistorySelectByPosition(id)) return false;
   double sl=0; bool own=false,foreign=false;
   for(int k=0;k<HistoryDealsTotal();k++)
   {
      ulong deal=HistoryDealGetTicket(k);
      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT) continue;
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic || entry==DEAL_ENTRY_INOUT) foreign=true;
      else own=true;
      if(sl==0) sl=HistoryDealGetDouble(deal,DEAL_SL);
      if(sl==0) sl=HistoryOrderGetDouble((ulong)HistoryDealGetInteger(deal,DEAL_ORDER),ORDER_SL);
   }
   if(!own || foreign) { Log(i,"NETTING_CONFLICT","Mixed/manual entry history; automatic modifications refused"); return false; }
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   if(sl<=0 || MathAbs(entry-sl)<=0) { Log(i,"STATE_REFUSED","Original SL unavailable; cannot reconstruct initial R"); return false; }
   States[i].positionID=id; States[i].initialSL=sl; States[i].initialR=MathAbs(entry-sl);
   States[i].progressR=0; States[i].progressTime=(datetime)PositionGetInteger(POSITION_TIME);
   string tag=StringFormat("p%I64u",id);
   States[i].progressR=ReadState(i,tag+"r",0);
   States[i].progressTime=(datetime)ReadState(i,tag+"t",(double)States[i].progressTime);
   States[i].mfe=ReadState(i,tag+"mfe"); States[i].mae=ReadState(i,tag+"mae");
   States[i].positionEngine=(int)ReadState(i,tag+"planengine");
   States[i].entryScore=ReadState(i,tag+"planscore");
   States[i].entryBoxHigh=ReadState(i,tag+"planboxhigh");
   States[i].entryBoxLow=ReadState(i,tag+"planboxlow");
   States[i].entryRangeHigh=ReadState(i,tag+"planrangehigh");
   States[i].entryRangeLow=ReadState(i,tag+"planrangelow");
   States[i].invalidationBars=SB_ConfirmCount(ReadState(i,tag+"confirm"));
   States[i].lastManageBar=(datetime)ReadState(i,tag+"managebar");
   States[i].manageATR=ReadState(i,tag+"atr");
   States[i].manageAttemptBar=0; States[i].manageRetryAt=0;
   States[i].auditedMFE=States[i].mfe; States[i].auditedMAE=States[i].mae;
   return true;
}
void ClosePosition(int i,ulong ticket,int dir,MqlTick &q,string reason)
{
   if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL)!=States[i].symbol ||
      (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) return;
   ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string tag=StringFormat("p%I64u",id);
   PutState(i,tag+"exit",1);
   if(!Tester) GlobalVariablesFlush();
   // Never duplicate a close whose server outcome is unknown or still working.
   for(int k=0;k<OrdersTotal();k++)
      if(OrderGetTicket(k)>0 && (ulong)OrderGetInteger(ORDER_POSITION_ID)==id) return;
   if(!PositionSelectByTicket(ticket)) return;
   double volume=PositionGetDouble(POSITION_VOLUME);
   if(ReadState(i,tag+"closeunknown")>0)
   {
      bool observed=false;
      if(volume<ReadState(i,tag+"closevolume")-1e-8 && HistorySelectByPosition(id))
         for(int k=0;k<HistoryDealsTotal();k++)
         {
            ulong deal=HistoryDealGetTicket(k);
            long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
            if((entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY) &&
               (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)==InpMagic &&
               HistoryDealGetInteger(deal,DEAL_TIME)>=(long)ReadState(i,tag+"closeat")) observed=true;
         }
      if(!observed)
      { Log(i,"CLOSE_UNCERTAIN","Ticket close awaiting reconciliation; no duplicate request"); return; }
      PutState(i,tag+"closeunknown",0);
   }
   datetime last=(datetime)ReadState(i,tag+"closeat");
   if(last>0 && TimeCurrent()-last<10) return;
   dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1;
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL; req.position=ticket; req.symbol=States[i].symbol; req.magic=InpMagic;
   req.volume=volume; req.type=dir==1 ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price=dir==1 ? q.bid : q.ask; req.deviation=InpSlippagePoints; req.comment="SB4 "+reason;
   if(!Filling(req.symbol,req.type_filling)) return;
   PutState(i,tag+"closeat",(double)TimeCurrent()); PutState(i,tag+"closevolume",volume);
   PutState(i,tag+"closeunknown",1);
   if(!Tester) GlobalVariablesFlush();
   SendChecked(i,req,res);
   if(res.retcode!=0 && res.retcode!=TRADE_RETCODE_TIMEOUT && res.retcode!=TRADE_RETCODE_CONNECTION &&
      res.retcode!=TRADE_RETCODE_PLACED)
      PutState(i,tag+"closeunknown",0);
   if(!Tester) GlobalVariablesFlush();
}
void ManageTicket(int i,ulong ticket)
{
   string s=States[i].symbol;
   if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL)!=s) return;
   if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) return;
   ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(!VerifyExecution(i,ticket,id)) return;
   if(!PositionSelectByTicket(ticket)) return;
   MqlTick q; if(!Quote(i,q)) return;
   int dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1;
   string tag=StringFormat("p%I64u",id);
   if(DayBlocked || DrawdownBlocked || ReadState(i,tag+"exit")>0 ||
      (InpPatternExit && SB_ConfirmCount(ReadState(i,tag+"confirm"))>=InpInvalidationConfirmBars))
   { ClosePosition(i,ticket,dir,q,DayBlocked || DrawdownBlocked ? "RISK_LIMIT" : "EXIT_RETRY"); return; }
   MqlDateTime now; TimeToStruct(TimeCurrent(),now);
   if(SB_FridayClose(now.day_of_week,now.hour,InpFridayCloseHour))
   { ClosePosition(i,ticket,dir,q,"WEEKEND"); return; }
   if(!RestorePosition(i,id) || !PositionSelectByTicket(ticket)) return;
   double entry=PositionGetDouble(POSITION_PRICE_OPEN),oldSL=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   double price=dir==1 ? q.bid : q.ask, r=dir*(price-entry)/States[i].initialR;
   bool excursionAudit=false;
   if(r>States[i].mfe || -r>States[i].mae)
   {
      States[i].mfe=MathMax(States[i].mfe,r); States[i].mae=MathMax(States[i].mae,-r);
      string tag=StringFormat("p%I64u",id);
      PutState(i,tag+"mfe",States[i].mfe); PutState(i,tag+"mae",States[i].mae);
      if(States[i].mfe>=States[i].auditedMFE+InpProgressStepR)
      { States[i].auditedMFE=States[i].mfe; excursionAudit=true; }
      if(States[i].mae>=States[i].auditedMAE+InpProgressStepR)
      { States[i].auditedMAE=States[i].mae; excursionAudit=true; }
      if(excursionAudit) Audit(i,"EXCURSION",id,PositionGetDouble(POSITION_VOLUME),price);
   }
   if(r>=States[i].progressR+InpProgressStepR)
   {
      States[i].progressR=r; States[i].progressTime=TimeCurrent();
      string tag=StringFormat("p%I64u",id);
      PutState(i,tag+"r",r); PutState(i,tag+"t",(double)TimeCurrent());
   }
   datetime bar=iTime(s,InpEntryTF,0);
   bool data=false;
   bool manageWarmup=States[i].dataReason=="WARMUP";
   if(bar>0 && bar!=States[i].lastManageBar &&
      SB_DataRetryAllowed(bar,States[i].manageAttemptBar,TimeCurrent(),States[i].manageRetryAt,manageWarmup))
   {
      States[i].manageAttemptBar=bar;
      Snapshot d;
      data=LoadData(i,d);
      if(data)
      {
         States[i].manageRetryAt=0;
         States[i].lastManageBar=bar;
         States[i].manageATR=d.atr[0]; States[i].manageDirection=d.direction; States[i].manageADX=d.ha[0];
         if(InpPatternExit && States[i].positionEngine>0)
         {
            bool invalid=SB_PatternInvalidated(States[i].positionEngine,dir,d.bars[0].close,
               States[i].entryBoxHigh,States[i].entryBoxLow,States[i].entryRangeHigh,States[i].entryRangeLow,
               InpInvalidationBufferATR*d.atr[0]);
            string positionTag=StringFormat("p%I64u",id);
            double confirmation=SB_ConfirmState(ReadState(i,positionTag+"confirm"),d.bars[0].time,invalid,InpInvalidationConfirmBars);
            PutState(i,positionTag+"confirm",confirmation);
            States[i].invalidationBars=SB_ConfirmCount(confirmation);
            if(States[i].invalidationBars>=InpInvalidationConfirmBars)
            {
               Audit(i,"PATTERN_INVALID",id,PositionGetDouble(POSITION_VOLUME),price,0,0,
                  StringFormat("engine=%d score=%.2f close=%.8f",States[i].positionEngine,States[i].entryScore,d.bars[0].close));
               ClosePosition(i,ticket,dir,q,"PATTERN_INVALID"); return;
            }
         }
         int idle=iBarShift(s,InpEntryTF,States[i].progressTime,false);
         if(InpTimeExit && idle>=InpNoProgressBars) { ClosePosition(i,ticket,dir,q,"TIME"); return; }
         if(InpInvalidationExit && States[i].manageDirection==-dir && States[i].manageADX>=InpADXMin)
         { ClosePosition(i,ticket,dir,q,"INVALIDATION"); return; }
         PutState(i,tag+"atr",States[i].manageATR); PutState(i,tag+"managebar",(double)bar);
         if(!Tester) GlobalVariablesFlush();
      }
      else States[i].manageRetryAt=TimeCurrent()+60;
   }
   double newSL=oldSL;
   // Restore the original stop if externally removed/loosened, subject to broker constraints.
   if(oldSL==0 || dir*(oldSL-States[i].initialSL)<0) newSL=States[i].initialSL;
   if(InpBreakEven && r>=InpBreakEvenR)
   {
      double target=entry+dir*InpBreakEvenOffsetR*States[i].initialR;
      newSL=dir==1 ? MathMax(newSL,target) : (newSL==0 ? target : MathMin(newSL,target));
   }
   if(States[i].manageATR>0 && InpTrailing && r>=InpTrailingStartR)
   {
      double target=price-dir*InpTrailingATR*States[i].manageATR;
      newSL=dir==1 ? MathMax(newSL,target) : (newSL==0 ? target : MathMin(newSL,target));
   }
   double tick=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);
   newSL=SB_Price(newSL,tick,(int)SymbolInfoInteger(s,SYMBOL_DIGITS),dir<0);
   if(!SB_Tightens(dir,oldSL,newSL,States[i].initialSL)) return;
   if(!StopsValid(s,dir,q,newSL,tp,true)) { Log(i,"MODIFY_DEFERRED","Stops/freeze distance prevents tightening"); return; }
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=s; req.magic=InpMagic; req.sl=newSL; req.tp=tp;
   SendChecked(i,req,res);
}
void Manage(int i)
{
   // Snapshot tickets first: synchronous closes can change the position indices.
   ulong tickets[];
   for(int k=0;k<PositionsTotal();k++)
   {
      ulong ticket=PositionGetTicket(k);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=States[i].symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      int n=ArraySize(tickets); ArrayResize(tickets,n+1); tickets[n]=ticket;
   }
   if(ArraySize(tickets)>1) { ExecutionHold=true; PutState(-1,"uncertain",1); }
   if(ArraySize(tickets)==0) States[i].positionID=0;
   for(int k=0;k<ArraySize(tickets);k++) ManageTicket(i,tickets[k]);
}
void Process()
{
   if(Busy) return; Busy=true;
   UpdateRisk();
   for(int i=0;i<ArraySize(States);i++) Manage(i);
   UpdateRisk(); // A time/invalidation exit can be the third daily loss.
   for(int i=0;i<ArraySize(States);i++)
   {
      datetime bar=iTime(States[i].symbol,InpEntryTF,0);
      if(bar<=0 || bar==States[i].lastBar) continue;
      bool warmup=States[i].dataReason=="WARMUP";
      if(!SB_DataRetryAllowed(bar,States[i].dataAttemptBar,TimeCurrent(),States[i].dataRetryAt,warmup)) continue;
      States[i].dataAttemptBar=bar;
      Snapshot d;
      if(!LoadData(i,d)) { States[i].dataRetryAt=TimeCurrent()+60; continue; }
      States[i].dataRetryAt=0;
      if(iTime(States[i].symbol,InpEntryTF,0)!=bar) continue;
      string engine=""; int dir=Signal(i,d,engine);
      States[i].lastBar=bar; PutState(i,"bar",(double)bar);
      if(dir!=0)
      {
         double score=SetupScore(d,engine,dir);
         if(!InpExpertDecision || score>=InpMinimumSetupScore)
            Enter(i,dir,d,engine,bar,score);
         else
         {
            double candidateVolume=engine=="BREAKOUT" ? d.breakoutVolumeRatio : d.springVolumeRatio;
            Log(i,"QUALITY_REFUSED",StringFormat("engine=%s score=%.2f minimum=%.2f volume=%.3f efficiency=%.3f",
               engine,score,InpMinimumSetupScore,candidateVolume,d.efficiency));
            Audit(i,"SHADOW_SIGNAL",0,0,d.bars[0].close,0,0,
               StringFormat("engine=%s score=%.2f volume=%.3f efficiency=%.3f",engine,score,candidateVolume,d.efficiency));
         }
      }
      else Log(i,"NO_SIGNAL",StringFormat("regime=%d direction=%d range=%d structure=%d volume=%.3f springVolume=%.3f",
         d.regime,d.direction,d.rangeValid,d.structurePattern,d.breakoutVolumeRatio,d.springVolumeRatio));
   }
   Busy=false;
}
void OnTick() { Process(); }
void OnTimer() { Process(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
   {
      LastHistoryScan=0;
      if(HistoryDealSelect(trans.deal))
      {
         string s=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
         for(int i=0;i<ArraySize(States);i++) if(States[i].symbol==s)
         {
            Audit(i,"DEAL",trans.deal,HistoryDealGetDouble(trans.deal,DEAL_VOLUME),
               HistoryDealGetDouble(trans.deal,DEAL_PRICE),0,
               HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+HistoryDealGetDouble(trans.deal,DEAL_FEE)+HistoryDealGetDouble(trans.deal,DEAL_SWAP),
               StringFormat("position=%I64d entry=%d reason=%d profit=%.8f comment=%s",HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID),
               (int)HistoryDealGetInteger(trans.deal,DEAL_ENTRY),(int)HistoryDealGetInteger(trans.deal,DEAL_REASON),
               HistoryDealGetDouble(trans.deal,DEAL_PROFIT),HistoryDealGetString(trans.deal,DEAL_COMMENT)));
         }
      }
      // Force lifecycle revalidation after a manual/netting intervention.
      for(int i=0;i<ArraySize(States);i++) States[i].positionID=0;
   }
}
double OnTester()
{
   long snapshots=0;
   for(int i=0;i<ArraySize(States);i++) snapshots+=States[i].dataSnapshots;
   if(snapshots==0)
   { Log(-1,"TEST_INVALID_DATA","No usable entry/trend snapshot; inspect DATA_WAIT diagnostics and history coverage"); return -2000000; }
   ClosedTrade rows[]; if(!BuildClosed(rows)) return -1000000;
   int months[]; double sums[]; double positive=0,largest=0;
   for(int k=0;k<ArraySize(rows);k++)
   {
      if(!rows[k].own || rows[k].open || rows[k].closed==0) continue;
      MqlDateTime t; TimeToStruct(rows[k].closed,t); int key=t.year*12+t.mon;
      int j=0; for(;j<ArraySize(months);j++) if(months[j]==key) break;
      if(j==ArraySize(months)) { ArrayResize(months,j+1); ArrayResize(sums,j+1); months[j]=key; sums[j]=0; }
      sums[j]+=rows[k].net;
   }
   for(int j=0;j<ArraySize(sums);j++) if(sums[j]>0) { positive+=sums[j]; largest=MathMax(largest,sums[j]); }
   double concentration=positive>0 ? largest/positive : 1;
   double score=SB_Score(TesterStatistics(STAT_PROFIT),TesterStatistics(STAT_INITIAL_DEPOSIT),
      TesterStatistics(STAT_PROFIT_FACTOR),TesterStatistics(STAT_EQUITY_DDREL_PERCENT),
      TesterStatistics(STAT_TRADES),InpTesterMinTrades,concentration);
   PrintFormat("SB4 | TESTER | score=%.6f monthlyConcentration=%.4f; neighbour stability requires external multi-run validation",score,concentration);
   return score;
}
