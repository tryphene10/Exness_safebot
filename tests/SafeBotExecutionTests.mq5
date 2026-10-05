#property strict
// Deterministic broker fault injection. Production Enter/Manage/Close/Verify run unchanged.
// All account, order and position APIs used here are replaced; this script sends no real orders.
struct TestPosition { ulong ticket,id; double volume,entry,sl,tp; long magic; };
TestPosition Book[];
int Selected=-1,Sent=0,Passed=0,Failed=0;
uint Reply=TRADE_RETCODE_DONE;
datetime Now=D'2026.09.10 12:00:00';
double Equity=1000;
MqlTradeRequest LastRequest;
datetime TestTime() { return Now; }
int TestTotal() { return ArraySize(Book); }
bool TestSelect(ulong ticket)
{ Selected=-1; for(int k=0;k<ArraySize(Book);k++) if(Book[k].ticket==ticket) { Selected=k; return true; } return false; }
ulong TestTicket(int index) { if(index<0 || index>=ArraySize(Book)) return 0; Selected=index; return Book[index].ticket; }
long TestInteger(ENUM_POSITION_PROPERTY_INTEGER p)
{
   if(Selected<0) return 0;
   if(p==POSITION_MAGIC) return Book[Selected].magic;
   if(p==POSITION_TICKET) return (long)Book[Selected].ticket;
   if(p==POSITION_IDENTIFIER) return (long)Book[Selected].id;
   if(p==POSITION_TIME) return (long)Now;
   return POSITION_TYPE_BUY;
}
double TestDouble(ENUM_POSITION_PROPERTY_DOUBLE p)
{
   if(Selected<0) return 0;
   if(p==POSITION_VOLUME) return Book[Selected].volume;
   if(p==POSITION_PRICE_OPEN) return Book[Selected].entry;
   if(p==POSITION_SL) return Book[Selected].sl;
   if(p==POSITION_TP) return Book[Selected].tp;
   return 0;
}
string TestString(ENUM_POSITION_PROPERTY_STRING p) { return "EURUSD"; }
int TestOrders() { return 0; }
bool TestHistory(ulong id) { return true; }
int TestDeals() { return 1; }
ulong TestDeal(int k) { return 101; }
long TestDealInteger(ulong t,ENUM_DEAL_PROPERTY_INTEGER p)
{ if(p==DEAL_MAGIC) return Selected>=0 ? Book[Selected].magic : 17092026; return DEAL_ENTRY_IN; }
double TestDealDouble(ulong t,ENUM_DEAL_PROPERTY_DOUBLE p)
{ return p==DEAL_SL && Selected>=0 ? Book[Selected].sl : 0; }
bool TestQuote(string s,MqlTick &q) { ZeroMemory(q); q.bid=1.1; q.ask=1.10005; q.time=Now; return true; }
double TestSymbolDouble(string s,ENUM_SYMBOL_INFO_DOUBLE p)
{
   if(p==SYMBOL_POINT || p==SYMBOL_TRADE_TICK_SIZE) return 0.00001;
   if(p==SYMBOL_VOLUME_MIN || p==SYMBOL_VOLUME_STEP) return 0.01;
   if(p==SYMBOL_VOLUME_MAX) return 100;
   return 0;
}
long TestSymbolInteger(string s,ENUM_SYMBOL_INFO_INTEGER p)
{
   if(p==SYMBOL_DIGITS) return 5;
   if(p==SYMBOL_ORDER_MODE) return SYMBOL_ORDER_MARKET|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
   if(p==SYMBOL_TRADE_MODE) return SYMBOL_TRADE_MODE_FULL;
   if(p==SYMBOL_FILLING_MODE) return SYMBOL_FILLING_FOK;
   if(p==SYMBOL_TRADE_EXEMODE) return SYMBOL_TRADE_EXECUTION_MARKET;
   return 0;
}
double TestAccountDouble(ENUM_ACCOUNT_INFO_DOUBLE p)
{ if(p==ACCOUNT_EQUITY || p==ACCOUNT_MARGIN_FREE) return Equity; return 0; }
long TestAccountInteger(ENUM_ACCOUNT_INFO_INTEGER p) { return 1; }
bool TestProfit(ENUM_ORDER_TYPE type,string s,double volume,double entry,double exit,double &profit)
{ profit=(type==ORDER_TYPE_BUY ? 1 : -1)*(exit-entry)*100000*volume; return true; }
bool TestMargin(ENUM_ORDER_TYPE type,string s,double volume,double entry,double &margin) { margin=volume*100; return true; }
int TestMQL(ENUM_MQL_INFO_INTEGER p) { return 1; }
long TestTerminal(ENUM_TERMINAL_INFO_INTEGER p) { return 1; }
bool TestCheck(const MqlTradeRequest &req,MqlTradeCheckResult &res)
{ ZeroMemory(res); res.retcode=TRADE_RETCODE_DONE; res.equity=Equity; res.margin=1; return true; }
bool TestSend(const MqlTradeRequest &req,MqlTradeResult &res)
{
   Sent++; LastRequest=req; ZeroMemory(res); res.retcode=Reply;
   if(Reply!=TRADE_RETCODE_DONE && Reply!=TRADE_RETCODE_DONE_PARTIAL) return false;
   if(req.position==0)
   {
      int k=ArraySize(Book); ArrayResize(Book,k+1);
      Book[k].ticket=1001+k; Book[k].id=2001+k; Book[k].magic=(long)req.magic;
      Book[k].volume=req.volume*(Reply==TRADE_RETCODE_DONE_PARTIAL ? 0.5 : 1);
      Book[k].entry=req.price; Book[k].sl=req.sl; Book[k].tp=req.tp;
      res.volume=Book[k].volume;
   }
   else if(TestSelect(req.position))
   {
      if(req.action==TRADE_ACTION_SLTP) { Book[Selected].sl=req.sl; Book[Selected].tp=req.tp; }
      else if(Reply==TRADE_RETCODE_DONE_PARTIAL) Book[Selected].volume/=2;
      else { for(int k=Selected;k<ArraySize(Book)-1;k++) Book[k]=Book[k+1]; ArrayResize(Book,ArraySize(Book)-1); Selected=-1; }
   }
   return true;
}
#define TimeCurrent TestTime
#define PositionsTotal TestTotal
#define PositionSelectByTicket TestSelect
#define PositionGetTicket TestTicket
#define PositionGetInteger TestInteger
#define PositionGetDouble TestDouble
#define PositionGetString TestString
#define OrdersTotal TestOrders
#define HistorySelectByPosition TestHistory
#define HistoryDealsTotal TestDeals
#define HistoryDealGetTicket TestDeal
#define HistoryDealGetInteger TestDealInteger
#define HistoryDealGetDouble TestDealDouble
#define SymbolInfoTick TestQuote
#define SymbolInfoDouble TestSymbolDouble
#define SymbolInfoInteger TestSymbolInteger
#define AccountInfoDouble TestAccountDouble
#define AccountInfoInteger TestAccountInteger
#define OrderCalcProfit TestProfit
#define OrderCalcMargin TestMargin
#define MQLInfoInteger TestMQL
#define TerminalInfoInteger TestTerminal
#define OrderCheck TestCheck
#define OrderSend TestSend
#define OnInit UnusedInit
#define OnDeinit UnusedDeinit
#define OnTick UnusedTick
#define OnTimer UnusedTimer
#define OnTradeTransaction UnusedTransaction
#define OnTester UnusedTester
#include "../ExnessSafeBot.mq5"
void Check(bool ok,string name) { if(ok) Passed++; else Failed++; Print("EXEC_TEST | ",ok ? "PASS | " : "FAIL | ",name); }
void ResetFixture()
{
   Tester=true; Prefix="TEST."; ArrayResize(MemoryKeys,0); ArrayResize(MemoryValues,0);
   ArrayResize(States,1); ZeroMemory(States[0]); States[0].symbol="EURUSD";
   ArrayResize(Book,0); Selected=-1; Sent=0; Reply=TRADE_RETCODE_DONE;
   Now=D'2026.09.10 12:00:00'; Equity=1000; DayEquity=Peak=1000; CashTotal=DayCash=PeakCash=0;
   CashOK=HistoryOK=PersistenceOK=true; DayBlocked=DrawdownBlocked=LossBlocked=ExecutionHold=false;
}
void OpenFixture()
{
   Snapshot d; ArrayResize(d.atr,1); ArrayResize(d.bars,1); d.atr[0]=0.001;
   d.bars[0].time=Now-3600; d.bars[0].close=1.1; d.efficiency=0.8;
   d.rangeHigh=1.11; d.rangeLow=1.09; d.breakoutVolumeRatio=d.springVolumeRatio=1.5;
   Enter(0,1,d,"BREAKOUT",Now,90);
}
void OnStart()
{
   ResetFixture(); OpenFixture();
   Check(Sent==1 && TestTotal()==1,"production entry sends protected market request");
   Check(LastRequest.sl>0 && LastRequest.tp>0 && LastRequest.volume>0,"entry contains SL TP and volume");
   TestSelect(1001); Check(VerifyExecution(0,1001,2001),"filled position reconciles to original budget");
   Check(ReadState(0,"p2001bound")==1,"plan bound to lifecycle identifier");
   MqlTick q; TestQuote("EURUSD",q);
   Reply=TRADE_RETCODE_REJECT; ClosePosition(0,1001,1,q,"PATTERN_INVALID");
   Check(Sent==2 && TestTotal()==1 && ReadState(0,"p2001exit")==1,"rejected exit stays pending");
   Manage(0); Check(Sent==2,"retry throttled within ten seconds");
   States[0].positionID=0; Now+=11; Reply=TRADE_RETCODE_DONE; TestQuote("EURUSD",q);
   Manage(0); Check(Sent==3 && TestTotal()==0,"pending exit survives runtime reset and closes within same H1 bar");
   ResetFixture(); OpenFixture(); TestSelect(1001); VerifyExecution(0,1001,2001);
   Reply=TRADE_RETCODE_DONE_PARTIAL; TestQuote("EURUSD",q); ClosePosition(0,1001,1,q,"TIME");
   double remaining=Book[0].volume; Now+=11; Reply=TRADE_RETCODE_DONE; Manage(0);
   Check(TestTotal()==0 && MathAbs(LastRequest.volume-remaining)<1e-8,"partial close retries only remaining ticket volume");
   ResetFixture(); OpenFixture(); TestSelect(1001); VerifyExecution(0,1001,2001);
   Reply=TRADE_RETCODE_TIMEOUT; TestQuote("EURUSD",q); ClosePosition(0,1001,1,q,"TIME");
   Now+=30; Reply=TRADE_RETCODE_DONE; Manage(0);
   Check(Sent==2 && TestTotal()==1,"unknown close result never blindly resubmitted");
   Book[0].volume/=2; Now+=30; Manage(0);
   Check(Sent==2,"volume reduction without matching exit history cannot resolve timeout");
   ResetFixture(); OpenFixture(); DayBlocked=true; Manage(0);
   Check(TestTotal()==0,"daily equity stop closes own ticket");
   ResetFixture(); OpenFixture(); DrawdownBlocked=true; Manage(0);
   Check(TestTotal()==0,"drawdown stop closes own ticket");
   ResetFixture(); OpenFixture(); TestSelect(1001); VerifyExecution(0,1001,2001);
   ArrayResize(Book,3); Book[1]=Book[0]; Book[1].ticket=1002; Book[1].id=2002;
   Book[2]=Book[0]; Book[2].ticket=999; Book[2].id=1999; Book[2].magic=55;
   DayBlocked=true; Manage(0);
   Check(TestTotal()==1 && Book[0].magic==55,"all own hedging tickets close while manual position survives");
   ResetFixture(); Equity=985.5; OpenFixture(); Check(Sent==0,"remaining daily budget rejects unaffordable minimum lot");
   Check(MathAbs(SB_RemainingBudget(5,986,1000,1000,1.5,8)-1)<1e-8,"daily remaining capacity caps new risk");
   Check(MathAbs(SB_RemainingBudget(5,921,930,1000,1.5,8)-1)<1e-8,"drawdown remaining capacity caps new risk");
   Check(SB_RemainingBudget(5,984,1000,1000,1.5,8)==0,"exhausted capacity returns zero");
   ResetFixture(); States[0].armed=true; States[0].compressionID=Now-3600;
   States[0].boxHigh=1.12; States[0].boxLow=1.09; SaveCompression(0);
   States[0].armed=false; States[0].boxHigh=0; RestoreCompression(0);
   Check(States[0].armed && States[0].boxHigh==1.12,"compression restored unchanged");
   PutState(0,"boxready",0); RestoreCompression(0); Check(!States[0].armed,"incomplete compression commit cannot arm");
   double state=SB_ConfirmState(0,Now-3600,true,2);
   PutState(0,"p2001confirm",state);
   state=SB_ConfirmState(ReadState(0,"p2001confirm"),Now-3600,true,2);
   Check(SB_ConfirmCount(state)==1,"same closed candle after restart cannot double count");
   state=SB_ConfirmState(state,Now,true,2); Check(SB_ConfirmCount(state)==2,"second distinct candle confirms invalidation");
   state=SB_ConfirmState(state,Now+3600,false,2); Check(SB_ConfirmCount(state)==0,"valid candle resets sequence");
   ResetFixture(); Reply=TRADE_RETCODE_DONE_PARTIAL; OpenFixture(); TestSelect(1001);
   Check(VerifyExecution(0,1001,2001),"partial entry fill reconciles below budget");
   ResetFixture(); OpenFixture(); TestSelect(1001); Book[0].sl=0; VerifyExecution(0,1001,2001);
   Check(TestTotal()==0 && ExecutionHold,"missing broker SL triggers emergency close and hold");
   ResetFixture(); OpenFixture(); Book[0].volume*=2; TestSelect(1001); VerifyExecution(0,1001,2001);
   Check(TestTotal()==0 && ExecutionHold,"excessive broker fill triggers emergency close");
   ResetFixture(); OpenFixture(); Book[0].magic=55; Book[0].sl=0; double reserved=0;
   Check(!ReservedRisk(reserved),"external position without SL blocks new risk");
   Book[0].sl=1.098;
   Check(ReservedRisk(reserved) && reserved>0,"external protected exposure consumes remaining capacity");
   Prefix="SB4.1234567890123456789.1234567890."; States[0].symbol="SYMBOL_WITH_LONG_SUFFIX";
   Check(StringLen(Key(0,"p18446744073709551615planrangehigh"))<=63,"long lifecycle persistence key fits terminal limit");
   int file=FileOpen("SB4-execution-tests.txt",FILE_WRITE|FILE_TXT);
   if(file!=INVALID_HANDLE) { FileWrite(file,StringFormat("PASS=%d FAIL=%d",Passed,Failed)); FileClose(file); }
   PrintFormat("EXEC_TEST_RESULT | PASS=%d FAIL=%d",Passed,Failed);
}
