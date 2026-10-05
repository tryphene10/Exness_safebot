#property strict
#define OnInit UnusedInit
#define OnDeinit UnusedDeinit
#define OnTick UnusedTick
#define OnTimer UnusedTimer
#define OnTradeTransaction UnusedTransaction
#define OnTester UnusedTester
#include "../ExnessSafeBot.mq5"
void OnStart()
{
   Tester=false; Prefix="SB4_TEST_RESTART.";
   GlobalVariablesDeleteAll(Prefix);
   ArrayResize(States,1); ZeroMemory(States[0]); States[0].symbol="EURUSD";
   States[0].armed=true; States[0].compressionID=D'2026.09.10 10:00:00';
   States[0].boxHigh=1.12; States[0].boxLow=1.09; SaveCompression(0);
   PutState(0,"p123confirm",SB_ConfirmState(0,D'2026.09.10 11:00:00',true,2));
   PutState(0,"p123exit",1); PutState(0,"p123closeat",(double)D'2026.09.10 11:15:00');
   PutState(0,"p123closeunknown",1); PutState(0,"p123closevolume",0.02);
   GlobalVariablesFlush();
   int file=FileOpen("SB4-restart-write.txt",FILE_WRITE|FILE_TXT);
   if(file!=INVALID_HANDLE) { FileWrite(file,StringFormat("PASS=%d FAIL=%d",PersistenceOK ? 1 : 0,PersistenceOK ? 0 : 1)); FileClose(file); }
}
