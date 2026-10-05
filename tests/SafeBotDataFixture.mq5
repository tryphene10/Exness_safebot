#property strict
#define OnInit FixtureUnusedInit
#define OnDeinit FixtureUnusedDeinit
#define OnTick FixtureUnusedTick
#define OnTimer FixtureUnusedTimer
#define OnTradeTransaction FixtureUnusedTransaction
#define OnTester FixtureUnusedTester
#include "../ExnessSafeBot.mq5"
// Isolated, synthetic data for the nonvisual loading regression. No orders.
void OnStart()
{
   string s="SB3_DataFixture";
   bool custom=false;
   if(!SymbolExist(s,custom) && !CustomSymbolCreate(s,"SafeBotTests")) return;
   if(SymbolExist(s,custom) && !custom) return;
   CustomSymbolSetInteger(s,SYMBOL_DIGITS,5);
   CustomSymbolSetDouble(s,SYMBOL_POINT,0.00001);
   CustomSymbolSetDouble(s,SYMBOL_TRADE_TICK_SIZE,0.00001);
   // Tradable specification for the isolated native Strategy Tester execution probe.
   CustomSymbolSetString(s,SYMBOL_CURRENCY_BASE,"EUR");
   CustomSymbolSetString(s,SYMBOL_CURRENCY_PROFIT,"USD");
   CustomSymbolSetString(s,SYMBOL_CURRENCY_MARGIN,"USD");
   CustomSymbolSetInteger(s,SYMBOL_TRADE_CALC_MODE,SYMBOL_CALC_MODE_CFDLEVERAGE);
   CustomSymbolSetInteger(s,SYMBOL_TRADE_MODE,SYMBOL_TRADE_MODE_FULL);
   CustomSymbolSetInteger(s,SYMBOL_TRADE_EXEMODE,SYMBOL_TRADE_EXECUTION_MARKET);
   CustomSymbolSetInteger(s,SYMBOL_FILLING_MODE,SYMBOL_FILLING_FOK);
   CustomSymbolSetInteger(s,SYMBOL_ORDER_MODE,SYMBOL_ORDER_MARKET|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP);
   CustomSymbolSetDouble(s,SYMBOL_TRADE_CONTRACT_SIZE,100000);
   CustomSymbolSetDouble(s,SYMBOL_VOLUME_MIN,0.01);
   CustomSymbolSetDouble(s,SYMBOL_VOLUME_STEP,0.01);
   CustomSymbolSetDouble(s,SYMBOL_VOLUME_MAX,100);
   MqlDateTime session; ZeroMemory(session); session.hour=23; session.min=59; session.sec=59;
   for(int day=1;day<=5;day++)
   {
      CustomSymbolSetSessionTrade(s,(ENUM_DAY_OF_WEEK)day,0,0,StructToTime(session));
      CustomSymbolSetSessionQuote(s,(ENUM_DAY_OF_WEEK)day,0,0,StructToTime(session));
   }
   MqlRates rates[]; int n=90*1440;
   ArrayResize(rates,n);
   datetime start=D'2023.01.01';
   for(int k=0;k<n;k++)
   {
      rates[k].time=start+k*60;
      rates[k].open=1.10+0.005*MathSin(k/900.0)+k*0.0000001;
      rates[k].close=rates[k].open+0.00002*MathSin(k/7.0);
      rates[k].high=MathMax(rates[k].open,rates[k].close)+0.0001;
      rates[k].low=MathMin(rates[k].open,rates[k].close)-0.0001;
      rates[k].tick_volume=10; rates[k].spread=10; rates[k].real_volume=0;
   }
   int added=CustomRatesUpdate(s,rates);
   SymbolSelect(s,true);
   PrintFormat("SB3_DATA_FIXTURE | synthetic M1 bars=%d",added);
   Tester=true; ArrayResize(States,1); ZeroMemory(States[0]); States[0].symbol=s;
   States[0].fast=iMA(s,PERIOD_H1,20,0,MODE_EMA,PRICE_CLOSE);
   States[0].slow=iMA(s,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE);
   States[0].rsi=iRSI(s,PERIOD_H1,14,PRICE_CLOSE);
   States[0].atr=iATR(s,PERIOD_H1,14);
   States[0].adx=iADX(s,PERIOD_H1,14);
   States[0].htFast=iMA(s,PERIOD_H4,50,0,MODE_EMA,PRICE_CLOSE);
   States[0].htSlow=iMA(s,PERIOD_H4,200,0,MODE_EMA,PRICE_CLOSE);
   States[0].htADX=iADX(s,PERIOD_H4,14);
   States[0].htATR=iATR(s,PERIOD_H4,14);
   Snapshot d; bool ok=false;
   for(int attempt=0;attempt<20 && !ok;attempt++)
   { ok=LoadData(0,d); if(!ok) Sleep(100); }
   bool closed=ok && d.bars[0].time<iTime(s,PERIOD_H1,0) && d.atr[0]>0 && d.hv[0]>0;
   int f=FileOpen("SB3-data-integration.txt",FILE_WRITE|FILE_TXT);
   if(f!=INVALID_HANDLE) { FileWrite(f,StringFormat("PASS=%d ready=%I64d barsH1=%d barsH4=%d",closed,States[0].dataSnapshots,Bars(s,PERIOD_H1),Bars(s,PERIOD_H4))); FileClose(f); }
   PrintFormat("SB3_DATA_INTEGRATION | PASS=%d",closed);
   int handles[]={States[0].fast,States[0].slow,States[0].rsi,States[0].atr,States[0].adx,States[0].htFast,States[0].htSlow,States[0].htADX,States[0].htATR};
   for(int j=0;j<ArraySize(handles);j++) IndicatorRelease(handles[j]);
}
