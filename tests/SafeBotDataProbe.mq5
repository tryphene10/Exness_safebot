#property strict
#define OnInit UnusedInit
#define OnDeinit UnusedDeinit
#define OnTick UnusedTick
#define OnTimer UnusedTimer
#define OnTradeTransaction UnusedTransaction
#define OnTester UnusedTester
#include "../ExnessSafeBot.mq5"
#undef OnInit
#undef OnDeinit
#undef OnTick
#undef OnTimer
#undef OnTradeTransaction
#undef OnTester
long Good=0,Invalid=0,OldSkipped=0;
int OnInit() { return UnusedInit(); }
void OnTimer() {} // No trading, test data loading only.
void OnTick()
{
   int i=0;
   // Reproduce the former gate on an independent, never-requested handle.
   static int oldHandle=INVALID_HANDLE;
   if(oldHandle==INVALID_HANDLE) oldHandle=iMA(_Symbol,PERIOD_H1,21,0,MODE_EMA,PRICE_CLOSE);
   if(BarsCalculated(oldHandle)<4) OldSkipped++;
   Snapshot d;
   if(LoadData(i,d))
   {
      Good++;
      if(d.bars[0].time>=iTime(_Symbol,PERIOD_H1,0) || d.atr[0]<=0 || d.hv[0]<=0) Invalid++;
   }
}
void OnDeinit(const int reason) { UnusedDeinit(reason); }
double OnTester()
{
   bool ok=Good>0 && Invalid==0 && OldSkipped>0;
   PrintFormat("SB3_DATA_PROBE | PASS=%d ready=%I64d invalid=%I64d old_gate_skipped=%I64d",ok,Good,Invalid,OldSkipped);
   int f=FileOpen("SB3-data-probe.txt",FILE_WRITE|FILE_TXT);
   if(f!=INVALID_HANDLE) { FileWrite(f,StringFormat("PASS=%d ready=%I64d invalid=%I64d old_gate_skipped=%I64d",ok,Good,Invalid,OldSkipped)); FileClose(f); }
   return ok ? 1 : -1;
}
