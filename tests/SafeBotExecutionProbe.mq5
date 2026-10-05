#property strict
// Native MT5 tester only: actual OrderCheck/OrderSend/history, synthetic market data.
#define OnInit ProductionInit
#define OnDeinit ProductionDeinit
#define OnTick ProductionTick
#define OnTimer ProductionTimer
#define OnTradeTransaction ProductionTransaction
#define OnTester ProductionTester
#include "../ExnessSafeBot.mq5"
#undef OnInit
#undef OnDeinit
#undef OnTick
#undef OnTimer
#undef OnTradeTransaction
#undef OnTester
int Phase=0,Passed=0,Failed=0;
datetime EntryBar=0;
void Check(bool ok,string name) { if(ok) Passed++; else Failed++; Print("NATIVE_EXEC | ",ok ? "PASS | " : "FAIL | ",name); }
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   return ProductionInit();
}
void OnTimer() {}
void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &q,const MqlTradeResult &r)
{ ProductionTransaction(t,q,r); }
void OnTick()
{
   if(Phase>=4) return;
   UpdateRisk();
   if(Phase==0 || Phase==2)
   {
      datetime bar=iTime(_Symbol,PERIOD_H1,0);
      if(bar==EntryBar || !Session()) return;
      Snapshot d; if(!LoadData(0,d)) return;
      // A controlled eligible candidate exercises execution independently of signal frequency.
      d.atr[0]=0.002; d.efficiency=0.8;
      Enter(0,1,d,"SPRING",bar,90);
      if(PositionsTotal()==0) return;
      EntryBar=bar;
      ulong ticket=PositionGetTicket(0),id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      Check(PositionGetDouble(POSITION_SL)>0 && PositionGetDouble(POSITION_TP)>0,"native fill has SL and TP");
      Check(VerifyExecution(0,ticket,id),"native fill matches monetary budget");
      if(Phase==0)
      {
         PutState(0,StringFormat("p%I64u",id)+"exit",1);
         States[0].positionID=0; // Restore from lifecycle state before retry.
      }
      else DayBlocked=true;
      Phase++;
   }
   if(Phase==1 || Phase==3)
   {
      Manage(0);
      if(PositionsTotal()>0) return;
      Check(true,Phase==1 ? "native pending exit closes position" : "native daily stop closes position");
      ClosedTrade rows[];
      Check(BuildClosed(rows) && ArraySize(rows)==(Phase==1 ? 1 : 2),"complete position lifecycle present in broker history");
      Phase++;
   }
}
void OnDeinit(const int reason) { ProductionDeinit(reason); }
double OnTester()
{
   Check(Phase==4 && PositionsTotal()==0,"both native execution cycles complete");
   PrintFormat("NATIVE_EXEC_RESULT | PASS=%d FAIL=%d",Passed,Failed);
   return Failed==0 ? Passed : -Failed;
}
