#property strict
#define OnInit UnusedInit
#define OnDeinit UnusedDeinit
#define OnTick UnusedTick
#define OnTimer UnusedTimer
#define OnTradeTransaction UnusedTransaction
#define OnTester UnusedTester
#include "../ExnessSafeBot.mq5"
int Passed=0,Failed=0;
void Check(bool ok,string name) { if(ok) Passed++; else Failed++; Print("RESTART | ",ok ? "PASS | " : "FAIL | ",name); }
void OnStart()
{
   Tester=false; Prefix="SB4_TEST_RESTART.";
   ArrayResize(States,1); ZeroMemory(States[0]); States[0].symbol="EURUSD";
   RestoreCompression(0);
   Check(States[0].armed && States[0].boxHigh==1.12 && States[0].boxLow==1.09 &&
         States[0].compressionID==D'2026.09.10 10:00:00',"compression survives terminal restart");
   double confirmation=SB_ConfirmState(ReadState(0,"p123confirm"),D'2026.09.10 11:00:00',true,2);
   Check(SB_ConfirmCount(confirmation)==1,"persisted candle cannot count twice after restart");
   Check(ReadState(0,"p123exit")==1,"pending exit survives terminal restart");
   Check(ReadState(0,"p123closeunknown")==1 && ReadState(0,"p123closevolume")==0.02 &&
         (datetime)ReadState(0,"p123closeat")==D'2026.09.10 11:15:00',"uncertain close reconciliation state survives restart");
   GlobalVariablesDeleteAll(Prefix);
   int file=FileOpen("SB4-restart-read.txt",FILE_WRITE|FILE_TXT);
   if(file!=INVALID_HANDLE) { FileWrite(file,StringFormat("PASS=%d FAIL=%d",Passed,Failed)); FileClose(file); }
}
